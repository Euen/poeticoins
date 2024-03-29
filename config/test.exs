use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :poeticoins, PoeticoinsWeb.Endpoint,
  http: [port: 4002],
  server: false

config :poeticoins, :children, [
  PoeticoinsWeb.Telemetry,
  {Phoenix.PubSub, name: Poeticoins.PubSub},
  PoeticoinsWeb.Endpoint
]

# Print only warnings and errors during test
config :logger, level: :warn
