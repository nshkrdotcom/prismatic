project_root = Path.expand("..", __DIR__)
apps_root = Path.expand("..", project_root)

%{
  deps: %{
    prismatic_codegen: %{
      path: Path.join(apps_root, "prismatic_codegen"),
      github: %{repo: "nshkrdotcom/prismatic", branch: "main", subdir: "apps/prismatic_codegen"},
      hex: "~> 0.2.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    }
  }
}
