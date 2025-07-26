defmodule BlogWeb.LogHelper do
  @moduledoc """
  Helper functions for structured business logic logging in controllers.
  """

  require Logger

  @doc """
  Log a business operation error with structured metadata.
  """
  def log_operation_error(operation, error, conn, metadata \\ []) do
    base_metadata = [
      operation: operation,
      error: inspect(error),
      method: conn.method,
      path: conn.request_path,
      remote_ip: get_client_ip(conn),
      user_agent: get_user_agent(conn)
    ]

    Logger.error("Business operation failed", base_metadata ++ metadata)
  end

  @doc """
  Log a successful business operation with structured metadata.
  """
  def log_operation_success(operation, conn, metadata \\ []) do
    base_metadata = [
      operation: operation,
      method: conn.method,
      path: conn.request_path,
      remote_ip: get_client_ip(conn),
      user_agent: get_user_agent(conn)
    ]

    Logger.info("Business operation successful", base_metadata ++ metadata)
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      [] -> "unknown"
    end
  end

  defp get_client_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
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
end
