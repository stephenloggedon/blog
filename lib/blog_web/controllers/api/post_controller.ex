defmodule BlogWeb.Api.PostController do
  use BlogWeb, :controller

  alias Blog.Content
  alias Blog.Content.Post
  alias BlogWeb.Services.CloudStorage

  plug :put_view, json: BlogWeb.Api.PostJSON

  def index(conn, params) do
    page = Map.get(params, "page", 1) |> parse_integer(1)
    per_page = Map.get(params, "per_page", 20) |> parse_integer(20) |> min(100)

    posts = Content.list_posts_paginated(page, per_page)

    conn
    |> put_status(:ok)
    |> render(:index, posts: posts)
  end

  def show(conn, %{"id" => id}) do
    case Content.get_post(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(:error, %{message: "Post not found"})

      post ->
        conn
        |> put_status(:ok)
        |> render(:show, post: post)
    end
  end

  def create(conn, params) do
    with {:ok, post_params} <- parse_metadata(params),
         {:ok, image_urls} <- handle_image_uploads(params),
         {:ok, final_content} <- process_content_with_images(post_params["content"], image_urls),
         post_params <- Map.put(post_params, "content", final_content),
         {:ok, %Post{} = post} <- Content.create_post(post_params) do
      conn
      |> put_status(:created)
      |> render("show.json", post: post)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> render(:error, %{message: format_error(reason)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Content.get_post(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(:error, %{message: "Post not found"})

      post ->
        with {:ok, post_params} <- parse_metadata(params),
             {:ok, image_urls} <- handle_image_uploads(params),
             {:ok, final_content} <- process_content_with_images(post_params["content"], image_urls),
             post_params <- Map.put(post_params, "content", final_content),
             {:ok, updated_post} <- Content.update_post(post, post_params) do
          conn
          |> put_status(:ok)
          |> render(:show, post: updated_post)
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(:error, changeset: changeset)

          {:error, reason} ->
            conn
            |> put_status(:bad_request)
            |> render(:error, %{message: format_error(reason)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Content.get_post(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(:error, %{message: "Post not found"})

      post ->
        with {:ok, _deleted_post} <- Content.delete_post(post) do
          conn |> send_resp(:no_content, "")
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(:error, changeset: changeset)
        end
    end
  end

  # Private functions

  defp parse_metadata(%{"metadata" => metadata_json}) when is_binary(metadata_json) do
    case Jason.decode(metadata_json) do
      {:ok, metadata} -> {:ok, metadata}
      {:error, _} -> {:error, :invalid_json_metadata}
    end
  end

  defp parse_metadata(params) do
    # If metadata is not provided as JSON, extract from direct params
    metadata = %{
      "title" => params["title"],
      "content" => params["content"],
      "tags" => params["tags"] || [],
      "published" => params["published"] || false,
      "subtitle" => params["subtitle"]
    }

    {:ok, metadata}
  end

  defp handle_image_uploads(%{"images" => images}) when is_list(images) do
    CloudStorage.upload_images(images)
  end

  defp handle_image_uploads(%{"image" => image}) do
    case CloudStorage.upload_images([image]) do
      {:ok, [url]} -> {:ok, [url]}
      error -> error
    end
  end

  defp handle_image_uploads(_params) do
    {:ok, []}
  end

  defp process_content_with_images(content, []) do
    {:ok, content}
  end

  defp process_content_with_images(content, image_urls) do
    # Replace placeholder image references in markdown with actual URLs
    # This is a simple implementation - you might want more sophisticated processing
    updated_content =
      image_urls
      |> Enum.with_index()
      |> Enum.reduce(content, fn {url, index}, acc ->
        placeholder = "{{image_#{index}}}"
        markdown_image = "![Image](#{url})"
        String.replace(acc, placeholder, markdown_image)
      end)

    {:ok, updated_content}
  end

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_integer(value, _default) when is_integer(value), do: value
  defp parse_integer(_, default), do: default

  defp format_error(:invalid_json_metadata), do: "Invalid JSON in metadata field"
  defp format_error(:unsupported_file_type), do: "Unsupported file type. Please use JPEG, PNG, GIF, or WebP"
  defp format_error(:file_too_large), do: "File too large. Maximum size is 10MB"
  defp format_error(:upload_failed), do: "Failed to upload image to cloud storage"
  defp format_error(reason), do: "Error: #{reason}"
end
