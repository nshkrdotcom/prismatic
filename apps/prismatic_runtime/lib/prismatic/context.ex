defmodule Prismatic.Context do
  @moduledoc """
  Runtime context shared across operation executions.
  """

  @type auth_option ::
          nil
          | {:bearer, String.t()}
          | {:header, String.t(), String.t()}

  @type t :: %__MODULE__{
          base_url: String.t(),
          headers: [{String.t(), String.t()}],
          auth: auth_option(),
          transport: module(),
          req_options: keyword(),
          telemetry_prefix: [atom()]
        }

  @enforce_keys [:base_url, :transport]
  defstruct base_url: nil,
            headers: [],
            auth: nil,
            transport: nil,
            req_options: [],
            telemetry_prefix: [:prismatic, :execute]

  alias NimbleOptions.ValidationError

  @schema [
    base_url: [type: :string, required: true],
    headers: [type: {:list, {:tuple, [:string, :string]}}, default: []],
    auth: [type: :any, default: nil],
    transport: [type: :atom, default: Prismatic.Transport.Req],
    req_options: [type: :keyword_list, default: []],
    telemetry_prefix: [type: {:list, :atom}, default: [:prismatic, :execute]]
  ]

  @spec new(keyword()) :: {:ok, t()} | {:error, ValidationError.t()}
  def new(opts) do
    with {:ok, validated} <- NimbleOptions.validate(opts, @schema) do
      {:ok,
       struct!(__MODULE__,
         base_url: validated[:base_url],
         headers: normalize_headers(validated[:headers]),
         auth: validated[:auth],
         transport: validated[:transport],
         req_options: validated[:req_options],
         telemetry_prefix: validated[:telemetry_prefix]
       )}
    end
  end

  @spec new!(keyword()) :: t()
  def new!(opts) do
    case new(opts) do
      {:ok, context} -> context
      {:error, reason} -> raise reason
    end
  end

  defp normalize_headers(headers) do
    Enum.map(headers, fn {key, value} ->
      {String.downcase(key), value}
    end)
  end
end
