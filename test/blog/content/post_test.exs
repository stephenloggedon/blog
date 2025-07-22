defmodule Blog.Content.PostTest do
  use Blog.DataCase
  alias Blog.Content.Post

  describe "convert_internal_links/1" do
    test "converts internal file links to blog URLs" do
      content = "Check out my [previous post](/some_blog_post) for more info."
      result = Post.convert_internal_links(content)
      assert result == "Check out my [previous post](/blog/some-blog-post) for more info."
    end

    test "converts markdown file links to blog URLs" do
      content = "See [this guide](./getting_started.md) for details."
      result = Post.convert_internal_links(content)
      assert result == "See [this guide](/blog/getting-started) for details."
    end

    test "preserves external links" do
      content = "Visit [Google](https://google.com) for search."
      result = Post.convert_internal_links(content)
      assert result == "Visit [Google](https://google.com) for search."
    end

    test "preserves image links" do
      content = "Here's an image: ![test](/images/1)"
      result = Post.convert_internal_links(content)
      assert result == "Here's an image: ![test](/images/1)"
    end

    test "handles multiple links in same content" do
      content =
        "Read [part 1](/blog_part_1) and [part 2](./blog_part_2.md) but not [external](https://example.com)."

      result = Post.convert_internal_links(content)

      expected =
        "Read [part 1](/blog/blog-part-1) and [part 2](/blog/blog-part-2) but not [external](https://example.com)."

      assert result == expected
    end
  end

  describe "generate_slug_from_filename/1" do
    test "removes numbered prefixes and converts underscores" do
      assert Post.generate_slug_from_filename("02_blog_development") == "blog-development"
      assert Post.generate_slug_from_filename("some_file_name") == "some-file-name"
    end

    test "handles files without prefixes" do
      assert Post.generate_slug_from_filename("simple_filename") == "simple-filename"
    end
  end
end
