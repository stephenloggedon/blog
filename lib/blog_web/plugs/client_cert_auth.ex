defmodule BlogWeb.Plugs.ClientCertAuth do
  @moduledoc """
  Plug for authenticating API requests using client certificates (mTLS).

  This plug simply checks that a client certificate was presented. Cowboy
  handles all certificate validation during the TLS handshake.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    base_metadata = [
      method: conn.method,
      path: conn.request_path,
      remote_ip: get_client_ip(conn),
      user_agent: get_user_agent(conn)
    ]

    if has_client_certificate?(conn) do
      Logger.info("Client certificate authentication successful", base_metadata)
      conn
    else
      Logger.warning(
        "Client certificate authentication failed",
        base_metadata ++ [reason: "certificate_not_found"]
      )

      send_unauthorized(conn, "Client certificate required")
    end
  end

  # Check if a client certificate was presented
  defp has_client_certificate?(conn) do
    case conn.adapter do
      {Plug.Cowboy.Conn, cowboy_req} ->
        :cowboy_req.cert(cowboy_req) != :undefined

      _ ->
        # For testing, check peer data
        case Plug.Conn.get_peer_data(conn) do
          %{ssl_cert: cert_der} when is_binary(cert_der) -> true
          _ -> false
        end
    end
  end

  # Send unauthorized response
  defp send_unauthorized(conn, message) do
    conn
    |> Plug.Conn.put_status(:unauthorized)
    |> json(%{error: message})
    |> halt()
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
