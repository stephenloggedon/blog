defmodule BlogWeb.BlogPostLive do
  use BlogWeb, :live_view
  alias Blog.Content

  on_mount {BlogWeb.UserAuth, :mount_current_user}

  def mount(%{"slug" => slug}, _session, socket) do
    case Content.get_published_post_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Post not found")
         |> redirect(to: "/")}

      post ->
        {:ok,
         socket
         |> assign(:page_title, post.title)
         |> assign(:post, post)
        }
    end
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen bg-base flex flex-col">
      <!-- Page Header -->
      <.page_header page_title={@post.title} />
      
      <!-- Main Content with Adjacent Navigation -->
      <div class="flex-1 w-full px-6 pt-8 overflow-hidden">
        <div class="max-w-4xl mx-auto flex h-full bg-surface0 rounded-lg overflow-hidden">
          <!-- Navigation Adjacent to Article -->
          <.content_nav current_user={assigns[:current_user]} />

          <!-- Article Content Area -->
          <main class="flex-1 overflow-y-auto scrollbar-hide px-6">
            <!-- Back to Blog Link -->
            <div class="mb-6">
              <.link navigate="/" class="text-blue hover:text-lavender transition-colors inline-flex items-center">
                ← Back to Blog
              </.link>
            </div>
          <article class="py-6">
          <div>
            <!-- Article Header -->
            <header class="mb-8">
              <h1 class="text-3xl font-bold text-text mb-4"><%= @post.title %></h1>
              <div class="flex items-center text-sm text-subtext1 space-x-4">
                <time datetime={@post.published_at}>
                  <%= Calendar.strftime(@post.published_at, "%B %d, %Y") %>
                </time>
                <%= if Blog.Content.Post.tag_list(@post) != [] do %>
                  <span>•</span>
                  <div class="flex flex-wrap gap-2">
                    <%= for tag <- Blog.Content.Post.tag_list(@post) do %>
                      <span class="bg-surface1 text-subtext0 px-2 py-1 rounded text-xs">
                        <%= tag %>
                      </span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </header>

            <!-- Article Content -->
            <div class="prose prose-invert prose-lg max-w-none">
              <%= raw(@post.rendered_content) %>
            </div>
          </div>
        </article>

            <!-- Navigation -->
            <div class="mt-8 flex justify-center">
              <.link 
                navigate="/" 
                class="bg-blue hover:bg-opacity-80 text-base px-6 py-3 rounded-lg font-medium transition-all"
              >
                ← Back to All Posts
              </.link>
            </div>
          </main>
        </div>
      </div>
    </div>
    """
  end
end