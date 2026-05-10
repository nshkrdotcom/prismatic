project_root = Path.expand("..", __DIR__)
apps_root = Path.expand("..", project_root)

%{
  deps: %{
    prismatic: %{
      path: Path.join(apps_root, "prismatic_runtime"),
      github: %{repo: "nshkrdotcom/prismatic", branch: "main", subdir: "apps/prismatic_runtime"},
      hex: "~> 0.2.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    }
  }
}
