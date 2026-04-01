defmodule PrismaticCodegen.CompilerTest do
  use ExUnit.Case, async: true

  alias PrismaticCodegen.Compiler
  alias PrismaticCodegen.Provider
  alias PrismaticCodegen.ProviderIR
  alias PrismaticCodegen.Verify

  test "compiles introspection and curated documents into provider ir" do
    provider = fixture_provider(temp_root())

    assert %ProviderIR{
             provider: %ProviderIR.Provider{
               name: "Example",
               namespace: ExampleSDK.Generated,
               client_module: ExampleSDK.Client
             },
             documents: [
               %ProviderIR.Document{
                 id: "viewer",
                 name: "Viewer",
                 kind: :query,
                 root_field: "viewer"
               }
             ],
             operations: [
               %ProviderIR.Operation{id: "viewer", module: ExampleSDK.Generated.Operations.Viewer}
             ],
             models: [
               %ProviderIR.Model{name: "Account", module: ExampleSDK.Generated.Models.Account}
             ],
             enums: [
               %ProviderIR.Enum{
                 name: "AccountStatus",
                 module: ExampleSDK.Generated.Enums.AccountStatus
               }
             ],
             artifact_plan: %ProviderIR.ArtifactPlan{files: files}
           } = Compiler.compile!(provider)

    assert "lib/example_sdk/generated/operations/viewer.ex" in files
    assert "lib/example_sdk/generated/models/account.ex" in files
    assert "lib/example_sdk/generated/enums/account_status.ex" in files
    assert "guides/generated/README.md" in files
    assert "guides/generated/provider.md" in files
    assert "guides/generated/operations/README.md" in files
    assert "guides/generated/operations/viewer.md" in files
    assert "guides/generated/models/README.md" in files
    assert "guides/generated/models/account.md" in files
    assert "guides/generated/enums/README.md" in files
    assert "guides/generated/enums/account_status.md" in files
  end

  test "renders operation module, model module, and docs artifact" do
    provider = fixture_provider(temp_root())
    ir = Compiler.compile!(provider)
    rendered_files = Compiler.render!(provider)
    rendered_map = rendered_file_map(rendered_files)

    assert Map.has_key?(rendered_map, "lib/example_sdk/generated/operations/viewer.ex")
    assert Map.has_key?(rendered_map, "lib/example_sdk/generated/models/account.ex")
    assert Map.has_key?(rendered_map, "lib/example_sdk/generated/enums/account_status.ex")
    assert Map.has_key?(rendered_map, "guides/generated/README.md")
    assert Map.has_key?(rendered_map, "guides/generated/provider.md")
    assert Map.has_key?(rendered_map, "guides/generated/operations/README.md")
    assert Map.has_key?(rendered_map, "guides/generated/operations/viewer.md")
    assert Map.has_key?(rendered_map, "guides/generated/models/README.md")
    assert Map.has_key?(rendered_map, "guides/generated/models/account.md")
    assert Map.has_key?(rendered_map, "guides/generated/enums/README.md")
    assert Map.has_key?(rendered_map, "guides/generated/enums/account_status.md")

    assert rendered_map["lib/example_sdk/generated/operations/viewer.ex"] =~
             "defmodule ExampleSDK.Generated.Operations.Viewer do"

    assert rendered_map["lib/example_sdk/generated/operations/viewer.ex"] =~
             "ExampleSDK.Client.execute_operation(client, @operation, variables, opts)"

    assert rendered_map["lib/example_sdk/generated/models/account.ex"] =~
             "defmodule ExampleSDK.Generated.Models.Account do"

    assert rendered_map["guides/generated/README.md"] =~
             "# Generated Reference"

    assert rendered_map["guides/generated/provider.md"] =~
             "https://api.example.com/graphql"

    assert rendered_map["guides/generated/operations/viewer.md"] =~
             "ExampleSDK.Generated.Operations.Viewer"

    assert rendered_map["guides/generated/models/account.md"] =~
             "| `status` | `:status` | `ENUM` | [`AccountStatus`](../enums/account_status.md) |"

    assert rendered_map["guides/generated/enums/account_status.md"] =~
             "`ACTIVE`"

    rendered_files
    |> Enum.reject(&(&1.kind == :docs))
    |> Enum.each(fn file ->
      assert {:ok, _quoted} = Code.string_to_quoted(file.content),
             "expected #{file.path} to be valid Elixir"
    end)

    assert length(rendered_files) == length(ir.artifact_plan.files)
  end

  test "verify fails when a generated file is stale" do
    root = temp_root()
    provider = fixture_provider(root)

    assert :ok = Compiler.generate!(provider)

    stale_file = Path.join(root, "lib/example_sdk/generated/operations/viewer.ex")
    File.write!(stale_file, "stale")

    assert ["lib/example_sdk/generated/operations/viewer.ex" | _rest] =
             Verify.stale_files(provider)

    assert_raise ArgumentError, ~r/stale generated artifacts/, fn ->
      Verify.assert_current!(provider)
    end
  end

  test "verify reports unexpected generated files and generate prunes them" do
    root = temp_root()
    provider = fixture_provider(root)

    assert :ok = Compiler.generate!(provider)

    unexpected_path = Path.join(root, "guides/generated/operations/old.md")
    File.mkdir_p!(Path.dirname(unexpected_path))
    File.write!(unexpected_path, "obsolete")

    assert "guides/generated/operations/old.md" in Verify.stale_files(provider)

    assert :ok = Compiler.generate!(provider)
    refute File.exists?(unexpected_path)
  end

  defp rendered_file_map(rendered_files) do
    Map.new(rendered_files, fn file -> {file.path, file.content} end)
  end

  defp fixture_provider(root) do
    fixture_root = Path.expand("../fixtures/generic", __DIR__)

    Provider.new!(
      name: "Example",
      namespace: ExampleSDK.Generated,
      client_module: ExampleSDK.Client,
      base_url: "https://api.example.com/graphql",
      auth: %{type: :bearer},
      source: [
        introspection_path: Path.join(fixture_root, "introspection.json"),
        documents_root: Path.join(fixture_root, "documents")
      ],
      output: [
        root: root,
        lib_root: "lib/example_sdk/generated",
        docs_root: "guides/generated"
      ]
    )
  end

  defp temp_root do
    root = Path.join(System.tmp_dir!(), "prismatic_codegen_#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    root
  end
end
