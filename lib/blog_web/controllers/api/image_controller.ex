defmodule BlogWeb.Api.ImageController do
  use BlogWeb, :controller

  alias Blog.Images

  def upload(conn, %{"post_id" => post_id} = params) do
    with {:ok, image_file} <- extract_image_file(params),
         {:ok, image_binary} <- read_file_contents(image_file),
         {:ok, image} <-
           Images.store_image(
             String.to_integer(post_id),
             image_file.filename,
             image_file.content_type,
             image_binary,
             params["alt_text"]
           ) do
      image_url = "/images/#{image.id}"

      conn
      |> put_status(:created)
      |> json(%{
        id: image.id,
        url: image_url,
        filename: image.filename,
        alt_text: image.alt_text
      })
    else
      {:error, :file_too_large} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "File too large. Maximum size is 5MB"})

      {:error, :invalid_file_type} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid file type. Supported: JPEG, PNG, GIF, WebP"})

      {:error, :post_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Post not found"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Validation failed", details: changeset_errors(changeset)})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Upload failed: #{inspect(reason)}"})
    end
  end

  defp extract_image_file(%{"image" => %Plug.Upload{} = upload}) do
    {:ok, upload}
  end

  defp extract_image_file(_params) do
    {:error, :no_image_file}
  end

  defp read_file_contents(%Plug.Upload{path: path}) do
    case File.read(path) do
      {:ok, binary} -> {:ok, binary}
      {:error, _} -> {:error, :file_read_error}
    end
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
