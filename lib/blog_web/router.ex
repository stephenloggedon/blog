defmodule BlogWeb.Router do
  use BlogWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BlogWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug BlogWeb.Plugs.RequestLogger
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug BlogWeb.Plugs.RequestLogger
  end

  # mTLS authenticated routes moved to separate ApiEndpoint/ApiRouter

  scope "/", BlogWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/blog/:slug", BlogPostLive

    # Image serving routes (public)
    get "/images/:id", ImageController, :show
    get "/images/:id/thumb", ImageController, :thumbnail
  end

  # Public API routes (no authentication required)
  scope "/api", BlogWeb.Api do
    pipe_through :api

    get "/posts", PostController, :index
    get "/posts/:id", PostController, :show
  end

  # Protected API routes moved to separate ApiEndpoint (port 8443 with mTLS)

  # Enable LiveDashboard in development
  if Application.compile_env(:blog, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BlogWeb.Telemetry
    end
  end
end
