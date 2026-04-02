defmodule ExternalRuntimeTransport.MixProject do
  use Mix.Project

  @homepage_url "https://hex.pm/packages/external_runtime_transport"
  @source_url "https://github.com/nshkrdotcom/external_runtime_transport"
  @version "0.1.0"

  def project do
    [
      app: :external_runtime_transport,
      name: "ExternalRuntimeTransport",
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      homepage_url: @homepage_url,
      source_url: @source_url,
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {ExternalRuntimeTransport.Application, []}
    ]
  end

  defp deps do
    [
      {:erlexec, "~> 2.2"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Shared execution-surface substrate for local subprocess, SSH exec, and guest-bridge placement."
  end

  defp package do
    [
      name: "external_runtime_transport",
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "GitHub" => @source_url,
        "Hex" => @homepage_url,
        "HexDocs" => "https://hexdocs.pm/external_runtime_transport"
      },
      maintainers: ["nshkrdotcom"],
      files: [
        "lib",
        "guides",
        "examples",
        "assets/*.svg",
        "CHANGELOG.md",
        "LICENSE",
        "README.md",
        ".formatter.exs",
        "mix.exs"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @homepage_url,
      assets: %{"assets" => "assets"},
      logo: "assets/external_runtime_transport.svg",
      extras: [
        "README.md": [title: "Overview"],
        "guides/getting-started.md": [title: "Getting Started"],
        "guides/execution-surface-contract.md": [title: "Execution Surface Contract"],
        "guides/guest-bridge-contract.md": [title: "Guest Bridge Contract"],
        "CHANGELOG.md": [title: "Changelog"],
        LICENSE: [title: "License"]
      ],
      groups_for_extras: [
        "Project Overview": ["README.md"],
        Guides: [
          "guides/getting-started.md",
          "guides/execution-surface-contract.md",
          "guides/guest-bridge-contract.md"
        ],
        "Project Reference": ["CHANGELOG.md", "LICENSE"]
      ],
      formatters: ["html", "epub", "markdown"]
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      plt_core_path: "priv/plts/core",
      plt_local_path: "priv/plts",
      flags: [:error_handling, :underspecs]
    ]
  end
end
