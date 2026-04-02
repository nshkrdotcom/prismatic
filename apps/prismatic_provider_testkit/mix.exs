Code.require_file("../../build_support/dependency_resolver.exs", __DIR__)

defmodule Prismatic.ProviderTestkit.MixProject do
  use Mix.Project

  alias Prismatic.Build.DependencyResolver

  @version "0.2.0"
  @source_url "https://github.com/nshkrdotcom/prismatic"

  def project do
    [
      app: :prismatic_provider_testkit,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      build_path: "../../_build",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      dialyzer: dialyzer(),
      name: "Prismatic Provider Testkit",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      prismatic_codegen_dep(),
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp prismatic_codegen_dep do
    if publishing_package?() or installing_as_dependency?() do
      {:prismatic_codegen, "~> 0.2.0"}
    else
      DependencyResolver.prismatic_codegen()
    end
  end

  defp description do
    """
    Shared freshness and conformance helpers for Prismatic provider SDKs.
    """
  end

  defp docs do
    [
      main: "readme",
      name: "Prismatic Provider Testkit",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      extras: ["README.md"],
      groups_for_extras: [
        Overview: ["README.md"]
      ]
    ]
  end

  defp package do
    [
      name: "prismatic_provider_testkit",
      description: description(),
      files: ~w(lib mix.exs README.md),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["nshkrdotcom"]
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      plt_core_path: "../../_build/plts/core"
    ]
  end

  defp publishing_package?, do: Enum.any?(System.argv(), &(&1 in ["hex.build", "hex.publish"]))

  defp installing_as_dependency? do
    Enum.member?(Path.split(__DIR__), "deps")
  end
end
