defmodule Blog.Content.SeriesTest do
  use Blog.DataCase

  alias Blog.Content.Series

  describe "changeset/2" do
    test "valid changeset with all fields" do
      attrs = %{
        title: "Test Series",
        description: "A test series description",
        slug: "test-series"
      }

      changeset = Series.changeset(%Series{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :title) == "Test Series"
      assert get_field(changeset, :description) == "A test series description"
      assert get_field(changeset, :slug) == "test-series"
    end

    test "valid changeset with only required fields" do
      attrs = %{
        title: "Test Series",
        slug: "test-series"
      }

      changeset = Series.changeset(%Series{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :title) == "Test Series"
      assert get_field(changeset, :description) == nil
      assert get_field(changeset, :slug) == "test-series"
    end

    test "auto-generates slug from title when slug is empty" do
      attrs = %{
        title: "My Great Series",
        slug: ""
      }

      changeset = Series.changeset(%Series{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :slug) == "my-great-series"
    end

    test "auto-generates slug from title when slug is not provided" do
      attrs = %{
        title: "Another Great Series"
      }

      changeset = Series.changeset(%Series{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :slug) == "another-great-series"
    end

    test "slug generation handles special characters" do
      attrs = %{
        title: "Series with Special!@# Characters & More"
      }

      changeset = Series.changeset(%Series{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :slug) == "series-with-special-characters-more"
    end

    test "slug generation handles multiple spaces" do
      attrs = %{
        title: "Series    with     Multiple   Spaces"
      }

      changeset = Series.changeset(%Series{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :slug) == "series-with-multiple-spaces"
    end

    test "slug generation trims leading and trailing hyphens" do
      attrs = %{
        title: "   Series with Spaces   "
      }

      changeset = Series.changeset(%Series{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :slug) == "series-with-spaces"
    end

    test "preserves provided slug when given" do
      attrs = %{
        title: "Test Series",
        slug: "custom-slug"
      }

      changeset = Series.changeset(%Series{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :slug) == "custom-slug"
    end

    test "invalid changeset without title" do
      attrs = %{
        description: "A description without title"
      }

      changeset = Series.changeset(%Series{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).title
    end

    test "invalid changeset with empty title" do
      attrs = %{
        title: "",
        slug: "some-slug"
      }

      changeset = Series.changeset(%Series{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).title
    end

    test "invalid changeset with title too long" do
      attrs = %{
        # 256 characters, max is 255
        title: String.duplicate("a", 256),
        slug: "test-slug"
      }

      changeset = Series.changeset(%Series{}, attrs)
      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).title
    end

    test "invalid changeset with slug too long" do
      attrs = %{
        title: "Test Series",
        # 256 characters, max is 255
        slug: String.duplicate("a", 256)
      }

      changeset = Series.changeset(%Series{}, attrs)
      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).slug
    end

    test "updating existing series preserves existing slug if not provided" do
      existing_series = %Series{
        title: "Old Title",
        slug: "old-slug",
        description: "Old description"
      }

      attrs = %{
        title: "New Title",
        description: "New description"
      }

      changeset = Series.changeset(existing_series, attrs)
      assert changeset.valid?
      assert get_field(changeset, :title) == "New Title"
      assert get_field(changeset, :description) == "New description"
      # Should preserve existing slug
      assert get_field(changeset, :slug) == "old-slug"
    end

    test "updating existing series can override slug" do
      existing_series = %Series{
        title: "Old Title",
        slug: "old-slug",
        description: "Old description"
      }

      attrs = %{
        title: "New Title",
        slug: "new-slug"
      }

      changeset = Series.changeset(existing_series, attrs)
      assert changeset.valid?
      assert get_field(changeset, :slug) == "new-slug"
    end

    test "slug generation works with unicode characters" do
      attrs = %{
        title: "Série with Ümlauts and Çharacters"
      }

      changeset = Series.changeset(%Series{}, attrs)
      assert changeset.valid?
      # Unicode characters should be removed, leaving only ASCII
      assert get_field(changeset, :slug) == "srie-with-mlauts-and-haracters"
    end

    test "slug generation handles numbers" do
      attrs = %{
        title: "Series 123 with Numbers 456"
      }

      changeset = Series.changeset(%Series{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :slug) == "series-123-with-numbers-456"
    end

    test "slug generation handles single character title" do
      attrs = %{
        title: "A"
      }

      changeset = Series.changeset(%Series{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :slug) == "a"
    end

    test "unique constraint on slug" do
      # This test would require database interaction and should be in the Content context test
      # Just verify the changeset has the constraint
      changeset = Series.changeset(%Series{}, %{title: "Test", slug: "test"})

      assert changeset.constraints
             |> Enum.any?(fn c -> c.field == :slug and c.type == :unique end)
    end
  end
end
