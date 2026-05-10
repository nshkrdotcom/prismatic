defmodule Prismatic.DependencySourcesTest do
  use ExUnit.Case, async: false

  @project_root Path.expand("..", __DIR__)
  @runtime_root Path.join(@project_root, "apps/prismatic_runtime")
  @codegen_root Path.join(@project_root, "apps/prismatic_codegen")
  @testkit_root Path.join(@project_root, "apps/prismatic_provider_testkit")

  setup do
    original_argv = System.argv()

    on_exit(fn ->
      System.argv(original_argv)
    end)

    :ok
  end

  test "deps.get inside the workspace keeps sibling paths available" do
    System.argv(["deps.get"])

    assert {:pristine, opts} = DependencySources.dep(:pristine, @runtime_root)
    assert opts[:path] == Path.expand("../pristine/apps/pristine_runtime", @project_root)

    assert {:execution_plane, opts} = DependencySources.dep(:execution_plane, @runtime_root)
    assert opts[:path] == Path.expand("../execution_plane/core/execution_plane", @project_root)

    assert {:prismatic, opts} = DependencySources.dep(:prismatic, @project_root)
    assert opts[:path] == Path.join(@project_root, "apps/prismatic_runtime")

    assert {:prismatic_codegen, opts} = DependencySources.dep(:prismatic_codegen, @project_root)
    assert opts[:path] == Path.join(@project_root, "apps/prismatic_codegen")

    assert {:prismatic_provider_testkit, opts} =
             DependencySources.dep(:prismatic_provider_testkit, @project_root)

    assert opts[:path] == Path.join(@project_root, "apps/prismatic_provider_testkit")
  end

  test "publishing commands skip workspace paths" do
    System.argv(["hex.build"])

    assert {:pristine, "~> 0.2.1"} = DependencySources.dep(:pristine, @runtime_root)
    assert {:execution_plane, "~> 0.1.0"} = DependencySources.dep(:execution_plane, @runtime_root)
    assert {:prismatic, "~> 0.2.0"} = DependencySources.dep(:prismatic, @project_root)
    assert {:prismatic, "~> 0.2.0"} = DependencySources.dep(:prismatic, @codegen_root)

    assert {:prismatic_codegen, "~> 0.2.0"} =
             DependencySources.dep(:prismatic_codegen, @project_root)

    assert {:prismatic_codegen, "~> 0.2.0"} =
             DependencySources.dep(:prismatic_codegen, @testkit_root)

    assert {:prismatic_provider_testkit, "~> 0.2.0"} =
             DependencySources.dep(:prismatic_provider_testkit, @project_root)
  end

  test "github fallback metadata keeps package subdirectories precise" do
    assert %{deps: deps} =
             @project_root
             |> Path.join("build_support/dependency_sources.config.exs")
             |> eval_config!()

    assert deps.prismatic_codegen.github == %{
             repo: "nshkrdotcom/prismatic",
             branch: "main",
             subdir: "apps/prismatic_codegen"
           }

    assert %{deps: deps} =
             @runtime_root
             |> Path.join("build_support/dependency_sources.config.exs")
             |> eval_config!()

    assert deps.execution_plane.github == %{
             repo: "nshkrdotcom/execution_plane",
             branch: "main",
             subdir: "core/execution_plane"
           }
  end

  defp eval_config!(path) do
    {config, _binding} = Code.eval_file(path)
    config
  end
end
