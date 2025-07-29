defmodule Blog.TursoEctoServer do
  @moduledoc """
  A simple GenServer to act as the TursoEctoRepo process.

  Since we're using HTTP calls, we don't need persistent connections,
  but Ecto expects a GenServer that can be started and stopped.
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(_request, state) do
    {:noreply, state}
  end
end
