defmodule BlogWeb.Plugs.RequestLogger do
  @moduledoc """
  Plug for structured logging of HTTP requests with OpenTelemetry context.

  Captures request details, response status, timing, and client information
  in a structured format for better observability.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time()

    register_before_send(conn, fn conn ->
      duration = System.monotonic_time() - start_time
      duration_ms = System.convert_time_unit(duration, :native, :millisecond)
      remote_ip = get_client_ip(conn)
      geo_data = Blog.GeoIP.lookup_for_logging(remote_ip)

      Logger.info("HTTP request completed",
        method: conn.method,
        path: conn.request_path,
        status: conn.status,
        duration_ms: duration_ms,
        user_agent: get_user_agent(conn),
        remote_ip: remote_ip,
        query_string: conn.query_string,
        response_size: get_response_size(conn),
        request_id: Logger.metadata()[:request_id],
        country: geo_data.country,
        country_code: geo_data.country_code,
        ip_type: geo_data.ip_type
      )

      conn
    end)
  end

  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      [] -> "unknown"
    end
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_ip | _] ->
        forwarded_ip
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        case conn.remote_ip do
          {a, b, c, d} ->
            "#{a}.#{b}.#{c}.#{d}"

          {a, b, c, d, e, f, g, h} ->
            parts = [a, b, c, d, e, f, g, h]
            Enum.map_join(parts, ":", &Integer.to_string(&1, 16))

          _ ->
            "unknown"
        end
    end
  end

  defp get_response_size(conn) do
    case get_resp_header(conn, "content-length") do
      [size_str | _] ->
        case Integer.parse(size_str) do
          {size, _} -> size
          :error -> 0
        end

      [] ->
        0
    end
  end
end
