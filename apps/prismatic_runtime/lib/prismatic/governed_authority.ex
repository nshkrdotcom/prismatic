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
          tenant_ref: String.t(),
          workspace_ref: String.t(),
          organization_ref: String.t(),
          provider_account_ref: String.t(),
          connector_instance_ref: String.t(),
          credential_handle_ref: String.t(),
          credential_ref: String.t(),
          credential_lease_ref: String.t(),
          token_family_ref: String.t(),
          subject_ref: String.t(),
          target_ref: String.t(),
          request_scope_ref: String.t(),
          operation_policy_ref: String.t(),
          operation_name: String.t(),
          operation_document_ref: String.t(),
          allowed_variable_names: [String.t()],
          identity_kind: String.t(),
          redaction_ref: String.t(),
          headers: [header()],
          credential_headers: [header()]
        }

  @enforce_keys [
    :base_url,
    :tenant_ref,
    :workspace_ref,
    :organization_ref,
    :provider_account_ref,
    :connector_instance_ref,
    :credential_handle_ref,
    :credential_ref,
    :credential_lease_ref,
    :token_family_ref,
    :subject_ref,
    :target_ref,
    :request_scope_ref,
    :operation_policy_ref,
    :operation_name,
    :operation_document_ref,
    :allowed_variable_names,
    :identity_kind,
    :redaction_ref
  ]
  defstruct base_url: nil,
            tenant_ref: nil,
            workspace_ref: nil,
            organization_ref: nil,
            provider_account_ref: nil,
            connector_instance_ref: nil,
            credential_handle_ref: nil,
            credential_ref: nil,
            credential_lease_ref: nil,
            token_family_ref: nil,
            subject_ref: nil,
            target_ref: nil,
            request_scope_ref: nil,
            operation_policy_ref: nil,
            operation_name: nil,
            operation_document_ref: nil,
            allowed_variable_names: [],
            identity_kind: nil,
            redaction_ref: nil,
            headers: [],
            credential_headers: []

  @schema [
    base_url: [type: :string, required: true],
    tenant_ref: [type: :string, required: true],
    workspace_ref: [type: :string, required: true],
    organization_ref: [type: :string, required: true],
    provider_account_ref: [type: :string, required: true],
    connector_instance_ref: [type: :string, required: true],
    credential_handle_ref: [type: :string, required: true],
    credential_ref: [type: :string, required: false],
    credential_lease_ref: [type: :string, required: true],
    token_family_ref: [type: :string, required: true],
    subject_ref: [type: :string, required: true],
    target_ref: [type: :string, required: true],
    request_scope_ref: [type: :string, required: true],
    operation_policy_ref: [type: :string, required: true],
    operation_name: [type: :string, required: true],
    operation_document_ref: [type: :string, required: true],
    allowed_variable_names: [type: {:list, :string}, default: []],
    identity_kind: [type: :string, required: true],
    redaction_ref: [type: :string, required: true],
    headers: [type: {:list, {:tuple, [:string, :string]}}, default: []],
    credential_headers: [type: {:list, {:tuple, [:string, :string]}}, default: []]
  ]

  @unmanaged_authority_keys [
    :api_token,
    "api_token",
    :env,
    "env",
    :default_client,
    "default_client",
    :endpoint_url,
    "endpoint_url",
    :oauth2,
    "oauth2",
    :auth,
    "auth",
    :client_auth,
    "client_auth",
    :operation_auth,
    "operation_auth",
    :middleware,
    "middleware",
    :token_source,
    "token_source",
    :provider_payload,
    "provider_payload"
  ]

  @ref_prefixes [
    tenant_ref: "tenant://",
    workspace_ref: "workspace://",
    organization_ref: "organization://",
    provider_account_ref: "provider-account://",
    connector_instance_ref: "connector-instance://",
    credential_handle_ref: "credential-handle://",
    credential_lease_ref: "credential-lease://",
    token_family_ref: "token-family://",
    subject_ref: "subject://",
    target_ref: "target://",
    request_scope_ref: "request-scope://",
    operation_policy_ref: "operation-policy://",
    operation_document_ref: "graphql-document://",
    redaction_ref: "redaction://"
  ]

  @identity_kinds ["api_token", "oauth_app_user", "agent_session"]

  @spec new(keyword() | map() | t()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = authority), do: {:ok, authority}

  def new(opts) when is_map(opts) do
    opts
    |> Map.to_list()
    |> new()
  end

  def new(opts) when is_list(opts) do
    with :ok <- reject_unmanaged_authority_options(opts),
         {:ok, validated} <- NimbleOptions.validate(opts, @schema),
         :ok <- validate_non_empty_refs(validated),
         :ok <- validate_ref_prefixes(validated),
         :ok <- validate_credential_ref(validated),
         :ok <- validate_identity_kind(validated[:identity_kind]),
         {:ok, allowed_variable_names} <-
           normalize_allowed_variable_names(validated[:allowed_variable_names]),
         {:ok, headers} <- normalize_headers(validated[:headers], :headers),
         {:ok, credential_headers} <-
           normalize_headers(validated[:credential_headers], :credential_headers),
         :ok <- reject_provider_authorization_header(headers),
         :ok <- require_credential_headers(credential_headers) do
      {:ok,
       struct!(__MODULE__,
         base_url: validated[:base_url],
         tenant_ref: validated[:tenant_ref],
         workspace_ref: validated[:workspace_ref],
         organization_ref: validated[:organization_ref],
         provider_account_ref: validated[:provider_account_ref],
         connector_instance_ref: validated[:connector_instance_ref],
         credential_handle_ref: validated[:credential_handle_ref],
         credential_ref: validated[:credential_handle_ref],
         credential_lease_ref: validated[:credential_lease_ref],
         token_family_ref: validated[:token_family_ref],
         subject_ref: validated[:subject_ref],
         target_ref: validated[:target_ref],
         request_scope_ref: validated[:request_scope_ref],
         operation_policy_ref: validated[:operation_policy_ref],
         operation_name: String.trim(validated[:operation_name]),
         operation_document_ref: validated[:operation_document_ref],
         allowed_variable_names: allowed_variable_names,
         identity_kind: validated[:identity_kind],
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

  defp reject_unmanaged_authority_options(opts) do
    case unmanaged_authority_option(opts) do
      nil ->
        :ok

      key ->
        {:error,
         argument_error(
           "governed authority rejects unmanaged #{key}; use credential handle authority refs"
         )}
    end
  end

  defp unmanaged_authority_option(opts) do
    Enum.find_value(opts, fn
      {key, _value} ->
        if key in @unmanaged_authority_keys, do: key

      _entry ->
        nil
    end)
  end

  defp validate_non_empty_refs(validated) do
    [
      :base_url,
      :tenant_ref,
      :workspace_ref,
      :organization_ref,
      :provider_account_ref,
      :connector_instance_ref,
      :credential_handle_ref,
      :credential_lease_ref,
      :token_family_ref,
      :subject_ref,
      :target_ref,
      :request_scope_ref,
      :operation_policy_ref,
      :operation_name,
      :operation_document_ref,
      :identity_kind,
      :redaction_ref
    ]
    |> Enum.find_value(:ok, &non_empty_ref_error(validated, &1))
  end

  defp non_empty_ref_error(validated, key) do
    value = Keyword.fetch!(validated, key)

    if is_binary(value) and String.trim(value) != "" do
      nil
    else
      {:error, argument_error("governed authority requires non-empty #{key}")}
    end
  end

  defp validate_ref_prefixes(validated) do
    Enum.find_value(@ref_prefixes, :ok, fn {key, prefix} ->
      value = Keyword.fetch!(validated, key)

      if String.starts_with?(value, prefix) do
        nil
      else
        {:error, argument_error("governed authority requires #{key} to start with #{prefix}")}
      end
    end)
  end

  defp validate_credential_ref(validated) do
    credential_handle_ref = validated[:credential_handle_ref]

    case Keyword.get(validated, :credential_ref) do
      nil ->
        :ok

      credential_ref when credential_ref == credential_handle_ref ->
        :ok

      _other ->
        {:error,
         argument_error(
           "governed authority credential_ref must match credential_handle_ref when provided"
         )}
    end
  end

  defp validate_identity_kind(identity_kind) do
    if identity_kind in @identity_kinds do
      :ok
    else
      {:error, argument_error("governed authority identity_kind is not supported")}
    end
  end

  defp normalize_allowed_variable_names(variable_names) do
    Enum.reduce_while(variable_names, {:ok, []}, fn variable_name, {:ok, acc} ->
      case String.trim(variable_name) do
        "" ->
          {:halt,
           {:error, argument_error("governed authority allowed_variable_names cannot be blank")}}

        trimmed ->
          {:cont, {:ok, acc ++ [trimmed]}}
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
         "governed authority rejects unmanaged headers; use credential_headers for authorization"
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

defimpl Inspect, for: Prismatic.GovernedAuthority do
  import Inspect.Algebra

  def inspect(authority, opts) do
    fields = [
      base_url: authority.base_url,
      tenant_ref: authority.tenant_ref,
      workspace_ref: authority.workspace_ref,
      organization_ref: authority.organization_ref,
      provider_account_ref: authority.provider_account_ref,
      connector_instance_ref: authority.connector_instance_ref,
      credential_handle_ref: authority.credential_handle_ref,
      credential_lease_ref: authority.credential_lease_ref,
      token_family_ref: authority.token_family_ref,
      subject_ref: authority.subject_ref,
      target_ref: authority.target_ref,
      request_scope_ref: authority.request_scope_ref,
      operation_policy_ref: authority.operation_policy_ref,
      operation_name: authority.operation_name,
      operation_document_ref: authority.operation_document_ref,
      allowed_variable_names: authority.allowed_variable_names,
      identity_kind: authority.identity_kind,
      redaction_ref: authority.redaction_ref,
      headers: authority.headers,
      credential_headers: "[REDACTED]"
    ]

    concat(["#Prismatic.GovernedAuthority<", to_doc(fields, opts), ">"])
  end
end
