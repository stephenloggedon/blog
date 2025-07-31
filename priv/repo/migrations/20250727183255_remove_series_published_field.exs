defmodule Blog.Repo.Migrations.RemoveSeriesPublishedField do
  use Ecto.Migration

  def change do
    # SQLite doesn't support DROP COLUMN directly, but we can check if column exists
    # and handle the error gracefully if it doesn't exist

    try do
      alter table(:series) do
        remove :published
      end
    rescue
      # If the column doesn't exist, the migration should succeed silently
      # This handles cases where the series table was created without the published column
      error ->
        if String.contains?(Exception.message(error), "no such column") do
          :ok
        else
          reraise error, __STACKTRACE__
        end
    end
  end
end
