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

  # Handle both Post structs and maps dynamically
  defp data(%Post{} = post) do
    post |> Map.from_struct() |> data()
  end

  defp data(%{} = post_data) do
    # Only include fields that exist in the post data
    base_fields = [
      :id,
      :title,
      :slug,
      :excerpt,
      :tags,
      :published,
      :published_at,
      :inserted_at,
      :updated_at
    ]

    optional_fields = [:content, :subtitle]

    all_fields = base_fields ++ optional_fields

    all_fields
    |> Enum.filter(&Map.has_key?(post_data, &1))
    |> Map.new(fn field -> {field, Map.get(post_data, field)} end)
  end
end
