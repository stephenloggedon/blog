defmodule BlogWeb.HomeLive do
  use BlogWeb, :live_view
  alias Blog.Content

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Blog")
     |> assign(:posts, [])
     |> assign(:page, 1)
     |> assign(:per_page, 10)
     |> assign(:has_more, true)
     |> assign(:selected_tags, [])
     |> assign(:search_query, "")
     |> assign(:search_suggestions, [])
     |> assign(:top_tags, Content.list_top_tags(5))
     |> assign(:available_tags, Content.list_available_tags())
     |> assign(:drawer_open, false)}
  end

  def handle_params(params, _url, socket) do
    # Handle multiple selected tags from URL parameters
    selected_tags =
      case Map.get(params, "tags") do
        nil ->
          []

        tags_string when is_binary(tags_string) ->
          String.split(tags_string, ",") |> Enum.map(&String.trim/1)

        _ ->
          []
      end

    search_param = Map.get(params, "search")

    # Ensure search_query is always a clean string
    search_query =
      case search_param do
        nil -> ""
        query when is_binary(query) -> String.trim(query)
        %{"query" => query} when is_binary(query) -> String.trim(query)
        _ -> ""
      end

    {:noreply,
     socket
     |> assign(:selected_tags, selected_tags)
     |> assign(:search_query, search_query)
     |> assign(:search_suggestions, [])
     |> assign(:posts, [])
     |> assign(:page, 1)
     |> load_posts()}
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
        # Remove tag if already selected
        List.delete(current_tags, tag)
      else
        # Add tag if not selected
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

    # Get tag suggestions if query looks like it might be a tag
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
     # Update for display only
     |> assign(:search_query, search_input)
     |> assign(:search_suggestions, suggestions)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    search_query = String.trim(query || "")

    # If the search query matches an available tag exactly, add it as a tag
    if search_query in socket.assigns.available_tags and
         search_query not in socket.assigns.selected_tags do
      updated_tags = [search_query | socket.assigns.selected_tags]

      {:noreply,
       socket
       |> assign(:search_query, "")
       |> assign(:search_suggestions, [])
       |> push_patch(to: build_path_with_tags(socket, updated_tags))}
    else
      # Otherwise, treat it as a text search
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

  defp load_posts(socket) do
    %{
      page: page,
      per_page: per_page,
      posts: existing_posts,
      selected_tags: selected_tags,
      search_query: search_query
    } = socket.assigns

    opts = [page: page, per_page: per_page]
    opts = if selected_tags != [], do: Keyword.put(opts, :tags, selected_tags), else: opts
    opts = if search_query != "", do: Keyword.put(opts, :search, search_query), else: opts

    new_posts = Content.list_published_posts(opts)
    all_posts = existing_posts ++ new_posts
    has_more = length(new_posts) == per_page

    assign(socket, posts: all_posts, has_more: has_more)
  end

  defp build_path_with_tags(socket, tags) do
    %{search_query: search_query} = socket.assigns
    build_path_with_params(tags, search_query)
  end

  defp build_path_with_search(socket, search_query) do
    %{selected_tags: selected_tags} = socket.assigns
    build_path_with_params(selected_tags, search_query)
  end

  defp build_path_with_params(selected_tags, search_query) do
    # Ensure search_query is always a string
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
      if clean_search_query != "", do: [{"search", clean_search_query} | params], else: params

    case params do
      [] -> "/"
      _ -> "/?" <> URI.encode_query(params)
    end
  end

  def render(assigns) do
    ~H"""
    <div class="bg-mantle overflow-hidden" style="height: 100dvh; height: 100vh;">
      <!-- Theme Toggle - Top Right (Desktop only) -->
      <div class="fixed top-6 right-6 z-50 hidden lg:block">
        <.theme_toggle />
      </div>
      
      <!-- Desktop Layout -->
      <div class="w-full px-8 hidden lg:block" style="height: 100dvh; height: 100vh;">
        <div class="max-w-6xl mx-auto flex overflow-hidden" style="height: 100dvh; height: 100vh;">
          <!-- Navigation Adjacent to Blog Posts (Desktop) -->
          <.content_nav
            current_user={assigns[:current_user]}
            top_tags={@top_tags}
            available_tags={@available_tags}
            selected_tags={@selected_tags}
            search_query={@search_query}
            search_suggestions={@search_suggestions}
          />
          
          <!-- Blog Posts Scroll Area (Desktop) -->
          <main
            class="flex-1 overflow-y-auto scrollbar-hide px-6"
            id="posts-container"
            phx-hook="InfiniteScroll"
          >
            <.posts_content 
              posts={@posts}
              selected_tags={@selected_tags}
              search_query={@search_query}
              has_more={@has_more}
            />
          </main>
        </div>
      </div>
      
      <!-- Mobile Layout -->
      <div id="mobile-layout" class="w-full lg:hidden" style="height: 100dvh; height: 100vh;" phx-hook="MobileScrollFix">
        <!-- Mobile Posts Scroll Area -->
        <main
          class="overflow-y-auto scrollbar-hide px-4 pb-24 mobile-scroll-container"
          id="mobile-posts-container"
          phx-hook="InfiniteScroll"
          style="height: 100dvh; height: 100vh;"
        >
          <.posts_content 
            posts={@posts}
            selected_tags={@selected_tags}
            search_query={@search_query}
            has_more={@has_more}
          />
        </main>
        
        <!-- Mobile Drawer -->
        <.mobile_drawer id="mobile-nav" open={@drawer_open}>
          <div class="space-y-6">
            <!-- Theme Toggle in Mobile Drawer -->
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-text">Settings</h2>
              <.theme_toggle id="mobile-theme-toggle" />
            </div>
            
            <!-- Mobile Navigation Content -->
            <.mobile_content_nav
              current_user={assigns[:current_user]}
              top_tags={@top_tags}
              available_tags={@available_tags}
              selected_tags={@selected_tags}
              search_query={@search_query}
              search_suggestions={@search_suggestions}
            />
          </div>
        </.mobile_drawer>
      </div>
    </div>
    """
  end
end
