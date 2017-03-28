defmodule Phoenix.GenSocketClient.Mixfile do
  use Mix.Project

  @version "0.0.1"
  @github_url "https://github.com/Aircloak/phoenix_gen_socket_client"

  def project do
    [
      app: :phoenix_gen_socket_client,
      version: @version,
      elixir: "~> 1.2",
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
      {:websocket_client, github: "sanmiguel/websocket_client", tag: "1.1.0",
        only: [:dev, :test, :docs]},
      {:poison, "~> 1.5", only: :test},
      {:phoenix, "~> 1.1.4", only: :test},
      {:cowboy, "~> 1.0", only: :test},
      {:gproc, "~> 0.5.0", only: :test},
      {:ex_doc, "~> 0.11", only: :docs},
      {:earmark, "~> 0.2", only: :docs}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp applications(:test), do: [:logger, :websocket_client, :gproc, :cowboy, :phoenix]
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
