defmodule PrismaticCodegen.Source.Introspection do
  @moduledoc """
  Introspection snapshot loader for the generator.
  """

  defmodule Snapshot do
    @moduledoc """
    Normalized GraphQL schema snapshot used by the compiler.
    """

    @type t :: %__MODULE__{
            query_type_name: String.t(),
            mutation_type_name: String.t() | nil,
            subscription_type_name: String.t() | nil,
            types: %{String.t() => map()}
          }

    defstruct [:query_type_name, :mutation_type_name, :subscription_type_name, types: %{}]
  end

  @spec load!(Path.t()) :: Snapshot.t()
  def load!(path) do
    schema =
      path
      |> File.read!()
      |> Jason.decode!()
      |> extract_schema!()

    %Snapshot{
      query_type_name: get_in(schema, ["queryType", "name"]),
      mutation_type_name: get_in(schema, ["mutationType", "name"]),
      subscription_type_name: get_in(schema, ["subscriptionType", "name"]),
      types:
        schema
        |> Map.fetch!("types")
        |> Enum.reject(&is_nil(&1["name"]))
        |> Map.new(fn type -> {type["name"], normalize_type(type)} end)
    }
  end

  @spec query_field!(Snapshot.t(), String.t(), :query | :mutation) :: map()
  def query_field!(%Snapshot{} = snapshot, field_name, kind) do
    root_type_name =
      case kind do
        :query ->
          snapshot.query_type_name

        :mutation ->
          snapshot.mutation_type_name ||
            raise ArgumentError, "mutation root type is missing from introspection"
      end

    root_type = type!(snapshot, root_type_name)

    Enum.find(root_type.fields, &(Map.fetch!(&1, :name) == field_name)) ||
      raise ArgumentError, "missing #{kind} field #{field_name} on root type #{root_type_name}"
  end

  @spec type!(Snapshot.t(), String.t()) :: map()
  def type!(%Snapshot{} = snapshot, type_name) do
    Map.fetch!(snapshot.types, type_name)
  end

  @spec named_type(map()) :: %{kind: String.t(), name: String.t()}
  def named_type(%{name: name, kind: kind}) when is_binary(name), do: %{kind: kind, name: name}
  def named_type(%{of_type: of_type}), do: named_type(of_type)

  @spec type_signature(map()) :: String.t()
  def type_signature(%{kind: "NON_NULL", of_type: of_type}), do: type_signature(of_type) <> "!"
  def type_signature(%{kind: "LIST", of_type: of_type}), do: "[" <> type_signature(of_type) <> "]"
  def type_signature(%{name: name}) when is_binary(name), do: name

  defp extract_schema!(%{"data" => %{"__schema" => schema}}), do: schema
  defp extract_schema!(%{"__schema" => schema}), do: schema

  defp extract_schema!(other) do
    raise ArgumentError, "unsupported introspection payload: #{inspect(Map.keys(other))}"
  end

  defp normalize_type(type) do
    %{
      kind: type["kind"],
      name: type["name"],
      description: type["description"],
      specified_by_url: type["specifiedByURL"],
      fields:
        type
        |> Map.get("fields", [])
        |> List.wrap()
        |> Enum.map(&normalize_field/1),
      input_fields:
        type
        |> Map.get("inputFields", [])
        |> List.wrap()
        |> Enum.map(&normalize_input_value/1),
      interfaces:
        type
        |> Map.get("interfaces", [])
        |> List.wrap()
        |> Enum.map(&normalize_type_ref/1),
      enum_values:
        type
        |> Map.get("enumValues", [])
        |> List.wrap()
        |> Enum.map(&normalize_enum_value/1),
      possible_types:
        type
        |> Map.get("possibleTypes", [])
        |> List.wrap()
        |> Enum.map(&normalize_type_ref/1)
    }
  end

  defp normalize_field(field) do
    %{
      name: field["name"],
      description: field["description"],
      args:
        field
        |> Map.get("args", [])
        |> List.wrap()
        |> Enum.map(&normalize_input_value/1),
      type: normalize_type_ref(field["type"]),
      is_deprecated: field["isDeprecated"] || false,
      deprecation_reason: field["deprecationReason"]
    }
  end

  defp normalize_input_value(input_value) do
    %{
      name: input_value["name"],
      description: input_value["description"],
      type: normalize_type_ref(input_value["type"]),
      default_value: input_value["defaultValue"],
      is_deprecated: input_value["isDeprecated"] || false,
      deprecation_reason: input_value["deprecationReason"]
    }
  end

  defp normalize_enum_value(enum_value) do
    %{
      name: enum_value["name"],
      description: enum_value["description"],
      is_deprecated: enum_value["isDeprecated"] || false,
      deprecation_reason: enum_value["deprecationReason"]
    }
  end

  defp normalize_type_ref(nil), do: nil

  defp normalize_type_ref(type_ref) do
    %{
      kind: type_ref["kind"],
      name: type_ref["name"],
      of_type: normalize_type_ref(type_ref["ofType"])
    }
  end
end
