defmodule Blog.EctoRepoAdapter do
  @moduledoc """
  Repository adapter for Ecto/SQLite operations.

  This adapter wraps the standard Ecto.Repo to provide a consistent
  interface that can be swapped with other implementations.
  """

  @behaviour Blog.RepoAdapter

  import Ecto.Query
  alias Blog.Content.Post
  alias Blog.Repo

  @impl true
  def all(queryable, _opts \\ []) do
    results = Repo.all(queryable)
    {:ok, results}
  catch
    error -> {:error, error}
  end

  @impl true
  def get(schema, id) do
    case Repo.get(schema, id) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end

  @impl true
  def get_by(schema, clauses) do
    case Repo.get_by(schema, clauses) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end

  @impl true
  def one(queryable) do
    case Repo.one(queryable) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  catch
    error -> {:error, error}
  end

  @impl true
  def insert(changeset) do
    case Repo.insert(changeset) do
      {:ok, record} -> {:ok, record}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def update(changeset) do
    case Repo.update(changeset) do
      {:ok, record} -> {:ok, record}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def delete(record) do
    case Repo.delete(record) do
      {:ok, record} -> {:ok, record}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def query(sql, params) do
    case Repo.query(sql, params) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, error}
    end
  end

  @impl true
  def update_all(queryable, updates) do
    case Repo.update_all(queryable, updates) do
      {count, nil} -> {:ok, count}
      {count, records} -> {:ok, {count, records}}
    end
  catch
    error -> {:error, error}
  end

  @impl true
  def transaction(fun) do
    case Repo.transaction(fun) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, error}
    end
  end

  def list_published_posts(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)
    offset = (page - 1) * per_page

    query =
      from(p in Post,
        where: not is_nil(p.published_at),
        order_by: [desc: p.published_at],
        limit: ^per_page,
        offset: ^offset
      )

    all(query)
  end

  def get_post_by_slug(slug) do
    get_by(Post, slug: slug)
  end
end
