defmodule BlogWeb.UserSessionController do
  use BlogWeb, :controller

  alias Blog.Accounts
  alias BlogWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params
    totp_code = Map.get(user_params, "totp_code", "")

    if user = Accounts.get_user_by_email_and_password(email, password) do
      cond do
        # User has TOTP enabled but no code provided - show TOTP form
        user.totp_enabled and totp_code == "" ->
          conn
          |> put_session(:pending_user_id, user.id)
          |> render(:totp, error_message: nil)

        # User has TOTP enabled and code provided - verify it
        user.totp_enabled and totp_code != "" ->
          verify_totp_and_login(conn, user, totp_code, user_params)

        # User doesn't have TOTP enabled - login normally
        true ->
          conn
          |> put_flash(:info, "Welcome back!")
          |> UserAuth.log_in_user(user, user_params)
      end
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, :new, error_message: "Invalid email or password")
    end
  end

  def totp(conn, %{"user" => user_params}) do
    %{"totp_code" => totp_code, "backup_code" => backup_code} = user_params
    pending_user_id = get_session(conn, :pending_user_id)

    if pending_user_id do
      user = Accounts.get_user!(pending_user_id)
      
      cond do
        totp_code != "" and Blog.Accounts.User.valid_totp?(user, totp_code) ->
          complete_login(conn, user)

        backup_code != "" and Blog.Accounts.User.valid_backup_code?(user, backup_code) ->
          # Use the backup code and complete login
          {:ok, updated_user} = Accounts.update_user(user, Blog.Accounts.User.use_backup_code_changeset(user, backup_code))
          complete_login(conn, updated_user)

        true ->
          render(conn, :totp, error_message: "Invalid verification code")
      end
    else
      redirect(conn, to: ~p"/users/log_in")
    end
  end

  defp verify_totp_and_login(conn, user, totp_code, user_params) do
    if Blog.Accounts.User.valid_totp?(user, totp_code) do
      conn
      |> delete_session(:pending_user_id)
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, user_params)
    else
      conn
      |> put_session(:pending_user_id, user.id)
      |> render(:totp, error_message: "Invalid verification code")
    end
  end

  defp complete_login(conn, user) do
    conn
    |> delete_session(:pending_user_id)
    |> put_flash(:info, "Welcome back!")
    |> UserAuth.log_in_user(user, %{})
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
