defmodule Blog.RepoAdapter do
  @moduledoc """
  Behaviour for database repository adapters.
  
  This allows switching between different database implementations
  (local SQLite via Ecto, Turso via HTTP) based on environment.
  """
  
  @doc "Get all records matching a query"
  @callback all(query :: term(), opts :: keyword()) :: {:ok, [map()]} | {:error, term()}
  
  @doc "Get a single record by ID"
  @callback get(schema :: atom(), id :: term()) :: {:ok, map()} | {:error, :not_found}
  
  @doc "Get a single record by query"
  @callback get_by(schema :: atom(), clauses :: keyword()) :: {:ok, map()} | {:error, :not_found}
  
  @doc "Insert a new record"
  @callback insert(changeset :: term()) :: {:ok, map()} | {:error, term()}
  
  @doc "Update an existing record"
  @callback update(changeset :: term()) :: {:ok, map()} | {:error, term()}
  
  @doc "Delete a record"
  @callback delete(record :: map()) :: {:ok, map()} | {:error, term()}
  
  @doc "Execute raw SQL query"
  @callback query(sql :: String.t(), params :: [term()]) :: {:ok, map()} | {:error, term()}
  
  @doc "Execute transaction"
  @callback transaction(fun :: function()) :: {:ok, term()} | {:error, term()}
end