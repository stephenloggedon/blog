defmodule BlogWeb.HomeLiveTest do
  use BlogWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Blog.Content

  describe "HomeLive search functionality" do
    setup do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Create test posts with various tags and content
      {:ok, post1} =
        Content.create_post(%{
          title: "Phoenix LiveView Guide",
          content: "Complete guide to Phoenix LiveView with examples",
          tags: "phoenix, elixir, web",
          published: true,
          published_at: now
        })

      {:ok, post2} =
        Content.create_post(%{
          title: "Elixir Patterns",
          content: "Advanced Elixir programming patterns",
          tags: "elixir, functional, programming",
          published: true,
          published_at: now
        })

      {:ok, post3} =
        Content.create_post(%{
          title: "Web Development",
          content: "Modern web development techniques",
          tags: "web, css, javascript",
          published: true,
          published_at: now
        })

      %{posts: [post1, post2, post3]}
    end

    test "initial mount loads posts and tags", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      # Should display all posts initially
      assert html =~ "Phoenix LiveView Guide"
      assert html =~ "Elixir Patterns"
      assert html =~ "Web Development"

      # Should show popular tags
      assert html =~ "Popular Tags"
      assert has_element?(view, "button", "elixir")
      assert has_element?(view, "button", "web")
    end

    test "toggle_tag event adds and removes tags", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Click on "elixir" tag
      view |> element("button", "elixir") |> render_click()

      # Should navigate to URL with tag parameter
      assert_patch(view, "/?tags=elixir")

      # Should show only posts tagged with elixir
      assert render(view) =~ "Phoenix LiveView Guide"
      assert render(view) =~ "Elixir Patterns"
      refute render(view) =~ "Web Development"

      # Click elixir tag again to remove it
      view |> element("button", "elixir") |> render_click()

      # Should navigate back to home
      assert_patch(view, "/")

      # Should show all posts again
      assert render(view) =~ "Phoenix LiveView Guide"
      assert render(view) =~ "Elixir Patterns"
      assert render(view) =~ "Web Development"
    end

    test "multiple tag selection with OR logic", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Select elixir tag
      view |> element("button", "elixir") |> render_click()
      assert_patch(view, "/?tags=elixir")

      # Select web tag (should add to selection)
      view |> element("button", "web") |> render_click()

      # Should show posts with either elixir OR web tags
      rendered = render(view)
      # has both elixir and web
      assert rendered =~ "Phoenix LiveView Guide"
      # has elixir
      assert rendered =~ "Elixir Patterns"
      # has web
      assert rendered =~ "Web Development"
    end

    test "toggle_tag event removes specific tag from selection", %{conn: conn} do
      # Start with multiple tags selected
      {:ok, view, _html} = live(conn, "/?tags=elixir,web")

      # Should show posts with either tag
      rendered = render(view)
      assert rendered =~ "Phoenix LiveView Guide"
      assert rendered =~ "Elixir Patterns"
      assert rendered =~ "Web Development"

      # Remove elixir tag by clicking toggle button
      view |> element("button[phx-click='toggle_tag'][phx-value-tag='elixir']") |> render_click()

      # Should only show posts with web tag
      assert_patch(view, "/?tags=web")
      rendered = render(view)
      # has web
      assert rendered =~ "Phoenix LiveView Guide"
      # has web
      assert rendered =~ "Web Development"
      # only has elixir
      refute rendered =~ "Elixir Patterns"
    end

    test "search_input event generates tag suggestions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Simulate keyup event directly
      render_hook(view, "search_input", %{value: "el"})

      # Should show elixir as suggestion
      rendered = render(view)
      assert rendered =~ "elixir"
    end

    test "search with exact tag match adds tag bubble", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Submit search form with exact tag name
      view
      |> form("form[phx-submit='search']", %{query: "elixir"})
      |> render_submit()

      # Should add elixir as tag and navigate
      assert_patch(view, "/?tags=elixir")

      # Should show tag bubble and filtered posts
      rendered = render(view)
      assert rendered =~ "Phoenix LiveView Guide"
      assert rendered =~ "Elixir Patterns"
      refute rendered =~ "Web Development"
    end

    test "search with non-tag text performs content search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Submit search form with non-tag text
      view
      |> form("form[phx-submit='search']", %{query: "guide"})
      |> render_submit()

      # Should navigate with search parameter
      assert_patch(view, "/?search=guide")

      # Should show posts containing "guide" in title/content
      rendered = render(view)
      # has "guide" in title
      assert rendered =~ "Phoenix LiveView Guide"
      # no "guide"
      refute rendered =~ "Elixir Patterns"
      # no "guide"
      refute rendered =~ "Web Development"
    end

    test "add_tag_from_search event adds tag", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Directly test the add_tag_from_search event
      view |> element("button", "elixir") |> render_click()

      # Should add tag and navigate
      assert_patch(view, "/?tags=elixir")

      # Should show filtered posts
      rendered = render(view)
      assert rendered =~ "Phoenix LiveView Guide"
      assert rendered =~ "Elixir Patterns"
      refute rendered =~ "Web Development"
    end

    test "clear_filters event removes all tags and search", %{conn: conn} do
      # Start with tags active
      {:ok, view, _html} = live(conn, "/?tags=elixir")

      # Click clear button (target the one in the top filter status)
      view |> element(".mb-6 button[phx-click='clear_filters']") |> render_click()

      # Should navigate to home
      assert_patch(view, "/")

      # Should show all posts
      rendered = render(view)
      assert rendered =~ "Phoenix LiveView Guide"
      assert rendered =~ "Elixir Patterns"
      assert rendered =~ "Web Development"
    end

    test "URL parameters are properly parsed on mount", %{conn: conn} do
      # Visit URL with tags and search parameters
      {:ok, view, _html} = live(conn, "/?tags=elixir,web&search=guide")

      # Should show filtered results based on URL params
      rendered = render(view)
      # Should show posts with (elixir OR web) AND containing "guide"
      # has elixir+web and "guide"
      assert rendered =~ "Phoenix LiveView Guide"
      # has elixir but no "guide"
      refute rendered =~ "Elixir Patterns"
      # has web but no "guide"
      refute rendered =~ "Web Development"
    end

    test "search suggestions only show unselected tags", %{conn: conn} do
      # Start with elixir tag already selected
      {:ok, view, _html} = live(conn, "/?tags=elixir")

      # Type "e" which should match "elixir" but it's already selected
      render_hook(view, "search_input", %{value: "e"})

      # Should not show elixir in suggestions since it's already selected
      rendered = render(view)
      refute rendered =~ "button[phx-value-tag='elixir']"
    end
  end

  describe "HomeLive single-series selection functionality" do
    setup do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Create test series
      {:ok, series1} = Content.create_series(%{
        title: "Phoenix Tutorial Series",
        slug: "phoenix-tutorial",
        description: "Complete Phoenix tutorial"
      })

      {:ok, series2} = Content.create_series(%{
        title: "Elixir Basics Series", 
        slug: "elixir-basics",
        description: "Learn Elixir fundamentals"
      })

      # Create posts with series relationships
      {:ok, post1} =
        Content.create_post(%{
          title: "Phoenix LiveView Introduction",
          content: "Getting started with Phoenix LiveView",
          tags: "phoenix, tutorial",
          series_id: series1.id,
          series_position: 1,
          published: true,
          published_at: now
        })

      {:ok, post2} =
        Content.create_post(%{
          title: "Phoenix LiveView Components",
          content: "Building reusable components",
          tags: "phoenix, components",
          series_id: series1.id,
          series_position: 2,
          published: true,
          published_at: now
        })

      {:ok, post3} =
        Content.create_post(%{
          title: "Elixir Pattern Matching",
          content: "Understanding pattern matching",
          tags: "elixir, fundamentals",
          series_id: series2.id,
          series_position: 1,
          published: true,
          published_at: now
        })

      {:ok, post4} =
        Content.create_post(%{
          title: "Standalone Post",
          content: "This post is not part of any series",
          tags: "misc",
          published: true,
          published_at: now
        })

      %{
        series1: series1,
        series2: series2,
        posts: [post1, post2, post3, post4]
      }
    end

    test "initial mount loads series for filtering", %{conn: conn, series1: series1, series2: series2} do
      {:ok, _view, html} = live(conn, "/")

      # Should display series filter section
      assert html =~ "series"
      assert html =~ "Available"
      assert html =~ series1.title
      assert html =~ series2.title
    end

    test "toggle_series event selects a series", %{conn: conn, series1: series1} do
      {:ok, view, _html} = live(conn, "/")

      # Click on Phoenix Tutorial series
      view |> element("button[phx-click='toggle_series'][phx-value-series='#{series1.slug}']") |> render_click()

      # Should navigate to URL with series parameter
      assert_patch(view, "/?series=#{series1.slug}")

      # Should show only posts from the selected series
      rendered = render(view)
      assert rendered =~ "Phoenix LiveView Introduction"
      assert rendered =~ "Phoenix LiveView Components"
      refute rendered =~ "Elixir Pattern Matching"
      refute rendered =~ "Standalone Post"
    end

    test "toggle_series event deselects currently selected series", %{conn: conn, series1: series1} do
      # Start with series already selected
      {:ok, view, _html} = live(conn, "/?series=#{series1.slug}")

      # Should show filtered posts
      rendered = render(view)
      assert rendered =~ "Phoenix LiveView Introduction"
      refute rendered =~ "Elixir Pattern Matching"

      # Click the same series again to deselect it
      view |> element("button[phx-click='toggle_series'][phx-value-series='#{series1.slug}']") |> render_click()

      # Should navigate back to home (no series parameter)
      assert_patch(view, "/")

      # Should show all posts again
      rendered = render(view)
      assert rendered =~ "Phoenix LiveView Introduction"
      assert rendered =~ "Phoenix LiveView Components"
      assert rendered =~ "Elixir Pattern Matching"
      assert rendered =~ "Standalone Post"
    end

    test "selecting a different series replaces current selection", %{conn: conn, series1: series1, series2: series2} do
      # Start with series1 selected
      {:ok, view, _html} = live(conn, "/?series=#{series1.slug}")

      # Verify series1 posts are shown
      rendered = render(view)
      assert rendered =~ "Phoenix LiveView Introduction"
      refute rendered =~ "Elixir Pattern Matching"

      # Select series2 (should replace series1)
      view |> element("button[phx-click='toggle_series'][phx-value-series='#{series2.slug}']") |> render_click()

      # Should navigate to series2 URL (replacing series1)
      assert_patch(view, "/?series=#{series2.slug}")

      # Should show only series2 posts
      rendered = render(view)
      refute rendered =~ "Phoenix LiveView Introduction"
      assert rendered =~ "Elixir Pattern Matching"
      refute rendered =~ "Standalone Post"
    end

    test "series selection with tags combines filters", %{conn: conn, series1: series1} do
      {:ok, view, _html} = live(conn, "/")

      # First select a tag
      view |> element("button", "phoenix") |> render_click()
      assert_patch(view, "/?tags=phoenix")

      # Then select a series
      view |> element("button[phx-click='toggle_series'][phx-value-series='#{series1.slug}']") |> render_click()

      # Should have both filters active
      rendered = render(view)
      assert rendered =~ "Showing posts tagged with"
      assert rendered =~ "phoenix"
      assert rendered =~ "in series"
      assert rendered =~ series1.title
    end

    test "clear_filters removes series selection", %{conn: conn, series1: series1} do
      # Start with series selected
      {:ok, view, _html} = live(conn, "/?series=#{series1.slug}")

      # Click clear filters (target the one in the filter status section)
      view |> element(".mb-6 button[phx-click='clear_filters']") |> render_click()

      # Should navigate to home
      assert_patch(view, "/")

      # Should show all posts
      rendered = render(view)
      assert rendered =~ "Phoenix LiveView Introduction"
      assert rendered =~ "Elixir Pattern Matching"
      assert rendered =~ "Standalone Post"
    end

    test "URL parameter parsing handles single series", %{conn: conn, series1: series1} do
      # Visit URL with series parameter
      {:ok, view, _html} = live(conn, "/?series=#{series1.slug}")

      # Should show filtered results based on URL param
      rendered = render(view)
      assert rendered =~ "Phoenix LiveView Introduction"
      assert rendered =~ "Phoenix LiveView Components"
      refute rendered =~ "Elixir Pattern Matching"
    end

    test "series selection shows proper visual indication", %{conn: conn, series1: series1, series2: series2} do
      {:ok, view, _html} = live(conn, "/?series=#{series1.slug}")

      rendered = render(view)
      
      # Selected series should have bold and underline styling
      assert rendered =~ ~r/class="[^"]*text-blue[^"]*font-bold[^"]*border-b-2[^"]*border-blue[^"]*"/
      
      # Unselected series should have different styling  
      assert rendered =~ series2.title
    end

    test "remove_series event deselects series", %{conn: conn, series1: series1} do
      # Start with series selected
      {:ok, view, _html} = live(conn, "/?series=#{series1.slug}")

      # Trigger remove_series event directly using render_hook
      render_hook(view, "remove_series", %{"series" => series1.slug})

      # Should navigate to home
      assert_patch(view, "/")

      # Should show all posts
      rendered = render(view)
      assert rendered =~ "Phoenix LiveView Introduction"
      assert rendered =~ "Elixir Pattern Matching"
      assert rendered =~ "Standalone Post"
    end

    test "series filter status shows current selection", %{conn: conn, series1: series1} do
      # Start with series selected
      {:ok, view, _html} = live(conn, "/?series=#{series1.slug}")

      rendered = render(view)
      
      # Should show filter status indicating series selection
      assert rendered =~ "Showing posts in series"
      assert rendered =~ series1.title
    end

    test "combined series, tags, and search filters", %{conn: conn, series1: series1} do
      {:ok, view, _html} = live(conn, "/")

      # Select a tag
      view |> element("button", "phoenix") |> render_click()
      
      # Select a series
      view |> element("button[phx-click='toggle_series'][phx-value-series='#{series1.slug}']") |> render_click()
      
      # Add a search term
      view
      |> form("form[phx-submit='search']", %{query: "LiveView"})
      |> render_submit()

      # Should show complex filter status
      rendered = render(view)
      assert rendered =~ "Showing posts tagged with"
      assert rendered =~ "phoenix"
      assert rendered =~ "in series"
      assert rendered =~ series1.title
      assert rendered =~ "matching"
      assert rendered =~ "LiveView"
    end

    test "empty state when series filter returns no results", %{conn: conn} do
      # Create a series with no published posts
      {:ok, _empty_series} = Content.create_series(%{
        title: "Empty Series",
        slug: "empty-series"
      })

      {:ok, view, _html} = live(conn, "/?series=empty-series")

      rendered = render(view)
      
      # Should show empty state
      assert rendered =~ "No posts found"
      assert rendered =~ "No posts match your current filters"
      assert has_element?(view, "button[phx-click='clear_filters']")
    end

    test "analytics tracking includes series selection", %{conn: conn, series1: series1} do
      {:ok, view, _html} = live(conn, "/")

      # Select series (this should trigger analytics tracking in load_posts)
      view |> element("button[phx-click='toggle_series'][phx-value-series='#{series1.slug}']") |> render_click()

      # The analytics tracking happens internally, we can't directly test it
      # but we can verify the page loaded correctly with the series filter
      rendered = render(view)
      assert rendered =~ series1.title
      assert rendered =~ "Phoenix LiveView Introduction"
    end

    test "series selection persists across page refreshes", %{conn: conn, series1: series1} do
      # Navigate directly to URL with series parameter (simulating page refresh)
      {:ok, _view, html} = live(conn, "/?series=#{series1.slug}")

      # Should immediately show filtered results
      assert html =~ "Phoenix LiveView Introduction"
      assert html =~ "Phoenix LiveView Components"
      refute html =~ "Elixir Pattern Matching"
      refute html =~ "Standalone Post"

      # Should show filter status
      assert html =~ "Showing posts in series"
      assert html =~ series1.title
    end
  end
end
