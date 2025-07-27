defmodule Blog.GeoIP do
  @moduledoc """
  Geographic IP lookup functionality using MaxMind GeoLite2 Country database.

  This module provides lightweight country-level geographic resolution for IP addresses
  with intelligent fallbacks for private/local IPs and error cases.
  """

  @doc """
  Looks up geographic information for an IP address.

  Returns a map with country-level geographic data or an error tuple.

  ## Examples

      iex> Blog.GeoIP.lookup("8.8.8.8")
      {:ok, %{
        country: "United States",
        country_code: "US", 
        city: "Unknown",
        region: "Unknown"
      }}
      
      iex> Blog.GeoIP.lookup("invalid")
      {:error, :invalid_ip}
  """
  def lookup(ip_string) when is_binary(ip_string) do
    case parse_ip(ip_string) do
      {:ok, ip} -> lookup_ip(ip)
      {:error, reason} -> {:error, reason}
    end
  end

  def lookup(_), do: {:error, :invalid_input}

  @doc """
  Looks up geographic information and returns a simplified map suitable for logging.

  This function is optimized for structured logging and provides intelligent
  fallbacks for private/local IPs and error cases.
  """
  def lookup_for_logging(ip_string) when is_binary(ip_string) do
    # First check if it's a private/local IP
    cond do
      private_ip?(ip_string) ->
        %{
          country: "Private Network",
          country_code: "PN",
          ip_type: "private"
        }

      localhost_ip?(ip_string) ->
        %{
          country: "Localhost",
          country_code: "LH",
          ip_type: "localhost"
        }

      true ->
        # Try GeoIP lookup for public IPs
        case lookup(ip_string) do
          {:ok, geo_data} ->
            Map.put(geo_data, :ip_type, "public")

          {:error, _reason} ->
            %{
              country: "Unknown",
              country_code: "XX",
              ip_type: "unknown"
            }
        end
    end
  end

  def lookup_for_logging(_),
    do: %{
      country: "Invalid",
      country_code: "XX",
      ip_type: "invalid"
    }

  @doc """
  Returns whether the GeoIP database is available and configured.
  """
  def available? do
    case Application.get_application(Geolix) do
      :geolix ->
        try do
          case Geolix.lookup({8, 8, 8, 8}, where: :country) do
            nil -> false
            _ -> true
          end
        rescue
          _ -> false
        end

      _ ->
        false
    end
  end

  # Private functions

  defp parse_ip(ip_string) do
    case :inet.parse_address(String.to_charlist(ip_string)) do
      {:ok, ip} -> {:ok, ip}
      {:error, :einval} -> {:error, :invalid_ip}
    end
  end

  defp lookup_ip(ip) do
    case Application.get_application(Geolix) do
      :geolix ->
        try do
          case Geolix.lookup(ip, where: :country) do
            %{country: country_data} when is_map(country_data) ->
              {:ok,
               %{
                 country: get_country_name(country_data),
                 country_code: get_country_code(country_data)
               }}

            result when is_map(result) ->
              case Map.get(result, :country) do
                country_data when is_map(country_data) ->
                  {:ok,
                   %{
                     country: get_country_name(country_data),
                     country_code: get_country_code(country_data)
                   }}

                _ ->
                  {:error, :not_found}
              end

            _ ->
              {:error, :not_found}
          end
        rescue
          _ -> {:error, :lookup_failed}
        end

      _ ->
        {:error, :geolix_not_available}
    end
  end

  defp get_country_name(%{names: names}) when is_map(names) do
    Map.get(names, :en, Map.get(names, "en", "Unknown"))
  end

  defp get_country_name(%{name: name}) when is_binary(name), do: name
  defp get_country_name(_), do: "Unknown"

  defp get_country_code(%{iso_code: code}) when is_binary(code), do: code
  defp get_country_code(_), do: "XX"

  # IP classification helpers
  defp private_ip?(ip_string) do
    case :inet.parse_address(String.to_charlist(ip_string)) do
      {:ok, {192, 168, _, _}} -> true
      {:ok, {10, _, _, _}} -> true
      {:ok, {172, b, _, _}} when b >= 16 and b <= 31 -> true
      # Link-local
      {:ok, {169, 254, _, _}} -> true
      _ -> false
    end
  end

  defp localhost_ip?(ip_string) do
    case :inet.parse_address(String.to_charlist(ip_string)) do
      {:ok, {127, _, _, _}} -> true
      # IPv6 localhost
      {:ok, {0, 0, 0, 0, 0, 0, 0, 1}} -> true
      _ -> false
    end
  end
end
