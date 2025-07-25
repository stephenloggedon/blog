defmodule Blog.ContentTest do
  use Blog.DataCase

  alias Blog.Content

  describe "posts" do
    alias Blog.Content.Post

    import Blog.ContentFixtures

    @invalid_attrs %{
      title: nil,
      slug: nil,
      content: nil,
      excerpt: nil,
      tags: nil,
      published: nil,
      published_at: nil
    }

    test "list_posts/0 returns all posts without content and excludes specific fields" do
      post = post_fixture()

      expected =
        post
        |> Map.from_struct()
        |> Map.drop([
          :__meta__,
          :rendered_content,
          :images,
          :content,
          :excerpt,
          :inserted_at,
          :published
        ])
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()

      assert Content.list_posts() == [expected]
    end

    test "list_posts/1 with include_content: true returns posts with content but still excludes specific fields" do
      post = post_fixture()

      expected =
        post
        |> Map.from_struct()
        |> Map.drop([:__meta__, :rendered_content, :images, :excerpt, :inserted_at, :published])
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()

      assert Content.list_posts(include_content: true) == [expected]
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture()
      assert Content.get_post!(post.id) == post
    end

    test "create_post/1 with valid data creates a post" do
      valid_attrs = %{
        title: "some title",
        slug: "some slug",
        content: "some content",
        excerpt: "some excerpt",
        tags: "some tags",
        published: true
      }

      assert {:ok, %Post{} = post} = Content.create_post(valid_attrs)
      assert post.title == "some title"
      assert post.slug == "some slug"
      assert post.content == "some content"
      assert post.excerpt == "some excerpt"
      assert post.tags == "some tags"
      assert post.published == true
      # Check that published_at was auto-generated
      assert post.published_at != nil
      assert DateTime.diff(DateTime.utc_now(), post.published_at, :second) < 5
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_post(@invalid_attrs)
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()

      update_attrs = %{
        title: "some updated title",
        slug: "some updated slug",
        content: "some updated content",
        excerpt: "some updated excerpt",
        tags: "some updated tags",
        published: false
      }

      assert {:ok, %Post{} = post} = Content.update_post(post, update_attrs)
      assert post.title == "some updated title"
      assert post.slug == "some updated slug"
      assert post.content == "some updated content"
      assert post.excerpt == "some updated excerpt"
      assert post.tags == "some updated tags"
      assert post.published == false
      assert post.published_at != nil
      assert DateTime.diff(DateTime.utc_now(), post.published_at, :second) < 5
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = post_fixture()
      assert {:error, %Ecto.Changeset{}} = Content.update_post(post, @invalid_attrs)
      assert post == Content.get_post!(post.id)
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Content.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Content.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Content.change_post(post)
    end

    test "list_published_posts/1 with search filters by title" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, post1} =
        Content.create_post(%{
          title: "Phoenix LiveView Guide",
          content: "Content about Phoenix",
          published: true,
          published_at: now
        })

      {:ok, _post2} =
        Content.create_post(%{
          title: "Elixir Patterns",
          content: "Content about patterns",
          published: true,
          published_at: now
        })

      # Search by title
      results = Content.list_published_posts(search: "Phoenix")
      assert length(results) == 1
      assert hd(results).id == post1.id
    end

    test "list_published_posts/1 with search filters by content" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, post1} =
        Content.create_post(%{
          title: "Guide One",
          content: "Content about Phoenix LiveView",
          published: true,
          published_at: now
        })

      {:ok, _post2} =
        Content.create_post(%{
          title: "Guide Two",
          content: "Content about Elixir",
          published: true,
          published_at: now
        })

      # Search by content
      results = Content.list_published_posts(search: "LiveView")
      assert length(results) == 1
      assert hd(results).id == post1.id
    end

    test "list_published_posts/1 with search filters by subtitle" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, post1} =
        Content.create_post(%{
          title: "Guide One",
          subtitle: "Phoenix tutorial",
          content: "Content",
          published: true,
          published_at: now
        })

      {:ok, _post2} =
        Content.create_post(%{
          title: "Guide Two",
          subtitle: "Elixir tutorial",
          content: "Content",
          published: true,
          published_at: now
        })

      # Search by subtitle
      results = Content.list_published_posts(search: "Phoenix")
      assert length(results) == 1
      assert hd(results).id == post1.id
    end

    test "list_published_posts/1 with tag filter" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, post1} =
        Content.create_post(%{
          title: "Guide One",
          content: "Content",
          tags: "phoenix, web",
          published: true,
          published_at: now
        })

      {:ok, _post2} =
        Content.create_post(%{
          title: "Guide Two",
          content: "Content",
          tags: "elixir, functional",
          published: true,
          published_at: now
        })

      # Filter by tag using new tags parameter
      results = Content.list_published_posts(tags: ["phoenix"])
      assert length(results) == 1
      assert hd(results).id == post1.id
    end

    test "list_published_posts/1 with multiple tag filter (OR logic)" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, post1} =
        Content.create_post(%{
          title: "Phoenix Guide",
          content: "Content",
          tags: "phoenix, web",
          published: true,
          published_at: now
        })

      {:ok, post2} =
        Content.create_post(%{
          title: "Elixir Basics",
          content: "Content",
          tags: "elixir, functional",
          published: true,
          published_at: now
        })

      {:ok, _post3} =
        Content.create_post(%{
          title: "CSS Guide",
          content: "Content",
          tags: "css, design",
          published: true,
          published_at: now
        })

      # Filter by multiple tags with OR logic - should return posts with phoenix OR elixir
      results = Content.list_published_posts(tags: ["phoenix", "elixir"])
      assert length(results) == 2
      assert Enum.map(results, & &1.id) |> Enum.sort() == [post1.id, post2.id] |> Enum.sort()
    end

    test "list_published_posts/1 with combined search and tag filter" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, post1} =
        Content.create_post(%{
          title: "Phoenix Guide",
          content: "LiveView content",
          tags: "phoenix, web",
          published: true,
          published_at: now
        })

      {:ok, _post2} =
        Content.create_post(%{
          title: "Phoenix Basics",
          content: "Basic content",
          tags: "elixir, basics",
          published: true,
          published_at: now
        })

      {:ok, post3} =
        Content.create_post(%{
          title: "Elixir Guide",
          content: "LiveView content",
          tags: "phoenix, advanced",
          published: true,
          published_at: now
        })

      # Search for "LiveView" AND tag "phoenix" using new tags parameter
      results = Content.list_published_posts(search: "LiveView", tags: ["phoenix"])
      assert length(results) == 2
      assert Enum.map(results, & &1.id) |> Enum.sort() == [post1.id, post3.id] |> Enum.sort()
    end

    test "list_available_tags/0 returns unique sorted tags" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _post1} =
        Content.create_post(%{
          title: "Post One",
          content: "Content",
          tags: "phoenix, web, elixir",
          published: true,
          published_at: now
        })

      {:ok, _post2} =
        Content.create_post(%{
          title: "Post Two",
          content: "Content",
          tags: "elixir, functional",
          published: true,
          published_at: now
        })

      {:ok, _post3} =
        Content.create_post(%{
          title: "Post Three",
          content: "Content",
          tags: "web, css",
          published: true,
          published_at: now
        })

      tags = Content.list_available_tags()
      assert tags == ["css", "elixir", "functional", "phoenix", "web"]
    end

    test "list_available_tags/0 ignores unpublished posts" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _post1} =
        Content.create_post(%{
          title: "Published",
          content: "Content",
          tags: "phoenix",
          published: true,
          published_at: now
        })

      {:ok, _post2} =
        Content.create_post(%{
          title: "Draft",
          content: "Content",
          tags: "draft-tag",
          published: false
        })

      tags = Content.list_available_tags()
      assert tags == ["phoenix"]
    end

    test "list_top_tags/1 returns most frequent tags" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      # Create posts with various tag frequencies
      {:ok, _post1} =
        Content.create_post(%{
          title: "Post 1",
          content: "Content",
          tags: "elixir, phoenix",
          published: true,
          published_at: now
        })

      {:ok, _post2} =
        Content.create_post(%{
          title: "Post 2",
          content: "Content",
          tags: "elixir, web",
          published: true,
          published_at: now
        })

      {:ok, _post3} =
        Content.create_post(%{
          title: "Post 3",
          content: "Content",
          tags: "elixir, functional",
          published: true,
          published_at: now
        })

      {:ok, _post4} =
        Content.create_post(%{
          title: "Post 4",
          content: "Content",
          tags: "phoenix, web",
          published: true,
          published_at: now
        })

      {:ok, _post5} =
        Content.create_post(%{
          title: "Post 5",
          content: "Content",
          tags: "css",
          published: true,
          published_at: now
        })

      # elixir: 3, phoenix: 2, web: 2, functional: 1, css: 1
      top_tags = Content.list_top_tags(3)
      assert length(top_tags) == 3
      assert "elixir" in top_tags
      assert "phoenix" in top_tags
      assert "web" in top_tags
    end

    test "list_top_tags/1 respects limit parameter" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _post1} =
        Content.create_post(%{
          title: "Post 1",
          content: "Content",
          tags: "tag1, tag2, tag3, tag4, tag5, tag6",
          published: true,
          published_at: now
        })

      top_tags_3 = Content.list_top_tags(3)
      assert length(top_tags_3) == 3

      top_tags_5 = Content.list_top_tags(5)
      assert length(top_tags_5) == 5

      top_tags_10 = Content.list_top_tags(10)
      # Only 6 unique tags exist
      assert length(top_tags_10) == 6
    end

    test "list_published_posts/1 with combined text search and tag filtering" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, post1} =
        Content.create_post(%{
          title: "Phoenix LiveView Guide",
          content: "Advanced Phoenix tutorial",
          tags: "phoenix, tutorial",
          published: true,
          published_at: now
        })

      {:ok, _post2} =
        Content.create_post(%{
          title: "Elixir Basics",
          content: "Phoenix introduction",
          tags: "elixir, basics",
          published: true,
          published_at: now
        })

      {:ok, post3} =
        Content.create_post(%{
          title: "Advanced Phoenix",
          content: "Deep dive tutorial",
          tags: "phoenix, advanced",
          published: true,
          published_at: now
        })

      # Search for "tutorial" AND tag "phoenix" - should find posts with both
      results = Content.list_published_posts(search: "tutorial", tags: ["phoenix"])
      assert length(results) == 2
      assert Enum.map(results, & &1.id) |> Enum.sort() == [post1.id, post3.id] |> Enum.sort()
    end

    test "list_published_posts/1 with empty search and no tags returns all posts" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, post1} =
        Content.create_post(%{
          title: "Post 1",
          content: "Content",
          published: true,
          published_at: now
        })

      {:ok, post2} =
        Content.create_post(%{
          title: "Post 2",
          content: "Content",
          published: true,
          published_at: now
        })

      results = Content.list_published_posts(search: "", tags: [])
      assert length(results) == 2
      assert Enum.map(results, & &1.id) |> Enum.sort() == [post1.id, post2.id] |> Enum.sort()
    end

    test "list_published_posts/1 with whitespace-only search is treated as empty" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _post1} =
        Content.create_post(%{
          title: "Post 1",
          content: "Content",
          published: true,
          published_at: now
        })

      results_empty = Content.list_published_posts(search: "")
      results_whitespace = Content.list_published_posts(search: "   ")

      assert length(results_empty) == length(results_whitespace)
      assert results_empty == results_whitespace
    end
  end
end
