# Quick integration test for the RequireUserAgent plug

# Start the Phoenix server for testing
{:ok, _} = Application.ensure_all_started(:blog)

# Test 1: Request without User-Agent should be blocked
IO.puts("Testing request without User-Agent...")
response1 = HTTPoison.get("http://localhost:4000/api/posts", [])

case response1 do
  {:ok, %{status_code: 400, body: "User-Agent header required"}} ->
    IO.puts("✅ Correctly blocked request without User-Agent")

  {:ok, %{status_code: code, body: body}} ->
    IO.puts("❌ Expected 400 but got #{code}: #{body}")

  {:error, reason} ->
    IO.puts("❌ Request failed: #{inspect(reason)}")
end

# Test 2: Request with User-Agent should pass
IO.puts("Testing request with User-Agent...")
response2 = HTTPoison.get("http://localhost:4000/api/posts", [{"User-Agent", "Test/1.0"}])

case response2 do
  {:ok, %{status_code: 200}} ->
    IO.puts("✅ Correctly allowed request with User-Agent")

  {:ok, %{status_code: code, body: body}} ->
    IO.puts("❌ Expected 200 but got #{code}: #{body}")

  {:error, reason} ->
    IO.puts("❌ Request failed: #{inspect(reason)}")
end

# Test 3: Request with empty User-Agent should be blocked
IO.puts("Testing request with empty User-Agent...")
response3 = HTTPoison.get("http://localhost:4000/api/posts", [{"User-Agent", ""}])

case response3 do
  {:ok, %{status_code: 400, body: "Valid User-Agent header required"}} ->
    IO.puts("✅ Correctly blocked request with empty User-Agent")

  {:ok, %{status_code: code, body: body}} ->
    IO.puts("❌ Expected 400 but got #{code}: #{body}")

  {:error, reason} ->
    IO.puts("❌ Request failed: #{inspect(reason)}")
end

IO.puts("User-Agent plug test completed!")
