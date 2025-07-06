defmodule BlogWeb.Api.PostJSON do
  alias Blog.Content.Post

  def index(%{posts: posts}) do
    %{data: for(post <- posts, do: data(post))}
  end

  def show(%{post: post}) do
    %{data: data(post)}
  end

  def error(%{changeset: changeset}) do
    %{errors: errors_for_changeset(changeset)}
  end

  def error(%{message: message}) do
    %{message: message}
  end

  defp errors_for_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp data(%Post{} = post) do
    %{
      id: post.id,
      title: post.title,
      slug: post.slug,
      content: post.content,
      excerpt: post.excerpt,
      tags: post.tags,
      published: post.published,
      published_at: post.published_at,
      inserted_at: post.inserted_at,
      updated_at: post.updated_at
    }
  end
end
