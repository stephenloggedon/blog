defmodule BlogWeb.Api.PostControllerTest do
  use BlogWeb.ConnCase

  import Blog.ContentFixtures

  setup %{conn: conn} do
    conn = 
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("test-client-cert", "valid")
    
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

  describe "create" do
    test "creates post", %{conn: conn} do
      valid_attrs = %{
        title: "New Post",
        slug: "new-post", 
        content: "Content of new post",
        excerpt: "Excerpt of new post",
        tags: "new, post",
        published: true
      }

      conn = post(conn, ~p"/api/posts", %{"metadata" => Jason.encode!(valid_attrs)})
      assert %{"id" => id} = json_response(conn, 201)["data"]
      
      # Use get_post! to fetch any post regardless of published status for testing
      created_post = Blog.Repo.get!(Blog.Content.Post, id)
      assert created_post.title == "New Post"
    end

    test "validates required fields", %{conn: conn} do
      invalid_attrs = %{content: "Missing title"}
      conn = post(conn, ~p"/api/posts", %{"metadata" => Jason.encode!(invalid_attrs)})
      assert json_response(conn, 422)["errors"]["title"] == ["can't be blank"]
    end
  end

  describe "update" do
    test "updates post", %{conn: conn} do
      post = post_fixture()
      update_attrs = %{title: "Updated Title", content: "Updated content", published: false}

      conn = put(conn, ~p"/api/posts/#{post.id}", %{"metadata" => Jason.encode!(update_attrs)})
      assert json_response(conn, 200)["data"]["title"] == "Updated Title"
      
      # Use direct repo access to check the actual update
      updated_post = Blog.Repo.get!(Blog.Content.Post, post.id)
      assert updated_post.published == false
    end

    test "returns 404 for non-existent post", %{conn: conn} do
      conn = put(conn, ~p"/api/posts/99999999", %{"metadata" => Jason.encode!(%{title: "Non Existent", content: "test"})})
      assert json_response(conn, 404)["message"] == "Post not found"
    end

    test "validates invalid data", %{conn: conn} do
      post = post_fixture()
      invalid_attrs = %{title: "", content: "Missing title"}
      conn = put(conn, ~p"/api/posts/#{post.id}", %{"metadata" => Jason.encode!(invalid_attrs)})
      assert json_response(conn, 422)["errors"]["title"] == ["can't be blank"]
    end
  end

  describe "delete" do
    test "deletes post", %{conn: conn} do
      post = post_fixture()
      conn = delete(conn, ~p"/api/posts/#{post.id}")
      assert response(conn, 204) == ""
      assert_raise Ecto.NoResultsError, fn -> Blog.Repo.get!(Blog.Content.Post, post.id) end
    end

    test "returns 404 for non-existent post", %{conn: conn} do
      conn = delete(conn, ~p"/api/posts/99999999")
      assert json_response(conn, 404)["message"] == "Post not found"
    end
  end
end
