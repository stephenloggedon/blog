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
    <div class="h-screen bg-base flex flex-col">
      <!-- Page Header -->
      <.page_header page_title="Blog" />
      
      <!-- Main Content with Adjacent Navigation -->
      <div class="flex-1 w-full px-6 pt-8 overflow-hidden">
        <div class="max-w-4xl mx-auto flex h-full bg-surface0 rounded-lg overflow-hidden">
          <!-- Navigation Adjacent to Blog Posts -->
          <.content_nav current_user={assigns[:current_user]} />

          <!-- Blog Posts Scroll Area -->
          <main class="flex-1 overflow-y-auto scrollbar-hide px-6" id="posts-container">
          <%= for post <- @posts do %>
            <article class="border-b border-surface1 last:border-b-0">
              <.link navigate={"/blog/#{post.slug}"} class="block py-6 hover:bg-surface0/20 transition-colors cursor-pointer">
                <header class="mb-4">
                  <h2 class="text-xl font-semibold text-text mb-2 hover:text-blue transition-colors">
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
                
                <div class="relative">
                  <div class="text-subtext1 leading-relaxed overflow-hidden h-36">
                    <%= raw(Blog.Content.Post.render_content(post) |> String.slice(0, 400)) %>
                  </div>
                  <div class="absolute bottom-0 left-0 right-0 h-12 bg-gradient-to-t from-surface0 via-surface0/80 to-transparent pointer-events-none"></div>
                </div>
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