defmodule Blog.Repo.Migrations.AddTotpToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :totp_secret, :string
      add :totp_enabled, :boolean, default: false
      add :backup_codes, {:array, :string}, default: []
    end
  end
end
