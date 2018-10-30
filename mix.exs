defmodule RCON.Mixfile do
	use Mix.Project
	
	@description """
	Source compatible RCON implementation
	"""

	def project, do: [
		app: :rcon,
		version: "0.2.0",
		elixir: "~> 1.7",
		deps: deps(),
		package: package(),
		description: @description
	]

	# Configuration for the OTP application
	def application, do: [
		applications: []
	]

	defp deps, do: [
		{:socket, "~> 0.3"},
		{:ex_doc, "~> 0.19", only: :dev, runtime: false}
	]

	defp package, do: [
		name: :rcon,
		files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
		maintainers: ["James Dyson"],
		licenses: ["MIT"],
		links: %{"GitHub" => "https://github.com/avitex/elixir-rcon"}
	]
end
