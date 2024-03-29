# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :when_to_process,
  ecto_repos: [WhenToProcess.Repo]

# Configures the endpoint
config :when_to_process, WhenToProcessWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: WhenToProcessWeb.ErrorHTML, json: WhenToProcessWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: WhenToProcess.PubSub,
  adapter: Bandit.PhoenixAdapter,
  live_view: [signing_salt: "mjvB+Zye"],
  http: [
  # For testing purposes
  # COWBOY
    # transport_options: [
    #   handshake_timeout: 20_000,
    #   num_acceptors: 2_000,
    #   num_listen_sockets: 5,
    #   max_connections: :infinity
    # ]
  # BANDIT
    thousand_island_options: [
      num_acceptors: 1_000,
      num_connections: 50_000
    ]
  ]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :when_to_process, WhenToProcess.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.1.8",
  default: [
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

config :hackney, use_default_pool: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
