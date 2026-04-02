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
             schema: %ProviderIR.Schema{
               query_type_name: "Query",
               mutation_type_name: "Mutation",
               subscription_type_name: "Subscription"
             },
             artifact_plan: %ProviderIR.ArtifactPlan{files: files}
           } = Compiler.compile!(provider)

    assert "lib/example_sdk/generated/operations/viewer.ex" in files
    assert "lib/example_sdk/generated/models/account.ex" in files
    assert "lib/example_sdk/generated/enums/account_status.ex" in files
    assert "guides/api/graph-reference.md" in files
    assert "guides/api/queries.md" in files
    assert "guides/api/queries/viewer-query.md" in files
    assert "guides/api/mutations.md" in files
    assert "guides/api/mutations/update_viewer-mutation.md" in files
    assert "guides/api/subscriptions.md" in files
    assert "guides/api/subscriptions/account_updated-subscription.md" in files
    assert "guides/api/objects.md" in files
    assert "guides/api/objects/account-object.md" in files
    assert "guides/api/objects/project-object.md" in files
    assert "guides/api/input-objects.md" in files
    assert "guides/api/input-objects/viewer_input-input.md" in files
    assert "guides/api/interfaces.md" in files
    assert "guides/api/interfaces/node-interface.md" in files
    assert "guides/api/unions.md" in files
    assert "guides/api/unions/search_result-union.md" in files
    assert "guides/api/enums.md" in files
    assert "guides/api/enums/account_status-enum.md" in files
    assert "guides/api/scalars.md" in files
    assert "guides/api/scalars/date_time-scalar.md" in files
    assert "lib/example_sdk/queries.ex" in files
    assert "lib/example_sdk/queries/viewer.ex" in files
    assert "lib/example_sdk/mutations/update_viewer.ex" in files
    assert "lib/example_sdk/subscriptions/account_updated.ex" in files
    assert "lib/example_sdk/objects/account.ex" in files
    assert "lib/example_sdk/inputs/viewer_input.ex" in files
    assert "lib/example_sdk/interfaces/node.ex" in files
    assert "lib/example_sdk/unions/search_result.ex" in files
    assert "lib/example_sdk/enums/account_status.ex" in files
    assert "lib/example_sdk/scalars/date_time.ex" in files
  end

  test "renders operation module, model module, and full schema docs artifact set" do
    provider = fixture_provider(temp_root())
    ir = Compiler.compile!(provider)
    rendered_files = Compiler.render!(provider)
    rendered_map = rendered_file_map(rendered_files)

    assert Map.has_key?(rendered_map, "lib/example_sdk/generated/operations/viewer.ex")
    assert Map.has_key?(rendered_map, "lib/example_sdk/generated/models/account.ex")
    assert Map.has_key?(rendered_map, "lib/example_sdk/generated/enums/account_status.ex")
    assert Map.has_key?(rendered_map, "guides/api/graph-reference.md")
    assert Map.has_key?(rendered_map, "guides/api/queries.md")
    assert Map.has_key?(rendered_map, "guides/api/queries/viewer-query.md")
    assert Map.has_key?(rendered_map, "guides/api/mutations/update_viewer-mutation.md")
    assert Map.has_key?(rendered_map, "guides/api/subscriptions/account_updated-subscription.md")
    assert Map.has_key?(rendered_map, "guides/api/objects/account-object.md")
    assert Map.has_key?(rendered_map, "guides/api/input-objects/viewer_input-input.md")
    assert Map.has_key?(rendered_map, "guides/api/interfaces/node-interface.md")
    assert Map.has_key?(rendered_map, "guides/api/unions/search_result-union.md")
    assert Map.has_key?(rendered_map, "guides/api/enums/account_status-enum.md")
    assert Map.has_key?(rendered_map, "guides/api/scalars/date_time-scalar.md")
    assert Map.has_key?(rendered_map, "lib/example_sdk/queries.ex")
    assert Map.has_key?(rendered_map, "lib/example_sdk/queries/viewer.ex")
    assert Map.has_key?(rendered_map, "lib/example_sdk/objects/account.ex")
    assert Map.has_key?(rendered_map, "lib/example_sdk/enums/account_status.ex")
    assert Map.has_key?(rendered_map, "lib/example_sdk/scalars/date_time.ex")

    assert rendered_map["lib/example_sdk/generated/operations/viewer.ex"] =~
             "defmodule ExampleSDK.Generated.Operations.Viewer do"

    assert rendered_map["lib/example_sdk/generated/operations/viewer.ex"] =~
             "ExampleSDK.Client.execute_operation(client, @operation, variables, opts)"

    assert rendered_map["lib/example_sdk/generated/models/account.ex"] =~
             "defmodule ExampleSDK.Generated.Models.Account do"

    assert rendered_map["lib/example_sdk/queries.ex"] =~
             "defmodule ExampleSDK.Queries do"

    assert rendered_map["lib/example_sdk/queries/viewer.ex"] =~
             "defmodule ExampleSDK.Queries.Viewer do"

    assert rendered_map["lib/example_sdk/queries/viewer.ex"] =~
             "GraphQL query field `viewer`."

    assert rendered_map["lib/example_sdk/objects/account.ex"] =~
             "defmodule ExampleSDK.Objects.Account do"

    assert rendered_map["lib/example_sdk/objects/account.ex"] =~
             "GraphQL object `Account`."

    assert rendered_map["guides/api/graph-reference.md"] =~
             "# API Reference"

    assert rendered_map["guides/api/graph-reference.md"] =~
             "schema.graphql"

    assert rendered_map["guides/api/queries/viewer-query.md"] =~
             "Fetch the authenticated account."

    assert rendered_map["guides/api/queries/viewer-query.md"] =~
             "[`Account`](../objects/account-object.md)"

    assert rendered_map["guides/api/objects/account-object.md"] =~
             "[`Project`](project-object.md)"

    assert rendered_map["guides/api/input-objects/viewer_input-input.md"] =~
             "ACTIVE"

    assert rendered_map["guides/api/interfaces/node-interface.md"] =~
             "[`Account`](../objects/account-object.md)"

    assert rendered_map["guides/api/unions/search_result-union.md"] =~
             "[`Project`](../objects/project-object.md)"

    assert rendered_map["guides/api/enums/account_status-enum.md"] =~
             "Use PAUSED instead."

    assert rendered_map["guides/api/scalars/date_time-scalar.md"] =~
             "https://example.com/scalars/datetime"

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

    unexpected_path = Path.join(root, "guides/api/queries/old-query.md")
    File.mkdir_p!(Path.dirname(unexpected_path))
    File.write!(unexpected_path, "obsolete")

    assert "guides/api/queries/old-query.md" in Verify.stale_files(provider)

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
        schema_sdl_path: Path.join(fixture_root, "schema.graphql"),
        documents_root: Path.join(fixture_root, "documents")
      ],
      output: [
        root: root,
        lib_root: "lib/example_sdk/generated",
        docs_root: "guides/api"
      ]
    )
  end

  defp temp_root do
    root = Path.join(System.tmp_dir!(), "prismatic_codegen_#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    root
  end
end
