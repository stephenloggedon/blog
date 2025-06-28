defmodule BlogWeb.BlogPostLive do
  use BlogWeb, :live_view
  alias Blog.Content

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
    <div class="min-h-screen bg-base">
      <!-- Header -->
      <header class="bg-surface0 border-b border-surface1">
        <div class="max-w-4xl mx-auto px-6 py-4">
          <div class="flex items-center justify-between">
            <a href="/" class="text-blue hover:text-lavender transition-colors">
              ← Back to Blog
            </a>
            <nav class="flex items-center space-x-4">
              <a href="/posts" class="text-blue hover:text-lavender transition-colors">Admin</a>
              <a href="/users/log_in" class="text-subtext1 hover:text-text transition-colors">Login</a>
            </nav>
          </div>
        </div>
      </header>

      <!-- Article -->
      <main class="max-w-4xl mx-auto px-6 py-8">
        <article class="bg-surface0 rounded-lg border border-surface1 overflow-hidden">
          <div class="p-8">
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
          <a 
            href="/" 
            class="bg-blue hover:bg-opacity-80 text-base px-6 py-3 rounded-lg font-medium transition-all"
          >
            ← Back to All Posts
          </a>
        </div>
      </main>
    </div>
    """
  end
end