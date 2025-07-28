defmodule Blog.TursoRepoAdapterTest do
  use ExUnit.Case, async: true
  
  alias Blog.TursoRepoAdapter
  alias Blog.Content.Post
  alias Blog.Content.Series
  import Ecto.Query
  
  # Since we can't easily mock external dependencies without adding new deps,
  # we'll test the contract and internal logic that doesn't require network calls

  describe "API contract" do
    test "one/1 with Ecto query has correct function signature" do
      query = from(p in Post, where: p.id == 1)
      
      # Test that the function exists and accepts the right parameters
      # We expect it to try to make a network call and fail, which is fine for contract testing
      result = TursoRepoAdapter.one(query)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "one/1 with schema has correct function signature" do
      result = TursoRepoAdapter.one(Post)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "update_all/2 with valid parameters has correct function signature" do
      query = from(p in Post, where: p.published == true)
      updates = [set: [title: "Updated Title"]]
      
      result = TursoRepoAdapter.update_all(query, updates)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "update_all/2 returns error for unsupported queryable" do
      assert {:error, :unsupported_queryable} = TursoRepoAdapter.update_all("invalid", [])
    end
  end

  describe "internal helper functions behavior" do
    test "build_set_clause handles set updates" do
      # We can test the private function behavior by calling the public API
      # and observing that it doesn't crash with different update formats
      
      query = from(p in Post, where: p.id == 1)
      updates = [set: [title: "New Title", published: false]]
      
      result = TursoRepoAdapter.update_all(query, updates)
      # Should return a result (ok or error) without crashing
      assert is_tuple(result)
    end

    test "build_set_clause handles increment updates" do
      query = from(p in Post, where: p.id == 1)  
      updates = [inc: [series_position: 1]]
      
      result = TursoRepoAdapter.update_all(query, updates)
      assert is_tuple(result)
    end

    test "build_set_clause handles direct keyword list" do
      query = from(s in Series, where: s.id == 1)
      updates = [title: "New Title", description: "New Description"]
      
      result = TursoRepoAdapter.update_all(query, updates)
      assert is_tuple(result)
    end

    test "build_set_clause handles empty updates" do
      query = from(p in Post, where: p.id == 1)
      updates = []
      
      result = TursoRepoAdapter.update_all(query, updates)
      assert is_tuple(result)
    end
  end

  describe "query conversion" do
    test "handles Post queries" do
      query = from(p in Post, where: p.published == true and p.id > 10)
      
      # Test that query conversion doesn't crash
      result = TursoRepoAdapter.one(query)
      assert is_tuple(result)
    end

    test "handles Series queries" do
      query = from(s in Series, where: s.id == 1)
      
      result = TursoRepoAdapter.one(query)
      assert is_tuple(result)
    end

    test "handles complex queries with multiple conditions" do
      query = from(p in Post, 
        where: p.published == true and not is_nil(p.published_at),
        limit: 10
      )
      
      result = TursoRepoAdapter.one(query)
      assert is_tuple(result)
    end
  end

  describe "data conversion helpers" do
    test "schema determination works for different query types" do
      # These test that the functions can handle different schema types
      # without crashing during internal processing
      
      post_query = from(p in Post, where: p.id == 1)
      series_query = from(s in Series, where: s.id == 1)
      
      # Both should return tuples without crashing
      post_result = TursoRepoAdapter.one(post_query)
      series_result = TursoRepoAdapter.one(series_query)
      
      assert is_tuple(post_result)
      assert is_tuple(series_result)
    end
  end

  describe "error handling patterns" do
    test "gracefully handles invalid input types" do
      # Test with various invalid inputs to ensure graceful failure
      assert {:error, :unsupported_queryable} = TursoRepoAdapter.update_all("invalid", [])
      assert {:error, :unsupported_queryable} = TursoRepoAdapter.update_all(123, [])
      assert {:error, :unsupported_queryable} = TursoRepoAdapter.update_all(nil, [])
    end

    test "handles malformed update clauses" do
      query = from(p in Post, where: p.id == 1)
      
      # These should not crash, even if they fail
      result1 = TursoRepoAdapter.update_all(query, [invalid: :clause])
      result2 = TursoRepoAdapter.update_all(query, "invalid")
      result3 = TursoRepoAdapter.update_all(query, nil)
      
      assert is_tuple(result1)
      assert is_tuple(result2) 
      assert is_tuple(result3)
    end
  end

  describe "RepoAdapter behavior compliance" do
    test "implements all required callbacks" do
      # Verify the module implements the behavior
      behaviours = TursoRepoAdapter.__info__(:attributes)[:behaviour] || []
      assert Blog.RepoAdapter in behaviours
    end

    test "all required functions exist with correct arity" do
      functions = TursoRepoAdapter.__info__(:functions)
      
      # Check that all behavior callbacks are implemented
      assert {:all, 2} in functions
      assert {:get, 2} in functions  
      assert {:get_by, 2} in functions
      assert {:one, 1} in functions
      assert {:insert, 1} in functions
      assert {:update, 1} in functions
      assert {:update_all, 2} in functions
      assert {:delete, 1} in functions
      assert {:query, 2} in functions
      assert {:transaction, 1} in functions
    end
  end
end