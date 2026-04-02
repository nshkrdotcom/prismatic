defmodule Prismatic.Context do
  @moduledoc """
  Runtime context shared across operation executions.
  """

  @type auth_option ::
          nil
          | {:bearer, String.t()}
          | {:header, String.t(), String.t()}

  @type oauth2_option :: keyword() | nil

  @type t :: %__MODULE__{
          base_url: String.t(),
          headers: [{String.t(), String.t()}],
          auth: auth_option(),
          oauth2: oauth2_option(),
          transport: module(),
          req_options: keyword(),
          telemetry_prefix: [atom()]
        }

  @enforce_keys [:base_url, :transport]
  defstruct base_url: nil,
            headers: [],
            auth: nil,
            oauth2: nil,
            transport: nil,
            req_options: [],
            telemetry_prefix: [:prismatic, :execute]

  @schema [
    base_url: [type: :string, required: true],
    headers: [type: {:list, {:tuple, [:string, :string]}}, default: []],
    auth: [type: :any, default: nil],
    oauth2: [type: :any, default: nil],
    transport: [type: :atom, default: Prismatic.Transport.Req],
    req_options: [type: :keyword_list, default: []],
    telemetry_prefix: [type: {:list, :atom}, default: [:prismatic, :execute]]
  ]

  @spec new(keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(opts) do
    with {:ok, validated} <- NimbleOptions.validate(opts, @schema) do
      validate_auth_configuration(validated)
      |> case do
        :ok ->
          {:ok,
           struct!(__MODULE__,
             base_url: validated[:base_url],
             headers: normalize_headers(validated[:headers]),
             auth: validated[:auth],
             oauth2: normalize_oauth2(validated[:oauth2]),
             transport: validated[:transport],
             req_options: validated[:req_options],
             telemetry_prefix: validated[:telemetry_prefix]
           )}

        {:error, _reason} = error ->
          error
      end
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

  defp normalize_oauth2(nil), do: nil
  defp normalize_oauth2(oauth2) when is_list(oauth2), do: oauth2
  defp normalize_oauth2(oauth2), do: [token_source: oauth2]

  defp validate_auth_configuration(validated) do
    auth = validated[:auth]
    oauth2 = validated[:oauth2]

    if is_nil(auth) or is_nil(oauth2) do
      :ok
    else
      {:error, ArgumentError.exception("pass either :auth or :oauth2, not both")}
    end
  end
end
