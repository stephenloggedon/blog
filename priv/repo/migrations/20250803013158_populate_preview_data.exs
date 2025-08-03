defmodule Blog.Repo.Migrations.PopulatePreviewData do
  use Ecto.Migration

  def up do
    # Populate preview field for all posts that have content but no preview
    execute("""
      UPDATE posts 
      SET preview = SUBSTR(content, 1, 500)
      WHERE content IS NOT NULL 
        AND content <> ''
        AND (preview IS NULL OR preview = '')
    """)
  end

  def down do
    # Optionally clear preview data if rolling back
    execute("UPDATE posts SET preview = NULL")
  end
end
