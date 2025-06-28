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
    # Create a user if one isn't provided
    user = Map.get(attrs, :user) || Blog.AccountsFixtures.user_fixture()

    {:ok, post} =
      attrs
      |> Enum.into(%{
        content: "some content",
        excerpt: "some excerpt",
        published: true,
        slug: unique_post_slug(),
        tags: "some tags",
        title: "some title",
        user_id: user.id
      })
      |> Blog.Content.create_post()

    post
  end
end
