defmodule Blog.Repo.Migrations.FixDevlogLinksSimple do
  use Ecto.Migration

  def up do
    # Use individual UPDATE statements instead of nested REPLACE functions
    # This is more reliable and easier to debug
    execute(
      "UPDATE posts SET content = REPLACE(content, '](/02_blog_development)', '](/blog/building-a-blog-with-claude-4-an-ai-development-adventure)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/03_blog_development)', '](/blog/the-art-of-polish-when-ai-meets-human-ux-intuition)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/04_blog_development)', '](/blog/when-ai-debugging-meets-real-world-chaos-building-search-that-actually-works)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/05_blog_development)', '](/blog/the-deployment-odyssey-when-ai-promises-meet-platform-reality)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/06_blog_development)', '](/blog/securing-the-recursive-loop-when-ai-builds-mtls-authentication-for-its-own-blog)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/07_blog_development)', '](/blog/the-database-evolution-when-ai-discovers-the-magic-of-distributed-sqlite)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/08_blog_development)', '](/blog/the-dual-endpoint-discovery-when-architecture-decisions-hide-in-production-failures)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/09_blog_development)', '](/blog/the-mobile-revolution-when-ai-discovers-the-power-of-touch-interfaces)')"
    )
  end

  def down do
    # Reverse the changes if needed
    execute(
      "UPDATE posts SET content = REPLACE(content, '](/blog/building-a-blog-with-claude-4-an-ai-development-adventure)', '](/02_blog_development)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/blog/the-art-of-polish-when-ai-meets-human-ux-intuition)', '](/03_blog_development)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/blog/when-ai-debugging-meets-real-world-chaos-building-search-that-actually-works)', '](/04_blog_development)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/blog/the-deployment-odyssey-when-ai-promises-meet-platform-reality)', '](/05_blog_development)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/blog/securing-the-recursive-loop-when-ai-builds-mtls-authentication-for-its-own-blog)', '](/06_blog_development)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/blog/the-database-evolution-when-ai-discovers-the-magic-of-distributed-sqlite)', '](/07_blog_development)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/blog/the-dual-endpoint-discovery-when-architecture-decisions-hide-in-production-failures)', '](/08_blog_development)')"
    )

    execute(
      "UPDATE posts SET content = REPLACE(content, '](/blog/the-mobile-revolution-when-ai-discovers-the-power-of-touch-interfaces)', '](/09_blog_development)')"
    )
  end
end
