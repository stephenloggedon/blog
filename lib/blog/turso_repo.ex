defmodule Blog.TursoRepo do
  @moduledoc """
  Turso/libSQL repository for distributed SQLite operations.
  
  This module provides an interface to Turso's distributed SQLite service
  using a custom HTTP client that supports BLOB data properly.
  """
  
  require Logger
  alias Blog.TursoHttpClient
  
  @doc """
  Child specification for supervisor.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
  
  @doc """
  Starts the Turso repository process.
  This is mainly for supervisor compatibility - the HTTP client is stateless.
  """
  def start_link(_opts \\ []) do
    Logger.info("Starting Turso HTTP client (stateless)")
    # Start a simple GenServer to satisfy supervisor requirements
    # Don't test connection during startup to avoid Finch dependency issues
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  @doc """
  Executes a query against the Turso database.
  """
  def query(sql, params \\ []) do
    TursoHttpClient.execute(sql, params)
  end
  
  @doc """
  Executes a query and returns the first result.
  """
  def query_one(sql, params \\ []) do
    TursoHttpClient.query_one(sql, params)
  end
  
  @doc """
  Runs multiple statements in a transaction.
  """
  def transaction(statements) when is_list(statements) do
    TursoHttpClient.transaction(statements)
  end
  
  def transaction(fun) when is_function(fun) do
    # This is a simplified implementation - for complex transactions,
    # collect the statements and use the HTTP transaction API
    try do
      result = fun.()
      {:ok, result}
    catch
      :throw, {:rollback, reason} -> {:error, reason}
      error -> {:error, error}
    end
  end
  
  @doc """
  Tests the connection to Turso.
  """
  def test_connection do
    case TursoHttpClient.execute("SELECT 1 as test") do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  # GenServer implementation for supervisor compatibility
  @behaviour GenServer
  
  @impl true
  def init(state) do
    {:ok, state}
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