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
  # SQLite database configuration for production
  config :blog, Blog.Repo,
    adapter: Ecto.Adapters.SQLite3,
    database: System.get_env("DATABASE_URL") || "priv/repo/blog_prod.db",
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

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

  # SSL certificate paths
  ssl_keyfile = System.get_env("SSL_KEYFILE") || Path.join([Application.app_dir(:blog), "priv", "cert", "server", "server-key.pem"])
  ssl_certfile = System.get_env("SSL_CERTFILE") || Path.join([Application.app_dir(:blog), "priv", "cert", "server", "server-cert.pem"])
  ssl_cacertfile = System.get_env("SSL_CACERTFILE") || Path.join([Application.app_dir(:blog), "priv", "cert", "ca", "ca.pem"])

  config :blog, BlogWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    server: true,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port,
      transport_options: [socket_opts: [:inet6]]
    ],
    https: [
      # HTTPS with mTLS for API endpoints on separate port
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: mtls_port,
      cipher_suite: :strong,
      keyfile: ssl_keyfile,
      certfile: ssl_certfile,
      cacertfile: ssl_cacertfile,
      verify: :verify_peer,
      fail_if_no_peer_cert: false,  # Allow non-API requests
      reuse_sessions: false,
      depth: 2,
      transport_options: [socket_opts: [:inet6]]
    ],
    secret_key_base: secret_key_base

  # ExAws configuration for cloud storage
  config :ex_aws,
    access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
    region: System.get_env("AWS_REGION") || "us-east-1"

  # S3 bucket configuration for production
  config :blog,
    s3_bucket: System.get_env("S3_BUCKET") || "blog-images-prod"

  

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
