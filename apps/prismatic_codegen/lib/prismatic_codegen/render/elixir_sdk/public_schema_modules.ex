defmodule PrismaticCodegen.Render.ElixirSDK.PublicSchemaModules do
  @moduledoc """
  Public schema-reference module renderer for provider SDKs.
  """

  alias PrismaticCodegen.Provider
  alias PrismaticCodegen.ProviderIR
  alias PrismaticCodegen.ProviderIR.Schema
  alias PrismaticCodegen.RenderedFile

  @root_categories [
    {:query, "Query", "Queries"},
    {:mutation, "Mutation", "Mutations"},
    {:subscription, "Subscription", "Subscriptions"}
  ]

  @type_categories [
    {"OBJECT", "Objects"},
    {"INPUT_OBJECT", "Inputs"},
    {"INTERFACE", "Interfaces"},
    {"UNION", "Unions"},
    {"ENUM", "Enums"},
    {"SCALAR", "Scalars"}
  ]

  @spec render(ProviderIR.t()) :: [RenderedFile.t()]
  def render(%ProviderIR{} = ir) do
    category_modules(ir) ++ entry_modules(ir)
  end

  @spec artifact_paths(ProviderIR.t()) :: [Path.t()]
  def artifact_paths(%ProviderIR{} = ir) do
    render(ir) |> Enum.map(& &1.path)
  end

  @spec managed_roots(Provider.t()) :: [Path.t()]
  def managed_roots(%Provider{} = provider) do
    public_root = public_root(provider.public_namespace)

    root_files =
      (root_category_names() ++ type_category_names())
      |> Enum.map(fn segment -> Path.join(public_root, "#{Macro.underscore(segment)}.ex") end)

    root_dirs =
      (root_category_names() ++ type_category_names())
      |> Enum.map(fn segment -> Path.join(public_root, Macro.underscore(segment)) end)

    root_files ++ root_dirs
  end

  defp category_modules(%ProviderIR{} = ir) do
    Enum.map(@root_categories, fn {kind, root_name, module_segment} ->
      fields = root_fields(ir.schema, root_name)
      module = Module.concat([ir.provider.public_namespace, module_segment])

      %RenderedFile{
        path: module_path(module),
        kind: :public_schema_module,
        content: render_module(module, render_root_category_doc(ir, kind, module_segment, fields))
      }
    end) ++
      Enum.map(@type_categories, fn {kind, module_segment} ->
        types = schema_types(ir.schema, kind)
        module = Module.concat([ir.provider.public_namespace, module_segment])

        %RenderedFile{
          path: module_path(module),
          kind: :public_schema_module,
          content:
            render_module(module, render_type_category_doc(ir, kind, module_segment, types))
        }
      end)
  end

  defp entry_modules(%ProviderIR{} = ir) do
    root_modules =
      Enum.flat_map(@root_categories, fn {_kind, root_name, module_segment} ->
        root_fields(ir.schema, root_name)
        |> Enum.map(fn field ->
          module =
            Module.concat([
              ir.provider.public_namespace,
              module_segment,
              module_segment_for_name(field.name)
            ])

          %RenderedFile{
            path: module_path(module),
            kind: :public_schema_module,
            content: render_module(module, render_root_field_doc(ir, root_name, field))
          }
        end)
      end)

    type_modules =
      Enum.flat_map(@type_categories, fn {kind, module_segment} ->
        schema_types(ir.schema, kind)
        |> Enum.map(fn type ->
          module = Module.concat([ir.provider.public_namespace, module_segment, type.name])

          %RenderedFile{
            path: module_path(module),
            kind: :public_schema_module,
            content: render_module(module, render_type_doc(ir, type))
          }
        end)
      end)

    root_modules ++ type_modules
  end

  defp render_module(module, moduledoc) do
    """
    defmodule #{inspect(module)} do
      @moduledoc #{moduledoc_literal(moduledoc)}
    end
    """
    |> String.trim()
  end

  defp render_root_category_doc(ir, kind, module_segment, fields) do
    heading = String.downcase(module_segment)

    rows =
      Enum.map_join(fields, "\n", fn field ->
        "| `#{field.name}` | #{inspect(root_field_module(ir, kind, field.name))} | #{type_signature(ir, field.type)} | #{length(field.args)} | #{summary(field.description)} |"
      end)

    """
    Public schema reference for #{heading}.

    ## Fields

    | Field | Module | Return Type | Argument Count | Description |
    | --- | --- | --- | --- | --- |
    #{rows}
    """
    |> String.trim()
  end

  defp render_type_category_doc(ir, kind, module_segment, types) do
    rows =
      Enum.map_join(types, "\n", fn type ->
        "| `#{type.name}` | #{inspect(type_module(ir, kind, type.name))} | #{type_detail_count(type)} | #{summary(type.description)} |"
      end)

    """
    Public schema reference for #{String.downcase(module_segment)}.

    ## Types

    | Name | Module | Detail Count | Description |
    | --- | --- | --- | --- |
    #{rows}
    """
    |> String.trim()
  end

  defp render_root_field_doc(ir, root_name, field) do
    args_section =
      if field.args == [] do
        "No arguments."
      else
        """
        | Name | Type | Default | Deprecated | Description |
        | --- | --- | --- | --- | --- |
        #{Enum.map_join(field.args, "\n", &argument_row(ir, &1))}
        """
        |> String.trim()
      end

    deprecation_section =
      if field.is_deprecated do
        """
        ## Deprecation

        #{field.deprecation_reason || "Deprecated."}
        """
      else
        nil
      end

    [
      """
      GraphQL #{String.downcase(root_name)} field `#{field.name}`.

      #{description(field.description)}

      ## Signature

      - Root Type: `#{root_name}`
      - Return Type: #{type_signature(ir, field.type)}

      ## Arguments

      #{args_section}
      """,
      deprecation_section
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
    |> String.trim()
  end

  defp render_type_doc(ir, %Schema.Type{} = type) do
    [
      """
      GraphQL #{String.downcase(type.kind)} `#{type.name}`.

      #{description(type.description)}

      ## Summary

      - Kind: `#{String.downcase(type.kind)}`
      """,
      relationship_section(ir, type),
      detail_section(ir, type)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
    |> String.trim()
  end

  defp relationship_section(ir, type) do
    entries =
      []
      |> maybe_add_relationship("Implements", module_list(ir, type.interfaces))
      |> maybe_add_relationship("Possible Types", module_list(ir, type.possible_types))
      |> maybe_add_relationship("Specified By", specified_by_link(type))

    if entries == [] do
      nil
    else
      """
      ## Relationships

      #{Enum.join(entries, "\n")}
      """
      |> String.trim()
    end
  end

  defp detail_section(ir, %Schema.Type{kind: "OBJECT"} = type),
    do: object_detail_section(ir, type)

  defp detail_section(ir, %Schema.Type{kind: "INTERFACE"} = type),
    do: object_detail_section(ir, type)

  defp detail_section(ir, %Schema.Type{kind: "INPUT_OBJECT"} = type),
    do: input_detail_section(ir, type)

  defp detail_section(ir, %Schema.Type{kind: "UNION"} = type), do: union_detail_section(ir, type)
  defp detail_section(_ir, %Schema.Type{kind: "ENUM"} = type), do: enum_detail_section(type)
  defp detail_section(_ir, %Schema.Type{kind: "SCALAR"} = type), do: scalar_detail_section(type)

  defp object_detail_section(ir, type) do
    rows =
      Enum.map_join(type.fields, "\n", fn field ->
        "| `#{field.name}` | #{type_signature(ir, field.type)} | #{argument_summary(ir, field.args)} | #{deprecated_flag(field.is_deprecated)} | #{summary(field.description)} |"
      end)

    """
    ## Fields

    | Name | Type | Arguments | Deprecated | Description |
    | --- | --- | --- | --- | --- |
    #{rows}
    """
    |> String.trim()
  end

  defp input_detail_section(ir, type) do
    rows =
      Enum.map_join(type.input_fields, "\n", fn input_field ->
        "| `#{input_field.name}` | #{type_signature(ir, input_field.type)} | #{default_value(input_field.default_value)} | #{deprecated_flag(input_field.is_deprecated)} | #{summary(input_field.description)} |"
      end)

    """
    ## Input Fields

    | Name | Type | Default | Deprecated | Description |
    | --- | --- | --- | --- | --- |
    #{rows}
    """
    |> String.trim()
  end

  defp union_detail_section(ir, type) do
    rows =
      Enum.map_join(type.possible_types, "\n", fn ref ->
        "- #{module_ref(ir, ref)}"
      end)

    """
    ## Possible Types

    #{rows}
    """
    |> String.trim()
  end

  defp enum_detail_section(type) do
    rows =
      Enum.map_join(type.enum_values, "\n", fn value ->
        "| `#{value.name}` | #{deprecated_flag(value.is_deprecated)} | #{default_value(value.deprecation_reason)} | #{summary(value.description)} |"
      end)

    """
    ## Values

    | Name | Deprecated | Deprecation Reason | Description |
    | --- | --- | --- | --- |
    #{rows}
    """
    |> String.trim()
  end

  defp scalar_detail_section(type) do
    """
    ## Notes

    - Specified By: #{specified_by_link(type) || "`n/a`"}
    """
    |> String.trim()
  end

  defp argument_row(ir, arg) do
    "| `#{arg.name}` | #{type_signature(ir, arg.type)} | #{default_value(arg.default_value)} | #{deprecated_flag(arg.is_deprecated)} | #{summary(arg.description)} |"
  end

  defp root_fields(%Schema{} = schema, root_type_name) do
    case Enum.find(schema.types, &(&1.name == root_type_name)) do
      nil -> []
      type -> Enum.reject(type.fields, &hidden_field?/1)
    end
  end

  defp schema_types(%Schema{} = schema, kind) do
    schema.types
    |> Enum.filter(&(&1.kind == kind))
    |> Enum.reject(&(hidden_type?(&1) or root_type?(&1, schema)))
  end

  defp hidden_type?(%Schema.Type{name: name}), do: String.starts_with?(name, "_")
  defp hidden_field?(%Schema.Field{name: name}), do: String.starts_with?(name, "_")

  defp root_type?(%Schema.Type{name: name}, %Schema{} = schema) do
    name in [schema.query_type_name, schema.mutation_type_name, schema.subscription_type_name]
  end

  defp type_signature(ir, %Schema.TypeRef{kind: "NON_NULL", of_type: of_type}) do
    type_signature(ir, of_type) <> "!"
  end

  defp type_signature(ir, %Schema.TypeRef{kind: "LIST", of_type: of_type}) do
    "[" <> type_signature(ir, of_type) <> "]"
  end

  defp type_signature(ir, %Schema.TypeRef{} = ref), do: module_ref(ir, ref)

  defp module_ref(ir, %Schema.TypeRef{name: name} = ref) do
    case type_module_for_ref(ir, ref) do
      nil -> "`#{name}`"
      module -> inspect(module)
    end
  end

  defp type_module_for_ref(ir, %Schema.TypeRef{kind: "NON_NULL", of_type: of_type}),
    do: type_module_for_ref(ir, of_type)

  defp type_module_for_ref(ir, %Schema.TypeRef{kind: "LIST", of_type: of_type}),
    do: type_module_for_ref(ir, of_type)

  defp type_module_for_ref(ir, %Schema.TypeRef{name: name}) do
    case Enum.find(ir.schema.types, &(&1.name == name)) do
      nil ->
        nil

      %Schema.Type{} = type ->
        cond do
          hidden_type?(type) -> nil
          root_type?(type, ir.schema) -> nil
          true -> type_module(ir, type.kind, type.name)
        end
    end
  end

  defp root_field_module(ir, kind, field_name) do
    {module_segment, _root_name} = root_category(kind)

    Module.concat([
      ir.provider.public_namespace,
      module_segment,
      module_segment_for_name(field_name)
    ])
  end

  defp type_module(ir, kind, type_name) do
    {module_segment, _kind} = type_category(kind)
    Module.concat([ir.provider.public_namespace, module_segment, type_name])
  end

  defp root_category(kind) do
    {_kind, root_name, module_segment} =
      Enum.find(@root_categories, fn {candidate, _, _} -> candidate == kind end)

    {module_segment, root_name}
  end

  defp type_category(kind) do
    {schema_kind, module_segment} =
      Enum.find(@type_categories, fn {candidate, _} -> candidate == kind end)

    {module_segment, schema_kind}
  end

  defp module_path(module) do
    ["lib" | Enum.map(Module.split(module), &Macro.underscore/1)]
    |> Path.join()
    |> Kernel.<>(".ex")
  end

  defp public_root(namespace) do
    ["lib" | Enum.map(Module.split(namespace), &Macro.underscore/1)]
    |> Path.join()
  end

  defp module_segment_for_name(name) do
    name
    |> Macro.underscore()
    |> Macro.camelize()
  end

  defp root_category_names do
    Enum.map(@root_categories, fn {_kind, _root_name, module_segment} -> module_segment end)
  end

  defp type_category_names do
    Enum.map(@type_categories, fn {_kind, module_segment} -> module_segment end)
  end

  defp description(nil), do: "_No description._"
  defp description(value), do: value

  defp summary(nil), do: "_"

  defp summary(value) do
    value
    |> String.split("\n")
    |> List.first()
    |> String.replace("|", "\\|")
  end

  defp argument_summary(_ir, []), do: "`none`"

  defp argument_summary(ir, args) do
    Enum.map_join(args, ", ", fn arg ->
      "`#{arg.name}: #{type_signature(ir, arg.type)}`"
    end)
  end

  defp type_detail_count(%Schema.Type{kind: "OBJECT", fields: fields}), do: length(fields)
  defp type_detail_count(%Schema.Type{kind: "INTERFACE", fields: fields}), do: length(fields)

  defp type_detail_count(%Schema.Type{kind: "INPUT_OBJECT", input_fields: input_fields}),
    do: length(input_fields)

  defp type_detail_count(%Schema.Type{kind: "UNION", possible_types: possible_types}),
    do: length(possible_types)

  defp type_detail_count(%Schema.Type{kind: "ENUM", enum_values: enum_values}),
    do: length(enum_values)

  defp type_detail_count(%Schema.Type{}), do: 0

  defp deprecated_flag(true), do: "Yes"
  defp deprecated_flag(false), do: "No"
  defp default_value(nil), do: "`n/a`"
  defp default_value(value), do: "`#{String.replace(to_string(value), "|", "\\|")}`"

  defp specified_by_link(%Schema.Type{specified_by_url: nil}), do: nil
  defp specified_by_link(%Schema.Type{specified_by_url: url}), do: "[`#{url}`](#{url})"

  defp maybe_add_relationship(entries, _label, []), do: entries
  defp maybe_add_relationship(entries, _label, nil), do: entries
  defp maybe_add_relationship(entries, label, value), do: entries ++ ["- #{label}: #{value}"]

  defp module_list(_ir, []), do: []

  defp module_list(ir, refs) do
    Enum.map_join(refs, ", ", fn ref ->
      module_ref(ir, ref)
    end)
  end

  defp moduledoc_literal(moduledoc) do
    cond do
      not String.contains?(moduledoc, "'''") ->
        "~S'''\n#{moduledoc}\n'''"

      not String.contains?(moduledoc, ~s/"""/) ->
        ~s/~S"""\n#{moduledoc}\n"""/

      true ->
        inspect(moduledoc, limit: :infinity, printable_limit: :infinity)
    end
  end
end
