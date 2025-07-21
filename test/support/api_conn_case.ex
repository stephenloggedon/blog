defmodule BlogWeb.ApiConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection to the API endpoint.

  This case is specifically for testing the mTLS-protected API endpoints
  that run on the separate BlogWeb.ApiEndpoint.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Use the API endpoint for testing
      @endpoint BlogWeb.ApiEndpoint

      use BlogWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import BlogWeb.ConnCase
    end
  end

  setup tags do
    Blog.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
