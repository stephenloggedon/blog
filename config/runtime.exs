import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/blog start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :blog, BlogWeb.Endpoint, server: true
end

if config_env() == :prod do
  # Use Turso for production database operations
  config :blog, :repo_adapter, Blog.TursoRepoAdapter

  # Turso Ecto Repo configuration for production migrations and operations
  config :blog, Blog.TursoEctoRepo,
    # Use memory database since we're using HTTP for actual operations
    database: ":memory:",
    adapter: Blog.TursoEctoAdapter,
    pool_size: 1,
    # Use the same migrations as the main repo
    priv: "priv/repo"

  # Turso distributed SQLite configuration for production (legacy)
  # Local SQLite is only used for development and testing
  config :blog, Blog.TursoRepo,
    uri: System.get_env("LIBSQL_URI"),
    auth_token: System.get_env("LIBSQL_TOKEN"),
    database: "blog.db",
    sync: true

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")
  mtls_port = String.to_integer(System.get_env("MTLS_PORT") || "8443")

  config :blog, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # SSL certificate handling - load from environment variables (for production) or local files (for development)
  ssl_keyfile =
    case System.get_env("SSL_KEYFILE_CONTENT") do
      nil ->
        # Development: use local certificate files
        System.get_env("SSL_KEYFILE") ||
          Path.join([Application.app_dir(:blog), "priv", "cert", "server", "server-key.pem"])

      content ->
        # Production: write environment variable content to app directory
        cert_dir = Path.join([Application.app_dir(:blog), "priv", "runtime"])
        File.mkdir_p!(cert_dir)
        path = Path.join(cert_dir, "server-key.pem")
        File.write!(path, content)
        # Secure permissions
        File.chmod!(path, 0o600)
        path
    end

  ssl_certfile =
    case System.get_env("SSL_CERTFILE_CONTENT") do
      nil ->
        # Development: use local certificate files
        System.get_env("SSL_CERTFILE") ||
          Path.join([Application.app_dir(:blog), "priv", "cert", "server", "server-cert.pem"])

      content ->
        # Production: write environment variable content to app directory
        cert_dir = Path.join([Application.app_dir(:blog), "priv", "runtime"])
        File.mkdir_p!(cert_dir)
        path = Path.join(cert_dir, "server-cert.pem")
        File.write!(path, content)
        path
    end

  ssl_cacertfile =
    case System.get_env("SSL_CACERTFILE_CONTENT") do
      nil ->
        # Development: use local certificate files
        System.get_env("SSL_CACERTFILE") ||
          Path.join([Application.app_dir(:blog), "priv", "cert", "ca", "ca.pem"])

      content ->
        # Production: write environment variable content to app directory
        cert_dir = Path.join([Application.app_dir(:blog), "priv", "runtime"])
        File.mkdir_p!(cert_dir)
        path = Path.join(cert_dir, "ca.pem")
        File.write!(path, content)
        path
    end

  config :blog, BlogWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    check_origin: [
      "https://#{host}",
      "//#{host}",
      "https://blog-nameless-grass-3626.fly.dev",
      "//blog-nameless-grass-3626.fly.dev"
    ],
    server: true,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port,
      transport_options: [socket_opts: [:inet6]]
    ],
    # HTTPS/mTLS removed from main endpoint - handled by separate TCP service on port 8443
    # This eliminates WebSocket 403 errors while preserving mTLS for API endpoints
    secret_key_base: secret_key_base

  # Separate mTLS API endpoint configuration
  config :blog, BlogWeb.ApiEndpoint,
    url: [host: host, port: mtls_port, scheme: "https"],
    server: true,
    https: [
      # HTTPS with mTLS for API endpoints only
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: mtls_port,
      cipher_suite: :strong,
      keyfile: ssl_keyfile,
      certfile: ssl_certfile,
      cacertfile: ssl_cacertfile,
      verify: :verify_peer,
      # Allow non-API requests to fail gracefully
      fail_if_no_peer_cert: false,
      reuse_sessions: false,
      depth: 2,
      transport_options: [socket_opts: [:inet6]]
    ],
    secret_key_base: secret_key_base

  # Configure GeoIP database path for production release
  config :geolix,
    databases: [
      %{
        id: :country,
        adapter: Geolix.Adapter.MMDB2,
        source: Path.join([Application.app_dir(:blog), "priv", "geoip", "GeoLite2-Country.mmdb"])
      }
    ]

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :blog, BlogWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :blog, BlogWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :blog, Blog.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end

# OpenTelemetry configuration for all environments
# Configure OTLP exporter with Grafana Cloud credentials from environment variables
if System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") do
  config :opentelemetry_exporter,
    otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT"),
    otlp_headers: [
      {"Authorization", "Basic #{System.get_env("OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION")}"}
    ]
end

# Configure environment-specific attributes
environment =
  case config_env() do
    :prod -> "production"
    :dev -> "development"
    :test -> "test"
    env -> to_string(env)
  end

config :opentelemetry, :resource,
  service: [
    name: "blog",
    version: "0.1.0"
  ],
  deployment: [
    environment: environment
  ]

# Configure dual logging: human-readable console + structured OTLP
config :logger,
  backends: [:console, Blog.OTLPLoggerBackend],
  level: :info

# Human-readable console logs
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Structured logging for OTLP export
config :logger, Blog.OTLPLoggerBackend,
  level: :info,
  metadata: [
    :request_id,
    :trace_id,
    :span_id,
    :user_id,
    :remote_ip,
    :method,
    :path,
    :status,
    :duration,
    :duration_ms,
    :query_string,
    :response_size,
    :user_agent,
    :operation,
    :error,
    :post_id,
    :post_title,
    :post_slug,
    :published,
    :reason,
    # Geographic metadata
    :country,
    :country_code,
    :ip_type
  ]
