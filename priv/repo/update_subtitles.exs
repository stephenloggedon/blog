alias Blog.{Repo, Content}
alias Blog.Content.Post
import Ecto.Query

# Update existing posts with subtitles
post_updates = [
  %{title: "Welcome to My Blog", subtitle: "My first blog post and introduction to what you can expect here"},
  %{title: "Building a Phoenix LiveView Blog", subtitle: "A deep dive into creating this blog with Phoenix, Svelte, and Tailwind CSS"},
  %{title: "The Power of Elixir for Web Development", subtitle: "Why Elixir has become my go-to language for building web applications"},
  %{title: "Deploying Phoenix Apps to Production", subtitle: "A comprehensive guide to deploying Phoenix applications using modern hosting platforms"}
]

Enum.each(post_updates, fn %{title: title, subtitle: subtitle} ->
  case Repo.one(from p in Post, where: p.title == ^title) do
    nil -> 
      IO.puts("Post not found: #{title}")
    post ->
      case Content.update_post(post, %{subtitle: subtitle}) do
        {:ok, _updated_post} ->
          IO.puts("Updated subtitle for: #{title}")
        {:error, changeset} ->
          IO.puts("Failed to update #{title}: #{inspect(changeset.errors)}")
      end
  end
end)

IO.puts("Subtitle updates completed!")