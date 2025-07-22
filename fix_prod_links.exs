# Script to fix internal links in production posts
posts = Blog.Repo.all(Blog.Content.Post)
IO.puts("Found #{length(posts)} total posts")

posts_with_old_links =
  Enum.filter(posts, fn post ->
    String.contains?(post.content, "](/0") ||
      String.contains?(post.content, "](/blog_development")
  end)

IO.puts("Found #{length(posts_with_old_links)} posts with old internal links")

Enum.each(posts_with_old_links, fn post ->
  updated_content =
    post.content
    |> String.replace(
      "](/02_blog_development)",
      "](/blog/building-a-blog-with-claude-4-an-ai-development-adventure)"
    )
    |> String.replace(
      "](/03_blog_development)",
      "](/blog/the-art-of-polish-when-ai-meets-human-ux-intuition)"
    )
    |> String.replace(
      "](/04_blog_development)",
      "](/blog/when-ai-debugging-meets-real-world-chaos-building-search-that-actually-works)"
    )
    |> String.replace(
      "](/05_blog_development)",
      "](/blog/the-deployment-odyssey-when-ai-promises-meet-platform-reality)"
    )
    |> String.replace(
      "](/06_blog_development)",
      "](/blog/securing-the-recursive-loop-when-ai-builds-mtls-authentication-for-its-own-blog)"
    )
    |> String.replace(
      "](/07_blog_development)",
      "](/blog/the-database-evolution-when-ai-discovers-the-magic-of-distributed-sqlite)"
    )
    |> String.replace(
      "](/08_blog_development)",
      "](/blog/the-dual-endpoint-discovery-when-architecture-decisions-hide-in-production-failures)"
    )
    |> String.replace(
      "](/09_blog_development)",
      "](/blog/the-mobile-revolution-when-ai-discovers-the-power-of-touch-interfaces)"
    )

  if updated_content != post.content do
    Blog.Repo.update!(Ecto.Changeset.change(post, %{content: updated_content}))
    IO.puts("Updated post: #{post.title}")
  end
end)

IO.puts("Link fixing completed!")
