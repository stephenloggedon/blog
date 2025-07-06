defmodule BlogWeb.Plugs.SimpleApiAuth do
  @moduledoc """
  Simple API key authentication plug for testing mTLS setup.
  
  This is a temporary authentication mechanism while we work out
  the mTLS certificate extraction details.
  """
  
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  
  require Logger
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    case get_req_header(conn, "x-api-key") do
      [api_key] when api_key != "" ->
        if valid_api_key?(api_key) do
          Logger.info("API key authentication successful")
          assign(conn, :authenticated, true)
        else
          Logger.warning("Invalid API key provided")
          send_unauthorized(conn, "Invalid API key")
        end
      
      _ ->
        Logger.warning("No API key provided")
        send_unauthorized(conn, "API key required in X-API-Key header")
    end
  end
  
  # Simple API key validation - in production this would be more sophisticated
  defp valid_api_key?(api_key) do
    # For now, accept a simple test key
    # In production, this would validate against a database or environment variable
    api_key == "blog-api-test-key-2024"
  end
  
  # Send unauthorized response
  defp send_unauthorized(conn, message) do
    conn
    |> Plug.Conn.put_status(:unauthorized)
    |> json(%{error: message})
    |> halt()
  end
end