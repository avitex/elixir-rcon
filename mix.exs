defmodule RCON.Mixfile do
  use Mix.Project

  @version "0.3.0"

  @description """
  Source compatible RCON implementation
  """

  def project,
    do: [
      app: :rcon,
      version: @version,
      elixir: "~> 1.7",
      deps: deps(),
      package: package(),
      description: @description,
      name: "RCON",
      docs: docs(),
      dialyzer: [
        plt_add_deps: :project,
      ]

    ]

  # Configuration for the OTP application
  def application,
    do: [
      applications: []
    ]

  defp deps,
    do: [
      {:socket, "~> 0.3"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false}
    ]

  defp package,
    do: [
      name: :rcon,
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["James Dyson"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/avitex/elixir-rcon"}
    ]

  defp docs,
    do: [
      extras: ["README.md"],
      main: "readme",
      source_url: "https://github.com/avitex/elixir-rcon"
    ]
end
