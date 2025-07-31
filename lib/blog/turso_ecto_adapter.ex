defmodule Blog.TursoEctoAdapter do
  @moduledoc """
  Custom Ecto adapter that bridges SQLite3 with Turso's HTTP API.
  """

  @behaviour Ecto.Adapter
  @behaviour Ecto.Adapter.Migration
  @behaviour Ecto.Adapter.Queryable
  @behaviour Ecto.Adapter.Schema
  @behaviour Ecto.Adapter.Storage
  @behaviour Ecto.Adapter.Transaction

  def query(_repo, sql, params, _opts \\ []) do
    case Blog.TursoHttpClient.execute(sql, params) do
      {:ok, %{rows: rows, columns: columns, num_rows: count}} ->
        {:ok, %{rows: rows, columns: columns, num_rows: count}}

      {:error, reason} ->
        {:error, %{message: "Turso query failed: #{reason}"}}
    end
  end

  def query!(repo, sql, params, opts \\ []) do
    case query(repo, sql, params, opts) do
      {:ok, result} ->
        result

      {:error, %{message: message}} ->
        raise Ecto.QueryError, query: sql, message: message

      {:error, reason} ->
        raise Ecto.QueryError, query: sql, message: "Turso query failed: #{inspect(reason)}"
    end
  end

  alias Ecto.Adapters.SQLite3

  @impl Ecto.Adapter
  defdelegate dumpers(primitive, type), to: SQLite3
  @impl Ecto.Adapter
  defdelegate loaders(primitive, type), to: SQLite3
  @impl Ecto.Adapter.Schema
  defdelegate autogenerate(type), to: SQLite3

  @impl Ecto.Adapter
  def checked_out?(_conn_pid), do: false

  @impl Ecto.Adapter
  defmacro __before_compile__(_env), do: quote(do: :ok)

  @impl Ecto.Adapter
  def ensure_all_started(_config, type), do: Application.ensure_all_started(:finch, type)

  @impl Ecto.Adapter
  def init(config) do
    # Since we're using HTTP, we don't need a persistent connection process
    # Just return a minimal child_spec that Ecto expects
    child_spec = %{
      id: __MODULE__,
      start: {Agent, :start_link, [fn -> config end, [name: __MODULE__]]},
      type: :worker
    }

    meta = %{pid: __MODULE__, opts: config}
    {:ok, child_spec, meta}
  end

  @impl Ecto.Adapter
  def checkout(_meta, _config, function), do: function.(:turso_http)

  @impl Ecto.Adapter.Queryable
  def prepare(operation, query), do: SQLite3.prepare(operation, query)

  @impl Ecto.Adapter.Queryable
  def execute(repo, meta, prepared, params, options) do
    case prepared do
      %{cache: statement} when is_binary(statement) ->
        execute_turso_query(statement, params)

      {:cache, _fun, {_cache_key, statement}} when is_binary(statement) ->
        execute_turso_query(statement, params)

      _ ->
        SQLite3.execute(repo, meta, prepared, params, options)
    end
  end

  @impl Ecto.Adapter.Queryable
  def stream(repo, meta, prepared, params, options) do
    case execute(repo, meta, prepared, params, options) do
      {count, rows} -> Stream.zip(Stream.repeatedly(fn -> count end), rows)
      rows when is_list(rows) -> Stream.map(rows, & &1)
    end
  end

  @impl Ecto.Adapter.Schema
  def insert_all(_repo, schema_meta, header, rows, on_conflict, returning, placeholders, options) do
    case SQLite3.insert_all(
           nil,
           schema_meta,
           header,
           rows,
           on_conflict,
           returning,
           placeholders,
           options
         ) do
      {sql, params} when is_binary(sql) -> execute_sql(sql, params, options)
      result -> result
    end
  end

  @impl Ecto.Adapter.Schema
  def insert(_repo, schema_meta, params, on_conflict, returning, options) do
    case schema_meta.source do
      "schema_migrations" ->
        insert_schema_migration(params)

      _ ->
        insert_regular_record(schema_meta, params, on_conflict, returning, options)
    end
  end

  defp insert_schema_migration(params) do
    version = Keyword.get(params, :version)
    inserted_at = Keyword.get(params, :inserted_at)

    datetime_string = format_datetime(inserted_at)
    sql = "INSERT OR IGNORE INTO schema_migrations (version, inserted_at) VALUES (?, ?)"

    case Blog.TursoHttpClient.execute(sql, [version, datetime_string]) do
      {:ok, %{num_rows: _count}} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_regular_record(schema_meta, params, on_conflict, returning, options) do
    dummy_repo_meta = %{adapter: Ecto.Adapters.SQLite3, repo: nil, pid: nil, telemetry: []}

    case SQLite3.insert(dummy_repo_meta, schema_meta, params, on_conflict, returning, options) do
      {sql, params} when is_binary(sql) ->
        execute_insert_sql(sql, params)

      result ->
        result
    end
  end

  defp format_datetime(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp format_datetime(string) when is_binary(string), do: string
  defp format_datetime(other), do: to_string(other)

  defp execute_insert_sql(sql, params) do
    case Blog.TursoHttpClient.execute(sql, params) do
      {:ok, %{num_rows: _count}} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Ecto.Adapter.Schema
  def update(_repo, schema_meta, params, filters, returning, options) do
    case SQLite3.update(nil, schema_meta, params, filters, returning, options) do
      {sql, params} when is_binary(sql) ->
        execute_sql(sql, params, options)
        {:ok, nil}

      result ->
        result
    end
  end

  @impl Ecto.Adapter.Schema
  def delete(_repo, schema_meta, filters, returning, options) do
    case SQLite3.delete(nil, schema_meta, filters, returning, options) do
      {sql, params} when is_binary(sql) ->
        execute_sql(sql, params, options)
        {:ok, nil}

      result ->
        result
    end
  end

  @impl Ecto.Adapter.Migration
  def supports_ddl_transaction?, do: true

  @impl Ecto.Adapter.Migration
  def execute_ddl(_meta, definition, options) do
    sql = generate_ddl_sql(definition, options)
    execute_sql(sql, [], options)
    {:ok, [{:info, sql, []}]}
  end

  defp generate_ddl_sql(definition, options) do
    case definition do
      {:create_if_not_exists, %Ecto.Migration.Table{name: :schema_migrations}, columns} ->
        generate_schema_migrations_sql(columns)

      {:create, %Ecto.Migration.Table{name: table_name}, columns} ->
        generate_create_table_sql(table_name, columns)

      {:alter, %Ecto.Migration.Table{name: table_name}, changes} ->
        generate_alter_table_sql(table_name, changes)

      {:create, %Ecto.Migration.Index{} = index} ->
        generate_create_index_sql(index)

      sql_string when is_binary(sql_string) ->
        sql_string

      _ ->
        fallback_ddl_sql(definition, options)
    end
  end

  defp fallback_ddl_sql(definition, options) do
    temp_config = [adapter: SQLite3, database: ":memory:"]

    case SQLite3.execute_ddl({nil, temp_config}, definition, options) do
      sql when is_binary(sql) -> sql
      _ -> raise "Unsupported DDL operation: #{inspect(definition)}"
    end
  rescue
    _error -> reraise "Unsupported DDL operation: #{inspect(definition)}", __STACKTRACE__
  end

  @impl Ecto.Adapter.Migration
  def lock_for_migrations(_repo, _options, fun), do: fun.()

  @impl Ecto.Adapter.Storage
  def storage_up(_opts), do: :ok

  @impl Ecto.Adapter.Storage
  def storage_down(_opts), do: :ok

  @impl Ecto.Adapter.Storage
  def storage_status(_opts), do: :up

  @impl Ecto.Adapter.Transaction
  def transaction(_repo, _options, function) do
    case Blog.TursoHttpClient.execute("BEGIN", []) do
      {:ok, _} ->
        try do
          result = function.()

          case Blog.TursoHttpClient.execute("COMMIT", []) do
            {:ok, _} ->
              {:ok, result}

            {:error, reason} when is_binary(reason) ->
              if String.contains?(reason, "no transaction is active") do
                {:ok, result}
              else
                Blog.TursoHttpClient.execute("ROLLBACK", [])
                {:error, reason}
              end

            error ->
              Blog.TursoHttpClient.execute("ROLLBACK", [])
              error
          end
        rescue
          error ->
            Blog.TursoHttpClient.execute("ROLLBACK", [])
            reraise error, __STACKTRACE__
        catch
          :throw, value ->
            Blog.TursoHttpClient.execute("ROLLBACK", [])
            throw(value)

          type, error ->
            Blog.TursoHttpClient.execute("ROLLBACK", [])
            :erlang.raise(type, error, __STACKTRACE__)
        end

      error ->
        error
    end
  end

  @impl Ecto.Adapter.Transaction
  def in_transaction?(_repo), do: false

  @impl Ecto.Adapter.Transaction
  def rollback(_repo, value) do
    Blog.TursoHttpClient.execute("ROLLBACK", [])
    exit({:shutdown, value})
  end

  defp generate_schema_migrations_sql(_columns) do
    """
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version BIGINT PRIMARY KEY,
      inserted_at DATETIME NOT NULL DEFAULT (datetime('now'))
    )
    """
  end

  defp generate_create_table_sql(table_name, columns) do
    column_definitions = Enum.map(columns, &format_column_definition/1)
    column_sql = Enum.join(column_definitions, ",\n  ")
    "CREATE TABLE IF NOT EXISTS #{table_name} (\n  #{column_sql}\n)"
  end

  defp generate_alter_table_sql(table_name, changes) do
    change_sqls =
      Enum.map(changes, fn
        {:add, column_name, type, opts} ->
          column_def = format_column_definition({:add, column_name, type, opts})
          generate_safe_add_column_sql(table_name, column_name, column_def)

        {:modify, _column_name, _type, _opts} ->
          raise "SQLite doesn't support column modification. Use migrations to recreate table."

        {:remove, column_name} ->
          "ALTER TABLE #{table_name} DROP COLUMN #{column_name}"
      end)

    Enum.join(change_sqls, ";\n")
  end

  defp generate_safe_add_column_sql(table_name, _column_name, column_def) do
    # For SQLite, we need to handle duplicate columns at the execution level
    # since SQLite doesn't support conditional DDL directly
    "ALTER TABLE #{table_name} ADD COLUMN #{column_def}"
  end

  defp generate_create_index_sql(%Ecto.Migration.Index{
         table: table,
         columns: columns,
         name: name,
         unique: unique
       }) do
    index_type = if unique, do: "UNIQUE INDEX", else: "INDEX"
    column_list = Enum.join(columns, ", ")
    index_name = name || "#{table}_#{Enum.join(columns, "_")}_index"
    "CREATE #{index_type} IF NOT EXISTS #{index_name} ON #{table} (#{column_list})"
  end

  defp format_column_definition({:add, column_name, type, opts}) do
    sql_type = map_type_to_sql(type)
    constraints = build_column_constraints(opts)
    constraint_sql = format_constraints(constraints)

    "#{column_name} #{sql_type}#{constraint_sql}"
  end

  defp map_type_to_sql(:id), do: "INTEGER PRIMARY KEY AUTOINCREMENT"
  defp map_type_to_sql(:bigint), do: "BIGINT"
  defp map_type_to_sql(:integer), do: "INTEGER"
  defp map_type_to_sql(:string), do: "TEXT"
  defp map_type_to_sql(:text), do: "TEXT"
  defp map_type_to_sql(:boolean), do: "INTEGER"
  defp map_type_to_sql(:datetime), do: "DATETIME"
  defp map_type_to_sql(:naive_datetime), do: "DATETIME"
  defp map_type_to_sql(:date), do: "DATE"
  defp map_type_to_sql(:time), do: "TIME"
  defp map_type_to_sql(:float), do: "REAL"
  defp map_type_to_sql(:decimal), do: "DECIMAL"
  defp map_type_to_sql(:binary), do: "BLOB"
  defp map_type_to_sql(_), do: "TEXT"

  defp build_column_constraints(opts) do
    []
    |> add_primary_key_constraint(opts)
    |> add_null_constraint(opts)
    |> add_default_constraint(opts)
  end

  defp add_primary_key_constraint(constraints, opts) do
    if Keyword.get(opts, :primary_key, false) do
      ["PRIMARY KEY" | constraints]
    else
      constraints
    end
  end

  defp add_null_constraint(constraints, opts) do
    if Keyword.get(opts, :null, true) == false do
      ["NOT NULL" | constraints]
    else
      constraints
    end
  end

  defp add_default_constraint(constraints, opts) do
    case Keyword.get(opts, :default) do
      nil -> constraints
      default -> ["DEFAULT #{format_default_value(default)}" | constraints]
    end
  end

  defp format_default_value(value) when is_binary(value), do: "'#{value}'"
  defp format_default_value(value) when is_number(value), do: to_string(value)
  defp format_default_value(true), do: "1"
  defp format_default_value(false), do: "0"
  defp format_default_value(_), do: "NULL"

  defp format_constraints([]), do: ""
  defp format_constraints(constraints), do: " " <> Enum.join(constraints, " ")

  defp execute_turso_query(statement, params) do
    case Blog.TursoHttpClient.execute(statement, params) do
      {:ok, %{rows: rows, num_rows: _count}} ->
        {length(rows), rows}

      {:error, reason} ->
        raise Ecto.QueryError, query: statement, message: "Turso query failed: #{reason}"
    end
  end

  defp execute_sql(sql, params, _options) do
    statements = parse_sql_statements(sql)

    case statements do
      [single_statement] -> execute_single_statement(single_statement, params)
      multiple_statements -> execute_multiple_statements(multiple_statements)
    end
  end

  defp parse_sql_statements(sql) do
    sql
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp execute_single_statement(statement, params) do
    case Blog.TursoHttpClient.execute(statement, params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        if should_ignore_error?(reason, statement) do
          :ok
        else
          raise "Turso SQL execution failed: #{reason}"
        end
    end
  end

  defp execute_multiple_statements(statements) do
    Enum.each(statements, &execute_statement_without_params/1)
  end

  defp execute_statement_without_params(statement) do
    case Blog.TursoHttpClient.execute(statement, []) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        if should_ignore_error?(reason, statement) do
          :ok
        else
          raise "Turso SQL execution failed: #{reason}"
        end
    end
  end

  defp should_ignore_error?(reason, statement) do
    reason_str = to_string(reason)

    # Ignore duplicate column errors for ALTER TABLE ADD COLUMN
    # Ignore "no such column" errors for ALTER TABLE DROP COLUMN
    (String.contains?(reason_str, "duplicate column name") and
       String.contains?(statement, "ALTER TABLE") and
       String.contains?(statement, "ADD COLUMN")) or
      (String.contains?(reason_str, "no such column") and
         String.contains?(statement, "ALTER TABLE") and
         String.contains?(statement, "DROP COLUMN"))
  end
end
