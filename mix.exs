defmodule Blog.MixProject do
  use Mix.Project

  def project do
    [
      app: :blog,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Blog.Application, []},
      extra_applications: [:logger, :runtime_tools, :geolix]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.18"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.18"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.36.0"},
      {:phoenix_live_dashboard, "~> 0.8.6"},
      {:esbuild, "~> 0.8", runtime: Mix.env() != :test},
      {:tailwind, "~> 0.2", runtime: Mix.env() != :test},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:finch, "~> 0.19"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.1.3"},
      {:plug_cowboy, "~> 2.6"},
      # Blog-specific dependencies
      {:earmark, "~> 1.4"},
      {:credo, "~> 1.7", runtime: false},
      {:live_svelte, "~> 0.13.3"},
      # Image processing
      {:vix, "~> 0.26"},
      # OpenTelemetry observability
      {:opentelemetry, "~> 1.5"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_exporter, "~> 1.8"},
      {:opentelemetry_phoenix, "~> 2.0"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry_cowboy, "~> 0.3"},
      # Structured JSON logging
      {:logger_json, "~> 6.1"},
      # GeoIP for geolocation analysis
      {:geolix, "~> 2.0"},
      {:geolix_adapter_mmdb2, "~> 0.6.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "cmd --cd assets npm install"],
      "ecto.reset": ["ecto.drop", "ecto.create", "ecto.migrate"],
      test: ["test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind blog", "esbuild blog"],
      "assets.deploy": [
        "tailwind blog --minify",
        "esbuild blog --minify",
        "phx.digest"
      ]
    ]
  end

  defp releases do
    [
      blog: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent],
        steps: [:assemble, &copy_geoip_files/1, &copy_bin_files/1, :tar]
      ]
    ]
  end

  defp copy_geoip_files(release) do
    # Copy GeoIP database to release if it exists
    geoip_source = "priv/geoip"

    if File.exists?(geoip_source) do
      geoip_dest = Path.join([release.path, "lib", "blog-#{release.version}", "priv", "geoip"])
      File.mkdir_p!(geoip_dest)
      File.cp_r!(geoip_source, Path.dirname(geoip_dest))
      IO.puts("GeoIP database included in release")
    else
      IO.puts("GeoIP database not found - geolocation will use fallbacks")
    end

    release
  end

  defp copy_bin_files(release) do
    File.cp_r!("rel/overlays", release.path)
    release
  end
end
