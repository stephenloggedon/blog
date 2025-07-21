defmodule Blog.RepoService do
  @moduledoc """
  Service layer for database operations that automatically uses the 
  configured repository adapter based on environment.

  Dev/Test: Uses Blog.EctoRepoAdapter (local SQLite)
  Production: Uses Blog.TursoRepoAdapter (distributed Turso)
  """

  @doc """
  Get the configured repository adapter for the current environment.
  """
  def repo_adapter do
    Application.get_env(:blog, :repo_adapter, Blog.EctoRepoAdapter)
  end

  @doc """
  Delegate all repository operations to the configured adapter.
  """
  defdelegate all(queryable, opts \\ []), to: __MODULE__, as: :delegate_all
  defdelegate get(schema, id), to: __MODULE__, as: :delegate_get
  defdelegate get_by(schema, clauses), to: __MODULE__, as: :delegate_get_by
  defdelegate insert(changeset), to: __MODULE__, as: :delegate_insert
  defdelegate update(changeset), to: __MODULE__, as: :delegate_update
  defdelegate delete(record), to: __MODULE__, as: :delegate_delete
  defdelegate query(sql, params), to: __MODULE__, as: :delegate_query
  defdelegate transaction(fun), to: __MODULE__, as: :delegate_transaction

  def delegate_all(queryable, opts), do: repo_adapter().all(queryable, opts)
  def delegate_get(schema, id), do: repo_adapter().get(schema, id)
  def delegate_get_by(schema, clauses), do: repo_adapter().get_by(schema, clauses)
  def delegate_insert(changeset), do: repo_adapter().insert(changeset)
  def delegate_update(changeset), do: repo_adapter().update(changeset)
  def delegate_delete(record), do: repo_adapter().delete(record)
  def delegate_query(sql, params), do: repo_adapter().query(sql, params)
  def delegate_transaction(fun), do: repo_adapter().transaction(fun)

  # High-level convenience functions

  @doc """
  List published posts with pagination.
  """
  def list_published_posts(opts \\ []) do
    adapter = repo_adapter()

    if function_exported?(adapter, :list_published_posts, 1) do
      adapter.list_published_posts(opts)
    else
      # Fallback implementation
      all("SELECT * FROM posts WHERE published_at IS NOT NULL ORDER BY published_at DESC", [])
    end
  end

  @doc """
  Get a post by slug.
  """
  def get_post_by_slug(slug) do
    adapter = repo_adapter()

    if function_exported?(adapter, :get_post_by_slug, 1) do
      adapter.get_post_by_slug(slug)
    else
      # Fallback implementation
      get_by(Blog.Content.Post, slug: slug)
    end
  end
end
