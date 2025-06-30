defmodule Blog.ContentFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Blog.Content` context.
  """

  @doc """
  Generate a unique post slug.
  """
  def unique_post_slug, do: "some slug#{System.unique_integer([:positive])}"

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}) do
    {:ok, post} =
      attrs
      |> Enum.into(%{
        content: "some content",
        excerpt: "some excerpt",
        published: true,
        slug: unique_post_slug(),
        tags: "some tags",
        title: "some title"
      })
      |> Blog.Content.create_post()

    post
  end
end
