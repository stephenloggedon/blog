defmodule BlogWeb.Plugs.ClientCertAuth do
  @moduledoc """
  Plug for authenticating API requests using client certificates (mTLS).
  
  This plug validates that the client has presented a valid certificate
  signed by our trusted Certificate Authority. The plug supports both
  production use (with Cowboy SSL adapter) and testing (with Plug.Test adapter).
  
  In production, certificates are extracted from the SSL socket via Cowboy.
  In tests, certificates are provided via `Plug.Test.put_peer_data/2`.
  """
  
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  
  require Logger
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
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
  
  # Extract the client certificate from the SSL connection
  defp get_client_certificate(conn) do
    # For Cowboy adapter, get the peer certificate from the SSL socket
    case conn.adapter do
      {Plug.Cowboy.Conn, cowboy_req} ->
        get_peer_cert_from_cowboy(cowboy_req)
      
      _ ->
        # For testing, try to get certificate from peer data
        get_peer_cert_from_test_data(conn)
    end
  end
  
  # Get peer certificate from Cowboy request
  defp get_peer_cert_from_cowboy(cowboy_req) do
    try do
      # Get the SSL socket from the cowboy request
      case :cowboy_req.cert(cowboy_req) do
        :undefined ->
          {:error, "No client certificate presented"}
        
        cert_der when is_binary(cert_der) ->
          decode_certificate(cert_der)
        
        _ ->
          {:error, "Invalid certificate format"}
      end
    rescue
      error ->
        {:error, "Failed to access peer certificate: #{inspect(error)}"}
    end
  end
  
  # Get peer certificate from test peer data (for testing)
  defp get_peer_cert_from_test_data(conn) do
    try do
      case Plug.Conn.get_peer_data(conn) do
        %{ssl_cert: cert_der} when is_binary(cert_der) ->
          decode_certificate(cert_der)
        
        %{ssl_cert: nil} ->
          {:error, "No client certificate presented"}
        
        _ ->
          {:error, "No client certificate presented"}
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
      # Use the built-in path validation instead of manual verification
      case :public_key.pkix_path_validation(ca_cert, [client_cert], []) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, "Certificate not signed by trusted CA: #{inspect(reason)}"}
      end
    rescue
      error ->
        {:error, "Certificate verification failed: #{inspect(error)}"}
    end
  end
  
  # Check if the certificate is still valid (not expired)
  defp check_certificate_validity(cert) do
    case cert do
      {:OTPCertificate, {:OTPTBSCertificate, _version, _serial, _sig_alg, _issuer, validity, _subject, _pub_key_info, _issuer_uid, _subject_uid, _extensions}, _sig_alg2, _signature} ->
        {:Validity, not_before, not_after} = validity
        
        current_time = :calendar.universal_time()
        
        # Check: not_before <= current_time <= not_after
        case {parse_and_compare_time(not_before, current_time), parse_and_compare_time(current_time, not_after)} do
          {:less, :less} -> :ok
          {:equal, :less} -> :ok
          {:less, :equal} -> :ok
          {:equal, :equal} -> :ok
          _ -> {:error, "Certificate expired or not yet valid"}
        end
      
      _ ->
        {:error, "Invalid certificate format for validity check"}
    end
  end
  
  
  # Parse certificate time and compare with current time
  defp parse_and_compare_time(current_time, cert_time) do
    case parse_cert_time(cert_time) do
      {:ok, parsed_time} ->
        time_compare(current_time, parsed_time)
      
      {:error, _} ->
        :less  # If we can't parse the time, assume it's invalid
    end
  end
  
  # Parse certificate time format
  defp parse_cert_time({:utcTime, time_string}) when is_list(time_string) do
    # Convert charlist to string and parse YYMMDDHHMMSSZ format
    time_str = to_string(time_string)
    parse_utc_time_string(time_str)
  end
  
  defp parse_cert_time({:generalTime, time_string}) when is_list(time_string) do
    # Convert charlist to string and parse YYYYMMDDHHMMSSZ format
    time_str = to_string(time_string)
    parse_general_time_string(time_str)
  end
  
  defp parse_cert_time(_), do: {:error, "Unknown time format"}
  
  # Parse UTC time string (YYMMDDHHMMSSZ)
  defp parse_utc_time_string(time_str) do
    case Regex.run(~r/^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/, time_str) do
      [_, yy, mm, dd, hh, min, ss] ->
        year = String.to_integer(yy)
        # Handle Y2K - years 00-49 are 20xx, 50-99 are 19xx
        full_year = if year <= 49, do: 2000 + year, else: 1900 + year
        
        month = String.to_integer(mm)
        day = String.to_integer(dd)
        hour = String.to_integer(hh)
        minute = String.to_integer(min)
        second = String.to_integer(ss)
        
        {:ok, {{full_year, month, day}, {hour, minute, second}}}
      
      _ ->
        {:error, "Invalid UTC time format"}
    end
  end
  
  # Parse general time string (YYYYMMDDHHMMSSZ)
  defp parse_general_time_string(time_str) do
    case Regex.run(~r/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/, time_str) do
      [_, yyyy, mm, dd, hh, min, ss] ->
        year = String.to_integer(yyyy)
        month = String.to_integer(mm)
        day = String.to_integer(dd)
        hour = String.to_integer(hh)
        minute = String.to_integer(min)
        second = String.to_integer(ss)
        
        {:ok, {{year, month, day}, {hour, minute, second}}}
      
      _ ->
        {:error, "Invalid general time format"}
    end
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
      :equal -> :equal
      :less -> :less
    end
  end
  
  # Get certificate subject for logging
  defp cert_subject(cert) do
    case cert do
      {:OTPCertificate, {:OTPTBSCertificate, _version, _serial, _sig_alg, _issuer, _validity, subject, _pub_key_info, _issuer_uid, _subject_uid, _extensions}, _sig_alg2, _signature} ->
        case subject do
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
      
      _ ->
        "Invalid certificate format"
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