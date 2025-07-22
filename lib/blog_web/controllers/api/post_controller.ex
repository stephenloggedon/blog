defmodule BlogWeb.Api.PostController do
  use BlogWeb, :controller

  alias Blog.Content
  alias Blog.Content.Post

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

  def patch(conn, %{"id" => id} = params) do
    case Content.get_post(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(:error, %{message: "Post not found"})

      post ->
        with {:ok, patch_params} <- parse_patch_params(params),
             {:ok, updated_post} <- Content.update_post(post, patch_params) do
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
        case Content.delete_post(post) do
          {:ok, _deleted_post} ->
            conn |> send_resp(:no_content, "")

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
    # Handle nested post parameters or direct parameters
    post_params = params["post"] || params

    metadata = %{
      "title" => post_params["title"],
      "content" => post_params["content"],
      "slug" => post_params["slug"],
      "tags" => post_params["tags"] || [],
      "published" => post_params["published"] || false,
      "subtitle" => post_params["subtitle"]
    }

    {:ok, metadata}
  end

  defp parse_patch_params(params) do
    # Handle nested post parameters or direct parameters
    post_params = params["post"] || params

    # Only include non-nil values for partial updates
    patch_data =
      %{}
      |> maybe_put("title", post_params["title"])
      |> maybe_put("content", post_params["content"])
      |> maybe_put("slug", post_params["slug"])
      |> maybe_put("tags", post_params["tags"])
      |> maybe_put("published", post_params["published"])
      |> maybe_put("subtitle", post_params["subtitle"])

    {:ok, patch_data}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_integer(value, _default) when is_integer(value), do: value
  defp parse_integer(_, default), do: default

  defp format_error(:invalid_json_metadata), do: "Invalid JSON in metadata field"
  defp format_error({:error, reason}), do: "Error: #{reason}"
  defp format_error(reason), do: "Error: #{inspect(reason)}"
end
