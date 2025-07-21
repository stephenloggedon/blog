ExUnit.start()

# Set up in-memory database schema
Ecto.Adapters.SQL.query!(
  Blog.Repo,
  "CREATE TABLE IF NOT EXISTS schema_migrations (version bigint, inserted_at datetime, PRIMARY KEY (version))"
)

# Run migrations on the in-memory database
path = Application.app_dir(:blog, "priv/repo/migrations")
Ecto.Migrator.run(Blog.Repo, path, :up, all: true, log: false)

Ecto.Adapters.SQL.Sandbox.mode(Blog.Repo, :manual)
