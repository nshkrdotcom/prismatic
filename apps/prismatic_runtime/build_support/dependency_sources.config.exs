project_root = Path.expand("..", __DIR__)
siblings_root = Path.expand("../../..", project_root)

%{
  deps: %{
    execution_plane: %{
      path: Path.join(siblings_root, "execution_plane/core/execution_plane"),
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "core/execution_plane"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    pristine: %{
      path: Path.join(siblings_root, "pristine/apps/pristine_runtime"),
      github: %{repo: "nshkrdotcom/pristine", branch: "main", subdir: "apps/pristine_runtime"},
      hex: "~> 0.2.1",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    }
  }
}
