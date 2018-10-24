defmodule Rcon.Mixfile do
	use Mix.Project

	def project do
		[
			app: :rcon,
			version: "0.1.0",
			elixir: "~> 1.3",
			deps: deps(),
			package: package(),
			description: "Source compatible RCON implementation.",
		]
	end

	# Configuration for the OTP application
	def application do
		[applications: []]
	end

	defp deps, do: []

	defp package do
		[
			name: :rcon,
			files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
			maintainers: ["James Dyson"],
			licenses: ["MIT"],
			links: %{"GitHub" => "https://github.com/avitex/elixir-rcon"}
		]
	end
end
