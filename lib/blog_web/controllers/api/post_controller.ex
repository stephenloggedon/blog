defmodule BlogWeb.Api.PostController do
  use BlogWeb, :controller

  alias Blog.Analytics
  alias Blog.Content
  alias Blog.Content.Post
  alias BlogWeb.LogHelper

  plug :put_view, json: BlogWeb.Api.PostJSON

  def index(conn, params) do
    page = Map.get(params, "page", 1) |> parse_integer(1)
    per_page = Map.get(params, "per_page", 20) |> parse_integer(20) |> min(100)
    include_content = Map.get(params, "include_content", "false") |> parse_boolean()

    opts = [
      page: page,
      per_page: per_page,
      include_content: include_content
    ]

    posts = Content.list_posts(opts)

    Analytics.track_api_usage("/api/posts", "GET", 200, conn)

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
        Analytics.track_api_usage("/api/posts/#{id}", "GET", 200, conn)
        Analytics.track_post_view(post.id, post.title, post.slug, conn)

        conn
        |> put_status(:ok)
        |> render(:show, post: post)
    end
  end

  def create(conn, params) do
    # Automatically handle both regular and chunked uploads based on content size
    # Large content (>50KB) is uploaded in chunks to avoid request size limits
    case detect_upload_type(params) do
      :chunked ->
        create_with_chunks(conn, params)

      :regular ->
        create_regular(conn, params)
    end
  end

  defp detect_upload_type(params) do
    content = get_in(params, ["content"]) || get_in(params, ["post", "content"]) || ""
    content_size = byte_size(content)

    if content_size > 50_000 or Map.has_key?(params, "chunks") do
      :chunked
    else
      :regular
    end
  end

  defp create_regular(conn, params) do
    with {:ok, post_params} <- parse_metadata(params),
         {:ok, %Post{} = post} <- Content.create_post(post_params) do
      LogHelper.log_operation_success("create_post", conn,
        post_id: post.id,
        post_title: post.title,
        post_slug: post.slug,
        published: post.published
      )

      conn
      |> put_status(:created)
      |> render("show.json", post: post)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)

      {:error, reason} ->
        LogHelper.log_operation_error("create_post", reason, conn)

        conn
        |> put_status(:bad_request)
        |> render(:error, %{message: format_error(reason)})
    end
  end

  defp create_with_chunks(conn, params) do
    {:ok, post_params} = parse_chunked_metadata(params)
    create_chunked_post_with_content(conn, post_params, params)
  end

  defp create_chunked_post_with_content(conn, post_params, params) do
    case Content.create_post(post_params) do
      {:ok, %Post{} = post} ->
        handle_chunked_content_upload(conn, post, params)

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

  defp handle_chunked_content_upload(conn, post, params) do
    content = get_in(params, ["content"]) || get_in(params, ["post", "content"]) || ""

    if content != "" do
      upload_and_finalize_chunked_post(conn, post, content, params)
    else
      conn
      |> put_status(:created)
      |> render("show.json", post: post)
    end
  end

  defp upload_and_finalize_chunked_post(conn, post, content, params) do
    case upload_content_in_chunks(post, content) do
      {:ok, updated_post} ->
        finalize_chunked_post(conn, updated_post, params)

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> render(:error, %{message: format_error(reason)})
    end
  end

  defp finalize_chunked_post(conn, post, params) do
    published = get_in(params, ["published"]) || get_in(params, ["post", "published"]) || false

    case Content.update_post(post, %{"published" => published}) do
      {:ok, final_post} ->
        conn
        |> put_status(:created)
        |> render("show.json", post: final_post)

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> render(:error, %{message: format_error(reason)})
    end
  end

  defp upload_content_in_chunks(post, content) do
    # 10KB chunks
    chunk_size = 10_000
    chunks = chunk_string(content, chunk_size)

    Enum.reduce_while(chunks, {:ok, post}, fn {chunk, index}, {:ok, current_post} ->
      updated_content =
        if index == 0 do
          # Replace placeholder content with first chunk
          chunk
        else
          # Append subsequent chunks
          (current_post.content || "") <> chunk
        end

      case Content.update_post(current_post, %{"content" => updated_content}) do
        {:ok, updated_post} ->
          {:cont, {:ok, updated_post}}

        {:error, reason} ->
          {:halt, {:error, "Failed at chunk #{index}: #{inspect(reason)}"}}
      end
    end)
  end

  defp chunk_string(string, chunk_size) do
    string
    |> String.graphemes()
    |> Enum.chunk_every(chunk_size)
    |> Enum.with_index()
    |> Enum.map(fn {chunk, index} -> {Enum.join(chunk), index} end)
  end

  def update(conn, %{"id" => id} = params) do
    case Content.get_post(id, allow_unpublished: true) do
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
            LogHelper.log_operation_error("update_post", reason, conn, post_id: id)

            conn
            |> put_status(:bad_request)
            |> render(:error, %{message: format_error(reason)})
        end
    end
  end

  def patch(conn, %{"id" => id} = params) do
    case Content.get_post(id, allow_unpublished: true) do
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
            LogHelper.log_operation_error("patch_post", reason, conn, post_id: id)

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
      |> maybe_put("series_id", post_params["series_id"])
      |> maybe_put("series_position", post_params["series_position"])

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

  defp parse_boolean("true"), do: true
  defp parse_boolean("1"), do: true
  defp parse_boolean(true), do: true
  defp parse_boolean(_), do: false

  defp parse_chunked_metadata(params) do
    # Create post with minimal content initially
    post_params = params["post"] || params

    metadata = %{
      "title" => post_params["title"],
      # Temporary placeholder content
      "content" => "Draft content - uploading in chunks...",
      "slug" => post_params["slug"],
      "tags" => post_params["tags"] || [],
      # Don't publish until finalized
      "published" => false,
      "subtitle" => post_params["subtitle"]
    }

    {:ok, metadata}
  end

  defp format_error(:invalid_json_metadata), do: "Invalid JSON in metadata field"
  defp format_error({:error, reason}), do: "Error: #{reason}"
  defp format_error(reason), do: "Error: #{inspect(reason)}"
end
