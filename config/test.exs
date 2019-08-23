use Mix.Config

config :logger, level: :warn
config :phoenix_gen_socket_client, TestSite.Endpoint, []
config :phoenix, :json_library, Jason
