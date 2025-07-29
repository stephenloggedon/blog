defmodule Blog.TursoEctoRepo do
  @moduledoc """
  A custom Ecto repo that bridges SQLite3 adapter with Turso's HTTP API.

  This repo uses the standard SQLite3 adapter for migrations and query building,
  but executes queries against Turso's HTTP endpoint for production data.
  """

  use Ecto.Repo,
    otp_app: :blog,
    adapter: Blog.TursoEctoAdapter
end
