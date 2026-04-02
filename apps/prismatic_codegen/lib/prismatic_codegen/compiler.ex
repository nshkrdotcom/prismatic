defmodule PrismaticCodegen.Compiler do
  @moduledoc """
  Compiler from provider definitions into a GraphQL-native provider IR.
  """

  alias Prismatic.Operation
  alias PrismaticCodegen.Provider
  alias PrismaticCodegen.ProviderIR
  alias PrismaticCodegen.Render.ElixirSDK
  alias PrismaticCodegen.Render.ElixirSDK.DocTree
  alias PrismaticCodegen.Render.ElixirSDK.PublicSchemaModules
  alias PrismaticCodegen.RenderedFile
  alias PrismaticCodegen.Source.Documents
  alias PrismaticCodegen.Source.Introspection

  @spec compile(Provider.t() | module() | String.t()) :: {:ok, ProviderIR.t()} | {:error, term()}
  def compile(provider) do
    {:ok, compile!(provider)}
  rescue
    error in [ArgumentError] -> {:error, error}
  end

  @spec compile!(Provider.t() | module() | String.t()) :: ProviderIR.t()
  def compile!(provider) do
    provider = Provider.load!(provider)
    introspection = Introspection.load!(provider.source.introspection_path)
    documents = Documents.load!(provider.source.documents_root)
    operation_specs = build_operation_specs(provider, documents, introspection)
    models = build_models(provider, operation_specs, introspection)
    enums = build_enums(provider, models, introspection)
    operations = attach_model_modules(operation_specs, models)
    schema = build_schema(introspection)

    ir = %ProviderIR{
      provider: %ProviderIR.Provider{
        name: provider.name,
        namespace: provider.namespace,
        public_namespace: provider.public_namespace,
        client_module: provider.client_module,
        base_url: provider.base_url,
        auth: provider.auth,
        source: %{
          introspection_path: provider.source.introspection_path,
          schema_sdl_path: provider.source.schema_sdl_path
        },
        output: %{
          lib_root: provider.output.lib_root,
          docs_root: provider.output.docs_root
        }
      },
      schema: schema,
      documents: documents,
      operations: operations,
      models: models,
      enums: enums
    }

    %{ir | artifact_plan: %ProviderIR.ArtifactPlan{files: build_artifact_plan(ir)}}
  end

  @spec render!(Provider.t() | module() | String.t()) :: [PrismaticCodegen.RenderedFile.t()]
  def render!(provider) do
    provider
    |> compile!()
    |> then(fn ir ->
      ElixirSDK.render(ir) ++ DocTree.render(ir) ++ PublicSchemaModules.render(ir)
    end)
    |> Enum.map(&normalize_rendered_file/1)
  end

  @spec generate!(Provider.t() | module() | String.t()) :: :ok
  def generate!(provider) do
    provider = Provider.load!(provider)
    prepare_output!(provider)

    render!(provider)
    |> Enum.each(fn file ->
      path = Path.join(provider.output.root, file.path)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, file.content)
    end)

    :ok
  end

  defp build_operation_specs(provider, documents, introspection) do
    Enum.map(documents, fn document ->
      root_field = Introspection.query_field!(introspection, document.root_field, document.kind)
      response_type = root_field.type |> Introspection.named_type() |> Map.fetch!(:name)

      %ProviderIR.Operation{
        id: document.id,
        name: document.name,
        module: Module.concat([provider.namespace, "Operations", document.name]),
        operation:
          Operation.new!(
            id: document.id,
            name: document.name,
            kind: document.kind,
            document: document.document,
            root_field: document.root_field
          ),
        document: document,
        response_type: response_type,
        model_module: nil
      }
    end)
  end

  defp build_models(provider, operations, introspection) do
    operations
    |> Enum.map(& &1.response_type)
    |> Enum.uniq()
    |> Enum.flat_map(fn type_name ->
      type = Introspection.type!(introspection, type_name)

      case type.kind do
        "OBJECT" ->
          [
            %ProviderIR.Model{
              name: type_name,
              module: Module.concat([provider.namespace, "Models", type_name]),
              fields:
                Enum.map(type.fields, fn field ->
                  named = Introspection.named_type(field.type)

                  %ProviderIR.Model.Field{
                    name: field.name,
                    key: field.name |> Macro.underscore() |> String.to_atom(),
                    kind: named.kind,
                    type_name: named.name
                  }
                end)
            }
          ]

        _other ->
          []
      end
    end)
  end

  defp build_enums(provider, models, introspection) do
    models
    |> Enum.flat_map(& &1.fields)
    |> Enum.filter(&(&1.kind == "ENUM"))
    |> Enum.map(& &1.type_name)
    |> Enum.uniq()
    |> Enum.map(fn type_name ->
      type = Introspection.type!(introspection, type_name)

      %ProviderIR.Enum{
        name: type_name,
        module: Module.concat([provider.namespace, "Enums", type_name]),
        values: Enum.map(type.enum_values, & &1.name)
      }
    end)
  end

  defp build_schema(%Introspection.Snapshot{} = snapshot) do
    %ProviderIR.Schema{
      query_type_name: snapshot.query_type_name,
      mutation_type_name: snapshot.mutation_type_name,
      subscription_type_name: snapshot.subscription_type_name,
      types:
        snapshot.types
        |> Map.values()
        |> Enum.map(&build_schema_type/1)
        |> Enum.sort_by(& &1.name)
    }
  end

  defp build_schema_type(type) do
    %ProviderIR.Schema.Type{
      kind: type.kind,
      name: type.name,
      description: type.description,
      specified_by_url: type.specified_by_url,
      fields: Enum.map(type.fields, &build_schema_field/1),
      input_fields: Enum.map(type.input_fields, &build_schema_input_value/1),
      interfaces: Enum.map(type.interfaces, &build_schema_type_ref/1),
      enum_values: Enum.map(type.enum_values, &build_schema_enum_value/1),
      possible_types: Enum.map(type.possible_types, &build_schema_type_ref/1)
    }
  end

  defp build_schema_field(field) do
    %ProviderIR.Schema.Field{
      name: field.name,
      description: field.description,
      args: Enum.map(field.args, &build_schema_input_value/1),
      type: build_schema_type_ref(field.type),
      is_deprecated: field.is_deprecated,
      deprecation_reason: field.deprecation_reason
    }
  end

  defp build_schema_input_value(input_value) do
    %ProviderIR.Schema.InputValue{
      name: input_value.name,
      description: input_value.description,
      type: build_schema_type_ref(input_value.type),
      default_value: input_value.default_value,
      is_deprecated: input_value.is_deprecated,
      deprecation_reason: input_value.deprecation_reason
    }
  end

  defp build_schema_enum_value(enum_value) do
    %ProviderIR.Schema.EnumValue{
      name: enum_value.name,
      description: enum_value.description,
      is_deprecated: enum_value.is_deprecated,
      deprecation_reason: enum_value.deprecation_reason
    }
  end

  defp build_schema_type_ref(type_ref) do
    %ProviderIR.Schema.TypeRef{
      kind: type_ref.kind,
      name: type_ref.name,
      of_type:
        case type_ref.of_type do
          nil -> nil
          nested -> build_schema_type_ref(nested)
        end
    }
  end

  defp attach_model_modules(operations, models) do
    model_modules = Map.new(models, &{&1.name, &1.module})

    Enum.map(operations, fn operation ->
      %{operation | model_module: Map.get(model_modules, operation.response_type)}
    end)
  end

  defp build_artifact_plan(%ProviderIR{} = ir) do
    [
      namespace_root_path(ir.provider)
      | Enum.map(ir.operations, &module_path(ir.provider, &1.module))
    ] ++
      Enum.map(ir.models, &module_path(ir.provider, &1.module)) ++
      Enum.map(ir.enums, &module_path(ir.provider, &1.module)) ++
      DocTree.artifact_paths(ir) ++
      PublicSchemaModules.artifact_paths(ir)
  end

  defp namespace_root_path(provider) do
    "#{provider.output.lib_root}.ex"
  end

  defp module_path(provider, module) do
    suffix =
      module
      |> Module.split()
      |> Enum.drop(length(Module.split(provider.namespace)))
      |> Enum.map(&Macro.underscore/1)

    Path.join([provider.output.lib_root | suffix]) <> ".ex"
  end

  defp normalize_rendered_file(%RenderedFile{} = file) do
    %{file | content: normalize_content(file.path, file.content)}
  end

  defp normalize_content(path, content) do
    case Path.extname(path) do
      ".ex" ->
        content
        |> Code.format_string!()
        |> IO.iodata_to_binary()
        |> Kernel.<>("\n")

      _other ->
        content
        |> String.trim_trailing()
        |> Kernel.<>("\n")
    end
  end

  defp prepare_output!(provider) do
    lib_root_path = Path.join(provider.output.root, provider.output.lib_root)
    docs_root_path = Path.join(provider.output.root, provider.output.docs_root)
    namespace_root = Path.join(provider.output.root, namespace_root_path(provider))
    public_managed_roots = PublicSchemaModules.managed_roots(provider)

    File.rm_rf!(lib_root_path)
    File.rm_rf!(docs_root_path)

    Enum.each(public_managed_roots, fn path ->
      full_path = Path.join(provider.output.root, path)

      cond do
        File.dir?(full_path) -> File.rm_rf!(full_path)
        File.regular?(full_path) -> File.rm!(full_path)
        true -> :ok
      end
    end)

    case File.rm(namespace_root) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> raise File.Error, reason: reason, action: "remove", path: namespace_root
    end
  end
end
