defmodule PrismaticCodegen.SourcePolicyTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../..", __DIR__)

  @source_globs [
    "apps/prismatic_codegen/lib/**/*.ex",
    "apps/prismatic_codegen/test/**/*.exs",
    "apps/prismatic_provider_testkit/lib/**/*.ex",
    "apps/prismatic_provider_testkit/test/**/*.exs",
    "apps/prismatic_runtime/lib/**/*.ex",
    "apps/prismatic_runtime/test/**/*.exs",
    "test/**/*.exs",
    "mix.exs",
    "build_support/**/*.exs"
  ]

  @prohibited_tokens [
    "String." <> "to_atom",
    "binary_" <> "to_atom",
    "to_existing_" <> "atom",
    "list_" <> "to_atom",
    "Reg" <> "ex",
    "~" <> "r",
    ":r" <> "e.",
    "String." <> "match",
    "Reg" <> "Exp",
    "reg" <> "exp",
    "re." <> "compile",
    "import " <> "re"
  ]

  test "active source avoids dynamic atom conversion and pattern engines" do
    violations =
      for path <- source_files(),
          token <- @prohibited_tokens,
          file_contains?(path, token) do
        "#{Path.relative_to(path, @repo_root)} contains #{token}"
      end

    assert violations == []
  end

  defp source_files do
    @source_globs
    |> Enum.flat_map(fn glob -> Path.wildcard(Path.join(@repo_root, glob)) end)
    |> Enum.uniq()
    |> Enum.reject(&generated_or_build_path?/1)
    |> Enum.sort()
  end

  defp generated_or_build_path?(path) do
    parts = Path.split(path)

    Enum.any?(parts, &(&1 in ["deps", "_build", "dist", "doc", "tmp", "node_modules"]))
  end

  defp file_contains?(path, token) do
    path
    |> File.read!()
    |> String.contains?(token)
  end
end
