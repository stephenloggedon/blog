defmodule Blog.OTLPLoggerBackend do
  @moduledoc """
  A custom logger backend that forwards structured logs to Grafana Cloud via OTLP HTTP/protobuf.

  This backend converts Elixir log messages to OpenTelemetry log records and sends them
  to the configured OTLP endpoint using HTTP/protobuf protocol.
  """

  @behaviour :gen_event

  defstruct [:level, :metadata, :endpoint, :headers]

  def init(__MODULE__) do
    init({__MODULE__, []})
  end

  def init({__MODULE__, opts}) do
    config = configure(opts)
    {:ok, config}
  end

  def handle_call({:configure, opts}, _state) do
    config = configure(opts)
    {:ok, :ok, config}
  end

  def handle_event({level, _gl, {Logger, msg, timestamp, metadata}}, state) do
    if Logger.compare_levels(level, state.level) != :lt do
      send_log(level, msg, timestamp, metadata, state)
    end

    {:ok, state}
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  # Private functions

  defp configure(opts) do
    endpoint = get_otlp_endpoint(opts)
    headers = get_otlp_headers(opts)
    level = Keyword.get(opts, :level, :info)
    metadata = Keyword.get(opts, :metadata, [:request_id, :trace_id, :span_id])

    %__MODULE__{
      level: level,
      metadata: metadata,
      endpoint: endpoint,
      headers: headers
    }
  end

  defp get_otlp_endpoint(opts) do
    System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") ||
      Keyword.get(opts, :endpoint)
  end

  defp get_otlp_headers(opts) do
    base_headers = [{"Content-Type", "application/json"}]

    case System.get_env("OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION") do
      nil ->
        Keyword.get(opts, :headers, []) ++ base_headers

      auth ->
        [{"Authorization", "Basic #{auth}"} | base_headers]
    end
  end

  defp send_log(level, msg, timestamp, metadata, state) do
    if state.endpoint do
      log_record = build_log_record(level, msg, timestamp, metadata)
      send_to_otlp(log_record, state)
    end
  end

  defp build_log_record(level, msg, timestamp, metadata) do
    # Convert timestamp to Unix nanoseconds - handle different timestamp formats
    unix_nano = convert_timestamp_to_nano(timestamp)

    # Build OpenTelemetry log record in JSON format (simplified protobuf representation)
    %{
      "resourceLogs" => [
        %{
          "resource" => %{
            "attributes" => [
              %{"key" => "service.name", "value" => %{"stringValue" => "blog"}},
              %{"key" => "service.version", "value" => %{"stringValue" => "0.1.0"}},
              %{
                "key" => "deployment.environment",
                "value" => %{"stringValue" => get_environment()}
              }
            ]
          },
          "scopeLogs" => [
            %{
              "scope" => %{
                "name" => "elixir.logger",
                "version" => "1.0.0"
              },
              "logRecords" => [
                %{
                  "timeUnixNano" => unix_nano,
                  "severityNumber" => severity_number(level),
                  "severityText" => String.upcase(to_string(level)),
                  "body" => %{"stringValue" => format_message_with_metadata(msg, metadata)},
                  "attributes" => build_attributes(metadata),
                  "traceId" => get_trace_id(metadata),
                  "spanId" => get_span_id(metadata)
                }
              ]
            }
          ]
        }
      ]
    }
  end

  defp get_environment do
    case Application.get_env(:blog, :environment) do
      nil ->
        # In releases, Mix.env is not available, so determine from other indicators
        cond do
          Application.get_env(:blog, BlogWeb.Endpoint)[:server] == true ->
            "production"

          Code.ensure_loaded?(IEx) ->
            "development"

          true ->
            "production"
        end

      env ->
        to_string(env)
    end
  end

  defp build_attributes(metadata) do
    metadata
    |> Enum.filter(fn {key, _value} -> key not in [:trace_id, :span_id] end)
    |> Enum.map(fn {key, value} ->
      %{
        "key" => to_string(key),
        "value" => %{"stringValue" => format_value(value)}
      }
    end)
  end

  defp get_trace_id(metadata) do
    case Keyword.get(metadata, :trace_id) do
      nil -> ""
      trace_id -> format_trace_id(trace_id)
    end
  end

  defp get_span_id(metadata) do
    case Keyword.get(metadata, :span_id) do
      nil -> ""
      span_id -> format_span_id(span_id)
    end
  end

  defp format_trace_id(trace_id) when is_integer(trace_id) do
    trace_id |> Integer.to_string(16) |> String.pad_leading(32, "0")
  end

  defp format_trace_id(trace_id) when is_binary(trace_id), do: trace_id
  defp format_trace_id(_), do: ""

  defp format_span_id(span_id) when is_integer(span_id) do
    span_id |> Integer.to_string(16) |> String.pad_leading(16, "0")
  end

  defp format_span_id(span_id) when is_binary(span_id), do: span_id
  defp format_span_id(_), do: ""

  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_atom(value), do: to_string(value)
  defp format_value(value) when is_number(value), do: to_string(value)
  defp format_value(value), do: inspect(value)

  # OpenTelemetry severity numbers mapping
  @severity_map %{
    emergency: 21,
    alert: 18,
    critical: 17,
    error: 13,
    warning: 9,
    notice: 5,
    info: 5,
    debug: 1
  }

  defp severity_number(level) do
    Map.get(@severity_map, level, 5)
  end

  defp convert_timestamp_to_nano(timestamp) do
    case timestamp do
      # Erlang datetime tuple format: {{year, month, day}, {hour, minute, second, microsecond}}
      {{year, month, day}, {hour, minute, second, microsecond}} ->
        # Convert to DateTime and then to nanoseconds
        case DateTime.new(
               Date.new!(year, month, day),
               Time.new!(hour, minute, second, {microsecond, 6})
             ) do
          {:ok, dt} -> DateTime.to_unix(dt, :nanosecond)
          {:error, _} -> DateTime.utc_now() |> DateTime.to_unix(:nanosecond)
        end

      # Unix microsecond timestamp (integer)
      microsecond_timestamp when is_integer(microsecond_timestamp) ->
        microsecond_timestamp
        |> DateTime.from_unix!(:microsecond)
        |> DateTime.to_unix(:nanosecond)

      # Already a DateTime struct
      %DateTime{} = dt ->
        DateTime.to_unix(dt, :nanosecond)

      # Fallback: use current time
      _ ->
        DateTime.utc_now() |> DateTime.to_unix(:nanosecond)
    end
  end

  defp format_message_with_metadata(msg, metadata) do
    structured_data =
      metadata
      |> Enum.reduce(%{message: to_string(msg)}, fn {key, value}, acc ->
        Map.put(acc, to_string(key), format_value(value))
      end)

    Jason.encode!(structured_data)
  end

  defp send_to_otlp(log_record, state) do
    if state.endpoint do
      endpoint = "#{state.endpoint}/v1/logs"
      body = Jason.encode!(log_record)

      request = Finch.build(:post, endpoint, state.headers, body)

      case Finch.request(request, Blog.Finch, receive_timeout: 5_000) do
        {:ok, %{status: status}} when status in 200..299 ->
          :ok

        {:ok, %{status: status}} ->
          # Log OTLP export failures to console only (avoid infinite loop)
          IO.puts("OTLP log export failed with status: #{status}")
          :error

        {:error, reason} ->
          IO.puts("OTLP log export error: #{inspect(reason)}")
          :error
      end
    else
      :ok
    end
  rescue
    error ->
      IO.puts("OTLP log export exception: #{inspect(error)}")
      :error
  end
end
