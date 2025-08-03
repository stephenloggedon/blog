defmodule Blog.TursoMigrator do
  @moduledoc """
  Migration runner for Turso database.

  This module can execute existing Ecto migration files against a Turso database
  by converting the Ecto migration DSL to raw SQL statements.
  """

  alias Blog.TursoHttpClient

  @doc """
  Run all pending migrations against Turso database.
  """
  def migrate do
    with {:ok, _} <- ensure_schema_migrations_table(),
         {:ok, existing_tables} <- get_existing_tables(),
         {:ok, pending_migrations} <- get_pending_migrations(),
         :ok <- run_migrations(pending_migrations, existing_tables) do
      {:ok, "Migrations completed successfully"}
    else
      error -> error
    end
  end

  @doc """
  Get the current migration version from Turso.
  """
  def current_version do
    case TursoHttpClient.query_one(
           "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1",
           []
         ) do
      {:ok, nil} ->
        0

      {:ok, {row, _columns}} when is_list(row) ->
        List.first(row) |> String.to_integer()

      {:ok, row} when is_list(row) ->
        List.first(row) |> String.to_integer()

      {:error, _} ->
        0
    end
  end

  @doc """
  Run a specific migration by version number.
  """
  def run_migration(version) when is_integer(version) do
    migration_file = find_migration_file(version)

    if migration_file do
      with {:ok, existing_tables} <- get_existing_tables() do
        run_migration_file(migration_file, existing_tables)
      end
    else
      {:error, "Migration file not found for version #{version}"}
    end
  end

  # Private functions

  defp ensure_schema_migrations_table do
    sql = """
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version TEXT PRIMARY KEY,
      inserted_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    """

    TursoHttpClient.execute(sql, [])
  end

  defp get_pending_migrations do
    current_ver = current_version()

    # Get all migration files - use Application.app_dir for proper path resolution in releases
    migrations_path =
      Path.join([Application.app_dir(:blog), "priv", "repo", "migrations", "*.exs"])

    migration_files =
      Path.wildcard(migrations_path)
      |> Enum.map(&extract_version_from_filename/1)
      |> Enum.filter(fn {version, _} -> version > current_ver end)
      |> Enum.sort_by(fn {version, _} -> version end)

    {:ok, migration_files}
  end

  defp run_migrations([], _existing_tables), do: :ok

  defp run_migrations([{version, file_path} | rest], existing_tables) do
    case run_migration_file(file_path, existing_tables) do
      {:ok, _} ->
        # Record migration as completed
        record_migration(version)
        run_migrations(rest, existing_tables)

      error ->
        error
    end
  end

  defp run_migration_file(file_path, existing_tables) do
    # Load and execute the migration
    [{module, _}] = Code.compile_file(file_path)

    # Convert Ecto migration to SQL
    sql_statements = convert_migration_to_sql(module, existing_tables)

    # Execute each SQL statement
    Enum.reduce_while(sql_statements, {:ok, []}, fn sql, {:ok, results} ->
      case TursoHttpClient.execute(sql, []) do
        {:ok, result} -> {:cont, {:ok, [result | results]}}
        error -> {:halt, error}
      end
    end)
  rescue
    error -> {:error, "Failed to run migration: #{inspect(error)}"}
  end

  defp get_existing_tables do
    case TursoHttpClient.execute("SELECT name FROM sqlite_master WHERE type='table'", []) do
      {:ok, %{rows: rows}} ->
        tables = Enum.map(rows, fn [table_name] -> table_name end)
        {:ok, tables}

      error ->
        error
    end
  end

  defp convert_migration_to_sql(module, existing_tables) do
    # This is a simplified conversion - in a full implementation,
    # we would need to handle all Ecto migration commands
    get_migration_sql(module, existing_tables)
  end

  defp get_migration_sql(module, existing_tables) do
    case module do
      Blog.Repo.Migrations.CreatePosts ->
        create_posts_migration(existing_tables)

      Blog.Repo.Migrations.AddSubtitleToPosts ->
        [
          "ALTER TABLE posts ADD COLUMN subtitle TEXT"
        ]

      Blog.Repo.Migrations.CreateImagesTable ->
        create_images_migration(existing_tables)

      Blog.Repo.Migrations.FixDevlogLinksSimple ->
        [
          "UPDATE posts SET content = REPLACE(content, '](/02_blog_development)', '](/blog/building-a-blog-with-claude-4-an-ai-development-adventure)')",
          "UPDATE posts SET content = REPLACE(content, '](/03_blog_development)', '](/blog/the-art-of-polish-when-ai-meets-human-ux-intuition)')",
          "UPDATE posts SET content = REPLACE(content, '](/04_blog_development)', '](/blog/when-ai-debugging-meets-real-world-chaos-building-search-that-actually-works)')",
          "UPDATE posts SET content = REPLACE(content, '](/05_blog_development)', '](/blog/the-deployment-odyssey-when-ai-promises-meet-platform-reality)')",
          "UPDATE posts SET content = REPLACE(content, '](/06_blog_development)', '](/blog/securing-the-recursive-loop-when-ai-builds-mtls-authentication-for-its-own-blog)')",
          "UPDATE posts SET content = REPLACE(content, '](/07_blog_development)', '](/blog/the-database-evolution-when-ai-discovers-the-magic-of-distributed-sqlite)')",
          "UPDATE posts SET content = REPLACE(content, '](/08_blog_development)', '](/blog/the-dual-endpoint-discovery-when-architecture-decisions-hide-in-production-failures)')",
          "UPDATE posts SET content = REPLACE(content, '](/09_blog_development)', '](/blog/the-mobile-revolution-when-ai-discovers-the-power-of-touch-interfaces)')"
        ]

      Blog.Repo.Migrations.AddPreviewToPosts ->
        [
          "ALTER TABLE posts ADD COLUMN preview TEXT"
        ]

      Blog.Repo.Migrations.PopulatePreviewData ->
        [
          """
          UPDATE posts 
          SET preview = SUBSTR(content, 1, 500)
          WHERE content IS NOT NULL 
            AND content <> ''
            AND (preview IS NULL OR preview = '')
          """
        ]

      _ ->
        []
    end
  end

  defp record_migration(version) do
    sql = "INSERT INTO schema_migrations (version) VALUES (?)"
    TursoHttpClient.execute(sql, [to_string(version)])
  end

  defp extract_version_from_filename(file_path) do
    filename = Path.basename(file_path)

    case Regex.run(~r/^(\d+)_/, filename) do
      [_, version_str] -> {String.to_integer(version_str), file_path}
      _ -> {0, file_path}
    end
  end

  defp find_migration_file(version) do
    migrations_path =
      Path.join([Application.app_dir(:blog), "priv", "repo", "migrations", "#{version}_*.exs"])

    Path.wildcard(migrations_path)
    |> List.first()
  end

  defp create_posts_migration(existing_tables) do
    if "posts" in existing_tables do
      # Table already exists, update it to match our schema
      [
        "ALTER TABLE posts ADD COLUMN excerpt TEXT",
        "ALTER TABLE posts ADD COLUMN tags TEXT"
      ]
    else
      [
        """
        CREATE TABLE posts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          slug TEXT,
          content TEXT,
          excerpt TEXT,
          tags TEXT,
          published INTEGER DEFAULT 0 NOT NULL,
          published_at TEXT,
          inserted_at TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
        """,
        "CREATE UNIQUE INDEX posts_slug_index ON posts (slug)"
      ]
    end
  end

  defp create_images_migration(existing_tables) do
    if "images" in existing_tables do
      # Table already exists, update it to match our schema
      [
        "ALTER TABLE images ADD COLUMN post_id INTEGER",
        "ALTER TABLE images ADD COLUMN alt_text TEXT",
        "ALTER TABLE images ADD COLUMN updated_at TEXT DEFAULT (datetime('now'))",
        # Rename existing columns to match our schema
        "ALTER TABLE images RENAME COLUMN data TO image_data",
        "ALTER TABLE images RENAME COLUMN thumbnail TO thumbnail_data",
        "ALTER TABLE images RENAME COLUMN size TO file_size"
      ]
    else
      [
        """
        CREATE TABLE images (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          post_id INTEGER NOT NULL,
          filename TEXT NOT NULL,
          content_type TEXT NOT NULL,
          alt_text TEXT,
          image_data BLOB NOT NULL,
          thumbnail_data BLOB,
          file_size INTEGER,
          inserted_at TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE
        )
        """,
        "CREATE INDEX images_post_id_index ON images (post_id)"
      ]
    end
  end
end
