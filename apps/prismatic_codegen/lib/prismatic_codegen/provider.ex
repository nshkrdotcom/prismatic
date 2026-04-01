defmodule PrismaticCodegen.Provider do
  @moduledoc """
  Provider definition contract for generated GraphQL SDKs.
  """

  alias NimbleOptions.ValidationError

  defmodule Source do
    @moduledoc """
    Source artifact locations used to compile a provider definition.
    """

    @type t :: %__MODULE__{
            introspection_path: Path.t(),
            documents_root: Path.t()
          }

    @enforce_keys [:introspection_path, :documents_root]
    defstruct [:introspection_path, :documents_root]
  end

  defmodule Output do
    @moduledoc """
    Output locations for generated provider artifacts.
    """

    @type t :: %__MODULE__{
            root: Path.t(),
            lib_root: Path.t(),
            docs_path: Path.t()
          }

    @enforce_keys [:root, :lib_root, :docs_path]
    defstruct [:root, :lib_root, :docs_path]
  end

  @type t :: %__MODULE__{
          name: String.t(),
          namespace: module(),
          client_module: module(),
          base_url: String.t(),
          auth: map(),
          source: Source.t(),
          output: Output.t()
        }

  @enforce_keys [:name, :namespace, :client_module, :base_url, :source, :output]
  defstruct [:name, :namespace, :client_module, :base_url, auth: %{}, source: nil, output: nil]

  @schema [
    name: [type: :string, required: true],
    namespace: [type: :atom, required: true],
    client_module: [type: :atom, required: true],
    base_url: [type: :string, required: true],
    auth: [type: :map, default: %{}],
    source: [
      type: :keyword_list,
      required: true,
      keys: [
        introspection_path: [type: :string, required: true],
        documents_root: [type: :string, required: true]
      ]
    ],
    output: [
      type: :keyword_list,
      required: true,
      keys: [
        root: [type: :string, required: true],
        lib_root: [type: :string, required: true],
        docs_path: [type: :string, required: true]
      ]
    ]
  ]

  @spec new(keyword()) :: {:ok, t()} | {:error, ValidationError.t() | term()}
  def new(opts) do
    with {:ok, validated} <- NimbleOptions.validate(opts, @schema) do
      provider = %__MODULE__{
        name: validated[:name],
        namespace: validated[:namespace],
        client_module: validated[:client_module],
        base_url: validated[:base_url],
        auth: validated[:auth],
        source: %Source{
          introspection_path: validated[:source][:introspection_path],
          documents_root: validated[:source][:documents_root]
        },
        output: %Output{
          root: validated[:output][:root],
          lib_root: validated[:output][:lib_root],
          docs_path: validated[:output][:docs_path]
        }
      }

      validate_paths(provider)
    end
  end

  @spec new!(keyword()) :: t()
  def new!(opts) do
    case new(opts) do
      {:ok, provider} -> provider
      {:error, reason} -> raise reason
    end
  end

  @spec load!(t() | module() | String.t()) :: t()
  def load!(%__MODULE__{} = provider), do: provider

  def load!(provider_module) when is_binary(provider_module) do
    provider_module
    |> String.split(".")
    |> Module.concat()
    |> load!()
  end

  def load!(provider_module) when is_atom(provider_module) do
    Code.ensure_loaded!(provider_module)

    cond do
      function_exported?(provider_module, :provider, 0) ->
        load!(provider_module.provider())

      function_exported?(provider_module, :definition, 0) ->
        load!(provider_module.definition())

      true ->
        raise ArgumentError,
              "provider module #{inspect(provider_module)} must export provider/0 or definition/0"
    end
  end

  defp validate_paths(%__MODULE__{} = provider) do
    cond do
      not File.regular?(provider.source.introspection_path) ->
        {:error,
         ArgumentError.exception(
           "missing introspection file: #{provider.source.introspection_path}"
         )}

      not File.dir?(provider.source.documents_root) ->
        {:error,
         ArgumentError.exception("missing documents root: #{provider.source.documents_root}")}

      true ->
        {:ok, provider}
    end
  end
end
