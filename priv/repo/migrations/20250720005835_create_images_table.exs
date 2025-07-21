defmodule Blog.Repo.Migrations.CreateImagesTable do
  use Ecto.Migration

  def change do
    create table(:images) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :alt_text, :text
      add :image_data, :binary, null: false
      add :thumbnail_data, :binary
      add :file_size, :integer

      timestamps()
    end

    create index(:images, [:post_id])
  end
end
