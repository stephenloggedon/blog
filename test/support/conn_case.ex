defmodule BlogWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  This module also provides helper functions for testing mTLS (mutual TLS)
  authentication by mocking client certificates using `Plug.Test.put_peer_data/2`.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use BlogWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint BlogWeb.Endpoint

      use BlogWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import BlogWeb.ConnCase
    end
  end

  setup tags do
    import Plug.Conn
    Blog.DataCase.setup_sandbox(tags)

    conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("user-agent", "BlogWeb.Test/1.0 (Elixir Phoenix Test Suite)")

    {:ok, conn: conn}
  end

  def register_and_log_in_user(_conn) do
    # No user authentication needed for this project
    :ok
  end

  def log_in_user(conn, _user) do
    # No user authentication needed for this project
    conn
  end

  @doc """
  Adds mocked client certificate data to the connection for testing mTLS authentication.

  This function uses Plug.Test.put_peer_data/2 to simulate an SSL client certificate
  in the connection's peer data, allowing tests to verify certificate authentication
  without requiring actual HTTPS connections.
  """
  def with_client_cert(conn, cert_options \\ []) do
    cert_data = Keyword.get(cert_options, :cert_data, load_real_test_certificate())
    address = Keyword.get(cert_options, :address, {127, 0, 0, 1})
    port = Keyword.get(cert_options, :port, 443)

    peer_data = %{
      address: address,
      port: port,
      ssl_cert: cert_data
    }

    Plug.Test.put_peer_data(conn, peer_data)
  end

  @doc """
  Adds invalid client certificate data to test rejection scenarios.

  Uses a self-signed certificate that is not signed by the trusted CA,
  which should be rejected by the authentication system.
  """
  def with_invalid_client_cert(conn) do
    # Use an invalid certificate for testing rejection
    invalid_cert_data = load_invalid_test_certificate()

    peer_data = %{
      address: {127, 0, 0, 1},
      port: 443,
      ssl_cert: invalid_cert_data
    }

    Plug.Test.put_peer_data(conn, peer_data)
  end

  @doc """
  Returns a connection without any client certificate (no peer data).

  This simulates a client that doesn't provide a certificate,
  which should be rejected by endpoints requiring mTLS authentication.
  """
  def without_client_cert(conn) do
    # Don't set any peer data to simulate missing client certificate
    conn
  end

  # Private helper functions for certificate mocking

  defp load_invalid_test_certificate do
    # Use the pre-generated invalid certificate (self-signed, not signed by our CA)
    cert_path = "priv/cert/clients/invalid-cert.pem"

    case File.read(cert_path) do
      {:ok, pem_data} ->
        try do
          [{:Certificate, cert_der, :not_encrypted}] = :public_key.pem_decode(pem_data)
          cert_der
        rescue
          error ->
            reraise "Failed to decode invalid test certificate: #{inspect(error)}", __STACKTRACE__
        end

      {:error, reason} ->
        raise "Failed to read invalid test certificate at #{cert_path}: #{inspect(reason)}"
    end
  end

  defp load_real_test_certificate do
    # Use the test auth certificate that's properly signed by our CA
    cert_path = "priv/cert/clients/test-auth-cert.pem"

    case File.read(cert_path) do
      {:ok, pem_data} ->
        try do
          [{:Certificate, cert_der, :not_encrypted}] = :public_key.pem_decode(pem_data)
          cert_der
        rescue
          error ->
            reraise "Failed to decode test certificate: #{inspect(error)}", __STACKTRACE__
        end

      {:error, reason} ->
        raise "Failed to read test certificate at #{cert_path}: #{inspect(reason)}"
    end
  end
end
