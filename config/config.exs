# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :blog,
  ecto_repos: [Blog.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :blog, BlogWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: BlogWeb.ErrorHTML, json: BlogWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Blog.PubSub,
  live_view: [signing_salt: "f7j7b37q"]

config :blog, BlogWeb.ApiEndpoint,
  render_errors: [
    formats: [json: BlogWeb.ErrorJSON],
    layout: false
  ]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  blog: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  blog: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Force Cowboy usage for mTLS compatibility  
config :phoenix, :serve_endpoints, true
config :phoenix, :adapter, :cowboy
config :blog, BlogWeb.Endpoint, server: true

# Repository adapter configuration
config :blog, :repo_adapter, Blog.EctoRepoAdapter

# OpenTelemetry configuration
config :opentelemetry,
  # Enable batch span processor for better performance
  span_processor: :batch,
  # Use OTLP exporter to send data to Grafana Cloud
  traces_exporter: :otlp

# OpenTelemetry exporter configuration (will be set in runtime.exs with env vars)
config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  # Placeholder - will be configured in runtime.exs with real Grafana Cloud endpoint
  otlp_endpoint: "http://localhost:4318",
  otlp_headers: []

# Resource attributes to identify your service
config :opentelemetry, :resource,
  service: [
    name: "blog",
    version: "0.1.0"
  ],
  # Add custom attributes for better filtering
  deployment: [
    environment: "production"
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
