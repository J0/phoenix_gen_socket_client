defmodule PhoenixGenSocketClient.Mixfile do
  use Mix.Project

  def project do
    [
      app: :phoenix_gen_socket_client,
      version: "0.0.1",
      elixir: "~> 1.2",
      elixirc_paths: elixirc_paths(Mix.env),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps
    ]
  end

  def application do
    [applications: [:logger, :gproc]]
  end

  defp deps do
    [
      {:websocket_client, github: "sanmiguel/websocket_client", tag: "1.1.0"},
      {:poison, "~> 1.5"},
      {:ex_doc, "~> 0.11"},
      {:phoenix, "~> 1.1.4", only: :test},
      {:cowboy, "~> 1.0", only: :test},
      {:gproc, "~> 0.5.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
