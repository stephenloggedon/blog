defmodule BlogWeb.TestSvelteLive do
  use BlogWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, message: "Hello from LiveView!")}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base p-6">
      <div class="max-w-4xl mx-auto">
        <h1 class="text-3xl font-bold text-text mb-6">Svelte Integration Test</h1>
        
        <div class="space-y-6">
          <div class="bg-surface0 p-6 rounded-lg border border-surface1">
            <h2 class="text-xl font-semibold text-text mb-4">LiveView Component</h2>
            <p class="text-subtext1">This is rendered by Phoenix LiveView.</p>
            <p class="text-text mt-2">Message: <%= @message %></p>
            <button phx-click="update_message" class="mt-4 bg-blue hover:bg-opacity-80 text-base px-4 py-2 rounded-lg">
              Update Message
            </button>
          </div>

          <div class="bg-surface0 p-6 rounded-lg border border-surface1">
            <h2 class="text-xl font-semibold text-text mb-4">Svelte Component Test</h2>
            <div
              phx-hook="SvelteHook"
              data-name="HelloWorld"
              data-props={Jason.encode!(%{name: "Phoenix LiveView"})}
              id="hello-world-component"
            >
              <!-- Svelte component will be mounted here -->
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("update_message", _params, socket) do
    new_message = "Updated at #{Time.utc_now() |> Time.to_string()}"
    {:noreply, assign(socket, message: new_message)}
  end
end