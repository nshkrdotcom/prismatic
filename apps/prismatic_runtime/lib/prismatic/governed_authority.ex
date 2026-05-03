defmodule Prismatic.GovernedAuthority do
  @moduledoc """
  Authority-selected GraphQL endpoint and credential materialization.

  This value is the governed-mode input for `Prismatic.Client`. Standalone
  clients keep passing `base_url:`, `auth:`, `headers:`, or `oauth2:` directly.
  Governed clients pass one authority value, and the runtime uses only the
  authority endpoint, policy refs, provider headers, and credential headers.
  """

  alias Prismatic.Headers

  @type header :: {String.t(), String.t()}

  @type t :: %__MODULE__{
          base_url: String.t(),
          credential_ref: String.t(),
          credential_lease_ref: String.t(),
          target_ref: String.t(),
          operation_policy_ref: String.t(),
          redaction_ref: String.t(),
          headers: [header()],
          credential_headers: [header()]
        }

  @enforce_keys [
    :base_url,
    :credential_ref,
    :credential_lease_ref,
    :target_ref,
    :operation_policy_ref,
    :redaction_ref
  ]
  defstruct base_url: nil,
            credential_ref: nil,
            credential_lease_ref: nil,
            target_ref: nil,
            operation_policy_ref: nil,
            redaction_ref: nil,
            headers: [],
            credential_headers: []

  @schema [
    base_url: [type: :string, required: true],
    credential_ref: [type: :string, required: true],
    credential_lease_ref: [type: :string, required: true],
    target_ref: [type: :string, required: true],
    operation_policy_ref: [type: :string, required: true],
    redaction_ref: [type: :string, required: true],
    headers: [type: {:list, {:tuple, [:string, :string]}}, default: []],
    credential_headers: [type: {:list, {:tuple, [:string, :string]}}, default: []]
  ]

  @spec new(keyword() | map() | t()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = authority), do: {:ok, authority}

  def new(opts) when is_map(opts) do
    opts
    |> Map.to_list()
    |> new()
  end

  def new(opts) when is_list(opts) do
    with {:ok, validated} <- NimbleOptions.validate(opts, @schema),
         :ok <- validate_non_empty_refs(validated),
         {:ok, headers} <- normalize_headers(validated[:headers], :headers),
         {:ok, credential_headers} <-
           normalize_headers(validated[:credential_headers], :credential_headers),
         :ok <- reject_provider_authorization_header(headers),
         :ok <- require_credential_headers(credential_headers) do
      {:ok,
       struct!(__MODULE__,
         base_url: validated[:base_url],
         credential_ref: validated[:credential_ref],
         credential_lease_ref: validated[:credential_lease_ref],
         target_ref: validated[:target_ref],
         operation_policy_ref: validated[:operation_policy_ref],
         redaction_ref: validated[:redaction_ref],
         headers: headers,
         credential_headers: credential_headers
       )}
    end
  end

  def new(_opts), do: {:error, argument_error("expected governed authority options")}

  @spec new!(keyword() | map() | t()) :: t()
  def new!(opts) do
    case new(opts) do
      {:ok, authority} -> authority
      {:error, reason} -> raise reason
    end
  end

  @spec headers(t()) :: [header()]
  def headers(%__MODULE__{} = authority) do
    authority.headers
    |> merge_headers(authority.credential_headers)
  end

  defp validate_non_empty_refs(validated) do
    [
      :base_url,
      :credential_ref,
      :credential_lease_ref,
      :target_ref,
      :operation_policy_ref,
      :redaction_ref
    ]
    |> Enum.find_value(:ok, fn key ->
      case Keyword.fetch!(validated, key) do
        value when is_binary(value) and value != "" -> nil
        _other -> {:error, argument_error("governed authority requires non-empty #{key}")}
      end
    end)
  end

  defp normalize_headers(headers, field) do
    headers
    |> Enum.reduce_while({:ok, []}, fn
      {key, value}, {:ok, acc} when key != "" and value != "" ->
        {:cont, {:ok, acc ++ [{String.downcase(key), value}]}}

      _other, _acc ->
        {:halt, {:error, argument_error("#{field} must contain non-empty string headers")}}
    end)
  end

  defp reject_provider_authorization_header(headers) do
    if Enum.any?(headers, fn {key, _value} -> key == "authorization" end) do
      {:error,
       argument_error(
         "governed authority provider headers cannot include authorization; use credential_headers"
       )}
    else
      :ok
    end
  end

  defp require_credential_headers([]) do
    {:error, argument_error("governed authority requires credential_headers")}
  end

  defp require_credential_headers(_headers), do: :ok

  defp merge_headers(headers, credential_headers) do
    Enum.reduce(credential_headers, headers, fn {key, value}, acc ->
      Headers.put_header(acc, key, value)
    end)
  end

  defp argument_error(message), do: ArgumentError.exception(message)
end
