defmodule PrismaticCodegen.Render.ElixirSDK do
  @moduledoc """
  Elixir renderer for generated provider SDK artifacts.
  """

  alias PrismaticCodegen.ProviderIR
  alias PrismaticCodegen.RenderedFile

  @spec render(ProviderIR.t()) :: [RenderedFile.t()]
  def render(%ProviderIR{} = ir) do
    operation_files =
      Enum.map(ir.operations, fn operation ->
        %RenderedFile{
          path: module_path(ir, operation.module),
          kind: :operation,
          content: render_operation_module(ir.provider.client_module, operation)
        }
      end)

    model_files =
      Enum.map(ir.models, fn model ->
        %RenderedFile{
          path: module_path(ir, model.module),
          kind: :model,
          content: render_model_module(model)
        }
      end)

    enum_files =
      Enum.map(ir.enums, fn enum ->
        %RenderedFile{
          path: module_path(ir, enum.module),
          kind: :enum,
          content: render_enum_module(enum)
        }
      end)

    inventory_file = %RenderedFile{
      path: namespace_root_path(ir),
      kind: :inventory,
      content: render_namespace_module(ir)
    }

    docs_file = %RenderedFile{
      path: ir.provider.output.docs_path,
      kind: :docs,
      content: render_docs(ir)
    }

    [inventory_file] ++ operation_files ++ model_files ++ enum_files ++ [docs_file]
  end

  @spec render_operation_module(module(), ProviderIR.Operation.t()) :: String.t()
  def render_operation_module(client_module, %ProviderIR.Operation{} = operation) do
    {model_alias, model_reference} =
      case operation.model_module do
        nil ->
          {nil, nil}

        model_module ->
          {"alias #{inspect(model_module)}", List.last(Module.split(model_module))}
      end

    typed_response_fun =
      case model_reference do
        nil ->
          """
            def call_typed(client, variables \\\\ %{}, opts \\\\ []) do
              call(client, variables, opts)
            end
          """

        model ->
          """
            def call_typed(client, variables \\\\ %{}, opts \\\\ []) do
              with {:ok, %Prismatic.Response{} = response} <- call(client, variables, opts) do
                typed_data =
                  response.data
                  |> Map.get(#{inspect(operation.document.root_field)})
                  |> #{model}.new()

                {:ok, %Prismatic.Response{response | data: typed_data}}
              end
            end
          """
      end

    aliases =
      Enum.reject(
        [
          "alias Prismatic.Operation",
          model_alias
        ],
        &is_nil/1
      )
      |> Enum.sort()
      |> Enum.join("\n  ")

    """
    defmodule #{inspect(operation.module)} do
      @moduledoc \"\"\"
      Generated #{operation.operation.kind} operation for the `#{operation.document.root_field}` root field.
      \"\"\"

      #{aliases}

      @operation Operation.new!(
                   id: #{inspect(operation.operation.id)},
                   name: #{inspect(operation.operation.name)},
                   kind: #{inspect(operation.operation.kind)},
                   document: #{inspect(operation.operation.document)},
                   root_field: #{inspect(operation.operation.root_field)},
                   description: #{inspect(operation.operation.description)}
                 )

      def operation, do: @operation

      def call(client, variables \\\\ %{}, opts \\\\ []) do
        #{inspect(client_module)}.execute_operation(client, @operation, variables, opts)
      end

    #{typed_response_fun}
    end
    """
    |> String.trim()
  end

  defp render_model_module(%ProviderIR.Model{} = model) do
    keys = Enum.map_join(model.fields, ", ", &":#{&1.key}")

    assignments =
      model.fields
      |> Enum.map_join(",\n", fn field ->
        "      #{field.key}: field_value(attributes, #{inspect(field.name)}, :#{field.key})"
      end)

    """
    defmodule #{inspect(model.module)} do
      @moduledoc \"\"\"
      Generated model for the `#{model.name}` GraphQL object type.
      \"\"\"

      defstruct [#{keys}]

      def fields, do: [#{keys}]

      def new(nil), do: nil

      def new(attributes) when is_map(attributes) do
        %__MODULE__{
    #{assignments}
        }
      end

      defp field_value(attributes, string_key, atom_key) do
        cond do
          Map.has_key?(attributes, string_key) -> Map.get(attributes, string_key)
          Map.has_key?(attributes, atom_key) -> Map.get(attributes, atom_key)
          true -> nil
        end
      end
    end
    """
    |> String.trim()
  end

  defp render_enum_module(%ProviderIR.Enum{} = enum) do
    values = Enum.map_join(enum.values, ", ", &inspect/1)

    """
    defmodule #{inspect(enum.module)} do
      @moduledoc \"\"\"
      Generated enum for the `#{enum.name}` GraphQL enum type.
      \"\"\"

      @values [#{values}]

      def values, do: @values

      def valid?(value), do: value in @values
    end
    """
    |> String.trim()
  end

  defp render_namespace_module(%ProviderIR{} = ir) do
    operations = ir.operations |> Enum.map_join(", ", &inspect(&1.module))
    models = ir.models |> Enum.map_join(", ", &inspect(&1.module))
    enums = ir.enums |> Enum.map_join(", ", &inspect(&1.module))

    """
    defmodule #{inspect(ir.provider.namespace)} do
      @moduledoc \"\"\"
      Inventory of generated operations, models, and enums for this provider SDK.
      \"\"\"

      @operations [#{operations}]
      @models [#{models}]
      @enums [#{enums}]

      def operations, do: @operations
      def models, do: @models
      def enums, do: @enums
    end
    """
    |> String.trim()
  end

  defp render_docs(%ProviderIR{} = ir) do
    operations_table =
      ir.operations
      |> Enum.map_join("\n", fn operation ->
        "| #{operation.name} | #{operation.operation.kind} | #{operation.document.root_field} | #{operation.response_type} |"
      end)

    models_list =
      ir.models
      |> Enum.map_join("\n", fn model ->
        fields =
          model.fields
          |> Enum.map_join(", ", &"`#{&1.name}`")

        "- `#{inspect(model.module)}`: #{fields}"
      end)

    enums_list =
      ir.enums
      |> Enum.map_join("\n", fn enum ->
        values = Enum.map_join(enum.values, ", ", &"`#{&1}`")
        "- `#{inspect(enum.module)}`: #{values}"
      end)

    """
    # Generated Surface

    This file is generated by `prismatic_codegen`. Do not edit it by hand.

    ## Operations

    | Name | Kind | Root Field | Response Type |
    | --- | --- | --- | --- |
    #{operations_table}

    ## Models

    #{models_list}

    ## Enums

    #{enums_list}
    """
    |> String.trim()
  end

  defp module_path(%ProviderIR{} = ir, module) do
    suffix =
      module
      |> Module.split()
      |> Enum.drop(length(Module.split(ir.provider.namespace)))
      |> Enum.map(&Macro.underscore/1)

    case suffix do
      [] -> namespace_root_path(ir)
      parts -> Path.join([ir.provider.output.lib_root | parts]) <> ".ex"
    end
  end

  defp namespace_root_path(%ProviderIR{} = ir) do
    "#{ir.provider.output.lib_root}.ex"
  end
end
