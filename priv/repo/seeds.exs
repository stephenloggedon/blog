# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Blog.Repo.insert!(%Blog.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Blog.{Repo, Accounts, Content}

# Create a user for blog posts
user = case Accounts.register_user(%{
  email: "admin@example.com",
  password: "password123456789"
}) do
  {:ok, user} -> user
  {:error, _changeset} -> Accounts.get_user_by_email("admin@example.com")
end

# Create some sample blog posts
sample_posts = [
  %{
    title: "Welcome to My Blog",
    content: """
    # Welcome to My Blog

    This is my first blog post! I'm excited to share my thoughts and experiences with you.

    ## What You Can Expect

    - Technical tutorials and tips
    - Personal reflections on development
    - Reviews of tools and technologies
    - And much more!

    Thanks for visiting, and I hope you find the content useful.
    """,
    tags: "welcome, introduction",
    published_at: ~U[2025-06-25 10:00:00Z],
    user_id: user.id
  },
  %{
    title: "Building a Phoenix LiveView Blog",
    content: """
    # Building a Phoenix LiveView Blog

    Today I want to share my experience building this blog using Phoenix LiveView, Svelte, and Tailwind CSS.

    ## The Tech Stack

    - **Phoenix LiveView**: For real-time, interactive web applications
    - **Svelte**: For enhanced client-side interactivity
    - **Tailwind CSS**: For rapid UI development
    - **PostgreSQL**: For reliable data storage

    ## Key Features

    - TOTP Two-Factor Authentication
    - Markdown content with syntax highlighting
    - Responsive design with dark theme
    - Infinite scroll homepage
    - Tag-based organization

    The combination of these technologies provides a modern, efficient, and secure blogging platform.
    """,
    tags: "phoenix, elixir, web-development",
    published_at: ~U[2025-06-26 14:30:00Z],
    user_id: user.id
  },
  %{
    title: "The Power of Elixir for Web Development",
    content: """
    # The Power of Elixir for Web Development

    Elixir has revolutionized how I think about building web applications. Here's why it's become my go-to language for web development.

    ## Concurrency and Fault Tolerance

    Elixir's actor model makes it incredibly easy to build concurrent, fault-tolerant applications. The supervised process tree ensures that failures are isolated and don't bring down the entire system.

    ## Pattern Matching

    Pattern matching in Elixir is not just a feature—it's a way of thinking that makes code more expressive and easier to reason about.

    ```elixir
    case get_user(id) do
      {:ok, user} -> render_user(user)
      {:error, :not_found} -> render_404()
      {:error, reason} -> handle_error(reason)
    end
    ```

    ## Phoenix LiveView

    LiveView brings the power of server-side rendering with the interactivity of single-page applications, without the complexity of managing client-side state.

    If you haven't tried Elixir yet, I highly recommend giving it a shot for your next web project.
    """,
    tags: "elixir, functional-programming, web-development",
    published_at: ~U[2025-06-27 09:15:00Z],
    user_id: user.id
  },
  %{
    title: "Deploying Phoenix Apps to Production",
    content: """
    # Deploying Phoenix Apps to Production

    Deploying Phoenix applications has become much easier with modern hosting platforms. Here's my experience with different deployment options.

    ## Platform Options

    ### Gigalixir
    - Elixir-native platform
    - Supports hot code upgrades
    - Easy scaling and clustering
    - Built-in monitoring

    ### Fly.io
    - Global edge deployment
    - Great performance
    - Docker-based deployments

    ### Traditional VPS
    - Full control over the environment
    - More configuration required
    - Cost-effective for larger applications

    ## Best Practices

    1. **Use releases** - Always deploy using Elixir releases
    2. **Environment configuration** - Keep secrets in environment variables
    3. **Health checks** - Implement proper health check endpoints
    4. **Monitoring** - Set up application monitoring and alerts
    5. **Database migrations** - Automate database migrations in your deployment pipeline

    The key is choosing the right platform for your specific needs and requirements.
    """,
    tags: "deployment, devops, phoenix",
    published_at: ~U[2025-06-28 11:45:00Z],
    user_id: user.id
  }
]

# Insert the sample posts
Enum.each(sample_posts, fn post_attrs ->
  {:ok, _post} = Content.create_post(post_attrs)
end)

IO.puts("Seeded database with sample user and blog posts!")