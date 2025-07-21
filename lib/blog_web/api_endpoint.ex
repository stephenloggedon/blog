defmodule BlogWeb.ApiEndpoint do
  @moduledoc """
  Separate endpoint for mTLS-authenticated API requests.

  This endpoint runs on port 8443 with client certificate authentication
  and only serves API routes that require authentication.
  """

  use Phoenix.Endpoint, otp_app: :blog

  # Only serve API routes - no static files or LiveView
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  # Use API router with only authenticated routes
  plug BlogWeb.ApiRouter
end
