defmodule BlogWeb.Plugs.ClientCertAuth do
  @moduledoc """
  Plug for authenticating API requests using client certificates (mTLS).
  
  This plug validates that the client has presented a valid certificate
  signed by our trusted Certificate Authority.
  """
  
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  
  require Logger
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    # In test environment, allow bypassing certificate authentication
    if Application.get_env(:blog, :env) == :test do
      # Check for test authentication header
      case get_req_header(conn, "test-client-cert") do
        ["valid"] ->
          Logger.info("Test client certificate authentication successful")
          assign(conn, :client_cert, :test_cert)
        
        _ ->
          Logger.warning("Test client certificate not found")
          send_unauthorized(conn, "Client certificate required")
      end
    else
      # Production/development mTLS authentication
      case get_client_certificate(conn) do
        {:ok, cert} ->
          case validate_certificate(cert) do
            :ok ->
              Logger.info("Client certificate authentication successful for #{cert_subject(cert)}")
              assign(conn, :client_cert, cert)
            
            {:error, reason} ->
              Logger.warning("Client certificate validation failed: #{reason}")
              send_unauthorized(conn, "Invalid client certificate: #{reason}")
          end
        
        {:error, reason} ->
          Logger.warning("Client certificate not found or invalid: #{reason}")
          send_unauthorized(conn, "Client certificate required")
      end
    end
  end
  
  # Extract the client certificate from the SSL connection
  defp get_client_certificate(conn) do
    # For Cowboy adapter, get the peer certificate from the SSL socket
    case conn.adapter do
      {Plug.Cowboy.Conn, cowboy_req} ->
        get_peer_cert_from_cowboy(cowboy_req)
      
      _ ->
        {:error, "mTLS authentication requires Cowboy adapter"}
    end
  end
  
  # Get peer certificate from Cowboy request
  defp get_peer_cert_from_cowboy(cowboy_req) do
    try do
      # Try to get SSL info from the connection
      case :cowboy_req.peer(cowboy_req) do
        {{_ip, _port}, _opts} ->
          # Try to access the peer certificate from SSL connection info
          case Map.get(cowboy_req, :cert, :undefined) do
            :undefined ->
              {:error, "No client certificate presented"}
            
            cert_der when is_binary(cert_der) ->
              decode_certificate(cert_der)
            
            _ ->
              {:error, "Invalid certificate format"}
          end
        
        _ ->
          {:error, "Not an SSL connection"}
      end
    rescue
      error ->
        {:error, "Failed to access peer certificate: #{inspect(error)}"}
    end
  end
  
  # Decode the certificate from DER format
  defp decode_certificate(cert_der) do
    try do
      cert = :public_key.pkix_decode_cert(cert_der, :otp)
      {:ok, cert}
    rescue
      error ->
        {:error, "Failed to decode certificate: #{inspect(error)}"}
    end
  end
  
  # Validate the client certificate against our CA
  defp validate_certificate(cert) do
    with {:ok, ca_cert} <- load_ca_certificate(),
         :ok <- verify_certificate_chain(cert, ca_cert),
         :ok <- check_certificate_validity(cert) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  # Load our Certificate Authority certificate
  defp load_ca_certificate do
    ca_cert_path = Path.join([Application.app_dir(:blog), "priv", "cert", "ca", "ca.pem"])
    
    case File.read(ca_cert_path) do
      {:ok, pem_data} ->
        try do
          [{:Certificate, cert_der, :not_encrypted}] = :public_key.pem_decode(pem_data)
          ca_cert = :public_key.pkix_decode_cert(cert_der, :otp)
          {:ok, ca_cert}
        rescue
          error ->
            {:error, "Failed to load CA certificate: #{inspect(error)}"}
        end
      
      {:error, reason} ->
        {:error, "Failed to read CA certificate: #{inspect(reason)}"}
    end
  end
  
  # Verify that the client certificate was signed by our CA
  defp verify_certificate_chain(client_cert, ca_cert) do
    try do
      # Extract public key from CA certificate
      ca_public_key = extract_public_key(ca_cert)
      
      # Verify the client certificate signature using CA public key
      case :public_key.pkix_verify(client_cert, ca_public_key) do
        true -> :ok
        false -> {:error, "Certificate not signed by trusted CA"}
      end
    rescue
      error ->
        {:error, "Certificate verification failed: #{inspect(error)}"}
    end
  end
  
  # Check if the certificate is still valid (not expired)
  defp check_certificate_validity(cert) do
    {{:Certificate, tbs_cert, _sig_alg, _signature}, _} = cert
    
    {:Validity, not_before, not_after} = tbs_cert.validity
    
    current_time = :calendar.universal_time()
    
    case {time_compare(current_time, not_before), time_compare(not_after, current_time)} do
      {:greater_or_equal, :greater_or_equal} -> :ok
      _ -> {:error, "Certificate expired or not yet valid"}
    end
  end
  
  # Extract public key from certificate
  defp extract_public_key(cert) do
    {{:Certificate, tbs_cert, _sig_alg, _signature}, _} = cert
    tbs_cert.subjectPublicKeyInfo.subjectPublicKey
  end
  
  # Compare two time tuples
  defp time_compare(time1, time2) do
    case :calendar.time_difference(time2, time1) do
      {days, _time} when days > 0 -> :greater
      {0, {hours, minutes, seconds}} when hours > 0 or minutes > 0 or seconds > 0 -> :greater
      {0, {0, 0, 0}} -> :equal
      _ -> :less
    end
    |> case do
      :greater -> :greater
      :equal -> :greater_or_equal
      :less -> :less
    end
  end
  
  # Get certificate subject for logging
  defp cert_subject(cert) do
    {{:Certificate, tbs_cert, _sig_alg, _signature}, _} = cert
    
    case tbs_cert.subject do
      {:rdnSequence, rdn_sequence} ->
        rdn_sequence
        |> List.flatten()
        |> Enum.map(fn {:AttributeTypeAndValue, oid, value} ->
          case oid do
            {2, 5, 4, 3} -> "CN=#{value}"  # Common Name
            {2, 5, 4, 10} -> "O=#{value}"  # Organization
            {2, 5, 4, 11} -> "OU=#{value}" # Organizational Unit
            _ -> "#{inspect(oid)}=#{value}"
          end
        end)
        |> Enum.join(", ")
      
      _ ->
        "Unknown subject"
    end
  end
  
  # Send unauthorized response
  defp send_unauthorized(conn, message) do
    conn
    |> Plug.Conn.put_status(:unauthorized)
    |> json(%{error: message})
    |> halt()
  end
end