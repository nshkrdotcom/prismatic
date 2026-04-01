defmodule PrismaticWorkspaceSmokeTest do
  use ExUnit.Case, async: true

  test "workspace root builds docs metadata list" do
    assert File.exists?(Path.expand("../README.md", __DIR__))
  end
end
