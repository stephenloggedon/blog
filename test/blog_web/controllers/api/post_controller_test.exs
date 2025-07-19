defmodule BlogWeb.Api.PostControllerTest do
  @moduledoc """
  Tests for the Post API controller, including both public endpoints
  (index, show) and protected endpoints that require mTLS authentication
  (create, update, delete).
  
  The protected endpoints use client certificate authentication to ensure
  only authorized clients can modify post data.
  """
  
  use BlogWeb.ConnCase

  import Blog.ContentFixtures

  setup %{conn: conn} do
    conn = put_req_header(conn, "accept", "application/json")
    {:ok, conn: conn}
  end

  describe "index" do
    test "lists all published posts", %{conn: conn} do
      post = post_fixture()
      conn = get(conn, ~p"/api/posts")
      assert json_response(conn, 200)["data"] |> Enum.any?(fn %{"id" => p_id} -> p_id == post.id end)
    end

    test "does not include unpublished posts", %{conn: conn} do
      post_fixture(%{published: false})
      conn = get(conn, ~p"/api/posts")
      refute json_response(conn, 200)["data"] |> Enum.any?(fn %{"published" => published} -> published == false end)
    end

    test "supports pagination", %{conn: conn} do
      # Create more posts than per_page to test pagination
      for i <- 1..30 do
        post_fixture(%{title: "Post #{i}", slug: "post-#{i}"})
      end

      conn = get(conn, ~p"/api/posts?page=1&per_page=5")
      assert length(json_response(conn, 200)["data"]) == 5

      conn = get(conn, ~p"/api/posts?page=2&per_page=5")
      assert length(json_response(conn, 200)["data"]) == 5
    end
  end

  describe "show" do
    test "shows published post", %{conn: conn} do
      post = post_fixture()
      conn = get(conn, ~p"/api/posts/#{post.id}")
      assert json_response(conn, 200)["data"]["id"] == post.id
    end

    test "returns 404 for non-existent post", %{conn: conn} do
      conn = get(conn, ~p"/api/posts/99999999")
      assert json_response(conn, 404)["message"] == "Post not found"
    end

    test "returns 404 for unpublished post", %{conn: conn} do
      post = post_fixture(%{published: false})
      conn = get(conn, ~p"/api/posts/#{post.id}")
      assert json_response(conn, 404)["message"] == "Post not found"
    end
  end

  describe "protected endpoints (require mTLS)" do
    test "create endpoint rejects requests without client certificate", %{conn: conn} do
      valid_attrs = %{
        title: "New Post",
        content: "Content of new post",
        published: true
      }

      conn = post(conn, ~p"/api/posts", %{"metadata" => Jason.encode!(valid_attrs)})
      assert json_response(conn, 401)["error"] == "Client certificate required"
    end

    test "update endpoint rejects requests without client certificate", %{conn: conn} do
      post = post_fixture()
      update_attrs = %{title: "Updated Title", content: "Updated content"}

      conn = put(conn, ~p"/api/posts/#{post.id}", %{"metadata" => Jason.encode!(update_attrs)})
      assert json_response(conn, 401)["error"] == "Client certificate required"
    end

    test "delete endpoint rejects requests without client certificate", %{conn: conn} do
      post = post_fixture()
      conn = delete(conn, ~p"/api/posts/#{post.id}")
      assert json_response(conn, 401)["error"] == "Client certificate required"
    end

    test "create endpoint accepts requests with valid client certificate", %{conn: conn} do
      valid_attrs = %{
        title: "New Post",
        content: "Content of new post",
        published: true
      }

      conn = 
        conn
        |> with_client_cert()
        |> post(~p"/api/posts", %{"metadata" => Jason.encode!(valid_attrs)})

      assert json_response(conn, 201)["data"]["title"] == "New Post"
    end

    test "update endpoint accepts requests with valid client certificate", %{conn: conn} do
      post = post_fixture()
      update_attrs = %{title: "Updated Title", content: "Updated content"}

      conn = 
        conn
        |> with_client_cert()
        |> put(~p"/api/posts/#{post.id}", %{"metadata" => Jason.encode!(update_attrs)})

      assert json_response(conn, 200)["data"]["title"] == "Updated Title"
    end

    test "delete endpoint accepts requests with valid client certificate", %{conn: conn} do
      post = post_fixture()

      conn = 
        conn
        |> with_client_cert()
        |> delete(~p"/api/posts/#{post.id}")

      assert conn.status == 204
    end

    test "create endpoint rejects requests with invalid client certificate", %{conn: conn} do
      valid_attrs = %{
        title: "New Post",
        content: "Content of new post",
        published: true
      }

      conn = 
        conn
        |> with_invalid_client_cert()
        |> post(~p"/api/posts", %{"metadata" => Jason.encode!(valid_attrs)})

      assert json_response(conn, 401)["error"] =~ "Invalid client certificate"
    end

    test "update endpoint rejects requests with invalid client certificate", %{conn: conn} do
      post = post_fixture()
      update_attrs = %{title: "Updated Title", content: "Updated content"}

      conn = 
        conn
        |> with_invalid_client_cert()
        |> put(~p"/api/posts/#{post.id}", %{"metadata" => Jason.encode!(update_attrs)})

      assert json_response(conn, 401)["error"] =~ "Invalid client certificate"
    end

    test "delete endpoint rejects requests with invalid client certificate", %{conn: conn} do
      post = post_fixture()

      conn = 
        conn
        |> with_invalid_client_cert()
        |> delete(~p"/api/posts/#{post.id}")

      assert json_response(conn, 401)["error"] =~ "Invalid client certificate"
    end
  end
end
