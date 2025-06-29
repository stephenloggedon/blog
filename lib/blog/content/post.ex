defmodule Blog.Content.Post do
  use Ecto.Schema
  import Ecto.Changeset

  alias Blog.Accounts.User

  schema "posts" do
    field :title, :string
    field :slug, :string
    field :content, :string
    field :excerpt, :string
    field :subtitle, :string
    field :tags, :string
    field :published, :boolean, default: false
    field :published_at, :utc_datetime
    field :rendered_content, :string, virtual: true

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :title,
      :slug,
      :content,
      :excerpt,
      :subtitle,
      :tags,
      :published,
      :published_at,
      :user_id
    ])
    |> validate_required([:title, :content, :user_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:content, min: 1)
    |> maybe_generate_slug()
    |> maybe_generate_excerpt()
    |> maybe_set_published_at()
    |> parse_tags()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Returns a list of tag names from the tags string.
  """
  def tag_list(%__MODULE__{tags: tags}) when is_binary(tags) do
    tags
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  def tag_list(_), do: []

  @doc """
  Renders the markdown content to HTML.
  """
  def render_content(%__MODULE__{content: content}) when is_binary(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} -> html
      {:error, _html, _errors} -> content
    end
  end

  def render_content(_), do: ""

  @doc """
  Returns the first N lines of content for preview.
  """
  def preview_content(content, lines \\ 6) do
    content
    |> String.split("\n")
    |> Enum.take(lines)
    |> Enum.join("\n")
  end

  defp maybe_generate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        case get_change(changeset, :title) do
          nil -> changeset
          title -> put_change(changeset, :slug, generate_slug(title))
        end

      _ ->
        changeset
    end
  end

  defp generate_slug(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end

  defp maybe_generate_excerpt(changeset) do
    case get_change(changeset, :excerpt) do
      nil ->
        case get_change(changeset, :content) do
          nil ->
            changeset

          content ->
            excerpt =
              content
              |> String.split("\n")
              |> Enum.take(3)
              |> Enum.join(" ")
              |> String.slice(0, 200)

            put_change(changeset, :excerpt, excerpt)
        end

      _ ->
        changeset
    end
  end

  defp maybe_set_published_at(changeset) do
    published = get_change(changeset, :published)
    current_published = Map.get(changeset.data, :published, false)

    if published == true and not current_published do
      put_change(changeset, :published_at, DateTime.utc_now() |> DateTime.truncate(:second))
    else
      changeset
    end
  end

  defp parse_tags(changeset) do
    case get_change(changeset, :tags) do
      nil ->
        changeset

      tags when is_binary(tags) ->
        cleaned_tags =
          tags
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.uniq()
          |> Enum.join(", ")

        put_change(changeset, :tags, cleaned_tags)

      _ ->
        changeset
    end
  end
end
