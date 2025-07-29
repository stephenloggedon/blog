defmodule Blog.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :blog

  def migrate do
    load_app()

    # Check if we're using Turso in production
    case Application.get_env(:blog, :repo_adapter) do
      Blog.TursoRepoAdapter ->
        IO.puts("Running Turso migrations via Ecto...")

        # Start required dependencies for Turso HTTP client
        Application.ensure_all_started(:finch)

        # Start Finch with proper supervision and registry
        case Finch.start_link(name: Blog.Finch) do
          {:ok, _pid} ->
            IO.puts("Finch started successfully")

          {:error, {:already_started, _pid}} ->
            IO.puts("Finch already started")

          {:error, reason} ->
            IO.puts("Failed to start Finch: #{inspect(reason)}")
            System.halt(1)
        end

        # Start Ecto and required applications
        Application.ensure_all_started(:ecto)
        Application.ensure_all_started(:ecto_sql)

        # Use TursoEctoRepo for proper Ecto migrations
        {:ok, _, _} =
          Ecto.Migrator.with_repo(Blog.TursoEctoRepo, &Ecto.Migrator.run(&1, :up, all: true))

        IO.puts("Turso migrations completed successfully")

      _ ->
        # Use standard Ecto migrations for other environments
        for repo <- repos() do
          {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
        end
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
