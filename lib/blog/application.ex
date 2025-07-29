defmodule Blog.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize OpenTelemetry instrumentation
    setup_opentelemetry()

    children = [
      BlogWeb.Telemetry,
      # Start the Finch HTTP client before TursoRepo
      {Finch, name: Blog.Finch},
      Blog.TursoRepo,
      {DNSCluster, query: Application.get_env(:blog, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Blog.PubSub},
      # Start a worker by calling: Blog.Worker.start_link(arg)
      # {Blog.Worker, arg},
      # Start to serve requests, typically the last entry
      BlogWeb.Endpoint,
      # Separate mTLS API endpoint for authenticated routes
      BlogWeb.ApiEndpoint
    ]

    # Only start local SQLite repo in development and test environments
    children =
      if Application.get_env(:blog, :repo_adapter) == Blog.EctoRepoAdapter do
        [Blog.Repo | Enum.drop(children, 1)]
      else
        # Add TursoEctoRepo to children when using Turso adapter
        [Blog.TursoEctoRepo | children]
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Blog.Supervisor]

    # Start the supervision tree
    case Supervisor.start_link(children, opts) do
      {:ok, _pid} = result ->
        # Run migrations automatically when using Turso adapter after supervisor starts
        if Application.get_env(:blog, :repo_adapter) == Blog.TursoRepoAdapter do
          # Run synchronously to see any errors
          run_turso_migrations()
        end

        result

      error ->
        error
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BlogWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp run_turso_migrations do
    :timer.sleep(2000)

    Ecto.Migrator.with_repo(Blog.TursoEctoRepo, fn repo ->
      Ecto.Migrator.run(repo, :up, all: true)
    end)
  rescue
    error -> IO.puts("Migration failed: #{Exception.message(error)}")
  catch
    _type, error -> IO.puts("Migration error: #{inspect(error)}")
  end

  # Initialize OpenTelemetry automatic instrumentation
  defp setup_opentelemetry do
    # Setup Cowboy (web server) instrumentation
    :opentelemetry_cowboy.setup()

    # Setup Phoenix instrumentation - includes HTTP requests, LiveView, and router
    OpentelemetryPhoenix.setup(adapter: :cowboy2)

    # Setup Ecto instrumentation for database queries
    OpentelemetryEcto.setup([:blog, :repo])

    # Add process propagator for better distributed tracing
    :application.set_env(:opentelemetry, :processors, [
      {:otel_batch_processor, %{}}
    ])
  end
end
