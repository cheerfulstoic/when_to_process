defmodule WhenToProcess.MixProject do
  use Mix.Project

  def project do
    [
      app: :when_to_process,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      preferred_cli_env: [
        "test.watch": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {WhenToProcess.Application, []},
      extra_applications: [:logger, :runtime_tools]
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
      # Temporary
      # See https://elixirforum.com/t/elixir-v1-15-0-released/56584/3
      {:ssl_verify_fun, "1.1.0", manager: :rebar3, runtime: false, override: true},
      {:phoenix, "~> 1.7.6", override: true},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.18.3"},
      {:heroicons, "~> 0.5"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.1.8", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.6.1"},
      {:cowboy, "~> 2.10.0", override: true},
      {:ranch, "~> 2.1.0", override: true},

      # Non-default:
      {:faker, "~> 0.17"},
      {:geocalc, "~> 0.8"},
      {:ecto_require_associations, "~> 0.1.3"},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:slipstream, "~> 1.1"},
      {:phoenix_client, "~> 0.3"},
      {:httpoison, "~> 2.0"},
      {:mint_web_socket, "~> 1.0"},
      {:ex2ms, "~> 1.6.1"},
      {:telemetry_metrics_statsd, "~> 0.7.0"},
      {:prom_ex, "~> 1.8.0"},
      {:cowboy_telemetry, "~> 0.4.0"},
      {:bandit, "~> 1.0-pre"},
      {:kino, "~> 0.9.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:rexbug, ">= 1.0.0"},

      {:replbug, "~> 0.1"},

      # Test
      {:ex_machina, "~> 2.7.0", only: :test},
      {:assertions, "~> 0.10", only: :test}
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
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
