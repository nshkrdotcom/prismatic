defmodule Prismatic.DependencyResolverTest do
  use ExUnit.Case, async: false

  alias Prismatic.Build.DependencyResolver

  @moduletag :tmp_dir

  @project_root Path.expand("..", __DIR__)

  setup do
    original_argv = System.argv()

    on_exit(fn ->
      System.argv(original_argv)
    end)

    :ok
  end

  test "deps.get inside the workspace keeps sibling paths available" do
    System.argv(["deps.get"])

    assert {:pristine, opts} = DependencyResolver.pristine_runtime()
    assert opts[:path] == Path.expand("../pristine/apps/pristine_runtime", @project_root)

    assert {:execution_plane, opts} = DependencyResolver.execution_plane()
    assert opts[:path] == Path.expand("../execution_plane", @project_root)

    assert {:prismatic, opts} = DependencyResolver.prismatic_runtime()
    assert opts[:path] == Path.join(@project_root, "apps/prismatic_runtime")

    assert {:prismatic_codegen, opts} = DependencyResolver.prismatic_codegen()
    assert opts[:path] == Path.join(@project_root, "apps/prismatic_codegen")

    assert {:prismatic_provider_testkit, opts} = DependencyResolver.prismatic_provider_testkit()
    assert opts[:path] == Path.join(@project_root, "apps/prismatic_provider_testkit")
  end

  test "publishing commands skip workspace paths" do
    System.argv(["hex.build"])

    assert {:pristine, "~> 0.2.1", []} = DependencyResolver.pristine_runtime()
    assert {:execution_plane, "~> 0.1.0", []} = DependencyResolver.execution_plane()
    assert {:prismatic, "~> 0.2.0", []} = DependencyResolver.prismatic_runtime()

    assert {:prismatic_codegen, opts} = DependencyResolver.prismatic_codegen()
    assert opts[:github] == "nshkrdotcom/prismatic"
    assert opts[:branch] == "main"
    refute Keyword.has_key?(opts, :path)

    assert {:prismatic_provider_testkit, opts} = DependencyResolver.prismatic_provider_testkit()
    assert opts[:github] == "nshkrdotcom/prismatic"
    assert opts[:branch] == "main"
    refute Keyword.has_key?(opts, :path)
  end

  test "prismatic_codegen uses Hex runtime deps for publishing commands", %{tmp_dir: tmp_dir} do
    probe_module =
      Module.concat([
        Prismatic,
        TestSupport,
        "CodegenMixProbe#{System.unique_integer([:positive])}"
      ])

    mix_path = Path.join([tmp_dir, "standalone", "prismatic_codegen", "mix.exs"])

    write_transformed_mix_exs!(
      Path.join(@project_root, "apps/prismatic_codegen/mix.exs"),
      mix_path,
      probe_module,
      "defmodule Prismatic.Codegen.MixProject do"
    )

    System.argv(["hex.build"])

    assert [{^probe_module, _beam}] = Code.compile_file(mix_path)
    assert {:prismatic, "~> 0.2.0"} = find_dependency!(probe_module.project()[:deps], :prismatic)

    on_exit(fn ->
      :code.purge(probe_module)
      :code.delete(probe_module)
    end)
  end

  test "prismatic_runtime uses Hex pristine deps for publishing commands", %{tmp_dir: tmp_dir} do
    probe_module =
      Module.concat([
        Prismatic,
        TestSupport,
        "RuntimeMixProbe#{System.unique_integer([:positive])}"
      ])

    mix_path = Path.join([tmp_dir, "standalone", "prismatic_runtime", "mix.exs"])

    write_transformed_mix_exs!(
      Path.join(@project_root, "apps/prismatic_runtime/mix.exs"),
      mix_path,
      probe_module,
      "defmodule Prismatic.Runtime.MixProject do"
    )

    System.argv(["hex.build"])

    assert [{^probe_module, _beam}] = Code.compile_file(mix_path)

    assert {:pristine, "~> 0.2.1", []} =
             find_dependency!(probe_module.project()[:deps], :pristine)

    assert {:execution_plane, "~> 0.1.0", []} =
             find_dependency!(probe_module.project()[:deps], :execution_plane)

    on_exit(fn ->
      :code.purge(probe_module)
      :code.delete(probe_module)
    end)
  end

  test "prismatic_provider_testkit uses Hex codegen deps for release-locking commands", %{
    tmp_dir: tmp_dir
  } do
    probe_module =
      Module.concat([
        Prismatic,
        TestSupport,
        "ProviderTestkitMixProbe#{System.unique_integer([:positive])}"
      ])

    mix_path = Path.join([tmp_dir, "standalone", "prismatic_provider_testkit", "mix.exs"])

    write_transformed_mix_exs!(
      Path.join(@project_root, "apps/prismatic_provider_testkit/mix.exs"),
      mix_path,
      probe_module,
      "defmodule Prismatic.ProviderTestkit.MixProject do"
    )

    System.argv(["hex.build"])

    assert [{^probe_module, _beam}] = Code.compile_file(mix_path)

    assert {:prismatic_codegen, "~> 0.2.0"} =
             find_dependency!(probe_module.project()[:deps], :prismatic_codegen)

    on_exit(fn ->
      :code.purge(probe_module)
      :code.delete(probe_module)
    end)
  end

  test "prismatic_provider_testkit installed from git keeps git codegen deps", %{tmp_dir: tmp_dir} do
    probe_module =
      Module.concat([
        Prismatic,
        TestSupport,
        "ProviderTestkitGitProbe#{System.unique_integer([:positive])}"
      ])

    resolver_module =
      Module.concat([
        Prismatic,
        TestSupport,
        "DependencyResolverProbe#{System.unique_integer([:positive])}"
      ])

    dependency_root = Path.join([tmp_dir, "deps", "prismatic_provider_testkit"])
    mix_path = Path.join([dependency_root, "apps", "prismatic_provider_testkit", "mix.exs"])

    write_transformed_mix_exs!(
      Path.join(@project_root, "apps/prismatic_provider_testkit/mix.exs"),
      mix_path,
      probe_module,
      "defmodule Prismatic.ProviderTestkit.MixProject do",
      copy_dependency_resolver?: true,
      resolver_module: resolver_module
    )

    File.mkdir_p!(dependency_root)
    File.write!(Path.join(dependency_root, ".git"), "gitdir: ./.git/worktrees/test\n")

    System.argv([])

    assert [{^probe_module, _beam}] = Code.compile_file(mix_path)

    assert {:prismatic_codegen, opts} =
             find_dependency!(probe_module.project()[:deps], :prismatic_codegen)

    assert opts[:github] == "nshkrdotcom/prismatic"
    assert opts[:branch] == "main"
    assert opts[:subdir] == "apps/prismatic_codegen"

    on_exit(fn ->
      :code.purge(probe_module)
      :code.delete(probe_module)
      :code.purge(resolver_module)
      :code.delete(resolver_module)
    end)
  end

  defp write_transformed_mix_exs!(
         source_path,
         destination_path,
         probe_module,
         module_declaration,
         opts \\ []
       ) do
    dependency_resolver_path =
      if opts[:copy_dependency_resolver?] do
        destination_dependency_resolver_path =
          Path.join([
            Path.dirname(destination_path),
            "../../build_support/dependency_resolver.exs"
          ])
          |> Path.expand()

        resolver_module =
          opts[:resolver_module] ||
            raise ArgumentError, "copy_dependency_resolver? requires :resolver_module"

        resolver_source =
          Path.join(@project_root, "build_support/dependency_resolver.exs")
          |> File.read!()
          |> String.replace(
            "defmodule Prismatic.Build.DependencyResolver do",
            "defmodule #{inspect(resolver_module)} do",
            global: false
          )

        File.mkdir_p!(Path.dirname(destination_dependency_resolver_path))
        File.write!(destination_dependency_resolver_path, resolver_source)

        destination_dependency_resolver_path
      else
        Path.join(@project_root, "build_support/dependency_resolver.exs")
      end

    source =
      source_path
      |> File.read!()
      |> maybe_replace_resolver_guard(opts)
      |> String.replace(
        "Code.require_file(\"../../build_support/dependency_resolver.exs\", __DIR__)",
        "Code.require_file(#{inspect(dependency_resolver_path)})",
        global: false
      )
      |> String.replace(
        module_declaration,
        "defmodule #{inspect(probe_module)} do",
        global: false
      )
      |> maybe_replace_alias(opts)

    File.mkdir_p!(Path.dirname(destination_path))
    File.write!(destination_path, source)
  end

  defp maybe_replace_alias(source, opts) do
    case opts[:resolver_module] do
      nil ->
        source

      resolver_module ->
        String.replace(
          source,
          "alias Prismatic.Build.DependencyResolver",
          "alias #{inspect(resolver_module)}, as: DependencyResolver",
          global: false
        )
    end
  end

  defp maybe_replace_resolver_guard(source, opts) do
    case opts[:resolver_module] do
      nil ->
        source

      resolver_module ->
        String.replace(
          source,
          "Code.ensure_loaded?(Prismatic.Build.DependencyResolver)",
          "Code.ensure_loaded?(#{inspect(resolver_module)})",
          global: false
        )
    end
  end

  defp find_dependency!(deps, app) do
    Enum.find(deps, fn
      {^app, _requirement} -> true
      {^app, _requirement, _opts} -> true
      {^app, opts} when is_list(opts) -> true
      _other -> false
    end) || flunk("expected dependency #{inspect(app)} to be present")
  end
end
