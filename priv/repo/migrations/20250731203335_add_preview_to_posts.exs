defmodule Blog.Repo.Migrations.AddPreviewToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :preview, :text
    end

    # Populate preview field for existing posts
    execute(&populate_preview_for_existing_posts/0, &rollback_preview_population/0)
  end

  defp populate_preview_for_existing_posts do
    # For Turso compatibility, use raw SQL to get posts and update them
    # First, get all posts that need preview population
    {:ok, result} =
      repo().query("SELECT id, content FROM posts WHERE preview IS NULL OR preview = ''", [])

    # Process each post and update with preview content
    for [id, content] <- result.rows do
      preview = generate_preview(content)
      repo().query!("UPDATE posts SET preview = ? WHERE id = ?", [preview, id])
    end
  end

  defp generate_preview(nil), do: ""

  defp generate_preview(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> Enum.take(6)
    |> Enum.join("\n")
  end

  defp generate_preview(_), do: ""

  defp rollback_preview_population do
    repo().query!("UPDATE posts SET preview = NULL")
  end
end
