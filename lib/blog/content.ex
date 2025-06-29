defmodule Blog.Content do
  @moduledoc """
  The Content context.
  """

  import Ecto.Query, warn: false
  alias Blog.Repo

  alias Blog.Content.Post

  @doc """
  Returns the list of posts.

  ## Examples

      iex> list_posts()
      [%Post{}, ...]

  """
  def list_posts do
    Repo.all(Post)
  end

  @doc """
  Returns published posts with pagination support.

  ## Examples

      iex> list_published_posts()
      [%Post{}, ...]

      iex> list_published_posts(page: 2, per_page: 5)
      [%Post{}, ...]

  """
  def list_published_posts(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)
    offset = (page - 1) * per_page

    posts = from(p in Post,
      where: not is_nil(p.published_at),
      order_by: [desc: p.published_at],
      limit: ^per_page,
      offset: ^offset
    )
    |> Repo.all()
    
    # Render content for each post
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
    post = from(p in Post,
      where: p.slug == ^slug and not is_nil(p.published_at)
    )
    |> Repo.one()
    
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
  def get_post!(id), do: Repo.get!(Post, id)

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
    |> Repo.insert()
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
    |> Repo.update()
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
    Repo.delete(post)
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
end
