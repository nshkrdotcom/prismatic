defmodule Prismatic.Runtime.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/nshkrdotcom/prismatic"

  def project do
    [
      app: :prismatic,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      build_path: "../../_build",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      dialyzer: dialyzer(),
      name: "Prismatic",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger, :telemetry]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.5.15"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.3"},
      {:nimble_options, "~> 1.1"},
      {:mox, "~> 1.2", only: :test, runtime: false},
      {:plug, "~> 1.19", optional: true, runtime: false},
      {:bandit, "~> 1.10", optional: true, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Shared GraphQL runtime for Prismatic-based Elixir SDKs.
    """
  end

  defp docs do
    [
      main: "Prismatic",
      name: "Prismatic",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      assets: %{"assets" => "assets"},
      logo: "assets/prismatic.svg",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        "guides/getting-started.md",
        "guides/client-configuration.md",
        "guides/oauth-and-token-sources.md",
        "guides/runtime-contract.md",
        "guides/error-handling-and-telemetry.md",
        "guides/developer/provider-sdk-architecture.md",
        "guides/developer/provider-testing-and-ci.md",
        "guides/developer/provider-docs-and-hexdocs.md",
        "guides/developer/provider-schema-reference-generation.md",
        "examples/examples.md"
      ],
      groups_for_extras: [
        Overview: ["README.md"],
        "User Guides": [
          "guides/getting-started.md",
          "guides/client-configuration.md",
          "guides/oauth-and-token-sources.md",
          "guides/runtime-contract.md",
          "guides/error-handling-and-telemetry.md"
        ],
        "Developer Guides": [
          "guides/developer/provider-sdk-architecture.md",
          "guides/developer/provider-testing-and-ci.md",
          "guides/developer/provider-docs-and-hexdocs.md",
          "guides/developer/provider-schema-reference-generation.md"
        ],
        Examples: ["examples/examples.md"],
        Project: ["CHANGELOG.md", "LICENSE"]
      ]
    ]
  end

  defp package do
    [
      name: "prismatic",
      description: description(),
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["nshkrdotcom"]
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit, :plug],
      plt_core_path: "../../_build/plts/core"
    ]
  end
end
