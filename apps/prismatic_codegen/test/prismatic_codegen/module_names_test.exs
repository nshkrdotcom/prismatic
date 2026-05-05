defmodule PrismaticCodegen.ModuleNamesTest do
  use ExUnit.Case, async: true

  alias PrismaticCodegen.ModuleNames

  test "generated module names accept bounded source strings" do
    assert ModuleNames.generated!(ExampleSDK.Generated, ["Operations", "viewer_query"]) ==
             ExampleSDK.Generated.Operations.ViewerQuery

    assert ModuleNames.generated!(ExampleSDK.Generated, ["Models", "Account"]) ==
             ExampleSDK.Generated.Models.Account
  end

  test "generated module names reject invalid source strings" do
    for segment <- ["", "123viewer", "viewer-name", "viewer.name", "viewer name", "viewer$"] do
      error =
        assert_raise ArgumentError, fn ->
          ModuleNames.generated!(ExampleSDK.Generated, ["Operations", segment])
        end

      assert error.message =~ "invalid generated module segment"
    end
  end

  test "generated module names reject non-string source segments" do
    error =
      assert_raise ArgumentError, fn ->
        ModuleNames.generated!(ExampleSDK.Generated, ["Operations", :viewer])
      end

    assert error.message =~ "module segment must be a string"
  end

  test "existing module lookup accepts only valid existing aliases" do
    assert ModuleNames.existing!(["PrismaticCodegen", "ModuleNames"]) == ModuleNames

    error =
      assert_raise ArgumentError, fn ->
        ModuleNames.existing!(["PrismaticCodegen", "bad-name"])
      end

    assert error.message =~ "invalid generated module segment"
  end
end
