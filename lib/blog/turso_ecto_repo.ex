defmodule Blog.TursoEctoRepo do
  @moduledoc """
  A custom Ecto repo that bridges SQLite3 adapter with Turso's HTTP API.

  This repo uses the standard SQLite3 adapter for migrations and query building,
  but executes queries against Turso's HTTP endpoint for production data.
  """

  use Ecto.Repo,
    otp_app: :blog,
    adapter: Blog.TursoEctoAdapter

  @doc """
  Dynamically starts the repo when required.
  Used in production to ensure the repo is available for migrations.
  """
  def ensure_started do
    case __MODULE__.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end
end
