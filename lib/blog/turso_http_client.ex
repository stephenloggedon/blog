defmodule Blog.TursoHttpClient do
  @moduledoc """
  HTTP client for Turso database with proper BLOB support.
  
  This client uses Turso's HTTP API directly to support BLOB data
  via base64 encoding, which libsqlex doesn't handle correctly.
  """
  
  require Logger
  
  @base_headers [
    {"Content-Type", "application/json"},
    {"Accept", "application/json"}
  ]
  
  @doc """
  Executes a SQL statement with proper BLOB parameter support.
  """
  def execute(sql, params \\ []) do
    with {:ok, config} <- get_config(),
         {:ok, request_body} <- build_request(sql, params),
         {:ok, response} <- send_request(config, request_body) do
      parse_response(response)
    end
  end
  
  @doc """
  Executes a query and returns only the first row.
  """
  def query_one(sql, params \\ []) do
    case execute(sql, params) do
      {:ok, %{rows: [row]}} -> {:ok, row}
      {:ok, %{rows: []}} -> {:ok, nil}
      {:ok, %{rows: rows}} when length(rows) > 1 -> 
        {:error, "Expected single row, got #{length(rows)}"}
      error -> error
    end
  end
  
  @doc """
  Starts a transaction and executes multiple statements.
  """
  def transaction(statements) when is_list(statements) do
    with {:ok, config} <- get_config(),
         {:ok, request_body} <- build_transaction_request(statements),
         {:ok, response} <- send_request(config, request_body) do
      parse_transaction_response(response)
    end
  end
  
  defp get_config do
    case {System.get_env("LIBSQL_URI"), System.get_env("LIBSQL_TOKEN")} do
      {nil, _} -> {:error, "LIBSQL_URI not configured"}
      {_, nil} -> {:error, "LIBSQL_TOKEN not configured"}
      {uri, token} -> 
        # Convert libsql:// to https://
        http_uri = String.replace(uri, "libsql://", "https://")
        {:ok, %{uri: http_uri, token: token}}
    end
  end
  
  defp build_request(sql, params) do
    args = Enum.map(params, &encode_parameter/1)
    
    request = %{
      requests: [
        %{
          type: "execute",
          stmt: %{
            sql: sql,
            args: args
          }
        }
      ]
    }
    
    {:ok, Jason.encode!(request)}
  end
  
  defp build_transaction_request(statements) do
    requests = [
      %{type: "execute", stmt: %{sql: "BEGIN"}}
    ] ++ 
    Enum.map(statements, fn {sql, params} ->
      args = Enum.map(params, &encode_parameter/1)
      %{
        type: "execute",
        stmt: %{
          sql: sql,
          args: args
        }
      }
    end) ++ [
      %{type: "execute", stmt: %{sql: "COMMIT"}}
    ]
    
    request = %{requests: requests}
    {:ok, Jason.encode!(request)}
  end
  
  defp encode_parameter(value) when is_binary(value) do
    # Check if it's likely binary data (non-printable characters)
    if String.printable?(value) do
      %{type: "text", value: value}
    else
      # Encode binary data as base64 BLOB
      %{type: "blob", base64: Base.encode64(value)}
    end
  end
  
  defp encode_parameter(value) when is_integer(value) do
    %{type: "integer", value: to_string(value)}
  end
  
  defp encode_parameter(value) when is_float(value) do
    %{type: "float", value: to_string(value)}
  end
  
  defp encode_parameter(value) when is_boolean(value) do
    %{type: "integer", value: if(value, do: "1", else: "0")}
  end
  
  defp encode_parameter(nil) do
    %{type: "null"}
  end
  
  # For explicit BLOB data
  defp encode_parameter({:blob, binary}) when is_binary(binary) do
    %{type: "blob", base64: Base.encode64(binary)}
  end
  
  defp send_request(%{uri: uri, token: token}, body) do
    url = "#{uri}/v2/pipeline"
    headers = @base_headers ++ [{"Authorization", "Bearer #{token}"}]
    
    case Finch.build(:post, url, headers, body) |> Finch.request(Blog.Finch) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}
      
      {:ok, %{status: status, body: error_body}} ->
        Logger.error("Turso HTTP request failed: #{status} - #{error_body}")
        {:error, "HTTP #{status}: #{error_body}"}
      
      {:error, error} ->
        Logger.error("Turso HTTP request error: #{inspect(error)}")
        {:error, "Network error: #{inspect(error)}"}
    end
  end
  
  defp parse_response(%{"results" => [result]}) do
    case result do
      %{"type" => "ok", "response" => %{"result" => response_result}} ->
        cols = Map.get(response_result, "cols", [])
        rows = Map.get(response_result, "rows", [])
        
        {:ok, %{
          columns: Enum.map(cols, & &1["name"]),
          rows: decode_rows(rows),
          num_rows: length(rows)
        }}
      
      %{"type" => "error", "error" => error} ->
        {:error, error["message"]}
    end
  end
  
  defp parse_response(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
  
  defp parse_transaction_response(%{"results" => results}) do
    case Enum.find(results, fn result -> result["type"] == "error" end) do
      nil -> {:ok, :transaction_committed}
      error -> {:error, error["error"]["message"]}
    end
  end
  
  defp decode_rows(rows) do
    Enum.map(rows, &decode_row/1)
  end
  
  defp decode_row(row) when is_list(row) do
    Enum.map(row, &decode_value/1)
  end
  
  defp decode_value(%{"type" => "blob", "base64" => base64}) do
    case Base.decode64(base64) do
      {:ok, binary} -> binary
      :error -> 
        IO.puts("Warning: Failed to decode base64 BLOB: #{inspect(base64)}")
        base64  # Return the base64 string if decoding fails
    end
  end
  
  defp decode_value(%{"type" => "text", "value" => value}), do: value
  defp decode_value(%{"type" => "integer", "value" => value}) when is_binary(value), do: String.to_integer(value)
  defp decode_value(%{"type" => "integer", "value" => value}) when is_integer(value), do: value
  defp decode_value(%{"type" => "float", "value" => value}) when is_binary(value), do: String.to_float(value)
  defp decode_value(%{"type" => "float", "value" => value}) when is_float(value), do: value
  defp decode_value(%{"type" => "null"}), do: nil
  defp decode_value(value) when is_binary(value), do: value
  defp decode_value(value) when is_number(value), do: value
  defp decode_value(nil), do: nil
end