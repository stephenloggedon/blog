defmodule BlogWeb.HomeLive do
  use BlogWeb, :live_view
  alias Blog.Content

  on_mount {BlogWeb.UserAuth, :mount_current_user}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Blog")
     |> assign(:posts, [])
     |> assign(:page, 1)
     |> assign(:per_page, 10)
     |> assign(:has_more, true)
     |> load_posts()
    }
  end

  def handle_event("load_more", _params, socket) do
    next_page = socket.assigns.page + 1

    {:noreply,
     socket
     |> assign(:page, next_page)
     |> load_posts()
    }
  end

  defp load_posts(socket) do
    %{page: page, per_page: per_page, posts: existing_posts} = socket.assigns

    new_posts = Content.list_published_posts(page: page, per_page: per_page)
    all_posts = existing_posts ++ new_posts
    has_more = length(new_posts) == per_page

    assign(socket, posts: all_posts, has_more: has_more)
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen bg-mantle overflow-hidden">
      <!-- Main Content with Adjacent Navigation -->
      <div class="w-full h-full px-8">
        <div class="max-w-6xl mx-auto flex h-full overflow-hidden">
          <!-- Navigation Adjacent to Blog Posts -->
          <.content_nav current_user={assigns[:current_user]} />

          <!-- Blog Posts Scroll Area -->
          <main class="flex-1 overflow-y-auto scrollbar-hide px-6" id="posts-container">
          <%= for post <- @posts do %>
            <article>
              <.link navigate={"/blog/#{post.slug}"} class="block py-6 mx-2 hover:bg-surface1/20 transition-all duration-300 cursor-pointer rounded-2xl hover:shadow-[0_0_50px_10px_rgba(49,50,68,0.3)] relative">
                <div class="space-y-4">
                  <header class="px-4">
                    <h2 class="text-xl font-semibold text-text mb-2">
                      <%= post.title %>
                    </h2>
                    <div class="flex items-center text-sm text-subtext1 space-x-4">
                      <time datetime={post.published_at}>
                        <%= Calendar.strftime(post.published_at, "%B %d, %Y") %>
                      </time>
                      <%= if Blog.Content.Post.tag_list(post) != [] do %>
                        <div class="flex items-center space-x-2">
                          <span>•</span>
                          <div class="flex flex-wrap gap-2">
                            <%= for tag <- Blog.Content.Post.tag_list(post) do %>
                              <span class="bg-surface1 text-subtext0 px-2 py-1 rounded text-xs">
                                <%= tag %>
                              </span>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </header>

                  <%= if post.subtitle do %>
                    <div class="text-subtext1 text-sm px-4">
                      <%= post.subtitle %>
                    </div>
                  <% end %>

                  <div class="relative">
                    <div class="text-subtext1 overflow-hidden h-36 px-4">
                      <%= raw(Blog.Content.Post.render_content(post) |> String.slice(0, 400)) %>
                    </div>
                  </div>
                </div>
                <!-- Fade effect covering the entire link area -->
                <div class="absolute bottom-0 left-0 right-0 h-48 bg-gradient-to-t from-mantle via-mantle/90 via-mantle/60 via-mantle/40 to-transparent pointer-events-none"></div>
              </.link>
            </article>
          <% end %>

            <!-- Load More Button -->
            <%= if @has_more do %>
              <div class="mt-12 text-center">
                <button
                  phx-click="load_more"
                  class="bg-blue hover:bg-opacity-80 text-base px-6 py-3 rounded-lg font-medium transition-all"
                >
                  Load More Posts
                </button>
              </div>
            <% end %>

            <!-- Empty State -->
            <%= if @posts == [] do %>
              <div class="text-center py-12">
                <div class="text-6xl mb-4">📝</div>
                <h2 class="text-xl font-semibold text-text mb-2">No posts yet</h2>
                <p class="text-subtext1">Check back later for new content.</p>
              </div>
            <% end %>
          </main>
        </div>
      </div>
    </div>
    """
  end
end
