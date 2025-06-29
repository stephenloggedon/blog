defmodule Blog.Repo.Migrations.AddSubtitleToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :subtitle, :string
    end
  end
end
