defmodule Blog.Repo.Migrations.RemoveSeriesPublishedField do
  use Ecto.Migration

  def change do
    alter table(:series) do
      remove :published
    end
  end
end