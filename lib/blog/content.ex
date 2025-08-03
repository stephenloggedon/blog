defmodule Blog.Content do
  @moduledoc """
  The Content context.
  """

  import Ecto.Query, warn: false
  alias Blog.RepoService

  alias Blog.Content.Post
  alias Blog.Content.Series

  @doc """
  Returns posts with pagination, filtering, and search support.

  ## Options
  - `:page` - Page number (default: 1)
  - `:per_page` - Posts per page (default: 10)  
  - `:tags` - List of tags to filter by
  - `:search` - Search term for title/content
  - `:allow_unpublished` - Include unpublished posts (default: false)
  - `:include_content` - Include full post content (default: false)
  - `:preview_lines` - Include truncated content for preview (number of lines, default: nil)
  - `:include_preview` - Include preview field with rendered HTML (default: false)

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
    series = Keyword.get(opts, :series, [])
    allow_unpublished = Keyword.get(opts, :allow_unpublished, false)
    include_content = Keyword.get(opts, :include_content, false)
    preview_lines = Keyword.get(opts, :preview_lines)
    include_preview = Keyword.get(opts, :include_preview, false)

    base_query =
      if allow_unpublished do
        from(p in Post)
      else
        from(p in Post, where: p.published == true and not is_nil(p.published_at))
      end

    result =
      base_query
      |> apply_tag_filter(tags)
      |> apply_search_filter(search)
      |> apply_series_filter(series)
      |> order_by([p], desc: p.inserted_at)
      |> limit(^per_page)
      |> offset(^offset)
      |> RepoService.all()
      |> case do
        {:ok, posts} -> posts
        {:error, _} -> []
      end

    result
    |> maybe_add_rendered_content(include_content, preview_lines, tags, search, page, per_page)
    |> maybe_add_rendered_preview(include_preview)
    |> maybe_filter_fields(opts)
  rescue
    _ -> []
  end

  defp maybe_add_rendered_preview(posts, false), do: posts

  defp maybe_add_rendered_preview(posts, true) do
    Enum.map(posts, fn post ->
      case Map.get(post, :preview) do
        nil ->
          post

        preview_markdown ->
          rendered_preview = Post.render_preview_content(preview_markdown)
          Map.put(post, :rendered_preview, rendered_preview)
      end
    end)
  end

  defp maybe_add_rendered_content(
         posts,
         include_content,
         preview_lines,
         tags,
         search,
         page,
         per_page
       ) do
    cond do
      # Add full rendered content if explicitly requested
      include_content and (tags != [] or search != nil or page != 1 or per_page != 10) ->
        Enum.map(posts, fn post ->
          %{post | rendered_content: Post.render_content(post)}
        end)

      # Add preview content if preview_lines is specified
      is_integer(preview_lines) and preview_lines > 0 ->
        Enum.map(posts, fn post ->
          preview_content = Post.preview_content(post.content, preview_lines)
          Map.put(post, :preview_content, preview_content)
        end)

      # No additional content processing
      true ->
        posts
    end
  end

  defp maybe_filter_fields(posts, opts) do
    exclude_fields = get_excluded_fields(opts)

    Enum.map(posts, fn post ->
      exclude_fields_from_struct(post, exclude_fields)
    end)
  end

  defp get_excluded_fields(opts) do
    excluded = [:__meta__, :rendered_content, :images]

    # For the preview_lines case (homepage), only exclude minimal fields and always preserve subtitle
    cond do
      Keyword.get(opts, :preview_lines) ->
        # Exclude both content and preview when using preview_lines
        excluded ++ [:content, :preview]

      Keyword.get(opts, :include_preview, false) ->
        excluded ++
          [:excerpt, :inserted_at, :published] ++
          if Keyword.get(opts, :include_content, false), do: [], else: [:content]

      true ->
        # Always exclude these fields for consistency
        excluded = excluded ++ [:excerpt, :inserted_at, :published, :preview]

        # Include or exclude content based on options
        excluded =
          if Keyword.get(opts, :include_content, false), do: excluded, else: [:content | excluded]

        excluded
    end
  end

  defp exclude_fields_from_struct(%Post{} = post, fields) do
    post
    |> Map.from_struct()
    |> Map.drop(fields)
    |> remove_null_values()
  end

  defp exclude_fields_from_struct(post_map, fields) when is_map(post_map) do
    post_map
    |> Map.drop(fields)
    |> remove_null_values()
  end

  defp remove_null_values(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  def list_published_posts(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)
    offset = (page - 1) * per_page
    tags = Keyword.get(opts, :tags, [])
    search = Keyword.get(opts, :search)
    series = Keyword.get(opts, :series, [])

    query = from(p in Post, where: p.published == true and not is_nil(p.published_at))

    query
    |> apply_tag_filter(tags)
    |> apply_search_filter(search)
    |> apply_series_filter(series)
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

  defp apply_series_filter(query, []), do: query

  defp apply_series_filter(query, series_slugs) when is_list(series_slugs) do
    from(p in query,
      join: s in Series,
      on: p.series_id == s.id,
      where: s.slug in ^series_slugs
    )
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

      iex> list_top_tags(15)
      ["elixir", "phoenix", "web-development", "programming", "tutorial"]

  """
  def list_top_tags(limit \\ 15) do
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

  @doc """
  Returns the list of series.

  ## Examples

      iex> list_series()
      [%Series{}, ...]

  """
  def list_series do
    from(s in Series, order_by: [asc: s.title])
    |> RepoService.all()
    |> case do
      {:ok, series} -> series
      {:error, _} -> []
    end
  end

  @doc """
  Returns the list of series for filtering.
  A series is available for filtering if it exists, regardless of published status.

  ## Examples

      iex> list_series_for_filtering()
      [%Series{}, ...]

  """
  def list_series_for_filtering do
    from(s in Series, order_by: [asc: s.title])
    |> RepoService.all()
    |> case do
      {:ok, series} -> series
      {:error, _} -> []
    end
  end

  @doc """
  Gets a single series.

  Raises `Ecto.NoResultsError` if the Series does not exist.

  ## Examples

      iex> get_series!(123)
      %Series{}

      iex> get_series!(456)
      ** (Ecto.NoResultsError)

  """
  def get_series!(id) do
    case RepoService.get(Series, id) do
      {:ok, series} -> series
      {:error, :not_found} -> raise Ecto.NoResultsError, queryable: Series
      {:error, _} -> raise "Database error"
    end
  end

  @doc """
  Gets a single series by ID.

  Returns nil if the Series does not exist.

  ## Examples

      iex> get_series(123)
      %Series{}

      iex> get_series(456)
      nil

  """
  def get_series(id) do
    case RepoService.get(Series, id) do
      {:ok, series} -> series
      {:error, _} -> nil
    end
  end

  @doc """
  Gets a series by slug.

  Returns nil if the series does not exist.

  ## Examples

      iex> get_series_by_slug("my-series")
      %Series{}

      iex> get_series_by_slug("nonexistent")
      nil

  """
  def get_series_by_slug(slug) do
    case RepoService.get_by(Series, slug: slug) do
      {:ok, series} -> series
      {:error, _} -> nil
    end
  end

  @doc """
  Creates a series.

  ## Examples

      iex> create_series(%{field: value})
      {:ok, %Series{}}

      iex> create_series(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_series(attrs \\ %{}) do
    %Series{}
    |> Series.changeset(attrs)
    |> RepoService.insert()
  end

  @doc """
  Updates a series.

  ## Examples

      iex> update_series(series, %{field: new_value})
      {:ok, %Series{}}

      iex> update_series(series, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_series(%Series{} = series, attrs) do
    series
    |> Series.changeset(attrs)
    |> RepoService.update()
  end

  @doc """
  Deletes a series.

  ## Examples

      iex> delete_series(series)
      {:ok, %Series{}}

      iex> delete_series(series)
      {:error, %Ecto.Changeset{}}

  """
  def delete_series(%Series{} = series) do
    RepoService.delete(series)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking series changes.

  ## Examples

      iex> change_series(series)
      %Ecto.Changeset{data: %Series{}}

  """
  def change_series(%Series{} = series, attrs \\ %{}) do
    Series.changeset(series, attrs)
  end

  @doc """
  Gets posts in a series, ordered by position.

  ## Examples

      iex> get_posts_in_series(series_id)
      [%Post{}, ...]

  """
  def get_posts_in_series(series_id, opts \\ []) do
    allow_unpublished = Keyword.get(opts, :allow_unpublished, false)

    base_query =
      if allow_unpublished do
        from(p in Post, where: p.series_id == ^series_id)
      else
        from(p in Post,
          where: p.series_id == ^series_id and p.published == true and not is_nil(p.published_at)
        )
      end

    base_query
    |> order_by([p], asc: p.series_position)
    |> RepoService.all()
    |> case do
      {:ok, posts} -> posts
      {:error, _} -> []
    end
  end

  @doc """
  Adds a post to a series at the specified position.
  If position is not provided, adds at the end.

  ## Examples

      iex> add_post_to_series(post, series_id, 1)
      {:ok, %Post{}}

      iex> add_post_to_series(post, series_id)
      {:ok, %Post{}}

  """
  def add_post_to_series(%Post{} = post, series_id, position \\ nil) do
    final_position = position || get_next_series_position(series_id)

    # If inserting in the middle, shift other posts
    if position && position <= get_max_series_position(series_id) do
      shift_series_positions(series_id, position, 1)
    end

    update_post(post, %{
      series_id: series_id,
      series_position: final_position
    })
  end

  @doc """
  Removes a post from its series.

  ## Examples

      iex> remove_post_from_series(post)
      {:ok, %Post{}}

  """
  def remove_post_from_series(%Post{} = post) do
    case post do
      %{series_id: nil} ->
        {:ok, post}

      %{series_id: series_id, series_position: position} ->
        # Remove from series
        result = update_post(post, %{series_id: nil, series_position: nil})

        # Shift remaining posts down
        shift_series_positions(series_id, position + 1, -1)

        result
    end
  end

  @doc """
  Reorders posts within a series.

  ## Examples

      iex> reorder_series_posts(series_id, [post_id1, post_id2, post_id3])
      :ok

  """
  def reorder_series_posts(_series_id, ordered_post_ids) do
    ordered_post_ids
    |> Enum.with_index(1)
    |> Enum.each(fn {post_id, position} ->
      case get_post(post_id, allow_unpublished: true) do
        %Post{} = post ->
          update_post(post, %{series_position: position})

        nil ->
          :skip
      end
    end)

    :ok
  end

  @doc """
  Gets the next post in a series.

  ## Examples

      iex> get_next_post_in_series(post)
      %Post{}

      iex> get_next_post_in_series(last_post)
      nil

  """
  def get_next_post_in_series(%Post{series_id: nil}), do: nil

  def get_next_post_in_series(%Post{series_id: series_id, series_position: position}) do
    from(p in Post,
      where:
        p.series_id == ^series_id and p.series_position == ^(position + 1) and
          p.published == true and not is_nil(p.published_at)
    )
    |> RepoService.one()
    |> case do
      {:ok, post} -> post
      {:error, _} -> nil
    end
  end

  @doc """
  Gets the previous post in a series.

  ## Examples

      iex> get_previous_post_in_series(post)
      %Post{}

      iex> get_previous_post_in_series(first_post)
      nil

  """
  def get_previous_post_in_series(%Post{series_id: nil}), do: nil

  def get_previous_post_in_series(%Post{series_id: series_id, series_position: position}) do
    from(p in Post,
      where:
        p.series_id == ^series_id and p.series_position == ^(position - 1) and
          p.published == true and not is_nil(p.published_at)
    )
    |> RepoService.one()
    |> case do
      {:ok, post} -> post
      {:error, _} -> nil
    end
  end

  # Private helper functions for series management

  defp get_next_series_position(series_id) do
    get_max_series_position(series_id) + 1
  end

  defp get_max_series_position(series_id) do
    from(p in Post,
      where: p.series_id == ^series_id,
      select: max(p.series_position)
    )
    |> RepoService.one()
    |> case do
      {:ok, nil} -> 0
      {:ok, max_position} -> max_position
      {:error, _} -> 0
    end
  end

  defp shift_series_positions(series_id, from_position, shift_amount) do
    from(p in Post,
      where: p.series_id == ^series_id and p.series_position >= ^from_position
    )
    |> RepoService.update_all(inc: [series_position: shift_amount])
  end

  @doc """
  Checks if a series (by slug) has unpublished posts but no published posts.

  Returns metadata about the series empty state:
  - `:no_posts` - Series has no posts at all
  - `:has_published` - Series has published posts
  - `{:upcoming_only, nil}` - Series has only unpublished posts with no scheduled date
  - `{:upcoming_only, datetime}` - Series has unpublished posts with earliest publication date

  ## Examples

      iex> get_series_empty_state("my-series")
      {:upcoming_only, ~U[2024-12-01 10:00:00Z]}
      
      iex> get_series_empty_state("published-series")
      :has_published
      
      iex> get_series_empty_state("empty-series")
      :no_posts
  """
  def get_series_empty_state(series_slug) when is_binary(series_slug) do
    case get_series_by_slug(series_slug) do
      nil -> :no_posts
      series -> get_series_empty_state_by_id(series.id)
    end
  end

  def get_series_empty_state(nil), do: :no_posts

  defp get_series_empty_state_by_id(series_id) do
    published_count = get_series_published_count(series_id)
    total_count = get_series_total_count(series_id)

    determine_series_empty_state(series_id, published_count, total_count)
  end

  defp get_series_published_count(series_id) do
    from(p in Post,
      where: p.series_id == ^series_id and p.published == true,
      select: count(p.id)
    )
    |> RepoService.one()
    |> case do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end

  defp get_series_total_count(series_id) do
    from(p in Post,
      where: p.series_id == ^series_id,
      select: count(p.id)
    )
    |> RepoService.one()
    |> case do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end

  defp determine_series_empty_state(_series_id, _published_count, 0), do: :no_posts

  defp determine_series_empty_state(_series_id, published_count, _total_count)
       when published_count > 0,
       do: :has_published

  defp determine_series_empty_state(series_id, 0, total_count) when total_count > 0 do
    earliest_date = get_earliest_unpublished_date(series_id)
    {:upcoming_only, earliest_date}
  end

  defp get_earliest_unpublished_date(series_id) do
    from(p in Post,
      where: p.series_id == ^series_id and p.published == false,
      select: min(p.published_at),
      order_by: [asc: :series_position]
    )
    |> RepoService.one()
    |> case do
      {:ok, nil} -> nil
      {:ok, datetime} -> datetime
      {:error, _} -> nil
    end
  end
end
