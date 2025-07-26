defmodule Blog.Analytics do
  @moduledoc """
  Custom OpenTelemetry instrumentation for blog-specific analytics and business metrics.

  This module provides functions to track user behavior, content engagement,
  and other business-critical metrics that complement the automatic instrumentation.
  """

  require OpenTelemetry.Tracer, as: Tracer

  @doc """
  Track when a user views a blog post.

  Creates a custom span with relevant attributes for analytics dashboards.
  """
  def track_post_view(post_id, post_title, post_slug, conn \\ nil) do
    Tracer.with_span "blog.post.view", %{
      "post.id" => post_id,
      "post.title" => post_title,
      "post.slug" => post_slug,
      "user.action" => "view_post"
    } do
      # Add HTTP-specific attributes if connection is available
      if conn do
        add_request_attributes(conn)
      end

      # Emit a telemetry event for other systems to consume
      :telemetry.execute(
        [:blog, :post, :viewed],
        %{count: 1},
        %{
          post_id: post_id,
          post_title: post_title,
          post_slug: post_slug
        }
      )
    end
  end

  @doc """
  Track search queries and their results.
  """
  def track_search(query, result_count, conn \\ nil) do
    Tracer.with_span "blog.search.query", %{
      "search.query" => query,
      "search.results.count" => result_count,
      "user.action" => "search"
    } do
      if conn do
        add_request_attributes(conn)
      end

      :telemetry.execute(
        [:blog, :search, :performed],
        %{count: 1, results: result_count},
        %{query: query}
      )
    end
  end

  @doc """
  Track API endpoint usage for the blog API.
  """
  def track_api_usage(endpoint, method, response_status, conn \\ nil) do
    Tracer.with_span "blog.api.request", %{
      "api.endpoint" => endpoint,
      "http.method" => method,
      "http.status_code" => response_status,
      "user.action" => "api_request"
    } do
      if conn do
        add_request_attributes(conn)
      end

      :telemetry.execute(
        [:blog, :api, :request],
        %{count: 1},
        %{
          endpoint: endpoint,
          method: method,
          status: response_status
        }
      )
    end
  end

  @doc """
  Track user navigation patterns and page views.
  """
  def track_page_view(page_path, page_title \\ nil, conn \\ nil) do
    Tracer.with_span "blog.page.view", %{
      "page.path" => page_path,
      "page.title" => page_title || page_path,
      "user.action" => "page_view"
    } do
      if conn do
        add_request_attributes(conn)
      end

      :telemetry.execute(
        [:blog, :page, :viewed],
        %{count: 1},
        %{
          path: page_path,
          title: page_title
        }
      )
    end
  end

  @doc """
  Track user engagement metrics like time spent reading.
  """
  def track_engagement(event_type, duration_ms \\ nil, metadata \\ %{}) do
    attributes = %{
      "engagement.type" => event_type,
      "user.action" => "engagement"
    }

    attributes =
      if duration_ms do
        Map.put(attributes, "engagement.duration_ms", duration_ms)
      else
        attributes
      end

    # Add any additional metadata as attributes
    attributes = Map.merge(attributes, stringify_keys(metadata))

    Tracer.with_span "blog.user.engagement", attributes do
      :telemetry.execute(
        [:blog, :engagement, :tracked],
        %{count: 1, duration: duration_ms || 0},
        Map.put(metadata, :type, event_type)
      )
    end
  end

  # Private helper functions

  defp add_request_attributes(conn) do
    # Extract user agent and parse browser info
    user_agent = get_header(conn, "user-agent") || "unknown"
    browser_info = parse_user_agent(user_agent)

    # Extract referrer information
    referrer = get_header(conn, "referer")

    # Extract IP address (considering proxies)
    client_ip = get_client_ip(conn)

    # Add attributes to current span
    Tracer.set_attributes(%{
      "http.user_agent" => user_agent,
      "user.browser.name" => browser_info.browser,
      "user.browser.version" => browser_info.version,
      "user.device.type" => browser_info.device_type,
      "http.referrer" => referrer,
      "user.ip" => client_ip
    })
  end

  defp get_header(conn, header_name) do
    case Plug.Conn.get_req_header(conn, header_name) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp get_client_ip(conn) do
    # Check for X-Forwarded-For header first (common with proxies/load balancers)
    case get_header(conn, "x-forwarded-for") do
      nil ->
        # Fall back to remote IP
        case conn.remote_ip do
          {a, b, c, d} ->
            "#{a}.#{b}.#{c}.#{d}"

          {a, b, c, d, e, f, g, h} ->
            # IPv6 - convert to string
            parts = [a, b, c, d, e, f, g, h]

            Enum.map_join(parts, ":", &Integer.to_string(&1, 16))

          _ ->
            "unknown"
        end

      forwarded_ip ->
        # Take the first IP in the X-Forwarded-For chain
        forwarded_ip
        |> String.split(",")
        |> List.first()
        |> String.trim()
    end
  end

  defp parse_user_agent(user_agent) do
    # Simple user agent parsing - you could use a more sophisticated library
    # like UAInspector or Whoami for better parsing
    cond do
      String.contains?(user_agent, "Chrome") ->
        %{
          browser: "Chrome",
          version: extract_version(user_agent, "Chrome"),
          device_type: detect_device(user_agent)
        }

      String.contains?(user_agent, "Firefox") ->
        %{
          browser: "Firefox",
          version: extract_version(user_agent, "Firefox"),
          device_type: detect_device(user_agent)
        }

      String.contains?(user_agent, "Safari") ->
        %{
          browser: "Safari",
          version: extract_version(user_agent, "Safari"),
          device_type: detect_device(user_agent)
        }

      String.contains?(user_agent, "Edge") ->
        %{
          browser: "Edge",
          version: extract_version(user_agent, "Edge"),
          device_type: detect_device(user_agent)
        }

      true ->
        %{browser: "Unknown", version: "Unknown", device_type: "Unknown"}
    end
  end

  defp extract_version(user_agent, browser) do
    # Simple version extraction - matches "BrowserName/X.Y.Z"
    case Regex.run(~r/#{browser}\/([0-9]+\.[0-9]+)/, user_agent) do
      [_, version] -> version
      _ -> "Unknown"
    end
  end

  defp detect_device(user_agent) do
    cond do
      String.contains?(user_agent, "Mobile") or String.contains?(user_agent, "Android") ->
        "Mobile"

      String.contains?(user_agent, "Tablet") or String.contains?(user_agent, "iPad") ->
        "Tablet"

      true ->
        "Desktop"
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  defp stringify_keys(_), do: %{}
end
