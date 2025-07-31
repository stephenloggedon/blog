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
    # Use simple SQL that works with both local SQLite and Turso
    # This will take the first 500 characters as a reasonable preview
    execute("""
      UPDATE posts 
      SET preview = SUBSTR(content, 1, 500)
      WHERE preview IS NULL OR preview = ''
    """)
  end

  defp rollback_preview_population do
    execute("UPDATE posts SET preview = NULL")
  end
end
