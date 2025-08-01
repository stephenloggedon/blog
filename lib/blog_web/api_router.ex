defmodule BlogWeb.ApiRouter do
  @moduledoc """
  Router for mTLS-authenticated API endpoints only.

  This router only contains routes that require client certificate authentication
  and runs on the separate mTLS endpoint (port 8443).
  """

  use BlogWeb, :router

  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug BlogWeb.Plugs.RequireUserAgent
    plug BlogWeb.Plugs.RequestLogger
    plug BlogWeb.Plugs.ClientCertAuth
  end

  # Protected API routes (client certificate authentication required)
  scope "/api", BlogWeb.Api do
    pipe_through :api_authenticated

    # Post management endpoints
    post "/posts", PostController, :create
    put "/posts/:id", PostController, :update
    patch "/posts/:id", PostController, :patch
    delete "/posts/:id", PostController, :delete

    # Series management endpoints
    post "/series", SeriesController, :create
    put "/series/:id", SeriesController, :update
    patch "/series/:id", SeriesController, :update
    delete "/series/:id", SeriesController, :delete

    # Image upload endpoint
    post "/posts/:post_id/images", ImageController, :upload
  end
end
