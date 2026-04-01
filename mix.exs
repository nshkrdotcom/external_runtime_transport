defmodule ExternalRuntimeTransport.MixProject do
  use Mix.Project

  @source_url "https://github.com/nshkrdotcom/external_runtime_transport"
  @version "0.1.0"

  def project do
    [
      app: :external_runtime_transport,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Elixir-first external runtime transport foundations for clean provider " <>
      "interop, adapter boundaries, and downstream AI SDK integration work."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "GitHub" => @source_url,
        "HexDocs" => "https://hexdocs.pm/external_runtime_transport"
      },
      maintainers: ["nshkrdotcom"],
      files: [
        "lib",
        "assets/*.svg",
        "CHANGELOG.md",
        "LICENSE",
        "README.md",
        "mix.exs"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "main",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Overview: ["README.md"],
        Project: ["CHANGELOG.md", "LICENSE"]
      ]
    ]
  end
end
