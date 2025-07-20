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

# Posts with images
posts_with_images = [
  %{
    title: "Elixir Performance Monitoring",
    subtitle: "Tracking your application metrics",
    content: """
    Performance monitoring is crucial for production Elixir applications. 
    
    ![Performance Dashboard](data:image/svg+xml,%3Csvg width='400' height='200' xmlns='http://www.w3.org/2000/svg'%3E%3Crect width='100%25' height='100%25' fill='%23f0f0f0'/%3E%3Ctext x='50%25' y='50%25' font-family='Arial,sans-serif' font-size='16' fill='%23333' text-anchor='middle' dy='.3em'%3EPerformance Dashboard%3C/text%3E%3Ccircle cx='50' cy='150' r='20' fill='%234CAF50'/%3E%3Ccircle cx='150' cy='100' r='25' fill='%2345AFFD'/%3E%3Ccircle cx='250' cy='70' r='30' fill='%2345AFFD'/%3E%3Ccircle cx='350' cy='40' r='35' fill='%2345AFFD'/%3E%3C/svg%3E)
    
    Use telemetry and metrics libraries to track response times, memory usage, and error rates.
    """,
    tags: "elixir,monitoring,telemetry,performance",
    published_at: ~U[2024-07-01 09:00:00Z],
    slug: "elixir-performance-monitoring"
  },
  %{
    title: "Building Reactive UIs with LiveView",
    subtitle: "Real-time interfaces that respond instantly",
    content: """
    Phoenix LiveView enables building highly interactive web applications without writing JavaScript.
    
    ![LiveView Architecture](data:image/svg+xml,%3Csvg width='400' height='250' xmlns='http://www.w3.org/2000/svg'%3E%3Crect width='100%25' height='100%25' fill='%23fff' stroke='%23ddd'/%3E%3Crect x='20' y='20' width='100' height='60' fill='%23FF6347' rx='5'/%3E%3Ctext x='70' y='55' font-family='Arial,sans-serif' font-size='12' fill='white' text-anchor='middle'%3EBrowser%3C/text%3E%3Crect x='280' y='20' width='100' height='60' fill='%234CAF50' rx='5'/%3E%3Ctext x='330' y='55' font-family='Arial,sans-serif' font-size='12' fill='white' text-anchor='middle'%3EServer%3C/text%3E%3Cline x1='120' y1='50' x2='280' y2='50' stroke='%23666' stroke-width='2' marker-end='url(%23arrow)'/%3E%3Cdefs%3E%3Cmarker id='arrow' markerWidth='10' markerHeight='10' refX='9' refY='3' orient='auto' markerUnits='strokeWidth'%3E%3Cpath d='M0,0 L0,6 L9,3 z' fill='%23666'/%3E%3C/marker%3E%3C/defs%3E%3Ctext x='200' y='40' font-family='Arial,sans-serif' font-size='10' fill='%23666' text-anchor='middle'%3EWebSocket%3C/text%3E%3Ctext x='200' y='120' font-family='Arial,sans-serif' font-size='14' fill='%23333' text-anchor='middle'%3ELiveView Architecture%3C/text%3E%3Ctext x='200' y='140' font-family='Arial,sans-serif' font-size='10' fill='%23666' text-anchor='middle'%3EReal-time updates via Diff %26 Patch%3C/text%3E%3C/svg%3E)
    
    The server sends HTML diffs over WebSocket connections, keeping the UI synchronized with server state.
    """,
    tags: "elixir,phoenix,liveview,websocket",
    published_at: ~U[2024-07-15 14:30:00Z],
    slug: "building-reactive-uis-liveview"
  },
  %{
    title: "Distributed Systems with Elixir",
    subtitle: "Building fault-tolerant clusters",
    content: """
    Elixir's distribution capabilities enable building resilient, scalable systems across multiple nodes.
    
    ![Distributed Architecture](data:image/svg+xml,%3Csvg width='400' height='300' xmlns='http://www.w3.org/2000/svg'%3E%3Crect width='100%25' height='100%25' fill='%23f9f9f9' stroke='%23eee'/%3E%3Ccircle cx='100' cy='80' r='40' fill='%234CAF50' stroke='%23337' stroke-width='2'/%3E%3Ctext x='100' y='85' font-family='Arial,sans-serif' font-size='12' fill='white' text-anchor='middle'%3ENode 1%3C/text%3E%3Ccircle cx='300' cy='80' r='40' fill='%2345AFFD' stroke='%23337' stroke-width='2'/%3E%3Ctext x='300' y='85' font-family='Arial,sans-serif' font-size='12' fill='white' text-anchor='middle'%3ENode 2%3C/text%3E%3Ccircle cx='200' cy='200' r='40' fill='%2345AFFD' stroke='%23337' stroke-width='2'/%3E%3Ctext x='200' y='205' font-family='Arial,sans-serif' font-size='12' fill='white' text-anchor='middle'%3ENode 3%3C/text%3E%3Cline x1='135' y1='90' x2='265' y2='90' stroke='%23666' stroke-width='2'/%3E%3Cline x1='125' y1='115' x2='175' y2='175' stroke='%23666' stroke-width='2'/%3E%3Cline x1='275' y1='115' x2='225' y2='175' stroke='%23666' stroke-width='2'/%3E%3Ctext x='200' y='30' font-family='Arial,sans-serif' font-size='16' fill='%23333' text-anchor='middle'%3EElixir Cluster%3C/text%3E%3Ctext x='200' y='48' font-family='Arial,sans-serif' font-size='10' fill='%23666' text-anchor='middle'%3EFault-tolerant distributed system%3C/text%3E%3C/svg%3E)
    
    Use OTP supervision trees and distributed Erlang to create systems that self-heal and scale horizontally.
    """,
    tags: "elixir,distributed,otp,clustering",
    published_at: ~U[2024-07-20 11:15:00Z],
    slug: "distributed-systems-elixir"
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

# Insert posts with images
Enum.each(posts_with_images, fn post_attrs ->
  case Content.create_post(post_attrs) do
    {:ok, post} ->
      IO.puts("Created post with images: #{post.title}")
    {:error, changeset} ->
      IO.puts("Failed to create post: #{inspect(changeset.errors)}")
  end
end)

total_posts = length(posts) + length(posts_with_images)
IO.puts("Seeding completed with #{total_posts} posts (#{length(posts_with_images)} with images)!")