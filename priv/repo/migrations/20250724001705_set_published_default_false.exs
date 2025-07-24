defmodule Blog.Repo.Migrations.SetPublishedDefaultFalse do
  use Ecto.Migration

  def change do
    # SQLite doesn't support ALTER COLUMN, so we'll update existing records
    # and rely on the schema default for new records
    execute "UPDATE posts SET published = COALESCE(published, false) WHERE published IS NULL"
  end
end
