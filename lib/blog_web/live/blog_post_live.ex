defmodule BlogWeb.BlogPostLive do
  use BlogWeb, :live_view
  alias Blog.Analytics
  alias Blog.Content

  def mount(%{"slug" => slug}, _session, socket) do
    case Content.get_published_post_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Post not found")
         |> redirect(to: "/")}

      post ->
        Analytics.track_post_view(post.id, post.title, post.slug)

        {:ok,
         socket
         |> assign(:page_title, post.title)
         |> assign(:post, post)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base">
      <div class="fixed top-6 right-6 z-50 hidden lg:block">
        <.theme_toggle />
      </div>

      <main class="max-w-4xl mx-auto px-4 lg:px-6 py-8 lg:py-12">
        <article class="prose prose-invert prose-xl max-w-none">
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

          <div class="prose-catppuccin">
            {raw(Blog.Content.Post.render_content(@post))}
          </div>
        </article>
      </main>

      <div class="fixed bottom-4 left-4 lg:bottom-6 lg:left-6 z-50">
        <a
          href="/"
          phx-hook="BackButton"
          id="back-button"
          class="flex items-center justify-center w-12 h-12 lg:w-14 lg:h-14 bg-blue hover:bg-blue/80 text-base rounded-full shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-105"
          title="Back to Blog"
        >
          <svg class="w-5 h-5 lg:w-6 lg:h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M10 19l-7-7m0 0l7-7m-7 7h18"
            >
            </path>
          </svg>
        </a>
      </div>
    </div>
    """
  end
end
