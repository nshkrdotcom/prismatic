defmodule PrismaticProviderTestkit.ArtifactsTest do
  use ExUnit.Case, async: true

  alias PrismaticProviderTestkit.Artifacts

  test "detects stale generated files" do
    root = temp_dir()
    path = Path.join(root, "generated/example.ex")
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "old")

    assert ["generated/example.ex"] ==
             Artifacts.stale_files(%{"generated/example.ex" => "new"}, root)
  end

  test "assert_current!/2 succeeds when files match" do
    root = temp_dir()
    path = Path.join(root, "generated/example.ex")
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "fresh")

    assert :ok = Artifacts.assert_current!(%{"generated/example.ex" => "fresh"}, root)
  end

  defp temp_dir do
    path =
      Path.join(
        System.tmp_dir!(),
        "prismatic_provider_testkit_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(path)
    path
  end
end
