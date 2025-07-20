defmodule Blog.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :string
      add :slug, :string
      add :content, :text
      add :excerpt, :text
      add :tags, :text
      add :published, :boolean, default: false, null: false
      add :published_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:posts, [:slug])
  end
end
