defmodule BlogWeb.Plugs.RequireUserAgent do
  @moduledoc """
  Plug to block requests that don't include a User-Agent header.

  This helps filter out basic bots and automated requests that don't 
  set a proper User-Agent string.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "user-agent") do
      [] ->
        # No User-Agent header present
        Logger.info("Blocked request with no User-Agent from #{get_client_ip(conn)}")

        conn
        |> put_status(:bad_request)
        |> put_resp_content_type("text/plain")
        |> send_resp(400, "User-Agent header required")
        |> halt()

      [""] ->
        # Empty User-Agent header
        Logger.info("Blocked request with empty User-Agent from #{get_client_ip(conn)}")

        conn
        |> put_status(:bad_request)
        |> put_resp_content_type("text/plain")
        |> send_resp(400, "Valid User-Agent header required")
        |> halt()

      [user_agent] ->
        # Valid User-Agent present, continue
        Logger.debug("Request from User-Agent: #{user_agent}")
        conn

      user_agents when is_list(user_agents) ->
        # Multiple User-Agent headers (unusual but valid)
        user_agent = List.first(user_agents)
        Logger.debug("Request from User-Agent: #{user_agent}")
        conn
    end
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_ip | _] ->
        # Use first IP from X-Forwarded-For header
        forwarded_ip
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        # Fall back to remote IP
        case conn.remote_ip do
          {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
          ip -> to_string(ip)
        end
    end
  end
end
