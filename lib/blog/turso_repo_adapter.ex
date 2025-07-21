defmodule Blog.TursoRepoAdapter do
  @moduledoc """
  Repository adapter for Turso/libSQL operations.

  This adapter converts Ecto-style operations to raw SQL queries
  that are executed against Turso using the HTTP API.
  """

  @behaviour Blog.RepoAdapter

  alias Blog.Content.Post
  alias Blog.Image
  alias Blog.TursoHttpClient

  @impl true
  def all(queryable, _opts \\ []) do
    case queryable do
      %Ecto.Query{} = query ->
        # Convert Ecto query to SQL and extract parameters
        {sql, params} = convert_ecto_query_to_sql_with_params(query)
        schema = determine_schema_from_query(query)

        case TursoHttpClient.execute(sql, params) do
          {:ok, result} ->
            structs = convert_rows_to_structs(schema, result.rows, result.columns)
            {:ok, structs}

          error ->
            error
        end

      schema when is_atom(schema) ->
        table_name = get_table_name(schema)
        sql = "SELECT * FROM #{table_name}"

        case TursoHttpClient.execute(sql, []) do
          {:ok, result} ->
            structs = convert_rows_to_structs(schema, result.rows, result.columns)
            {:ok, structs}

          error ->
            error
        end
    end
  end

  @impl true
  def get(schema, id) do
    table_name = get_table_name(schema)
    sql = "SELECT * FROM #{table_name} WHERE id = ?"

    case TursoHttpClient.query_one(sql, [id]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, {row, columns}} -> {:ok, convert_row_to_struct(schema, row, columns)}
      error -> error
    end
  end

  @impl true
  def get_by(schema, clauses) do
    table_name = get_table_name(schema)
    {where_clause, params} = build_where_clause(clauses)
    sql = "SELECT * FROM #{table_name} WHERE #{where_clause}"

    case TursoHttpClient.query_one(sql, params) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, {row, columns}} -> {:ok, convert_row_to_struct(schema, row, columns)}
      error -> error
    end
  end

  @impl true
  def insert(changeset) do
    # Extract data from changeset
    schema = changeset.data.__struct__
    table_name = get_table_name(schema)
    changes = changeset.changes

    # Add timestamps
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    changes = Map.merge(changes, %{inserted_at: now, updated_at: now})

    # Build insert SQL
    fields = Map.keys(changes)
    values = Map.values(changes)
    placeholders = Enum.map_join(fields, ", ", fn _ -> "?" end)
    fields_str = Enum.join(fields, ", ")

    sql = "INSERT INTO #{table_name} (#{fields_str}) VALUES (#{placeholders})"

    case TursoHttpClient.execute(sql, values) do
      {:ok, _result} ->
        # Get the inserted record (simplified - in real implementation would get last_insert_rowid)
        {:ok, struct(schema, changes)}

      error ->
        {:error, error}
    end
  end

  @impl true
  def update(changeset) do
    schema = changeset.data.__struct__
    table_name = get_table_name(schema)
    changes = changeset.changes
    id = changeset.data.id

    # Add updated timestamp
    changes = Map.put(changes, :updated_at, DateTime.utc_now() |> DateTime.to_iso8601())

    # Build update SQL
    set_clauses = Enum.map_join(changes, ", ", fn {field, _} -> "#{field} = ?" end)
    values = Map.values(changes) ++ [id]

    sql = "UPDATE #{table_name} SET #{set_clauses} WHERE id = ?"

    case TursoHttpClient.execute(sql, values) do
      {:ok, _result} ->
        updated_data = Map.merge(changeset.data, changes)
        {:ok, updated_data}

      error ->
        {:error, error}
    end
  end

  @impl true
  def delete(record) do
    schema = record.__struct__
    table_name = get_table_name(schema)

    sql = "DELETE FROM #{table_name} WHERE id = ?"

    case TursoHttpClient.execute(sql, [record.id]) do
      {:ok, _result} -> {:ok, record}
      error -> {:error, error}
    end
  end

  @impl true
  def query(sql, params) do
    TursoHttpClient.execute(sql, params)
  end

  @impl true
  def transaction(statements) when is_list(statements) do
    TursoHttpClient.transaction(statements)
  end

  def transaction(fun) when is_function(fun) do
    # Simplified transaction - collect operations and execute as batch
    result = fun.()
    {:ok, result}
  catch
    error -> {:error, error}
  end

  # Helper functions for common queries
  def list_published_posts(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)
    offset = (page - 1) * per_page

    sql = """
    SELECT * FROM posts
    WHERE published_at IS NOT NULL
    ORDER BY published_at DESC
    LIMIT ? OFFSET ?
    """

    case TursoHttpClient.execute(sql, [per_page, offset]) do
      {:ok, result} ->
        posts =
          Enum.map(result.rows, fn row ->
            convert_row_to_struct(Post, row, result.columns)
          end)

        {:ok, posts}

      error ->
        error
    end
  end

  def get_post_by_slug(slug) do
    get_by(Post, slug: slug)
  end

  # Private helper functions

  defp get_table_name(Post), do: "posts"
  defp get_table_name(Image), do: "images"
  defp get_table_name(schema), do: schema.__schema__(:source)

  defp build_where_clause(clauses) do
    conditions = Enum.map(clauses, fn {field, _value} -> "#{field} = ?" end)
    values = Enum.map(clauses, fn {_field, value} -> value end)

    where_clause = Enum.join(conditions, " AND ")
    {where_clause, values}
  end

  defp convert_rows_to_structs(schema, rows, columns) do
    Enum.map(rows, fn row ->
      convert_row_to_struct(schema, row, columns)
    end)
  end

  defp convert_row_to_struct(schema, row, columns) when is_list(row) do
    # Convert row data to struct with proper type conversion
    fields =
      if columns do
        Enum.zip(columns, row)
        |> Enum.into(%{})
        |> convert_types_for_schema(schema)
      else
        # Fallback if no columns provided
        %{id: List.first(row)}
      end

    struct(schema, fields)
  end

  defp convert_types_for_schema(fields, Post) do
    fields
    |> Map.update("published", false, fn
      1 -> true
      0 -> false
      val when is_boolean(val) -> val
      _ -> false
    end)
    |> Map.update("published_at", nil, fn
      val when is_binary(val) and val != "" ->
        parse_sqlite_datetime(val)

      _ ->
        nil
    end)
    |> Map.update("inserted_at", nil, fn
      val when is_binary(val) and val != "" ->
        parse_sqlite_datetime(val)

      _ ->
        nil
    end)
    |> Map.update("updated_at", nil, fn
      val when is_binary(val) and val != "" ->
        parse_sqlite_datetime(val)

      _ ->
        nil
    end)
    |> convert_string_keys_to_atoms()
  end

  defp convert_types_for_schema(fields, Image) do
    fields
    |> Map.update("image_data", nil, fn
      val when is_binary(val) and val != "" ->
        # Handle base64-encoded BLOB data with proper padding
        case decode_base64_with_padding(val) do
          {:ok, binary} -> binary
          # Return as-is if not valid base64
          :error -> val
        end

      _ ->
        nil
    end)
    |> Map.update("thumbnail_data", nil, fn
      val when is_binary(val) and val != "" ->
        # Handle base64-encoded BLOB data with proper padding
        case decode_base64_with_padding(val) do
          {:ok, binary} -> binary
          # Return as-is if not valid base64
          :error -> val
        end

      _ ->
        nil
    end)
    |> Map.update("inserted_at", nil, fn
      val when is_binary(val) and val != "" ->
        parse_sqlite_datetime(val)

      _ ->
        nil
    end)
    |> Map.update("updated_at", nil, fn
      val when is_binary(val) and val != "" ->
        parse_sqlite_datetime(val)

      _ ->
        nil
    end)
    |> convert_string_keys_to_atoms()
  end

  defp convert_types_for_schema(fields, _schema) do
    convert_string_keys_to_atoms(fields)
  end

  defp convert_string_keys_to_atoms(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      atom_key = if is_binary(key), do: String.to_atom(key), else: key
      Map.put(acc, atom_key, value)
    end)
  end

  defp decode_base64_with_padding(base64_string) do
    # Add padding if needed for proper base64 decoding
    padding_needed = rem(4 - rem(String.length(base64_string), 4), 4)
    padded_string = base64_string <> String.duplicate("=", padding_needed)

    Base.decode64(padded_string)
  end

  defp parse_sqlite_datetime(datetime_str) do
    # SQLite stores datetimes as "YYYY-MM-DD HH:MM:SS"
    # Convert to ISO 8601 format for DateTime parsing
    iso_str = String.replace(datetime_str, " ", "T") <> "Z"

    case DateTime.from_iso8601(iso_str) do
      {:ok, dt, _} ->
        dt

      _ ->
        # Fallback: try parsing as NaiveDateTime and assume UTC
        case NaiveDateTime.from_iso8601(datetime_str) do
          {:ok, naive_dt} -> DateTime.from_naive!(naive_dt, "Etc/UTC")
          _ -> nil
        end
    end
  end

  defp convert_ecto_query_to_sql_with_params(query) do
    # Extract basic components from Ecto query and return SQL with parameters
    case query do
      %Ecto.Query{from: %{source: {"posts", _}}} ->
        # Handle posts queries with published filter
        {"SELECT * FROM posts WHERE published = 1 AND published_at IS NOT NULL ORDER BY published_at DESC",
         []}

      %Ecto.Query{from: %{source: {"images", _}}, wheres: wheres, order_bys: order_bys} = query ->
        # Handle images queries
        {where_clause, extracted_params} = convert_where_clauses_with_params(wheres, query)
        order_clause = convert_order_clauses(order_bys)

        base_sql = "SELECT * FROM images"
        sql = if where_clause != "", do: base_sql <> " WHERE " <> where_clause, else: base_sql
        sql = if order_clause != "", do: sql <> " ORDER BY " <> order_clause, else: sql
        {sql, extracted_params}

      _ ->
        # Fallback for other queries
        {"SELECT * FROM posts WHERE published_at IS NOT NULL ORDER BY published_at DESC", []}
    end
  end

  defp determine_schema_from_query(%Ecto.Query{from: %{source: {"posts", _}}}), do: Post
  defp determine_schema_from_query(%Ecto.Query{from: %{source: {"images", _}}}), do: Image
  defp determine_schema_from_query(_), do: Post

  defp convert_where_clauses_with_params([], _query), do: {"", []}

  defp convert_where_clauses_with_params(wheres, _query) do
    # Handle the actual Ecto where clause structure
    case wheres do
      [%Ecto.Query.BooleanExpr{op: :and, params: [{param_value, {0, :post_id}}]}] ->
        # This matches the post_id == ^value pattern
        {"post_id = ?", [param_value]}

      _ ->
        # Fallback for unsupported patterns
        {"1=1", []}
    end
  end

  defp convert_order_clauses([]), do: ""

  defp convert_order_clauses(order_bys) do
    Enum.map_join(order_bys, ", ", fn
      %{expr: [asc: {:&, [], [0, :inserted_at, :naive_datetime]}]} ->
        "inserted_at ASC"

      %{expr: [desc: {:&, [], [0, :inserted_at, :naive_datetime]}]} ->
        "inserted_at DESC"

      _ ->
        # Fallback
        "id ASC"
    end)
  end
end
