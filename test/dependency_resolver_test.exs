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

    assert {:prismatic, opts} = DependencyResolver.prismatic_runtime()
    assert opts[:path] == Path.join(@project_root, "apps/prismatic_runtime")

    assert {:prismatic_codegen, opts} = DependencyResolver.prismatic_codegen()
    assert opts[:path] == Path.join(@project_root, "apps/prismatic_codegen")

    assert {:prismatic_provider_testkit, opts} = DependencyResolver.prismatic_provider_testkit()
    assert opts[:path] == Path.join(@project_root, "apps/prismatic_provider_testkit")
  end

  test "publishing commands skip workspace paths" do
    System.argv(["hex.build"])

    assert {:prismatic, "~> 0.1.1", []} = DependencyResolver.prismatic_runtime()

    assert {:prismatic_codegen, opts} = DependencyResolver.prismatic_codegen()
    assert opts[:github] == "nshkrdotcom/prismatic"
    refute Keyword.has_key?(opts, :path)

    assert {:prismatic_provider_testkit, opts} = DependencyResolver.prismatic_provider_testkit()
    assert opts[:github] == "nshkrdotcom/prismatic"
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
    assert {:prismatic, "~> 0.1.1"} = find_dependency!(probe_module.project()[:deps], :prismatic)

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

    assert {:prismatic_codegen, "~> 0.1.1"} =
             find_dependency!(probe_module.project()[:deps], :prismatic_codegen)

    on_exit(fn ->
      :code.purge(probe_module)
      :code.delete(probe_module)
    end)
  end

  defp write_transformed_mix_exs!(source_path, destination_path, probe_module, module_declaration) do
    dependency_resolver_path = Path.join(@project_root, "build_support/dependency_resolver.exs")

    source =
      source_path
      |> File.read!()
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

    File.mkdir_p!(Path.dirname(destination_path))
    File.write!(destination_path, source)
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
