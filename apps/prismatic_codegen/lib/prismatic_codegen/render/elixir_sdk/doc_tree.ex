defmodule PrismaticCodegen.Render.ElixirSDK.DocTree do
  @moduledoc """
  Generated API reference-doc tree for provider SDKs.
  """

  alias PrismaticCodegen.ProviderIR
  alias PrismaticCodegen.ProviderIR.Schema
  alias PrismaticCodegen.RenderedFile
  alias PrismaticCodegen.Source.Introspection

  @root_kinds [
    {"queries", "Query", :query},
    {"mutations", "Mutation", :mutation},
    {"subscriptions", "Subscription", :subscription}
  ]

  @type_categories [
    {"objects", "OBJECT", "-object.md", "Objects"},
    {"input-objects", "INPUT_OBJECT", "-input.md", "Input Objects"},
    {"interfaces", "INTERFACE", "-interface.md", "Interfaces"},
    {"unions", "UNION", "-union.md", "Unions"},
    {"enums", "ENUM", "-enum.md", "Enums"},
    {"scalars", "SCALAR", "-scalar.md", "Scalars"}
  ]

  @spec render(ProviderIR.t()) :: [RenderedFile.t()]
  def render(%ProviderIR{} = ir) do
    schema = ir.schema

    [
      docs_file(ir, api_reference_path(ir), render_api_reference(ir))
      | render_root_reference_files(ir, schema)
    ] ++ render_type_reference_files(ir, schema)
  end

  @spec artifact_paths(ProviderIR.t()) :: [Path.t()]
  def artifact_paths(%ProviderIR{} = ir) do
    schema = ir.schema

    [api_reference_path(ir)] ++
      root_reference_paths(ir, schema) ++
      type_reference_paths(ir, schema)
  end

  defp render_root_reference_files(ir, schema) do
    Enum.flat_map(@root_kinds, fn {dir, root_name, label} ->
      fields = root_fields(schema, root_name)

      if fields == [] do
        []
      else
        [
          docs_file(ir, root_index_path(ir, dir), render_root_index(ir, label, fields))
          | Enum.map(
              fields,
              &docs_file(
                ir,
                root_field_path(ir, dir, label, &1),
                render_root_field_page(ir, label, &1)
              )
            )
        ]
      end
    end)
  end

  defp render_type_reference_files(ir, schema) do
    Enum.flat_map(@type_categories, fn {dir, kind, suffix, label} ->
      types = schema_types(schema, kind)

      if types == [] do
        []
      else
        [
          docs_file(
            ir,
            type_index_path(ir, dir),
            render_type_index(ir, label, dir, suffix, types)
          )
          | Enum.map(
              types,
              &docs_file(
                ir,
                type_page_path(ir, dir, suffix, &1),
                render_type_page(ir, dir, suffix, &1)
              )
            )
        ]
      end
    end)
  end

  defp root_reference_paths(ir, schema) do
    Enum.flat_map(@root_kinds, fn {dir, root_name, label} ->
      fields = root_fields(schema, root_name)

      if fields == [] do
        []
      else
        [root_index_path(ir, dir) | Enum.map(fields, &root_field_path(ir, dir, label, &1))]
      end
    end)
  end

  defp type_reference_paths(ir, schema) do
    Enum.flat_map(@type_categories, fn {dir, kind, suffix, _label} ->
      types = schema_types(schema, kind)

      if types == [] do
        []
      else
        [type_index_path(ir, dir) | Enum.map(types, &type_page_path(ir, dir, suffix, &1))]
      end
    end)
  end

  defp docs_file(ir, path, content) do
    %RenderedFile{
      path: path,
      kind: :docs,
      content: render_generated_banner(ir) <> "\n\n" <> String.trim(content)
    }
  end

  defp render_generated_banner(_ir) do
    """
    <!-- Generated file. Do not edit by hand. -->
    """
    |> String.trim()
  end

  defp render_api_reference(%ProviderIR{} = ir) do
    schema = ir.schema
    counts = type_counts(schema)
    provider_root = Path.dirname(ir.provider.source.introspection_path)

    """
    # API Reference

    This reference is generated from committed upstream schema artifacts.

    ## Source Artifacts

    - Introspection JSON: `#{Path.relative_to(ir.provider.source.introspection_path, provider_root)}`
    - Schema SDL: `#{Path.relative_to(ir.provider.source.schema_sdl_path, provider_root)}`

    ## Entry Points

    #{root_summary(ir, schema)}

    ## Type Reference

    - [Objects](objects.md) (#{counts["OBJECT"]})
    - [Input Objects](input-objects.md) (#{counts["INPUT_OBJECT"]})
    - [Interfaces](interfaces.md) (#{counts["INTERFACE"]})
    - [Unions](unions.md) (#{counts["UNION"]})
    - [Enums](enums.md) (#{counts["ENUM"]})
    - [Scalars](scalars.md) (#{counts["SCALAR"]})
    """
    |> String.trim()
  end

  defp root_summary(ir, schema) do
    @root_kinds
    |> Enum.map(fn {dir, root_name, label} ->
      fields = root_fields(schema, root_name)

      if fields == [] do
        nil
      else
        "- [#{label_name(label)}](#{Path.basename(root_index_path(ir, dir))}) (#{length(fields)})"
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp render_root_index(ir, label, fields) do
    rows =
      Enum.map_join(fields, "\n", fn field ->
        path = Path.basename(root_field_path(ir, directory_name(label), label, field))

        "| [#{field.name}](#{path}) | #{inline_type_signature(ir, field.type, "")} | #{length(field.args)} | #{markdown_summary(field.description)} |"
      end)

    """
    # #{label_name(label)}

    | Field | Return Type | Argument Count | Description |
    | --- | --- | --- | --- |
    #{rows}
    """
    |> String.trim()
  end

  defp render_root_field_page(ir, label, field) do
    args_section =
      if field.args == [] do
        "No arguments."
      else
        argument_table(ir, directory_name(label), field.args)
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

    sections =
      [
        """
        # #{field.name}

        #{markdown_description(field.description)}

        ## Signature

        - Root: `#{label_name(label)}`
        - Return Type: #{inline_type_signature(ir, field.type, directory_name(label))}

        ## Arguments

        #{args_section}
        """,
        deprecation_section
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(sections, "\n\n")
  end

  defp render_type_index(ir, label, dir, suffix, types) do
    rows =
      Enum.map_join(types, "\n", fn type ->
        path = Path.basename(type_page_path(ir, dir, suffix, type))
        detail_count = type_detail_count(type)

        "| [#{type.name}](#{path}) | #{detail_count} | #{markdown_summary(type.description)} |"
      end)

    """
    # #{label}

    | Name | Detail Count | Description |
    | --- | --- | --- |
    #{rows}
    """
    |> String.trim()
  end

  defp render_type_page(ir, dir, suffix, %Schema.Type{} = type) do
    sections =
      [
        """
        # #{type.name}

        #{markdown_description(type.description)}

        ## Summary

        - Kind: `#{String.downcase(type.kind)}`
        """,
        relationship_section(ir, dir, suffix, type),
        detail_section(ir, dir, type)
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(sections, "\n\n")
  end

  defp relationship_section(ir, dir, _suffix, type) do
    entries =
      []
      |> maybe_add_relationship("Implements", interface_links(ir, dir, type.interfaces))
      |> maybe_add_relationship(
        "Possible Types",
        possible_type_links(ir, dir, type.possible_types)
      )
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

  defp detail_section(ir, dir, %Schema.Type{kind: "OBJECT"} = type),
    do: object_detail_section(ir, dir, type)

  defp detail_section(ir, dir, %Schema.Type{kind: "INPUT_OBJECT"} = type),
    do: input_detail_section(ir, dir, type)

  defp detail_section(ir, dir, %Schema.Type{kind: "INTERFACE"} = type),
    do: object_detail_section(ir, dir, type)

  defp detail_section(ir, dir, %Schema.Type{kind: "UNION"} = type),
    do: union_detail_section(ir, dir, type)

  defp detail_section(_ir, _dir, %Schema.Type{kind: "ENUM"} = type), do: enum_detail_section(type)

  defp detail_section(_ir, _dir, %Schema.Type{kind: "SCALAR"} = type),
    do: scalar_detail_section(type)

  defp object_detail_section(ir, dir, type) do
    rows =
      Enum.map_join(type.fields, "\n", fn field ->
        "| `#{field.name}` | #{inline_type_signature(ir, field.type, dir)} | #{argument_summary(ir, dir, field.args)} | #{deprecated_flag(field.is_deprecated)} | #{markdown_summary(field.description)} |"
      end)

    """
    ## Fields

    | Name | Type | Arguments | Deprecated | Description |
    | --- | --- | --- | --- | --- |
    #{rows}
    """
    |> String.trim()
  end

  defp input_detail_section(ir, dir, type) do
    rows =
      Enum.map_join(type.input_fields, "\n", fn input_field ->
        "| `#{input_field.name}` | #{inline_type_signature(ir, input_field.type, dir)} | #{default_value(input_field.default_value)} | #{deprecated_flag(input_field.is_deprecated)} | #{markdown_summary(input_field.description)} |"
      end)

    """
    ## Input Fields

    | Name | Type | Default | Deprecated | Description |
    | --- | --- | --- | --- | --- |
    #{rows}
    """
    |> String.trim()
  end

  defp union_detail_section(ir, dir, type) do
    rows =
      Enum.map_join(type.possible_types, "\n", fn possible_type ->
        "- #{inline_type_signature(ir, possible_type, dir)}"
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
        "| `#{value.name}` | #{deprecated_flag(value.is_deprecated)} | #{default_value(value.deprecation_reason)} | #{markdown_summary(value.description)} |"
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

  defp argument_table(ir, dir, args) do
    rows =
      Enum.map_join(args, "\n", fn arg ->
        "| `#{arg.name}` | #{inline_type_signature(ir, arg.type, dir)} | #{default_value(arg.default_value)} | #{deprecated_flag(arg.is_deprecated)} | #{markdown_summary(arg.description)} |"
      end)

    """
    | Name | Type | Default | Deprecated | Description |
    | --- | --- | --- | --- | --- |
    #{rows}
    """
    |> String.trim()
  end

  defp schema_types(%Schema{} = schema, kind) do
    schema.types
    |> Enum.filter(&(&1.kind == kind))
    |> Enum.reject(&(hidden_type?(&1) or root_type?(&1, schema)))
  end

  defp root_fields(%Schema{} = schema, root_type_name) do
    case Enum.find(schema.types, &(&1.name == root_type_name)) do
      nil -> []
      type -> Enum.reject(type.fields, &hidden_field?/1)
    end
  end

  defp type_counts(%Schema{} = schema) do
    schema.types
    |> Enum.group_by(& &1.kind)
    |> Map.new(fn {kind, types} ->
      visible =
        types
        |> Enum.reject(&(hidden_type?(&1) or root_type?(&1, schema)))

      {kind, length(visible)}
    end)
  end

  defp hidden_type?(%Schema.Type{name: name}), do: String.starts_with?(name, "_")
  defp hidden_field?(%Schema.Field{name: name}), do: String.starts_with?(name, "_")

  defp root_type?(%Schema.Type{name: name}, %Schema{} = schema) do
    name in [schema.query_type_name, schema.mutation_type_name, schema.subscription_type_name]
  end

  defp api_reference_path(%ProviderIR{} = ir) do
    Path.join(ir.provider.output.docs_root, "graph-reference.md")
  end

  defp root_index_path(%ProviderIR{} = ir, dir) do
    Path.join(ir.provider.output.docs_root, "#{dir}.md")
  end

  defp root_field_path(%ProviderIR{} = ir, dir, label, field) do
    Path.join([
      ir.provider.output.docs_root,
      dir,
      "#{slug(field.name)}-#{directory_singular(label)}.md"
    ])
  end

  defp type_index_path(%ProviderIR{} = ir, dir) do
    Path.join(ir.provider.output.docs_root, "#{dir}.md")
  end

  defp type_page_path(%ProviderIR{} = ir, dir, suffix, type) do
    Path.join([ir.provider.output.docs_root, dir, "#{slug(type.name)}#{suffix}"])
  end

  defp directory_name(:query), do: "queries"
  defp directory_name(:mutation), do: "mutations"
  defp directory_name(:subscription), do: "subscriptions"

  defp directory_singular(:query), do: "query"
  defp directory_singular(:mutation), do: "mutation"
  defp directory_singular(:subscription), do: "subscription"

  defp label_name(:query), do: "Queries"
  defp label_name(:mutation), do: "Mutations"
  defp label_name(:subscription), do: "Subscriptions"

  defp type_detail_count(%Schema.Type{kind: "OBJECT", fields: fields}), do: length(fields)
  defp type_detail_count(%Schema.Type{kind: "INTERFACE", fields: fields}), do: length(fields)

  defp type_detail_count(%Schema.Type{kind: "INPUT_OBJECT", input_fields: input_fields}),
    do: length(input_fields)

  defp type_detail_count(%Schema.Type{kind: "UNION", possible_types: possible_types}),
    do: length(possible_types)

  defp type_detail_count(%Schema.Type{kind: "ENUM", enum_values: enum_values}),
    do: length(enum_values)

  defp type_detail_count(%Schema.Type{}), do: 0

  defp markdown_description(nil), do: "_No description._"
  defp markdown_description(description), do: description

  defp markdown_summary(nil), do: "_"

  defp markdown_summary(description) do
    description
    |> String.split("\n")
    |> List.first()
    |> String.replace("|", "\\|")
  end

  defp argument_summary(_ir, _dir, []), do: "`none`"

  defp argument_summary(_ir, _dir, args) do
    Enum.map_join(args, ", ", fn arg ->
      "`#{arg.name}: #{Introspection.type_signature(type_ref_to_map(arg.type))}`"
    end)
  end

  defp deprecated_flag(true), do: "Yes"
  defp deprecated_flag(false), do: "No"

  defp default_value(nil), do: "`n/a`"
  defp default_value(value), do: "`#{String.replace(to_string(value), "|", "\\|")}`"

  defp inline_type_signature(ir, type_ref, current_dir) do
    render_type_ref(ir, type_ref, current_dir)
  end

  defp render_type_ref(ir, %Schema.TypeRef{kind: "NON_NULL", of_type: of_type}, current_dir) do
    render_type_ref(ir, of_type, current_dir) <> "!"
  end

  defp render_type_ref(ir, %Schema.TypeRef{kind: "LIST", of_type: of_type}, current_dir) do
    "[" <> render_type_ref(ir, of_type, current_dir) <> "]"
  end

  defp render_type_ref(ir, %Schema.TypeRef{name: name}, current_dir) do
    case type_reference_target(ir, name, current_dir) do
      nil -> "`#{name}`"
      path -> "[`#{name}`](#{path})"
    end
  end

  defp type_reference_target(ir, type_name, current_dir) do
    with %Schema.Type{} = type <- Enum.find(ir.schema.types, &(&1.name == type_name)),
         false <- hidden_type?(type),
         false <- root_type?(type, ir.schema) do
      {dir, suffix} = type_category(type.kind)

      current_dir_path =
        case current_dir do
          "" -> ir.provider.output.docs_root
          dir_path -> Path.join(ir.provider.output.docs_root, dir_path)
        end

      target = type_page_path(ir, dir, suffix, type)
      Path.relative_to(target, current_dir_path)
    else
      _other -> nil
    end
  end

  defp type_category(kind) do
    {dir, _kind, suffix, _label} =
      Enum.find(@type_categories, fn {_dir, category_kind, _suffix, _label} ->
        category_kind == kind
      end)

    {dir, suffix}
  end

  defp maybe_add_relationship(entries, _label, []), do: entries
  defp maybe_add_relationship(entries, _label, nil), do: entries
  defp maybe_add_relationship(entries, label, value), do: entries ++ ["- #{label}: #{value}"]

  defp interface_links(_ir, _dir, []), do: []

  defp interface_links(ir, dir, refs) do
    Enum.map_join(refs, ", ", &render_type_ref(ir, &1, dir))
  end

  defp possible_type_links(_ir, _dir, []), do: []

  defp possible_type_links(ir, dir, refs) do
    Enum.map_join(refs, ", ", &render_type_ref(ir, &1, dir))
  end

  defp specified_by_link(%Schema.Type{specified_by_url: nil}), do: nil
  defp specified_by_link(%Schema.Type{specified_by_url: url}), do: "[`#{url}`](#{url})"

  defp type_ref_to_map(%Schema.TypeRef{} = type_ref) do
    %{
      kind: type_ref.kind,
      name: type_ref.name,
      of_type:
        case type_ref.of_type do
          nil -> nil
          nested -> type_ref_to_map(nested)
        end
    }
  end

  defp slug(name) do
    name
    |> Macro.underscore()
    |> String.replace("/", "_")
  end
end
