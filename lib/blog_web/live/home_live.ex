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
     |> assign(:available_tags, Content.list_available_tags())}
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
    <div class="h-screen bg-mantle overflow-hidden">
      <!-- Main Content with Adjacent Navigation -->
      <div class="w-full h-full px-8">
        <div class="max-w-6xl mx-auto flex h-full overflow-hidden">
          <!-- Navigation Adjacent to Blog Posts -->
          <.content_nav
            current_user={assigns[:current_user]}
            top_tags={@top_tags}
            available_tags={@available_tags}
            selected_tags={@selected_tags}
            search_query={@search_query}
            search_suggestions={@search_suggestions}
          />
          
    <!-- Blog Posts Scroll Area -->
          <main
            class="flex-1 overflow-y-auto scrollbar-hide px-6"
            id="posts-container"
            phx-hook="InfiniteScroll"
          >
            <!-- Filter Status -->
            <%= if @selected_tags != [] || @search_query != "" do %>
              <div class="mb-6 p-4 bg-surface0/50 rounded-lg border border-surface1">
                <div class="flex items-center justify-between">
                  <div class="text-sm text-subtext1">
                    <%= cond do %>
                      <% @selected_tags != [] && @search_query != "" -> %>
                        Showing posts tagged with
                        <span class="text-blue">{Enum.join(@selected_tags, ", ")}</span>
                        matching "<span class="text-blue"><%= @search_query %></span>"
                      <% @selected_tags != [] -> %>
                        Showing posts tagged with
                        <span class="text-blue">{Enum.join(@selected_tags, ", ")}</span>
                      <% @search_query != "" -> %>
                        Showing posts matching "<span class="text-blue"><%= @search_query %></span>"
                    <% end %>
                  </div>
                  <button
                    phx-click="clear_filters"
                    class="text-xs text-subtext0 hover:text-text transition-colors"
                  >
                    Clear
                  </button>
                </div>
              </div>
            <% end %>
            
    <!-- Posts List -->
            <%= for post <- @posts do %>
              <article>
                <.link
                  navigate={"/blog/#{post.slug}"}
                  class="block py-6 mx-2 hover:bg-surface1/20 transition-all duration-300 cursor-pointer rounded-2xl hover:shadow-[0_0_50px_10px_rgba(49,50,68,0.3)] relative"
                >
                  <div class="space-y-4">
                    <header class="px-4">
                      <h2 class="text-xl font-semibold text-text mb-2">
                        {post.title}
                      </h2>
                      <div class="flex items-center text-sm text-subtext1 space-x-4">
                        <time datetime={post.published_at}>
                          {Calendar.strftime(post.published_at, "%B %d, %Y")}
                        </time>
                        <%= if Blog.Content.Post.tag_list(post) != [] do %>
                          <div class="flex items-center space-x-2">
                            <span>•</span>
                            <div class="flex flex-wrap gap-2">
                              <%= for tag <- Blog.Content.Post.tag_list(post) do %>
                                <span class="bg-surface1 text-subtext0 px-2 py-1 rounded text-xs">
                                  {tag}
                                </span>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </header>

                    <%= if post.subtitle do %>
                      <div class="text-subtext1 text-sm px-4">
                        {post.subtitle}
                      </div>
                    <% end %>

                    <div class="relative">
                      <div class="text-subtext1 overflow-hidden h-36 px-4">
                        {Blog.Content.Post.preview_content(post.content, 6)}
                      </div>
                    </div>
                  </div>
                  <!-- Fade effect covering the entire link area -->
                  <div class="absolute bottom-0 left-0 right-0 h-48 bg-gradient-to-t from-mantle via-mantle/90 via-mantle/60 via-mantle/40 to-transparent pointer-events-none">
                  </div>
                </.link>
              </article>
            <% end %>
            
    <!-- Loading Indicator for Infinite Scroll -->
            <%= if @has_more do %>
              <div class="mt-12 text-center py-8" id="loading-indicator">
                <div class="inline-flex items-center space-x-2 text-subtext1">
                  <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue"></div>
                  <span class="text-sm">Loading more posts...</span>
                </div>
              </div>
            <% end %>
            
    <!-- Empty State -->
            <%= if @posts == [] do %>
              <div class="text-center py-12">
                <%= if @selected_tags != [] || @search_query != "" do %>
                  <div class="text-6xl mb-4">🔍</div>
                  <h2 class="text-xl font-semibold text-text mb-2">No posts found</h2>
                  <p class="text-subtext1 mb-4">No posts match your current filters.</p>
                  <button
                    phx-click="clear_filters"
                    class="px-4 py-2 bg-blue hover:bg-blue/80 text-base rounded-lg font-medium transition-colors"
                  >
                    Clear Filters
                  </button>
                <% else %>
                  <div class="text-6xl mb-4">📝</div>
                  <h2 class="text-xl font-semibold text-text mb-2">No posts yet</h2>
                  <p class="text-subtext1">Check back later for new content.</p>
                <% end %>
              </div>
            <% end %>
          </main>
        </div>
      </div>
    </div>
    """
  end
end
