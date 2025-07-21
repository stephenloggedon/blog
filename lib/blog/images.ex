defmodule Blog.Images do
  @moduledoc """
  Context for managing image storage and retrieval.
  """

  import Ecto.Query
  alias Blog.Content.Post
  alias Blog.Image
  alias Blog.RepoService
  alias Vix.Vips.Image, as: VipsImage
  alias Vix.Vips.Operation, as: VipsOperation

  # 5MB
  @max_image_size 5 * 1024 * 1024
  @allowed_types ["image/jpeg", "image/png", "image/gif", "image/webp"]
  @thumbnail_size 400

  @doc """
  Stores an image for a given post.
  """
  def store_image(post_id, filename, content_type, image_binary, alt_text \\ nil) do
    with {:ok, _post} <- get_post(post_id),
         :ok <- validate_image(image_binary, content_type),
         {:ok, thumbnail_binary} <- create_thumbnail(image_binary, content_type) do
      %Image{}
      |> Image.changeset(%{
        post_id: post_id,
        filename: filename,
        content_type: content_type,
        alt_text: alt_text,
        image_data: image_binary,
        thumbnail_data: thumbnail_binary,
        file_size: byte_size(image_binary)
      })
      |> RepoService.insert()
    end
  end

  @doc """
  Gets an image by ID.
  """
  def get_image(id) do
    case RepoService.get(Image, id) do
      {:ok, image} -> {:ok, image}
      {:error, :not_found} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Gets all images for a post.
  """
  def get_post_images(post_id) do
    Image
    |> where([i], i.post_id == ^post_id)
    |> order_by([i], i.inserted_at)
    |> RepoService.all()
    |> case do
      {:ok, images} -> images
      {:error, _} -> []
    end
  end

  @doc """
  Deletes an image.
  """
  def delete_image(id) do
    case get_image(id) do
      {:ok, image} -> RepoService.delete(image)
      error -> error
    end
  end

  @doc """
  Gets the thumbnail data for an image.
  """
  def get_thumbnail(id) do
    _query =
      from i in Image,
        where: i.id == ^id,
        select: %{thumbnail_data: i.thumbnail_data, content_type: i.content_type}

    case RepoService.query("SELECT thumbnail_data, content_type FROM images WHERE id = ?", [id]) do
      {:ok, %{rows: [[nil, _]]}} ->
        {:error, :no_thumbnail}

      {:ok, %{rows: [[thumbnail_data, content_type]]}} ->
        {:ok, %{thumbnail_data: thumbnail_data, content_type: content_type}}

      {:ok, %{rows: []}} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  # Private functions

  defp get_post(post_id) do
    case RepoService.get(Post, post_id) do
      {:ok, post} -> {:ok, post}
      {:error, :not_found} -> {:error, :post_not_found}
      error -> error
    end
  end

  defp validate_image(image_binary, content_type) do
    cond do
      byte_size(image_binary) > @max_image_size ->
        {:error, :file_too_large}

      content_type not in @allowed_types ->
        {:error, :invalid_file_type}

      not valid_image_binary?(image_binary) ->
        {:error, :corrupted_image}

      true ->
        :ok
    end
  end

  defp valid_image_binary?(image_binary) do
    case VipsImage.new_from_buffer(image_binary) do
      {:ok, _image} -> true
      {:error, _} -> false
    end
  rescue
    _ ->
      # If Vix is not available, do basic header checks
      basic_image_validation(image_binary)
  end

  # PNG
  defp basic_image_validation(<<0x89, 0x50, 0x4E, 0x47, _rest::binary>>), do: true
  # JPEG
  defp basic_image_validation(<<0xFF, 0xD8, 0xFF, _rest::binary>>), do: true
  # GIF
  defp basic_image_validation(<<0x47, 0x49, 0x46, _rest::binary>>), do: true
  # WebP
  defp basic_image_validation(<<"RIFF", _size::32-little, "WEBP", _rest::binary>>), do: true
  defp basic_image_validation(_), do: false

  defp create_thumbnail(image_binary, _content_type) do
    # Create a thumbnail using Vix
    with {:ok, _image} <- VipsImage.new_from_buffer(image_binary),
         {:ok, resized} <-
           VipsOperation.thumbnail_buffer(image_binary, @thumbnail_size, height: @thumbnail_size),
         {:ok, thumbnail_binary} <- VipsImage.write_to_buffer(resized, ".png") do
      {:ok, thumbnail_binary}
    else
      _error ->
        # Fallback to original image if thumbnail creation fails
        {:ok, image_binary}
    end
  rescue
    _ ->
      # Fallback to original image if Vix is not available or fails
      {:ok, image_binary}
  end
end
