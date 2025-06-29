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
user =
  case Accounts.register_user(%{
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
    subtitle: "My first blog post and introduction to what you can expect here",
    content: """
    # Welcome to My Blog

    This is my first blog post! I'm excited to share my thoughts and experiences with you. Starting this blog has been something I've wanted to do for a long time, and I'm finally making it happen.

    ## What You Can Expect

    - In-depth technical tutorials and tips that I've learned through real-world experience
    - Personal reflections on software development, career growth, and the ever-evolving tech landscape
    - Comprehensive reviews of tools, frameworks, and technologies that I use in my daily work
    - Behind-the-scenes looks at projects I'm working on and the challenges I encounter
    - Discussions about best practices, code architecture, and software design patterns
    - And much more content that I hope will be valuable to fellow developers!

    ## My Background

    I've been working in software development for several years now, primarily focusing on web technologies. My experience spans from frontend frameworks like React and Vue to backend systems built with Node.js, Python, and more recently, Elixir and Phoenix LiveView.

    ## Why This Blog?

    The tech industry moves incredibly fast, and I've found that writing about what I learn helps me solidify my understanding while potentially helping others who might be facing similar challenges. This blog is my way of giving back to the community that has taught me so much.

    Thanks for visiting, and I hope you find the content useful and engaging. Feel free to reach out if you have any questions or suggestions for future topics!
    """,
    tags: "welcome, introduction",
    published_at: ~U[2025-06-25 10:00:00Z],
    user_id: user.id
  },
  %{
    title: "Building a Phoenix LiveView Blog",
    subtitle: "A deep dive into creating this blog with Phoenix, Svelte, and Tailwind CSS",
    content: """
    # Building a Phoenix LiveView Blog

    Today I want to share my experience building this blog using Phoenix LiveView, Svelte, and Tailwind CSS. This project has been an excellent learning experience and a chance to explore some cutting-edge web technologies.

    ## The Tech Stack

    After careful consideration, I chose this particular combination of technologies for several reasons:

    - **Phoenix LiveView**: For real-time, interactive web applications without the complexity of a separate frontend framework
    - **Svelte**: For enhanced client-side interactivity where needed, with minimal bundle size
    - **Tailwind CSS**: For rapid UI development and consistent design system
    - **PostgreSQL**: For reliable data storage with excellent Elixir integration

    ## Development Process

    The development process started with setting up the basic Phoenix application structure. I configured the database, set up authentication, and then built out the core features one by one.

    One of the most interesting challenges was integrating Svelte components with LiveView. While LiveView handles most of the interactivity beautifully, there are certain UI patterns where a client-side component framework provides a better user experience.

    ## Key Features Implemented

    - TOTP Two-Factor Authentication for secure admin access
    - Markdown content rendering with syntax highlighting for code blocks
    - Responsive design with a beautiful dark theme using Catppuccin colors
    - Infinite scroll homepage for smooth content browsing
    - Tag-based organization and filtering system
    - Full-text search capabilities for finding content quickly

    ## Performance Considerations

    Phoenix LiveView provides excellent performance out of the box, but there were several optimizations I implemented:

    - Efficient database queries with proper indexing
    - Image optimization and lazy loading
    - Careful management of LiveView state to avoid unnecessary re-renders
    - Strategic use of client-side components for intensive UI interactions

    The combination of these technologies provides a modern, efficient, and secure blogging platform that's both fun to develop and pleasant to use.
    """,
    tags: "phoenix, elixir, web-development",
    published_at: ~U[2025-06-26 14:30:00Z],
    user_id: user.id
  },
  %{
    title: "The Power of Elixir for Web Development",
    subtitle: "Why Elixir has become my go-to language for building web applications",
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
    subtitle:
      "A comprehensive guide to deploying Phoenix applications using modern hosting platforms",
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
