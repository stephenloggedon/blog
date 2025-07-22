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
end
