defmodule Blog.Repo.Migrations.CreateSeries do
  use Ecto.Migration

  def change do
    create table(:series) do
      add :title, :string, null: false
      add :description, :text
      add :slug, :string, null: false
      add :published, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:series, [:slug])
  end
end
