project_root = Path.expand("..", __DIR__)
siblings_root = Path.expand("..", project_root)

%{
  deps: %{
    blitz: %{
      path: Path.join(siblings_root, "blitz"),
      github: %{repo: "nshkrdotcom/blitz", branch: "main"},
      hex: "~> 0.3.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    prismatic: %{
      path: Path.join(project_root, "apps/prismatic_runtime"),
      github: %{repo: "nshkrdotcom/prismatic", branch: "main", subdir: "apps/prismatic_runtime"},
      hex: "~> 0.2.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    prismatic_codegen: %{
      path: Path.join(project_root, "apps/prismatic_codegen"),
      github: %{repo: "nshkrdotcom/prismatic", branch: "main", subdir: "apps/prismatic_codegen"},
      hex: "~> 0.2.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    prismatic_provider_testkit: %{
      path: Path.join(project_root, "apps/prismatic_provider_testkit"),
      github: %{
        repo: "nshkrdotcom/prismatic",
        branch: "main",
        subdir: "apps/prismatic_provider_testkit"
      },
      hex: "~> 0.2.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    }
  }
}
