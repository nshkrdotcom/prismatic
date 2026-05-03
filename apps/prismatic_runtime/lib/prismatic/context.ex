defmodule Prismatic.Context do
  @moduledoc """
  Runtime context shared across operation executions.
  """

  alias Prismatic.GovernedAuthority

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
          governed_authority: GovernedAuthority.t() | nil,
          transport: module(),
          req_options: keyword(),
          telemetry_prefix: [atom()]
        }

  @enforce_keys [:base_url, :transport]
  defstruct base_url: nil,
            headers: [],
            auth: nil,
            oauth2: nil,
            governed_authority: nil,
            transport: nil,
            req_options: [],
            telemetry_prefix: [:prismatic, :execute]

  @schema [
    base_url: [type: :string, required: false],
    headers: [type: {:list, {:tuple, [:string, :string]}}, default: []],
    auth: [type: :any, default: nil],
    oauth2: [type: :any, default: nil],
    governed_authority: [type: :any, default: nil],
    transport: [type: :atom, default: Prismatic.Transport.Pristine],
    req_options: [type: :keyword_list, default: []],
    telemetry_prefix: [type: {:list, :atom}, default: [:prismatic, :execute]]
  ]

  @spec new(keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(opts) do
    with {:ok, validated} <- NimbleOptions.validate(opts, @schema),
         :ok <- validate_auth_configuration(validated),
         {:ok, governed_authority} <- normalize_governed_authority(validated[:governed_authority]),
         :ok <- validate_mode(opts, validated, governed_authority) do
      {:ok, build_context(validated, governed_authority)}
    end
  end

  @spec new!(keyword()) :: t()
  def new!(opts) do
    case new(opts) do
      {:ok, context} -> context
      {:error, reason} -> raise reason
    end
  end

  @spec governed?(t()) :: boolean()
  def governed?(%__MODULE__{governed_authority: %GovernedAuthority{}}), do: true
  def governed?(%__MODULE__{}), do: false

  defp build_context(validated, nil) do
    struct!(__MODULE__,
      base_url: validated[:base_url],
      headers: normalize_headers(validated[:headers]),
      auth: validated[:auth],
      oauth2: normalize_oauth2(validated[:oauth2]),
      governed_authority: nil,
      transport: validated[:transport],
      req_options: validated[:req_options],
      telemetry_prefix: validated[:telemetry_prefix]
    )
  end

  defp build_context(validated, %GovernedAuthority{} = governed_authority) do
    struct!(__MODULE__,
      base_url: governed_authority.base_url,
      headers: GovernedAuthority.headers(governed_authority),
      auth: nil,
      oauth2: nil,
      governed_authority: governed_authority,
      transport: validated[:transport],
      req_options: validated[:req_options],
      telemetry_prefix: validated[:telemetry_prefix]
    )
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

  defp normalize_governed_authority(nil), do: {:ok, nil}
  defp normalize_governed_authority(%GovernedAuthority{} = authority), do: {:ok, authority}

  defp normalize_governed_authority(value) do
    GovernedAuthority.new(value)
  end

  defp validate_mode(_opts, validated, nil) do
    case validated[:base_url] do
      base_url when is_binary(base_url) and base_url != "" ->
        :ok

      _other ->
        {:error, ArgumentError.exception("base_url is required for standalone Prismatic clients")}
    end
  end

  defp validate_mode(opts, validated, %GovernedAuthority{}) do
    with :ok <- reject_governed_context_option(opts, :base_url),
         :ok <- reject_governed_context_option(opts, :headers),
         :ok <- reject_governed_context_option(opts, :auth),
         :ok <- reject_governed_context_option(opts, :oauth2) do
      reject_governed_req_options(validated[:req_options])
    end
  end

  defp reject_governed_context_option(opts, key) do
    if Keyword.has_key?(opts, key) do
      {:error,
       ArgumentError.exception(
         "governed Prismatic clients cannot accept #{key}; use governed_authority"
       )}
    else
      :ok
    end
  end

  defp reject_governed_req_options(req_options) do
    case forbidden_governed_req_option(req_options) do
      nil ->
        :ok

      key ->
        {:error,
         ArgumentError.exception(
           "governed Prismatic clients cannot accept req_options #{key}; use governed_authority"
         )}
    end
  end

  defp forbidden_governed_req_option(req_options) when is_list(req_options) do
    Enum.find_value(req_options, fn
      {key, _value} ->
        if key in forbidden_governed_request_keys(), do: key

      _entry ->
        nil
    end)
  end

  defp forbidden_governed_req_option(_req_options), do: nil

  defp forbidden_governed_request_keys do
    [
      :headers,
      "headers",
      :authorization,
      "authorization",
      :auth,
      "auth",
      :oauth2,
      "oauth2",
      :base_url,
      "base_url",
      :url,
      "url",
      :endpoint,
      "endpoint",
      :endpoint_url,
      "endpoint_url",
      :operation_policy,
      "operation_policy",
      :operation_policy_ref,
      "operation_policy_ref"
    ]
  end
end
