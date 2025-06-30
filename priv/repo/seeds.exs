# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias Blog.Content

# Clear existing posts in development/test
if Mix.env() in [:dev, :test] do
  Blog.Repo.delete_all(Blog.Content.Post)
end

# Brief blog posts for testing
posts = [
  %{
    title: "Getting Started with Phoenix LiveView",
    subtitle: "Real-time web apps without JavaScript",
    content: "Phoenix LiveView enables rich, real-time user experiences with server-rendered HTML. Build interactive UIs with just Elixir.",
    tags: "elixir,phoenix,liveview",
    published_at: ~U[2024-01-15 10:00:00Z],
    slug: "getting-started-phoenix-liveview"
  },
  %{
    title: "Building Scalable Elixir Apps",
    subtitle: "OTP patterns for fault tolerance",
    content: "Use supervision trees and GenServers to build fault-tolerant systems. The actor model provides excellent concurrency.",
    tags: "elixir,otp,scalability",
    published_at: ~U[2024-02-01 14:30:00Z],
    slug: "building-scalable-elixir-apps"
  },
  %{
    title: "Ecto Query Optimization",
    subtitle: "Making database queries faster",
    content: "Use preloading to avoid N+1 queries. Select only needed fields and create proper database indexes.",
    tags: "elixir,ecto,database",
    published_at: ~U[2024-02-15 09:15:00Z],
    slug: "ecto-query-optimization"
  },
  %{
    title: "Testing Phoenix Applications",
    subtitle: "Comprehensive testing strategies",
    content: "Test controllers, LiveViews, and business logic. Use factories for test data and property-based testing.",
    tags: "elixir,phoenix,testing",
    published_at: ~U[2024-03-01 11:45:00Z],
    slug: "testing-phoenix-applications"
  },
  %{
    title: "Deploying Elixir to Production",
    subtitle: "From development to production",
    content: "Use Elixir releases for deployment. Configure environment variables and implement health checks.",
    tags: "elixir,deployment,devops",
    published_at: ~U[2024-03-15 16:20:00Z],
    slug: "deploying-elixir-production"
  },
  %{
    title: "Understanding Elixir Processes",
    subtitle: "Lightweight concurrent actors",
    content: "Processes are isolated, lightweight units. They communicate via message passing and can be monitored.",
    tags: "elixir,concurrency,processes",
    published_at: ~U[2024-04-01 13:10:00Z],
    slug: "understanding-elixir-processes"
  },
  %{
    title: "Pattern Matching in Elixir",
    subtitle: "Destructuring and control flow",
    content: "Pattern matching is powerful for destructuring data and controlling program flow elegantly.",
    tags: "elixir,pattern-matching,functional",
    published_at: ~U[2024-04-15 08:30:00Z],
    slug: "pattern-matching-elixir"
  },
  %{
    title: "Building REST APIs with Phoenix",
    subtitle: "JSON APIs made simple",
    content: "Phoenix makes REST APIs straightforward with routing, controllers, and JSON views.",
    tags: "elixir,phoenix,api,rest",
    published_at: ~U[2024-05-01 15:45:00Z],
    slug: "building-rest-apis-phoenix"
  },
  %{
    title: "GenServer Deep Dive",
    subtitle: "Stateful server processes",
    content: "GenServer provides standardized stateful processes. Handle calls, casts, and info messages.",
    tags: "elixir,genserver,otp",
    published_at: ~U[2024-05-15 12:20:00Z],
    slug: "genserver-deep-dive"
  },
  %{
    title: "Debugging Elixir Applications",
    subtitle: "Tools and techniques",
    content: "Use IEx, Logger, and Observer for debugging. Trace processes and measure performance.",
    tags: "elixir,debugging,tools",
    published_at: ~U[2024-06-01 10:00:00Z],
    slug: "debugging-elixir-applications"
  },
  %{
    title: "Elixir Streams and Lazy Evaluation",
    subtitle: "Processing large datasets efficiently",
    content: "Streams provide lazy, composable enumerables. Perfect for large datasets and infinite sequences.",
    tags: "elixir,streams,performance",
    published_at: ~U[2024-06-15 14:25:00Z],
    slug: "elixir-streams-lazy-evaluation"
  },
  %{
    title: "Phoenix LiveView Components",
    subtitle: "Reusable UI building blocks",
    content: "Create reusable components with LiveView. Manage state and handle events efficiently.",
    tags: "elixir,phoenix,liveview,components",
    published_at: ~U[2024-06-28 09:30:00Z],
    slug: "phoenix-liveview-components"
  }
]

# Insert the posts
Enum.each(posts, fn post_attrs ->
  case Content.create_post(post_attrs) do
    {:ok, post} ->
      IO.puts("Created post: #{post.title}")
    {:error, changeset} ->
      IO.puts("Failed to create post: #{inspect(changeset.errors)}")
  end
end)

IO.puts("Seeding completed with #{length(posts)} posts!")