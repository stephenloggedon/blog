defmodule Blog.Content.Series do
  @moduledoc """
  Schema for blog post series, allowing posts to be grouped and ordered sequentially.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "series" do
    field :title, :string
    field :description, :string
    field :slug, :string

    has_many :posts, Blog.Content.Post, foreign_key: :series_id

    timestamps()
  end

  @doc false
  def changeset(series, attrs) do
    series
    |> cast(attrs, [:title, :description, :slug])
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 255)
    |> generate_slug_if_needed()
    |> validate_required([:slug])
    |> validate_length(:slug, min: 1, max: 255)
    |> unique_constraint(:slug)
  end

  defp generate_slug_if_needed(changeset) do
    title = get_field(changeset, :title)
    slug = get_field(changeset, :slug)

    if title && (!slug || slug == "") do
      generated_slug =
        title
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9\s-]/, "")
        |> String.replace(~r/\s+/, "-")
        |> String.trim("-")

      put_change(changeset, :slug, generated_slug)
    else
      changeset
    end
  end
end
