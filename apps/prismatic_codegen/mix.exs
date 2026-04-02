Code.require_file("../../build_support/dependency_resolver.exs", __DIR__)

defmodule Prismatic.Codegen.MixProject do
  use Mix.Project

  alias Prismatic.Build.DependencyResolver

  @version "0.1.1"
  @source_url "https://github.com/nshkrdotcom/prismatic"

  def project do
    [
      app: :prismatic_codegen,
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
      name: "Prismatic Codegen",
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
      prismatic_runtime_dep(),
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp prismatic_runtime_dep do
    if publishing_package?() or installing_as_dependency?() do
      {:prismatic, "~> 0.1.1"}
    else
      DependencyResolver.prismatic_runtime()
    end
  end

  defp description do
    """
    Shared provider compiler, Provider IR, and rendering package for Prismatic.
    """
  end

  defp docs do
    [
      main: "readme",
      name: "Prismatic Codegen",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      extras: ["README.md", "guides/code-generation.md"],
      groups_for_extras: [
        Overview: ["README.md"],
        Guides: ["guides/code-generation.md"]
      ]
    ]
  end

  defp package do
    [
      name: "prismatic_codegen",
      description: description(),
      files: ~w(lib mix.exs README.md guides),
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
