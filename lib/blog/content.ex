defmodule Blog.Content do
  @moduledoc """
  The Content context.
  """

  import Ecto.Query, warn: false
  alias Blog.RepoService

  alias Blog.Content.Post

  @doc """
  Returns posts with pagination, filtering, and search support.

  ## Options
  - `:page` - Page number (default: 1)
  - `:per_page` - Posts per page (default: 10)  
  - `:tags` - List of tags to filter by
  - `:search` - Search term for title/content
  - `:allow_unpublished` - Include unpublished posts (default: false)

  ## Examples

      iex> list_published_posts()
      [%Post{}, ...]

      iex> list_published_posts(page: 2, per_page: 5)
      [%Post{}, ...]

      iex> list_published_posts(tag: "elixir")
      [%Post{}, ...]

      iex> list_published_posts(search: "phoenix")
      [%Post{}, ...]

  """
  def list_posts(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)
    offset = (page - 1) * per_page
    tags = Keyword.get(opts, :tags, [])
    search = Keyword.get(opts, :search)
    allow_unpublished = Keyword.get(opts, :allow_unpublished, false)

    query =
      if allow_unpublished do
        from(p in Post)
      else
        from(p in Post, where: p.published == true and not is_nil(p.published_at))
      end

    result =
      query
      |> apply_tag_filter(tags)
      |> apply_search_filter(search)
      |> order_by([p], desc: p.inserted_at)
      |> limit(^per_page)
      |> offset(^offset)
      |> RepoService.all()
      |> case do
        {:ok, posts} -> posts
        {:error, _} -> []
      end

    # Only add rendered content if this looks like a web request (has pagination/search/tags)
    if tags != [] or search != nil or page != 1 or per_page != 10 do
      Enum.map(result, fn post ->
        %{post | rendered_content: Post.render_content(post)}
      end)
    else
      result
    end
  rescue
    _ -> []
  end

  def list_published_posts(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)
    offset = (page - 1) * per_page
    tags = Keyword.get(opts, :tags, [])
    search = Keyword.get(opts, :search)

    query = from(p in Post, where: p.published == true and not is_nil(p.published_at))

    query
    |> apply_tag_filter(tags)
    |> apply_search_filter(search)
    |> order_by([p], desc: p.published_at)
    |> limit(^per_page)
    |> offset(^offset)
    |> execute_query_and_render()
  rescue
    _ -> []
  end

  defp apply_tag_filter(query, []), do: query

  defp apply_tag_filter(query, [single_tag]) do
    from(p in query, where: like(p.tags, ^"%#{single_tag}%"))
  end

  defp apply_tag_filter(query, multiple_tags) do
    tag_conditions =
      Enum.map(multiple_tags, fn tag ->
        dynamic([p], like(p.tags, ^"%#{tag}%"))
      end)

    combined_condition =
      Enum.reduce(tag_conditions, fn condition, acc ->
        dynamic([], ^acc or ^condition)
      end)

    from(p in query, where: ^combined_condition)
  end

  defp apply_search_filter(query, nil), do: query
  defp apply_search_filter(query, ""), do: query

  defp apply_search_filter(query, search) do
    clean_search = String.trim(search)

    if clean_search == "" do
      query
    else
      search_term = "%#{clean_search}%"

      from(p in query,
        where:
          like(p.title, ^search_term) or
            like(p.content, ^search_term) or
            (not is_nil(p.subtitle) and like(p.subtitle, ^search_term))
      )
    end
  end

  defp execute_query_and_render(query) do
    posts =
      case RepoService.all(query) do
        {:ok, posts} -> posts
        {:error, _} -> []
      end

    Enum.map(posts, fn post ->
      %{post | rendered_content: Post.render_content(post)}
    end)
  end

  @doc """
  Gets a published post by slug.

  Returns nil if the post does not exist or is not published.

  ## Examples

      iex> get_published_post_by_slug("my-post")
      %Post{}

      iex> get_published_post_by_slug("nonexistent")
      nil

  """
  def get_published_post_by_slug(slug) do
    post =
      case RepoService.get_by(Post, slug: slug) do
        {:ok, post} when post.published == true and not is_nil(post.published_at) -> post
        _ -> nil
      end

    case post do
      nil -> nil
      post -> %{post | rendered_content: Post.render_content(post)}
    end
  end

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> get_post!(123)
      %Post{}

      iex> get_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_post!(id) do
    case RepoService.get(Post, id) do
      {:ok, post} -> post
      {:error, :not_found} -> raise Ecto.NoResultsError, queryable: Post
      {:error, _} -> raise "Database error"
    end
  end

  @doc """
  Gets a single post by ID.

  Returns nil if the Post does not exist.

  ## Examples

      iex> get_post(123)
      %Post{}

      iex> get_post(456)
      nil

  """
  def get_post(id, opts \\ []) do
    allow_unpublished = Keyword.get(opts, :allow_unpublished, false)

    case RepoService.get(Post, id) do
      {:ok, post} when allow_unpublished == true -> post
      {:ok, post} when post.published == true and not is_nil(post.published_at) -> post
      _ -> nil
    end
  end

  @doc """
  Returns posts with pagination for API usage.

  ## Examples

      iex> list_posts_paginated(1, 10)
      [%Post{}, ...]

  """
  def list_posts_paginated(page \\ 1, per_page \\ 20) do
    offset = (page - 1) * per_page

    from(p in Post,
      where: p.published == true and not is_nil(p.published_at),
      order_by: [desc: p.published_at],
      limit: ^per_page,
      offset: ^offset
    )
    |> RepoService.all()
    |> case do
      {:ok, posts} -> posts
      {:error, _} -> []
    end
  end

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> RepoService.insert()
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> RepoService.update()
  end

  @doc """
  Deletes a post.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    RepoService.delete(post)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{data: %Post{}}

  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @doc """
  Returns all unique tags from published posts.

  ## Examples

      iex> list_available_tags()
      ["elixir", "phoenix", "web-development"]

  """
  def list_available_tags do
    from(p in Post,
      where:
        p.published == true and not is_nil(p.published_at) and not is_nil(p.tags) and
          p.tags != ""
    )
    |> RepoService.all()
    |> case do
      {:ok, posts} -> posts
      {:error, _} -> []
    end
    |> Enum.map(& &1.tags)
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.flat_map(fn tags_string ->
      tags_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    end)
    |> Enum.uniq()
    |> Enum.sort()
  rescue
    _ -> []
  end

  @doc """
  Returns the top N most frequently used tags from published posts.

  ## Examples

      iex> list_top_tags(5)
      ["elixir", "phoenix", "web-development", "programming", "tutorial"]

  """
  def list_top_tags(limit \\ 5) do
    from(p in Post,
      where:
        p.published == true and not is_nil(p.published_at) and not is_nil(p.tags) and
          p.tags != ""
    )
    |> RepoService.all()
    |> case do
      {:ok, posts} -> posts
      {:error, _} -> []
    end
    |> Enum.map(& &1.tags)
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.flat_map(fn tags_string ->
      tags_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_tag, count} -> count end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {tag, _count} -> tag end)
  rescue
    _ -> []
  end
end
