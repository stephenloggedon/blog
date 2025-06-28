defmodule BlogWeb.UserTotpLive do
  use BlogWeb, :live_view

  alias Blog.Accounts
  alias Blog.Accounts.User

  def mount(_params, session, socket) do
    user = Accounts.get_user_by_session_token(session["user_token"])
    
    if user do
      {:ok, assign(socket, user: user, step: :setup)}
    else
      {:ok, redirect(socket, to: ~p"/users/log_in")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base">
      <div class="max-w-md mx-auto p-6">
        <h1 class="text-2xl font-bold text-text mb-6">Two-Factor Authentication</h1>
        
        <%= if @user.totp_enabled do %>
          <div class="bg-surface0 rounded-lg p-6 border border-surface1">
            <h2 class="text-lg font-semibold text-green mb-4">✓ TOTP is enabled</h2>
            <p class="text-subtext1 mb-4">Your account is protected with two-factor authentication.</p>
            
            <div class="space-y-4">
              <button 
                phx-click="show_backup_codes" 
                class="w-full bg-surface1 hover:bg-surface2 text-text py-2 px-4 rounded-lg transition-colors"
              >
                View Backup Codes
              </button>
              
              <button 
                phx-click="disable_totp" 
                data-confirm="Are you sure you want to disable two-factor authentication?" 
                class="w-full bg-red hover:bg-opacity-80 text-base py-2 px-4 rounded-lg transition-colors"
              >
                Disable TOTP
              </button>
            </div>
            
            <%= if assigns[:show_backup_codes] do %>
              <div class="mt-6 p-4 bg-crust rounded-lg">
                <h3 class="font-semibold text-text mb-2">Backup Codes</h3>
                <p class="text-subtext1 text-sm mb-3">Save these codes in a safe place. You can use them to access your account if you lose your authenticator device.</p>
                <div class="grid grid-cols-2 gap-2 font-mono text-sm">
                  <%= for code <- @user.backup_codes do %>
                    <div class="bg-surface0 p-2 rounded text-center text-text"><%= code %></div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <%= if @step == :setup do %>
            <div class="bg-surface0 rounded-lg p-6 border border-surface1">
              <h2 class="text-lg font-semibold text-text mb-4">Set up Two-Factor Authentication</h2>
              <p class="text-subtext1 mb-4">Scan this QR code with your authenticator app:</p>
              
              <div class="bg-white p-4 rounded-lg mb-4 flex justify-center">
                <%= if assigns[:qr_code_svg] do %>
                  <%= Phoenix.HTML.raw(@qr_code_svg) %>
                <% end %>
              </div>
              
              <p class="text-subtext1 text-sm mb-4">
                Or enter this secret manually: 
                <code class="bg-crust px-2 py-1 rounded text-text font-mono"><%= @totp_secret %></code>
              </p>
              
              <button 
                phx-click="proceed_to_verify" 
                class="w-full bg-blue hover:bg-opacity-80 text-base py-2 px-4 rounded-lg transition-colors"
              >
                I've added the account
              </button>
            </div>
          <% end %>
          
          <%= if @step == :verify do %>
            <div class="bg-surface0 rounded-lg p-6 border border-surface1">
              <h2 class="text-lg font-semibold text-text mb-4">Verify Setup</h2>
              <p class="text-subtext1 mb-4">Enter the 6-digit code from your authenticator app:</p>
              
              <form phx-submit="verify_totp" class="space-y-4">
                <input 
                  type="text" 
                  name="totp_code" 
                  placeholder="000000" 
                  class="w-full bg-surface1 border border-surface2 rounded-lg px-3 py-2 text-text placeholder-subtext0 focus:ring-2 focus:ring-blue focus:border-transparent"
                  maxlength="6"
                  pattern="[0-9]{6}"
                  required
                />
                
                <%= if assigns[:error] do %>
                  <div class="text-red text-sm"><%= @error %></div>
                <% end %>
                
                <div class="flex space-x-3">
                  <button 
                    type="submit" 
                    class="flex-1 bg-green hover:bg-opacity-80 text-base py-2 px-4 rounded-lg transition-colors"
                  >
                    Verify & Enable
                  </button>
                  
                  <button 
                    type="button" 
                    phx-click="back_to_setup" 
                    class="flex-1 bg-surface1 hover:bg-surface2 text-text py-2 px-4 rounded-lg transition-colors"
                  >
                    Back
                  </button>
                </div>
              </form>
            </div>
          <% end %>
        <% end %>
        
        <div class="mt-6">
          <.link navigate={~p"/users/settings"} class="text-blue hover:text-sapphire">
            ← Back to Settings
          </.link>
        </div>
      </div>
    </div>
    
    """
  end

  def handle_event("proceed_to_verify", _params, socket) do
    {:noreply, assign(socket, step: :verify)}
  end

  def handle_event("back_to_setup", _params, socket) do
    {:noreply, assign(socket, step: :setup, error: nil)}
  end

  def handle_event("verify_totp", %{"totp_code" => code}, socket) do
    user = socket.assigns.user
    
    if User.valid_totp?(user, code) do
      case Accounts.update_user(user, User.enable_totp_changeset(user, socket.assigns.totp_secret)) do
        {:ok, updated_user} ->
          {:noreply, 
           socket 
           |> assign(user: updated_user)
           |> put_flash(:info, "Two-factor authentication has been enabled successfully!")
           |> push_navigate(to: ~p"/users/settings")
          }
          
        {:error, _changeset} ->
          {:noreply, assign(socket, error: "Failed to enable TOTP. Please try again.")}
      end
    else
      {:noreply, assign(socket, error: "Invalid code. Please try again.")}
    end
  end

  def handle_event("disable_totp", _params, socket) do
    user = socket.assigns.user
    
    case Accounts.update_user(user, User.disable_totp_changeset(user)) do
      {:ok, updated_user} ->
        {:noreply, 
         socket 
         |> assign(user: updated_user)
         |> put_flash(:info, "Two-factor authentication has been disabled.")
        }
        
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to disable TOTP. Please try again.")}
    end
  end

  def handle_event("show_backup_codes", _params, socket) do
    {:noreply, assign(socket, show_backup_codes: true)}
  end

  defp setup_totp(socket) do
    secret = User.generate_totp_secret()
    user = %{socket.assigns.user | totp_secret: secret}
    uri = User.totp_provisioning_uri(user)
    
    # Generate QR code as SVG
    qr_code_svg = case QRCode.create(uri) do
      {:ok, qr_code} ->
        qr_code
        |> QRCode.render(:svg)
        |> elem(1)
      {:error, _} -> 
        ""
    end
    
    socket
    |> assign(totp_secret: secret, totp_uri: uri, qr_code_svg: qr_code_svg)
  end

  def handle_params(_params, _url, socket) do
    if socket.assigns.user.totp_enabled do
      {:noreply, socket}
    else
      {:noreply, setup_totp(socket)}
    end
  end
end