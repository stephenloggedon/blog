defmodule Blog.Repo.Migrations.AddSeriesPublishedIndex do
  use Ecto.Migration

  def change do
    # Add composite index for efficient series filtering by published posts
    # This supports queries like: posts WHERE series_id = ? AND published_at <= NOW()
    create index(:posts, [:series_id, :published_at])
  end
end
