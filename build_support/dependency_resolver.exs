defmodule Prismatic.Build.DependencyResolver do
  @moduledoc false

  @workspace_root Path.expand("..", __DIR__)
  @repo "nshkrdotcom/prismatic"

  def prismatic_runtime(opts \\ []) do
    case workspace_path(["apps/prismatic_runtime"]) do
      nil -> {:prismatic, "~> 0.2.0", opts}
      path -> {:prismatic, Keyword.merge([path: path], opts)}
    end
  end

  def prismatic_codegen(opts \\ []) do
    resolve(
      :prismatic_codegen,
      ["apps/prismatic_codegen"],
      [github: @repo, branch: "master", subdir: "apps/prismatic_codegen"],
      opts
    )
  end

  def prismatic_provider_testkit(opts \\ []) do
    resolve(
      :prismatic_provider_testkit,
      ["apps/prismatic_provider_testkit"],
      [github: @repo, branch: "master", subdir: "apps/prismatic_provider_testkit"],
      opts
    )
  end

  defp resolve(app, local_paths, fallback_opts, opts) do
    case workspace_path(local_paths) do
      nil -> {app, Keyword.merge(fallback_opts, opts)}
      path -> {app, Keyword.merge([path: path], opts)}
    end
  end

  defp workspace_path(local_paths) do
    if prefer_workspace_paths?() do
      Enum.find_value(local_paths, &existing_path/1)
    end
  end

  defp prefer_workspace_paths? do
    not publishing_package?() and not Enum.member?(Path.split(@workspace_root), "deps")
  end

  defp publishing_package?, do: Enum.any?(System.argv(), &(&1 in ["hex.build", "hex.publish"]))

  defp existing_path(relative_path) do
    expanded_path = Path.expand(relative_path, @workspace_root)

    if File.dir?(expanded_path) do
      expanded_path
    end
  end
end
