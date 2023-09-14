import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :when_to_process, WhenToProcess.Repo,
  username: "postgres",
  password: "when_to_process",
  hostname: "localhost",
  port: 5432,
  database: "when_to_process_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :when_to_process, WhenToProcessWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "V+HzmwISKS7Znb+ZRc8Vjy3lBVGziHz6+bWbjQYjBGPwm0ysBU1+WpKh3hl0mf1J",
  server: false

# In test we don't send emails.
config :when_to_process, WhenToProcess.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
