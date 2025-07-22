defmodule Blog.Repo.Migrations.FixInternalLinksInPosts do
  use Ecto.Migration
  import Ecto.Query
  alias Blog.Content.Post

  def up do
    # Get all posts that might have internal links (including old /posts/ prefix)
    query =
      from(p in "posts",
        where:
          like(p.content, "%](/%") or like(p.content, "%](./%") or like(p.content, "%](/posts/%"),
        select: %{id: p.id, content: p.content}
      )

    posts_with_links = Blog.Repo.all(query)

    Enum.each(posts_with_links, fn post ->
      # First convert any old /posts/ prefix to the correct /blog/ prefix
      intermediate_content = String.replace(post.content, "](/posts/", "](/blog/")

      # Then apply the standard internal link conversion
      converted_content = Post.convert_internal_links(intermediate_content)

      if converted_content != post.content do
        from(p in "posts", where: p.id == ^post.id)
        |> Blog.Repo.update_all(set: [content: converted_content])

        IO.puts("Updated post #{post.id} - converted internal links")
      end
    end)
  end

  def down do
    # This migration is not easily reversible since we don't know the original link format
    # If needed, restore from backup
    :ok
  end
end
