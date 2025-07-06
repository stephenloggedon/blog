defmodule BlogWeb.Services.CloudStorage do
  @moduledoc """
  Cloud storage service for handling image uploads.
  
  This module provides a unified interface for uploading images to cloud storage
  providers. Currently supports AWS S3 and S3-compatible services.
  """
  
  require Logger
  
  @doc """
  Upload an image file to cloud storage.
  
  Returns {:ok, public_url} on success or {:error, reason} on failure.
  """
  def upload_image(file_binary, filename, content_type \\ "image/jpeg") do
    bucket = get_bucket_name()
    key = generate_storage_key(filename)
    
    case ExAws.S3.put_object(bucket, key, file_binary, [
      content_type: content_type,
      acl: :public_read
    ]) |> ExAws.request() do
      {:ok, _response} ->
        public_url = build_public_url(bucket, key)
        Logger.info("Successfully uploaded image: #{key}")
        {:ok, public_url}
      
      {:error, reason} ->
        Logger.error("Failed to upload image: #{inspect(reason)}")
        {:error, :upload_failed}
    end
  end
  
  @doc """
  Upload multiple images from a multipart request.
  
  Returns {:ok, urls} with a list of public URLs or {:error, reason}.
  """
  def upload_images(uploads) when is_list(uploads) do
    results = Enum.map(uploads, &upload_single_image/1)
    
    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        urls = Enum.map(results, fn {:ok, url} -> url end)
        {:ok, urls}
      
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Delete an image from cloud storage.
  """
  def delete_image(public_url) do
    bucket = get_bucket_name()
    key = extract_key_from_url(public_url)
    
    case ExAws.S3.delete_object(bucket, key) |> ExAws.request() do
      {:ok, _response} ->
        Logger.info("Successfully deleted image: #{key}")
        :ok
      
      {:error, reason} ->
        Logger.error("Failed to delete image: #{inspect(reason)}")
        {:error, :delete_failed}
    end
  end
  
  @doc """
  Generate a unique storage key for a file.
  """
  def generate_storage_key(filename) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random_string = :crypto.strong_rand_bytes(8) |> Base.encode64(padding: false)
    extension = Path.extname(filename)
    
    "blog/images/#{timestamp}-#{random_string}#{extension}"
  end
  
  @doc """
  Validate that a file is a supported image format.
  """
  def validate_image(upload) do
    allowed_types = ["image/jpeg", "image/png", "image/gif", "image/webp"]
    max_size = 10 * 1024 * 1024  # 10MB
    
    cond do
      upload.content_type not in allowed_types ->
        {:error, :unsupported_file_type}
      
      upload.size > max_size ->
        {:error, :file_too_large}
      
      true ->
        :ok
    end
  end
  
  # Private functions
  
  defp upload_single_image(%Plug.Upload{} = upload) do
    with :ok <- validate_image(upload),
         {:ok, file_binary} <- File.read(upload.path) do
      upload_image(file_binary, upload.filename, upload.content_type)
    end
  end
  
  defp get_bucket_name do
    Application.get_env(:blog, :s3_bucket) ||
      System.get_env("S3_BUCKET") ||
      "blog-images-dev"
  end
  
  defp build_public_url(bucket, key) do
    region = Application.get_env(:ex_aws, :region, "us-east-1")
    
    case System.get_env("S3_ENDPOINT") do
      nil ->
        # Standard AWS S3 URL
        "https://#{bucket}.s3.#{region}.amazonaws.com/#{key}"
      
      endpoint ->
        # Custom S3-compatible endpoint (DigitalOcean Spaces, etc.)
        "#{endpoint}/#{bucket}/#{key}"
    end
  end
  
  defp extract_key_from_url(url) do
    # Extract the storage key from a public URL
    # This is a simplified implementation - you might need more robust parsing
    case String.split(url, "/") do
      parts when length(parts) >= 2 ->
        parts
        |> Enum.drop_while(&(not String.contains?(&1, "blog")))
        |> Enum.join("/")
      
      _ -> nil
    end
  end
end