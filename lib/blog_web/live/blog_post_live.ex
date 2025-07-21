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
         |> assign(:post, post)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base">
      <!-- Theme Toggle - Top Right -->
      <div class="fixed top-6 right-6 z-50">
        <.theme_toggle />
      </div>
      
      <!-- Main Article Content -->
      <main class="max-w-4xl mx-auto px-6 py-12">
        <article class="prose prose-invert prose-xl max-w-none">
          <!-- Article Header -->
          <header class="mb-12 text-center">
            <h1 class="text-4xl font-bold text-text mb-6 leading-tight">{@post.title}</h1>

            <%= if @post.subtitle do %>
              <div class="text-xl text-subtext0 mb-6 font-medium">
                {@post.subtitle}
              </div>
            <% end %>

            <div class="flex items-center justify-center text-sm text-subtext1 space-x-4">
              <time datetime={@post.published_at}>
                {Calendar.strftime(@post.published_at, "%B %d, %Y")}
              </time>
              <%= if Blog.Content.Post.tag_list(@post) != [] do %>
                <span>•</span>
                <div class="flex flex-wrap gap-2 justify-center">
                  <%= for tag <- Blog.Content.Post.tag_list(@post) do %>
                    <span class="bg-surface1 text-subtext0 px-3 py-1 rounded-full text-xs font-medium">
                      {tag}
                    </span>
                  <% end %>
                </div>
              <% end %>
            </div>
          </header>
          
    <!-- Article Content -->
          <div class="prose-catppuccin">
            {raw(Blog.Content.Post.render_content(@post))}
          </div>
        </article>
      </main>
      
    <!-- Floating Back Button -->
      <div class="fixed bottom-6 left-6 z-50">
        <.link
          navigate="/"
          class="flex items-center justify-center w-14 h-14 bg-blue hover:bg-blue/80 text-base rounded-full shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-105"
          title="Back to Blog"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M10 19l-7-7m0 0l7-7m-7 7h18"
            >
            </path>
          </svg>
        </.link>
      </div>
    </div>
    """
  end
end
