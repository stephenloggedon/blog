defmodule Blog.Content.Post do
  @moduledoc """
  The Post schema and changeset functions for blog posts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :slug, :string
    field :content, :string
    field :excerpt, :string
    field :preview, :string
    field :subtitle, :string
    field :tags, :string
    field :published, :boolean, default: false
    field :published_at, :utc_datetime
    field :rendered_content, :string, virtual: true
    field :series_position, :integer

    belongs_to :series, Blog.Content.Series
    has_many :images, Blog.Image, foreign_key: :post_id

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
      :preview,
      :subtitle,
      :tags,
      :published,
      :published_at,
      :series_id,
      :series_position
    ])
    |> validate_required([:title, :content])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:content, min: 1)
    |> validate_series_position()
    |> maybe_generate_slug()
    |> maybe_generate_excerpt()
    |> maybe_generate_preview()
    |> validate_required([:preview])
    |> maybe_set_published_at()
    |> convert_content_links()
    |> parse_tags()
    |> unique_constraint(:slug)
    |> unique_constraint([:series_id, :series_position])
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
  Converts internal markdown file links to proper blog post URLs.
  Converts patterns like [text](/filename) or [text](./filename.md) to [text](/blog/slug)
  """
  def convert_internal_links(content) when is_binary(content) do
    # Pattern to match markdown links that reference local files
    # Matches: [text](/filename), [text](./filename.md), [text](filename.md)
    link_pattern = ~r/\[([^\]]+)\]\(\.?\/?([\w_-]+)(?:\.md)?\)/

    Regex.replace(link_pattern, content, fn _full_match, link_text, filename ->
      # Convert filename to slug format (same as generate_slug/1)
      slug = generate_slug_from_filename(filename)
      "[#{link_text}](/blog/#{slug})"
    end)
  end

  @doc """
  Generates a slug from a filename, converting common patterns.
  """
  def generate_slug_from_filename(filename) do
    # Remove numbered prefixes like "02_" and generate slug from the rest
    cleaned_filename =
      filename
      # Remove leading numbers and underscore
      |> String.replace(~r/^\d+_/, "")
      # Convert underscores to spaces
      |> String.replace("_", " ")

    generate_slug(cleaned_filename)
  end

  @doc """
  Returns the first N lines of content for preview.
  """
  def preview_content(content, lines \\ 6) do
    truncated_markdown =
      content
      |> String.split("\n")
      |> Enum.take(lines)
      |> Enum.join("\n")

    render_preview_content(truncated_markdown)
  end

  @doc """
  Renders preview markdown content to HTML, removing anchor tags to avoid nested links.
  """
  def render_preview_content(preview_markdown) when is_binary(preview_markdown) do
    html = Earmark.as_html!(preview_markdown)

    # Parse the HTML and remove any anchor tags to avoid nested links.
    # The text content of the links will be preserved.
    {:ok, parsed_html} = Floki.parse_document(html)

    cleaned_html =
      parsed_html
      |> Floki.traverse_and_update(fn
        {"a", _attrs, children} -> children
        node -> node
      end)
      |> Floki.raw_html()

    Phoenix.HTML.raw(cleaned_html)
  end

  def render_preview_content(_), do: ""

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

  defp maybe_generate_preview(changeset) do
    case get_change(changeset, :preview) do
      nil ->
        case get_change(changeset, :content) do
          nil ->
            changeset

          content ->
            preview =
              content
              |> String.split("\n")
              |> Enum.take(6)
              |> Enum.join("\n")

            put_change(changeset, :preview, preview)
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

  defp convert_content_links(changeset) do
    case get_change(changeset, :content) do
      nil ->
        changeset

      content when is_binary(content) ->
        converted_content = convert_internal_links(content)
        put_change(changeset, :content, converted_content)

      _ ->
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

  defp validate_series_position(changeset) do
    series_id = get_field(changeset, :series_id)
    series_position = get_field(changeset, :series_position)

    cond do
      is_nil(series_id) and is_nil(series_position) ->
        # Both nil is valid
        changeset

      not is_nil(series_id) and not is_nil(series_position) ->
        # Both set is valid, validate position is positive
        validate_number(changeset, :series_position, greater_than: 0)

      is_nil(series_id) and not is_nil(series_position) ->
        # Position set without series is invalid
        add_error(changeset, :series_position, "cannot be set without a series")

      not is_nil(series_id) and is_nil(series_position) ->
        # Series set without position is invalid
        add_error(changeset, :series_position, "must be set when post belongs to a series")
    end
  end
end
