defmodule BlogWeb.Plugs.RequireUserAgentTest do
  use BlogWeb.ConnCase, async: true

  alias BlogWeb.Plugs.RequireUserAgent

  describe "RequireUserAgent plug" do
    test "allows requests with valid User-Agent header" do
      conn =
        build_conn()
        |> put_req_header("user-agent", "Mozilla/5.0 (compatible; TestBot/1.0)")
        |> RequireUserAgent.call([])

      refute conn.halted
    end

    test "blocks requests with no User-Agent header" do
      conn =
        build_conn()
        |> RequireUserAgent.call([])

      assert conn.halted
      assert conn.status == 400
      assert conn.resp_body == "User-Agent header required"
    end

    test "blocks requests with empty User-Agent header" do
      conn =
        build_conn()
        |> put_req_header("user-agent", "")
        |> RequireUserAgent.call([])

      assert conn.halted
      assert conn.status == 400
      assert conn.resp_body == "Valid User-Agent header required"
    end

    test "allows requests with multiple User-Agent headers" do
      conn =
        build_conn()
        |> put_req_header("user-agent", "Mozilla/5.0")
        |> put_req_header("user-agent", "TestAgent/1.0")
        |> RequireUserAgent.call([])

      refute conn.halted
    end

    test "allows requests with common browser User-Agent strings" do
      user_agents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
        "curl/7.68.0",
        "HTTPie/3.2.1"
      ]

      for user_agent <- user_agents do
        conn =
          build_conn()
          |> put_req_header("user-agent", user_agent)
          |> RequireUserAgent.call([])

        refute conn.halted, "Should allow User-Agent: #{user_agent}"
      end
    end
  end
end
