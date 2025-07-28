defmodule Blog.Repo.Migrations.AddSeriesToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :series_id, references(:series, on_delete: :nilify_all)
      add :series_position, :integer
    end

    create index(:posts, [:series_id])
    
    # Unique constraint on series_id + position, excluding NULLs
    create unique_index(:posts, [:series_id, :series_position], 
           where: "series_id IS NOT NULL")

    # Note: Check constraint validation will be handled at the application level
    # since SQLite doesn't support adding check constraints with ALTER TABLE
  end
end
