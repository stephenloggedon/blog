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
    if has_client_certificate?(conn) do
      Logger.info("Client certificate authentication successful")
      conn
    else
      Logger.warning("Client certificate not found")
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
end
