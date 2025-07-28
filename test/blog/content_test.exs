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

    test "list_published_posts/1 with series filter" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      
      # Create series
      series1 = series_fixture(%{title: "Phoenix Series", slug: "phoenix-series"})
      series2 = series_fixture(%{title: "Elixir Series", slug: "elixir-series"})

      # Create posts with series
      {:ok, post1} =
        Content.create_post(%{
          title: "Phoenix Guide Part 1",
          content: "Content about Phoenix",
          series_id: series1.id,
          series_position: 1,
          published: true,
          published_at: now
        })

      {:ok, post2} =
        Content.create_post(%{
          title: "Phoenix Guide Part 2",
          content: "More Phoenix content",
          series_id: series1.id,
          series_position: 2,
          published: true,
          published_at: now
        })

      {:ok, _post3} =
        Content.create_post(%{
          title: "Elixir Basics",
          content: "Content about Elixir",
          series_id: series2.id,
          series_position: 1,
          published: true,
          published_at: now
        })

      {:ok, _post4} =
        Content.create_post(%{
          title: "Standalone Post",
          content: "Content without series",
          published: true,
          published_at: now
        })

      # Filter by phoenix-series
      results = Content.list_published_posts(series: ["phoenix-series"])
      assert length(results) == 2
      assert Enum.map(results, & &1.id) |> Enum.sort() == [post1.id, post2.id] |> Enum.sort()
    end

    test "list_published_posts/1 with series and tags combined" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      
      series = series_fixture(%{title: "Tutorial Series", slug: "tutorial-series"})

      {:ok, post1} =
        Content.create_post(%{
          title: "Phoenix Tutorial",
          content: "Content",
          tags: "phoenix, tutorial",
          series_id: series.id,
          series_position: 1,
          published: true,
          published_at: now
        })

      {:ok, _post2} =
        Content.create_post(%{
          title: "Elixir Tutorial",
          content: "Content",
          tags: "elixir, tutorial",
          series_id: series.id,
          series_position: 2,
          published: true,
          published_at: now
        })

      {:ok, _post3} =
        Content.create_post(%{
          title: "Phoenix Standalone",
          content: "Content",
          tags: "phoenix, standalone",
          published: true,
          published_at: now
        })

      # Filter by series AND tag phoenix
      results = Content.list_published_posts(series: ["tutorial-series"], tags: ["phoenix"])
      assert length(results) == 1
      assert hd(results).id == post1.id
    end
  end

  describe "series" do
    alias Blog.Content.Series

    import Blog.ContentFixtures

    test "list_series/0 returns all series ordered by title" do
      series1 = series_fixture(%{title: "Z Series"})
      series2 = series_fixture(%{title: "A Series"})

      series_list = Content.list_series()
      assert length(series_list) == 2
      assert hd(series_list).id == series2.id  # A Series comes first
      assert List.last(series_list).id == series1.id  # Z Series comes last
    end

    test "list_series_for_filtering/0 returns all series ordered by title" do
      series1 = series_fixture(%{title: "Z Series"})
      series2 = series_fixture(%{title: "A Series"})

      series_list = Content.list_series_for_filtering()
      assert length(series_list) == 2
      assert hd(series_list).id == series2.id
      assert List.last(series_list).id == series1.id
    end

    test "get_series!/1 returns the series with given id" do
      series = series_fixture()
      assert Content.get_series!(series.id) == series
    end

    test "get_series/1 returns the series with given id" do
      series = series_fixture()
      assert Content.get_series(series.id) == series
    end

    test "get_series/1 returns nil for non-existent id" do
      assert Content.get_series(999) == nil
    end

    test "get_series_by_slug/1 returns the series with given slug" do
      series = series_fixture(%{slug: "test-series"})
      assert Content.get_series_by_slug("test-series") == series
    end

    test "get_series_by_slug/1 returns nil for non-existent slug" do
      assert Content.get_series_by_slug("non-existent") == nil
    end

    test "create_series/1 with valid data creates a series" do
      valid_attrs = %{
        title: "Test Series",
        description: "A test series",
        slug: "test-series"
      }

      assert {:ok, %Series{} = series} = Content.create_series(valid_attrs)
      assert series.title == "Test Series"
      assert series.description == "A test series"
      assert series.slug == "test-series"
    end

    test "create_series/1 auto-generates slug from title if not provided" do
      valid_attrs = %{
        title: "My Great Series"
      }

      assert {:ok, %Series{} = series} = Content.create_series(valid_attrs)
      assert series.title == "My Great Series"
      assert series.slug == "my-great-series"
    end

    test "create_series/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_series(%{})
    end

    test "update_series/2 with valid data updates the series" do
      series = series_fixture()
      update_attrs = %{title: "Updated Series", description: "Updated description"}

      assert {:ok, %Series{} = series} = Content.update_series(series, update_attrs)
      assert series.title == "Updated Series"
      assert series.description == "Updated description"
    end

    test "delete_series/1 deletes the series" do
      series = series_fixture()
      assert {:ok, %Series{}} = Content.delete_series(series)
      assert Content.get_series(series.id) == nil
    end

    test "get_posts_in_series/1 returns posts ordered by position" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      series = series_fixture()

      {:ok, post1} =
        Content.create_post(%{
          title: "Part 1",
          content: "First part",
          series_id: series.id,
          series_position: 1,
          published: true,
          published_at: now
        })

      {:ok, post2} =
        Content.create_post(%{
          title: "Part 2",
          content: "Second part",
          series_id: series.id,
          series_position: 2,
          published: true,
          published_at: now
        })

      posts = Content.get_posts_in_series(series.id)
      assert length(posts) == 2
      assert hd(posts).id == post1.id
      assert List.last(posts).id == post2.id
    end

    test "get_posts_in_series/1 only returns published posts by default" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      series = series_fixture()

      {:ok, post1} =
        Content.create_post(%{
          title: "Published Part",
          content: "Content",
          series_id: series.id,
          series_position: 1,
          published: true,
          published_at: now
        })

      {:ok, _post2} =
        Content.create_post(%{
          title: "Draft Part",
          content: "Content",
          series_id: series.id,
          series_position: 2,
          published: false
        })

      posts = Content.get_posts_in_series(series.id)
      assert length(posts) == 1
      assert hd(posts).id == post1.id
    end

    test "get_posts_in_series/1 with allow_unpublished: true returns all posts" do
      series = series_fixture()

      {:ok, post1} =
        Content.create_post(%{
          title: "Published Part",
          content: "Content",
          series_id: series.id,
          series_position: 1,
          published: true,
          published_at: DateTime.utc_now()
        })

      {:ok, post2} =
        Content.create_post(%{
          title: "Draft Part",
          content: "Content",
          series_id: series.id,
          series_position: 2,
          published: false
        })

      posts = Content.get_posts_in_series(series.id, allow_unpublished: true)
      assert length(posts) == 2
      assert Enum.map(posts, & &1.id) |> Enum.sort() == [post1.id, post2.id] |> Enum.sort()
    end

    test "add_post_to_series/2 adds post to end of series" do
      series = series_fixture()
      post = post_fixture()

      assert {:ok, updated_post} = Content.add_post_to_series(post, series.id)
      assert updated_post.series_id == series.id
      assert updated_post.series_position == 1
    end

    test "add_post_to_series/3 adds post at specific position" do
      series = series_fixture()
      post1 = post_fixture()
      post2 = post_fixture()

      # Add first post
      {:ok, _} = Content.add_post_to_series(post1, series.id, 1)
      
      # Add second post at position 1 (should shift first post)
      assert {:ok, updated_post2} = Content.add_post_to_series(post2, series.id, 1)
      assert updated_post2.series_position == 1

      # Check that first post was shifted
      updated_post1 = Content.get_post!(post1.id)
      assert updated_post1.series_position == 2
    end

    test "remove_post_from_series/1 removes post and shifts remaining posts" do
      series = series_fixture()
      post1 = post_fixture()
      post2 = post_fixture()
      post3 = post_fixture()

      # Add posts to series
      {:ok, _} = Content.add_post_to_series(post1, series.id, 1)
      {:ok, _} = Content.add_post_to_series(post2, series.id, 2)
      {:ok, _} = Content.add_post_to_series(post3, series.id, 3)

      # Remove middle post
      assert {:ok, removed_post} = Content.remove_post_from_series(Content.get_post!(post2.id))
      assert removed_post.series_id == nil
      assert removed_post.series_position == nil

      # Check that last post was shifted down
      updated_post3 = Content.get_post!(post3.id)
      assert updated_post3.series_position == 2
    end

    test "get_next_post_in_series/1 returns next post in series" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      series = series_fixture()

      {:ok, post1} =
        Content.create_post(%{
          title: "Part 1",
          content: "Content",
          series_id: series.id,
          series_position: 1,
          published: true,
          published_at: now
        })

      {:ok, post2} =
        Content.create_post(%{
          title: "Part 2",
          content: "Content",
          series_id: series.id,
          series_position: 2,
          published: true,
          published_at: now
        })

      next_post = Content.get_next_post_in_series(post1)
      assert next_post.id == post2.id
    end

    test "get_next_post_in_series/1 returns nil for last post" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      series = series_fixture()

      {:ok, post1} =
        Content.create_post(%{
          title: "Part 1",
          content: "Content",
          series_id: series.id,
          series_position: 1,
          published: true,
          published_at: now
        })

      next_post = Content.get_next_post_in_series(post1)
      assert next_post == nil
    end

    test "get_previous_post_in_series/1 returns previous post in series" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      series = series_fixture()

      {:ok, post1} =
        Content.create_post(%{
          title: "Part 1",
          content: "Content",
          series_id: series.id,
          series_position: 1,
          published: true,
          published_at: now
        })

      {:ok, post2} =
        Content.create_post(%{
          title: "Part 2",
          content: "Content",
          series_id: series.id,
          series_position: 2,
          published: true,
          published_at: now
        })

      previous_post = Content.get_previous_post_in_series(post2)
      assert previous_post.id == post1.id
    end

    test "get_previous_post_in_series/1 returns nil for first post" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      series = series_fixture()

      {:ok, post1} =
        Content.create_post(%{
          title: "Part 1",
          content: "Content",
          series_id: series.id,
          series_position: 1,
          published: true,
          published_at: now
        })

      previous_post = Content.get_previous_post_in_series(post1)
      assert previous_post == nil
    end
  end
end
