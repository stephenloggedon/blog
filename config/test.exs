import Config

# Only in tests, remove the complexity from the password hashing algorithm

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :blog, Blog.Repo,
  adapter: Ecto.Adapters.SQLite3,
  database: "file::memory:?cache=shared",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Turso configuration for testing (disabled by default)
config :blog, Blog.TursoRepo,
  uri: nil,
  auth_token: nil,
  database: "blog_test.db",
  sync: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :blog, BlogWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  https: [
    ip: {127, 0, 0, 1},
    port: 4003,
    cipher_suite: :strong,
    keyfile: "priv/cert/server/server-key.pem",
    certfile: "priv/cert/server/server-cert.pem",
    cacertfile: "priv/cert/ca/ca.pem",
    verify: :verify_peer,
    fail_if_no_peer_cert: false,
    reuse_sessions: false,
    depth: 2
  ],
  secret_key_base: "kKEUSeUJ9hKNmBizHeILCVP13lLA3AmLiKvT27ZGMXcLTNeaz7UWrzd/KKTRH85p",
  server: true

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true