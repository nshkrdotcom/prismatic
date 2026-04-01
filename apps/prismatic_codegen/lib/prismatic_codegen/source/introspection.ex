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
            types: %{String.t() => map()}
          }

    defstruct [:query_type_name, :mutation_type_name, types: %{}]
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
      fields:
        type
        |> Map.get("fields", [])
        |> List.wrap()
        |> Enum.map(&normalize_field/1),
      enum_values:
        type
        |> Map.get("enumValues", [])
        |> List.wrap()
        |> Enum.map(& &1["name"])
    }
  end

  defp normalize_field(field) do
    %{
      name: field["name"],
      description: field["description"],
      type: normalize_type_ref(field["type"])
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
