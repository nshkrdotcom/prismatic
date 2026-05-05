defmodule Prismatic.Workspace.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/nshkrdotcom/prismatic"
  @workspace_packages [
    prismatic: "apps/prismatic_runtime",
    prismatic_codegen: "apps/prismatic_codegen",
    prismatic_provider_testkit: "apps/prismatic_provider_testkit"
  ]

  def project do
    [
      app: :prismatic_workspace,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      blitz_workspace: blitz_workspace(),
      docs: docs(),
      description: description(),
      dialyzer: dialyzer(),
      name: "Prismatic Workspace",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:blitz, "~> 0.2.0", runtime: false},
      workspace_package_deps(),
      {:plug, "~> 1.19", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.2", only: :test, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
    |> List.flatten()
  end

  defp aliases do
    monorepo_aliases = [
      "monorepo.deps.get": ["blitz.workspace deps_get"],
      "monorepo.format": ["blitz.workspace format"],
      "monorepo.compile": ["blitz.workspace compile"],
      "monorepo.test": ["blitz.workspace test"],
      "monorepo.credo": ["blitz.workspace credo"],
      "monorepo.dialyzer": ["compile", "dialyzer --force-check"],
      "monorepo.docs": ["blitz.workspace docs"]
    ]

    mr_aliases = [
      "mr.deps.get": ["monorepo.deps.get"],
      "mr.format": ["monorepo.format"],
      "mr.compile": ["monorepo.compile"],
      "mr.test": ["monorepo.test"],
      "mr.credo": ["monorepo.credo"],
      "mr.dialyzer": ["monorepo.dialyzer"],
      "mr.docs": ["monorepo.docs"]
    ]

    [
      ci: [
        "monorepo.deps.get",
        "monorepo.format --check-formatted",
        "monorepo.compile",
        "monorepo.test",
        "monorepo.credo --strict",
        "monorepo.dialyzer",
        "monorepo.docs"
      ],
      quality: ["monorepo.credo --strict", "monorepo.dialyzer"],
      "docs.all": ["monorepo.docs"]
    ] ++ monorepo_aliases ++ mr_aliases
  end

  defp description do
    """
    Tooling workspace for the Prismatic GraphQL-native SDK monorepo.
    """
  end

  defp package do
    [
      name: "prismatic_workspace",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files:
        ~w(assets build_support .formatter.exs mix.exs README.md CHANGELOG.md LICENSE TASKS.md guides examples),
      exclude_patterns: [
        "**/_build/**",
        "**/deps/**",
        "**/doc/**",
        "**/*.beam",
        "**/*.plt",
        "**/*.plt.hash"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "Prismatic Workspace",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      assets: %{"assets" => "assets"},
      logo: "assets/prismatic.svg",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        "TASKS.md",
        "guides/workspace-overview.md",
        "guides/getting-started.md",
        "guides/runtime-and-execution.md",
        "guides/codegen-and-provider-ir.md",
        "guides/provider-testkit.md",
        "guides/maintaining-the-monorepo.md",
        "examples/index.md"
      ],
      groups_for_extras: [
        Project: [
          "README.md",
          "CHANGELOG.md",
          "LICENSE",
          "TASKS.md"
        ],
        "User Guides": [
          "guides/workspace-overview.md",
          "guides/getting-started.md",
          "guides/runtime-and-execution.md",
          "guides/codegen-and-provider-ir.md",
          "guides/provider-testkit.md"
        ],
        "Developer Guides": [
          "guides/maintaining-the-monorepo.md"
        ],
        Examples: [
          "examples/index.md"
        ]
      ]
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_add_deps: :app_tree,
      plt_add_apps: [:mix, :blitz, :plug],
      plt_core_path: "_build/plts/core",
      paths: workspace_dialyzer_paths()
    ]
  end

  defp workspace_package_deps do
    if publishing_package?() or installing_as_dependency?() do
      Enum.map(@workspace_packages, fn {app, _path} -> {app, "~> #{@version}"} end)
    else
      Enum.map(@workspace_packages, fn {app, path} -> {app, [path: path]} end)
    end
  end

  defp publishing_package?, do: Enum.any?(System.argv(), &(&1 in ["hex.build", "hex.publish"]))

  defp installing_as_dependency?, do: Enum.member?(Path.split(__DIR__), "deps")

  defp workspace_dialyzer_paths do
    build_path = Path.join("_build", to_string(Mix.env()))

    [
      Path.join([build_path, "lib", "prismatic_workspace", "ebin"])
      | Enum.map(@workspace_packages, fn {app, _path} ->
          Path.join([build_path, "lib", Atom.to_string(app), "ebin"])
        end)
    ]
  end

  defp blitz_workspace do
    [
      root: __DIR__,
      projects: [".", "apps/*"],
      isolation: [
        deps_path: false,
        build_path: false,
        lockfile: false,
        hex_home: "_build/hex",
        unset_env: ["HEX_API_KEY"]
      ],
      parallelism: [
        env: "PRISMATIC_MONOREPO_MAX_CONCURRENCY",
        multiplier: :auto,
        base: [
          deps_get: 1,
          format: 4,
          compile: 2,
          test: 1,
          credo: 2,
          dialyzer: 1,
          docs: 1
        ],
        overrides: [
          deps_get: 1,
          compile: 1,
          test: 1,
          credo: 1,
          docs: 1
        ]
      ],
      tasks: [
        deps_get: [args: ["deps.get"], preflight?: false],
        format: [args: ["format"]],
        compile: [args: ["compile", "--warnings-as-errors"], preflight?: true],
        test: [args: ["test"], mix_env: "test", color: true, preflight?: true],
        credo: [args: ["credo"], preflight?: true],
        dialyzer: [args: ["dialyzer", "--force-check"], preflight?: true],
        docs: [args: ["docs"], preflight?: true]
      ]
    ]
  end
end
