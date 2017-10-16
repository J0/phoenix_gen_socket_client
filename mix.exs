defmodule Phoenix.GenSocketClient.Mixfile do
  use Mix.Project

  @version "1.2.0"
  @github_url "https://github.com/Aircloak/phoenix_gen_socket_client"

  def project do
    [
      app: :phoenix_gen_socket_client,
      version: @version,
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package(),
      description: "Socket client behaviour for phoenix channels.",
      docs: [
        source_url: @github_url,
        source_ref: "v#{@version}",
        main: "readme",
        extras: ["README.md"],
      ],
      preferred_cli_env: [docs: :docs],
    ]
  end

  def application do
    [applications: applications(Mix.env)]
  end

  defp deps do
    [
      {:credo, "~> 0.3.0", only: [:dev, :test]},
      {:dialyze, "~> 0.2.1", only: :dev},
      {:websocket_client, github: "sanmiguel/websocket_client", tag: "1.2.4",
        only: [:dev, :test, :docs]},
      {:poison, "~> 2.0", only: [:dev, :test]},
      {:phoenix, "~> 1.3", only: :test},
      {:cowboy, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.17.1", only: :docs}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp applications(:test), do: [:logger, :websocket_client, :cowboy, :phoenix]
  defp applications(:dev), do: [:logger, :websocket_client]
  defp applications(_), do: [:logger]

  defp package do
    [
      maintainers: ["Aircloak"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @github_url,
        "Docs" => "http://hexdocs.pm/phoenix_gen_socket_client"
      }
    ]
  end
end
