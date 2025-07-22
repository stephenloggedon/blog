defmodule Blog.Repo.Migrations.FixDevlogInternalLinks do
  use Ecto.Migration
  import Ecto.Query
  alias Blog.Content.Post

  def up do
    # Get all posts and manually check for devlog link patterns
    query = from(p in "posts", select: %{id: p.id, content: p.content})

    posts = Blog.Repo.all(query)

    Enum.each(posts, fn post ->
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
        from(p in "posts", where: p.id == ^post.id)
        |> Blog.Repo.update_all(set: [content: updated_content])

        IO.puts("Fixed internal links in post #{post.id}")
      end
    end)
  end

  def down do
    # Reverse the changes if needed
    :ok
  end
end
