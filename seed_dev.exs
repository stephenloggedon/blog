# Seed the development Turso database with test posts
IO.puts("=== Seeding development database ===")

# Create test posts
posts_to_create = [
  %{
    title: "Test Post 1",
    content: "This is the first test post content.",
    published: true,
    published_at: DateTime.utc_now() |> DateTime.add(-3, :day),
    tags: "elixir, phoenix"
  },
  %{
    title: "Test Post 2", 
    content: "This is the second test post content.",
    published: true,
    published_at: DateTime.utc_now() |> DateTime.add(-2, :day),
    tags: "web-development, testing"
  },
  %{
    title: "Test Post 3",
    content: "This is the third test post content.",
    published: true,
    published_at: DateTime.utc_now() |> DateTime.add(-1, :day),
    tags: "turso, database"
  }
]

Enum.each(posts_to_create, fn post_attrs ->
  case Blog.Content.create_post(post_attrs) do
    {:ok, post} -> 
      IO.puts("Created post: #{post.title}")
    {:error, changeset} -> 
      IO.puts("Failed to create post: #{inspect(changeset.errors)}")
  end
end)

IO.puts("=== Seeding completed ===")