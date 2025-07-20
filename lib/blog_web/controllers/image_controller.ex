defmodule BlogWeb.ImageController do
  use BlogWeb, :controller
  
  alias Blog.Images
  
  def show(conn, %{"id" => id}) do
    case Images.get_image(id) do
      {:ok, image} ->
        conn
        |> put_resp_content_type(image.content_type)
        |> put_resp_header("cache-control", "public, max-age=31536000")  # 1 year
        |> put_resp_header("etag", generate_etag(image))
        |> maybe_send_not_modified(conn, image)
        
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> text("Image not found")
    end
  end
  
  def thumbnail(conn, %{"id" => id}) do
    case Images.get_thumbnail(id) do
      {:ok, %{thumbnail_data: thumbnail_data, content_type: content_type}} ->
        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("cache-control", "public, max-age=31536000")  # 1 year
        |> send_resp(200, thumbnail_data)
        
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> text("Image not found")
        
      {:error, :no_thumbnail} ->
        # Fallback to full image if no thumbnail
        show(conn, %{"id" => id})
    end
  end
  
  defp generate_etag(image) do
    # Use image ID and updated_at to generate ETag
    hash_data = "#{image.id}-#{image.updated_at}"
    :crypto.hash(:sha256, hash_data)
    |> Base.encode64()
  end
  
  defp maybe_send_not_modified(conn, original_conn, image) do
    etag = generate_etag(image)
    
    case get_req_header(original_conn, "if-none-match") do
      [^etag] ->
        conn
        |> put_status(:not_modified)
        |> send_resp(304, "")
        
      _ ->
        conn
        |> send_resp(200, image.image_data)
    end
  end
end