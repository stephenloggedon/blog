defmodule Blog.Image do
  use Ecto.Schema
  import Ecto.Changeset

  schema "images" do
    field :filename, :string
    field :content_type, :string
    field :alt_text, :string
    field :image_data, :binary
    field :thumbnail_data, :binary
    field :file_size, :integer

    belongs_to :post, Blog.Content.Post

    timestamps()
  end

  @doc false
  def changeset(image, attrs) do
    image
    |> cast(attrs, [
      :filename,
      :content_type,
      :alt_text,
      :image_data,
      :thumbnail_data,
      :file_size,
      :post_id
    ])
    |> validate_required([:filename, :content_type, :image_data, :post_id])
    |> validate_inclusion(:content_type, ["image/jpeg", "image/png", "image/gif", "image/webp"])
    |> foreign_key_constraint(:post_id)
  end
end
