defmodule BlogWeb.HomeLive do
  use BlogWeb, :live_view
  alias Blog.Analytics
  alias Blog.Content

  def mount(_params, _session, socket) do
    # Determine viewport - in tests, default to desktop for consistent behavior
    viewport = detect_viewport(socket)

    {:ok,
     socket
     |> assign(:page_title, "Blog")
     |> assign(:posts, [])
     |> assign(:page, 1)
     |> assign(:per_page, 10)
     |> assign(:has_more, true)
     |> assign(:selected_tags, [])
     |> assign(:selected_series, nil)
     |> assign(:search_query, "")
     |> assign(:search_suggestions, [])
     |> assign(:top_tags, Content.list_top_tags(15))
     |> assign(:available_tags, Content.list_available_tags())
     |> assign(:available_series, Content.list_series_for_filtering())
     |> assign(:drawer_open, false)
     |> assign(:viewport, viewport)
     |> assign(:series_empty_state, nil)}
  end

  def handle_params(params, _url, socket) do
    selected_tags = parse_tags_param(params)
    selected_series = parse_series_param(params)
    search_query = parse_search_param(params)

    {:noreply,
     socket
     |> assign(:selected_tags, selected_tags)
     |> assign(:selected_series, selected_series)
     |> assign(:search_query, search_query)
     |> assign(:search_suggestions, [])
     |> assign(:posts, [])
     |> assign(:page, 1)
     |> assign(:series_empty_state, nil)
     |> load_posts()}
  end

  defp parse_tags_param(params) do
    case Map.get(params, "tags") do
      nil ->
        []

      tags_string when is_binary(tags_string) ->
        String.split(tags_string, ",") |> Enum.map(&String.trim/1)

      _ ->
        []
    end
  end

  defp parse_series_param(params) do
    case Map.get(params, "series") do
      nil -> nil
      series_string when is_binary(series_string) -> String.trim(series_string)
      _ -> nil
    end
  end

  defp parse_search_param(params) do
    case Map.get(params, "search") do
      nil -> ""
      query when is_binary(query) -> String.trim(query)
      %{"query" => query} when is_binary(query) -> String.trim(query)
      _ -> ""
    end
  end

  def handle_event("load_more", _params, socket) do
    next_page = socket.assigns.page + 1

    {:noreply,
     socket
     |> assign(:page, next_page)
     |> load_posts()}
  end

  def handle_event("toggle_tag", %{"tag" => tag}, socket) do
    current_tags = socket.assigns.selected_tags

    updated_tags =
      if tag in current_tags do
        List.delete(current_tags, tag)
      else
        [tag | current_tags]
      end

    {:noreply,
     socket
     |> push_patch(to: build_path_with_tags(socket, updated_tags))}
  end

  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    updated_tags = List.delete(socket.assigns.selected_tags, tag)

    {:noreply,
     socket
     |> push_patch(to: build_path_with_tags(socket, updated_tags))}
  end

  def handle_event("toggle_series", %{"series" => series_slug}, socket) do
    current_series = socket.assigns.selected_series

    updated_series =
      if current_series == series_slug do
        nil
      else
        series_slug
      end

    {:noreply,
     socket
     |> push_patch(to: build_path_with_series(socket, updated_series))}
  end

  def handle_event("remove_series", %{"series" => _series_slug}, socket) do
    {:noreply,
     socket
     |> push_patch(to: build_path_with_series(socket, nil))}
  end

  def handle_event("add_tag_from_search", %{"tag" => tag}, socket) do
    current_tags = socket.assigns.selected_tags

    updated_tags =
      if tag in current_tags do
        current_tags
      else
        [tag | current_tags]
      end

    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:search_suggestions, [])
     |> push_patch(to: build_path_with_tags(socket, updated_tags))}
  end

  def handle_event("search_input", %{"value" => value}, socket) do
    search_input = String.trim(value || "")

    suggestions =
      if String.length(search_input) >= 2 do
        socket.assigns.available_tags
        |> Enum.filter(fn tag ->
          String.contains?(String.downcase(tag), String.downcase(search_input)) and
            tag not in socket.assigns.selected_tags
        end)
        |> Enum.take(5)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:search_query, search_input)
     |> assign(:search_suggestions, suggestions)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    search_query = String.trim(query || "")

    if search_query in socket.assigns.available_tags and
         search_query not in socket.assigns.selected_tags do
      updated_tags = [search_query | socket.assigns.selected_tags]

      Analytics.track_search("tag:#{search_query}", length(updated_tags))

      {:noreply,
       socket
       |> assign(:search_query, "")
       |> assign(:search_suggestions, [])
       |> push_patch(to: build_path_with_tags(socket, updated_tags))}
    else
      {:noreply,
       socket
       |> assign(:search_suggestions, [])
       |> push_patch(to: build_path_with_search(socket, search_query))}
    end
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_tags, [])
     |> assign(:selected_series, nil)
     |> assign(:search_query, "")
     |> assign(:search_suggestions, [])
     |> assign(:posts, [])
     |> assign(:page, 1)
     |> load_posts()
     |> push_patch(to: "/")}
  end

  def handle_event("open_drawer", _params, socket) do
    {:noreply, assign(socket, :drawer_open, true)}
  end

  def handle_event("close_drawer", _params, socket) do
    {:noreply, assign(socket, :drawer_open, false)}
  end

  def handle_event("set_viewport", %{"viewport" => viewport}, socket) do
    {:noreply, assign(socket, :viewport, viewport)}
  end

  defp load_posts(socket) do
    %{
      page: page,
      per_page: per_page,
      posts: existing_posts,
      selected_tags: selected_tags,
      selected_series: selected_series,
      search_query: search_query
    } = socket.assigns

    opts = build_post_query_opts(page, per_page, selected_tags, selected_series, search_query)
    new_posts = Content.list_posts(opts)
    all_posts = existing_posts ++ new_posts
    has_more = length(new_posts) == per_page

    track_analytics(page, search_query, selected_tags, selected_series, new_posts)
    series_empty_state = get_series_empty_state(selected_series)

    assign(socket, posts: all_posts, has_more: has_more, series_empty_state: series_empty_state)
  end

  defp build_post_query_opts(page, per_page, selected_tags, selected_series, search_query) do
    [page: page, per_page: per_page, include_preview: true]
    |> maybe_add_tags(selected_tags)
    |> maybe_add_series(selected_series)
    |> maybe_add_search(search_query)
  end

  defp maybe_add_tags(opts, []), do: opts
  defp maybe_add_tags(opts, tags), do: Keyword.put(opts, :tags, tags)

  defp maybe_add_series(opts, nil), do: opts
  defp maybe_add_series(opts, series), do: Keyword.put(opts, :series, [series])

  defp maybe_add_search(opts, ""), do: opts
  defp maybe_add_search(opts, query), do: Keyword.put(opts, :search, query)

  defp track_analytics(page, search_query, selected_tags, selected_series, new_posts) do
    if has_search_criteria?(search_query, selected_tags, selected_series) do
      search_term = build_search_term(search_query, selected_tags, selected_series)
      Analytics.track_search(search_term, length(new_posts))
    end

    if page == 1 do
      Analytics.track_page_view("/", "Blog Home")
    end
  end

  defp has_search_criteria?("", [], nil), do: false
  defp has_search_criteria?(_, _, _), do: true

  defp build_search_term("", [], series) when series != nil, do: "series:#{series}"
  defp build_search_term("", tags, nil) when tags != [], do: "tags:#{Enum.join(tags, ",")}"

  defp build_search_term("", tags, series) when tags != [] and series != nil,
    do: "tags:#{Enum.join(tags, ",")} series:#{series}"

  defp build_search_term(query, _, _), do: query

  defp get_series_empty_state(nil), do: nil
  defp get_series_empty_state(series), do: Content.get_series_empty_state(series)

  defp build_path_with_tags(socket, tags) do
    %{search_query: search_query, selected_series: selected_series} = socket.assigns
    build_path_with_params(tags, selected_series, search_query)
  end

  defp build_path_with_search(socket, search_query) do
    %{selected_tags: selected_tags, selected_series: selected_series} = socket.assigns
    build_path_with_params(selected_tags, selected_series, search_query)
  end

  defp build_path_with_series(socket, series) do
    %{selected_tags: selected_tags, search_query: search_query} = socket.assigns
    build_path_with_params(selected_tags, series, search_query)
  end

  defp detect_viewport(socket) do
    case get_connect_info(socket, :user_agent) do
      user_agent when is_binary(user_agent) ->
        mobile_patterns = [
          "Mobile",
          "Android",
          "iPhone",
          "iPad",
          "iPod",
          "BlackBerry",
          "Windows Phone",
          "Opera Mini",
          "IEMobile"
        ]

        is_mobile =
          Enum.any?(mobile_patterns, fn pattern ->
            String.contains?(user_agent, pattern)
          end)

        if is_mobile, do: "mobile", else: "desktop"

      _ ->
        "desktop"
    end
  end

  defp build_path_with_params(selected_tags, selected_series, search_query) do
    clean_search_query =
      case search_query do
        query when is_binary(query) -> String.trim(query)
        %{"query" => query} when is_binary(query) -> String.trim(query)
        _ -> ""
      end

    params = []

    params =
      if selected_tags != [], do: [{"tags", Enum.join(selected_tags, ",")} | params], else: params

    params =
      if selected_series != nil, do: [{"series", selected_series} | params], else: params

    params =
      if clean_search_query != "", do: [{"search", clean_search_query} | params], else: params

    case params do
      [] -> "/"
      _ -> "/?" <> URI.encode_query(params)
    end
  end

  def render(assigns) do
    ~H"""
    <div class="bg-mantle min-h-screen" phx-hook="ViewportDetector" id="viewport-container">
      <%= if @viewport == "desktop" do %>
        <div class="fixed top-6 right-6 z-50">
          <.theme_toggle />
        </div>

        <div class="w-full px-8" style="height: 100dvh; height: 100vh;">
          <div class="max-w-6xl mx-auto flex overflow-hidden" style="height: 100dvh; height: 100vh;">
            <.content_nav
              current_user={assigns[:current_user]}
              top_tags={@top_tags}
              available_tags={@available_tags}
              selected_tags={@selected_tags}
              available_series={@available_series}
              selected_series={@selected_series}
              search_query={@search_query}
              search_suggestions={@search_suggestions}
            />

            <main
              class="flex-1 overflow-y-auto scrollbar-hide px-6"
              id="posts-container"
              phx-hook="InfiniteScroll"
            >
              <.posts_content
                posts={@posts}
                selected_tags={@selected_tags}
                selected_series={@selected_series}
                search_query={@search_query}
                has_more={@has_more}
                series_empty_state={@series_empty_state}
              />
            </main>
          </div>
        </div>
      <% else %>
        <div id="mobile-layout" class="w-full safari-scroll-fix">
          <div
            class="px-4 safari-scroll-content"
            id="mobile-posts-container"
            phx-hook="InfiniteScroll"
          >
            <.posts_content
              posts={@posts}
              selected_tags={@selected_tags}
              selected_series={@selected_series}
              search_query={@search_query}
              has_more={@has_more}
              series_empty_state={@series_empty_state}
            />
          </div>

          <.mobile_drawer id="mobile-nav" open={@drawer_open}>
            <div class="space-y-6">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold text-text">Settings</h2>
                <.theme_toggle id="mobile-theme-toggle" />
              </div>

              <.mobile_content_nav
                current_user={assigns[:current_user]}
                top_tags={@top_tags}
                available_tags={@available_tags}
                selected_tags={@selected_tags}
                available_series={@available_series}
                selected_series={@selected_series}
                search_query={@search_query}
                search_suggestions={@search_suggestions}
              />
            </div>
          </.mobile_drawer>
        </div>
      <% end %>
    </div>
    """
  end
end
