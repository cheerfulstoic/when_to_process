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
#     PHX_SERVER=true bin/when_to_process start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :when_to_process, WhenToProcessWeb.Endpoint, server: true
end

if System.get_env("LOG_LEVEL") do
  config :logger, level: String.to_atom(System.get_env("LOG_LEVEL"))
end

config :when_to_process, :client, http_base: "http://when-to-process.internal:8080", ws_base: "ws://when-to-process.internal:8080"
# config :when_to_process, :client, http_base: "https://when-to-process.fly.dev", ws_base: "wss://when-to-process.fly.dev"

# RIDES_IMPLEMENTATION_MODULE should be one of:
#  WhenToProcess.Rides.ProcessesOnly
#  WhenToProcess.Rides.ProcessesWithETS
#  WhenToProcess.Rides.DB

global_state_implementation_module = System.get_env("RIDES_GLOBAL_IMPLEMENTATION_MODULE")
individual_state_implementation_module = System.get_env("RIDES_INDIVIDUAL_IMPLEMENTATION_MODULE")

if global_state_implementation_module && individual_state_implementation_module do
  config :when_to_process, WhenToProcess.Rides,
    global_state_implementation_module: String.to_atom("Elixir.#{global_state_implementation_module}"),
    individual_state_implementation_module: String.to_atom("Elixir.#{individual_state_implementation_module}")
else
  raise "RIDES_GLOBAL_IMPLEMENTATION_MODULE and RIDES_INDIVIDUAL_IMPLEMENTATION_MODULE environment variables required!"
end

config :when_to_process, WhenToProcess.Rides.PartitionedRecordStore, partitions: 4


if config_env() == :prod do
  # {grafana_host, grafana_token} = {
  #   System.get_env("GRAFANA_HOST"),
  #   System.get_env("GRAFANA_TOKEN")
  # }
  # if grafana_host && grafana_token do
  #   config :when_to_process, WhenToProcess.PromEx,
  #     manual_metrics_start_delay: :no_delay,
  #     grafana: [
  #       host: grafana_host,
  #       auth_token: grafana_token,
  #       upload_dashboards_on_start: true,
  #       folder_name: "WhenToProcess App Dashboards",
  #       annotate_app_lifecycle: true
  #     ]
  # else
  #   IO.puts("GRAFANA_HOST AND/OR GRAFANA_TOKEN NOT SET!!")
  # end

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :when_to_process, WhenToProcess.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

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

  config :when_to_process, WhenToProcessWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :when_to_process, WhenToProcessWeb.Endpoint,
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
  # We also recommend setting `force_ssl` in your endpoint, ensuring
  # no data is ever sent via http, always redirecting to https:
  #
  #     config :when_to_process, WhenToProcessWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :when_to_process, WhenToProcess.Mailer,
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
