defmodule Prismatic.Client do
  @moduledoc """
  Public runtime client for GraphQL providers.
  """

  alias Prismatic.Context
  alias Prismatic.Error
  alias Prismatic.GovernedAuthority
  alias Prismatic.GraphQL.Document
  alias Prismatic.Headers
  alias Prismatic.Operation
  alias Prismatic.Response
  alias Prismatic.Telemetry

  @type t :: %__MODULE__{
          context: Context.t()
        }

  @enforce_keys [:context]
  defstruct [:context]

  @spec new(keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(opts) do
    with {:ok, context} <- Context.new(opts) do
      {:ok, %__MODULE__{context: context}}
    end
  end

  @spec new!(keyword()) :: t()
  def new!(opts) do
    case new(opts) do
      {:ok, client} -> client
      {:error, reason} -> raise reason
    end
  end

  @spec execute_operation(t(), Operation.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def execute_operation(
        %__MODULE__{context: context},
        %Operation{} = operation,
        variables \\ %{},
        opts \\ []
      ) do
    with :ok <- validate_governed_operation_scope(context, operation.name, variables) do
      metadata = metadata(context, operation.name, operation.kind)

      execute_payload(
        context,
        build_payload(operation.document, variables, operation.name),
        metadata,
        opts
      )
    end
  end

  @spec execute_document(t(), String.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def execute_document(client, document, variables \\ %{}, opts \\ []) when is_binary(document) do
    with {:ok, selected_operation} <- select_operation(client.context, document, opts),
         :ok <-
           validate_governed_operation_scope(client.context, selected_operation.name, variables) do
      metadata = metadata(client.context, selected_operation.name, selected_operation.kind)

      execute_payload(
        client.context,
        build_payload(document, variables, selected_operation.name),
        metadata,
        opts
      )
    end
  end

  defp execute_payload(%Context{} = context, payload, metadata, opts) do
    Telemetry.span(context.telemetry_prefix, metadata, fn ->
      with :ok <- reject_public_simulation_selector(opts),
           :ok <- reject_governed_request_options(context, opts),
           {:ok, resolved_context} <- resolve_context_auth(context),
           {:ok, raw_response} <-
             resolved_context.transport.execute(resolved_context, payload, transport_opts(opts)) do
        normalize_response(raw_response)
      else
        {:error, %Error{} = error} -> {:error, error}
        {:error, reason} -> {:error, transport_error(reason)}
      end
    end)
  end

  defp build_payload(document, variables, operation_name) do
    %{
      "query" => document,
      "variables" => variables
    }
    |> maybe_put_operation_name(operation_name)
  end

  defp maybe_put_operation_name(payload, operation_name) when is_binary(operation_name) do
    Map.put(payload, "operationName", operation_name)
  end

  defp maybe_put_operation_name(payload, nil), do: payload

  defp metadata(%Context{} = context, operation_name, operation_kind) do
    %{
      base_url: context.base_url,
      operation: operation_name,
      kind: operation_kind
    }
    |> maybe_put_governed_metadata(context.governed_authority)
  end

  defp maybe_put_governed_metadata(metadata, %GovernedAuthority{} = authority) do
    Map.merge(metadata, %{
      governed?: true,
      tenant_ref: authority.tenant_ref,
      workspace_ref: authority.workspace_ref,
      organization_ref: authority.organization_ref,
      provider_account_ref: authority.provider_account_ref,
      connector_instance_ref: authority.connector_instance_ref,
      credential_handle_ref: authority.credential_handle_ref,
      credential_lease_ref: authority.credential_lease_ref,
      target_ref: authority.target_ref,
      request_scope_ref: authority.request_scope_ref,
      operation_policy_ref: authority.operation_policy_ref,
      operation_document_ref: authority.operation_document_ref,
      identity_kind: authority.identity_kind,
      redaction_ref: authority.redaction_ref
    })
  end

  defp maybe_put_governed_metadata(metadata, nil), do: metadata

  defp select_operation(%Context{governed_authority: %GovernedAuthority{}}, document, opts) do
    {:ok, Document.select_operation!(document, Keyword.get(opts, :operation_name))}
  rescue
    ArgumentError ->
      {:error, governed_operation_scope_error(:operation_document)}
  end

  defp select_operation(%Context{}, document, opts) do
    {:ok, Document.select_operation!(document, Keyword.get(opts, :operation_name))}
  end

  defp validate_governed_operation_scope(
         %Context{governed_authority: %GovernedAuthority{} = authority},
         operation_name,
         variables
       ) do
    case validate_governed_operation_name(authority, operation_name) do
      :ok -> validate_governed_variables(authority, variables)
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp validate_governed_operation_scope(%Context{}, _operation_name, _variables), do: :ok

  defp validate_governed_operation_name(%GovernedAuthority{} = authority, operation_name) do
    if operation_name == authority.operation_name do
      :ok
    else
      {:error, governed_operation_scope_error(:operation_name, authority)}
    end
  end

  defp validate_governed_variables(%GovernedAuthority{} = authority, variables)
       when is_map(variables) do
    if Enum.all?(Map.keys(variables), &allowed_variable?(&1, authority.allowed_variable_names)) do
      :ok
    else
      {:error, governed_operation_scope_error(:variables, authority)}
    end
  end

  defp validate_governed_variables(%GovernedAuthority{} = authority, _variables),
    do: {:error, governed_operation_scope_error(:variables, authority)}

  defp allowed_variable?(key, allowed_variable_names) when is_binary(key) do
    key in allowed_variable_names
  end

  defp allowed_variable?(key, allowed_variable_names) when is_atom(key) do
    Atom.to_string(key) in allowed_variable_names
  end

  defp allowed_variable?(_key, _allowed_variable_names), do: false

  defp transport_opts(opts), do: Keyword.drop(opts, [:operation_name])

  defp reject_public_simulation_selector(values) when is_list(values) do
    if Enum.any?(values, &public_simulation_entry?/1) do
      {:error, public_simulation_selector_error()}
    else
      :ok
    end
  end

  defp reject_public_simulation_selector(_values), do: :ok

  defp public_simulation_entry?({key, _value}), do: key in [:simulation, "simulation"]
  defp public_simulation_entry?(_entry), do: false

  defp reject_governed_request_options(%Context{governed_authority: nil}, _opts), do: :ok

  defp reject_governed_request_options(%Context{}, opts) when is_list(opts) do
    case forbidden_governed_request_option(opts) do
      nil -> :ok
      key -> {:error, governed_request_error(key)}
    end
  end

  defp reject_governed_request_options(%Context{}, _opts), do: :ok

  defp forbidden_governed_request_option(opts) do
    Enum.find_value(opts, fn
      {key, _value} ->
        if key in forbidden_governed_request_keys(), do: key

      _entry ->
        nil
    end)
  end

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
      "operation_policy_ref",
      :api_token,
      "api_token",
      :env,
      "env",
      :default_client,
      "default_client",
      :operation_auth,
      "operation_auth",
      :client_auth,
      "client_auth",
      :provider_payload,
      "provider_payload",
      :middleware,
      "middleware",
      :token_source,
      "token_source"
    ]
  end

  defp public_simulation_selector_error do
    %Error{
      type: :transport,
      message: "GraphQL request used a forbidden public simulation selector",
      status: nil,
      graphql_errors: nil,
      request_id: nil,
      details: %{reason: {:public_simulation_selector_forbidden, :prismatic}}
    }
  end

  defp governed_request_error(key) do
    %Error{
      type: :auth,
      message: "Governed GraphQL request used unmanaged request options",
      status: nil,
      graphql_errors: nil,
      request_id: nil,
      details: %{reason: {:governed_request_option_forbidden, key}}
    }
  end

  defp governed_operation_scope_error(reason) do
    %Error{
      type: :auth,
      message: "Governed GraphQL operation is outside authority scope",
      status: nil,
      graphql_errors: nil,
      request_id: nil,
      details: %{reason: {:governed_operation_scope_forbidden, reason}}
    }
  end

  defp governed_operation_scope_error(reason, %GovernedAuthority{} = authority) do
    %Error{
      type: :auth,
      message: "Governed GraphQL operation is outside authority scope",
      status: nil,
      graphql_errors: nil,
      request_id: nil,
      details: %{
        reason: {:governed_operation_scope_forbidden, reason},
        credential_handle_ref: authority.credential_handle_ref,
        credential_lease_ref: authority.credential_lease_ref,
        request_scope_ref: authority.request_scope_ref,
        operation_policy_ref: authority.operation_policy_ref,
        operation_document_ref: authority.operation_document_ref
      }
    }
  end

  defp resolve_context_auth(%Context{} = context) do
    with {:ok, headers} <- resolve_headers(context) do
      {:ok, %{context | headers: headers}}
    end
  end

  defp resolve_headers(%Context{} = context) do
    headers = Headers.merge_auth(context.headers, context.auth)

    case resolve_oauth2_headers(context.oauth2) do
      {:ok, []} ->
        {:ok, headers}

      {:ok, oauth2_headers} ->
        {:ok,
         Enum.reduce(oauth2_headers, headers, &Headers.put_header(&2, elem(&1, 0), elem(&1, 1)))}

      {:error, reason} ->
        {:error, auth_error(reason)}
    end
  end

  defp resolve_oauth2_headers(nil), do: {:ok, []}

  defp resolve_oauth2_headers(oauth2) when is_list(oauth2) do
    with {:ok, {source_module, source_opts}} <- fetch_oauth2_source(oauth2),
         {:ok, %Prismatic.OAuth2.Token{} = token} <-
           normalize_token_fetch_result(source_module.fetch(source_opts)),
         {:ok, access_token} <- fetch_access_token(token) do
      {:ok, [{"authorization", "Bearer #{access_token}"}]}
    end
  end

  defp fetch_oauth2_source(opts) do
    case Keyword.get(opts, :token_source) do
      {module, source_opts} when is_atom(module) and is_list(source_opts) ->
        {:ok, {module, source_opts}}

      module when is_atom(module) ->
        {:ok, {module, []}}

      _other ->
        {:error, :missing_oauth2_token_source}
    end
  end

  defp normalize_token_fetch_result({:ok, %Prismatic.OAuth2.Token{} = token}), do: {:ok, token}
  defp normalize_token_fetch_result(:error), do: {:error, :missing_oauth2_token}
  defp normalize_token_fetch_result({:error, _reason} = error), do: error
  defp normalize_token_fetch_result(_other), do: {:error, :invalid_oauth2_token_source_response}

  defp fetch_access_token(%Prismatic.OAuth2.Token{access_token: access_token})
       when is_binary(access_token) and access_token != "" do
    {:ok, access_token}
  end

  defp fetch_access_token(_token), do: {:error, :missing_oauth2_access_token}

  defp normalize_response(%{status: status, headers: headers, body: body}) do
    request_id = header_value(headers, "x-request-id")
    errors = Map.get(body, "errors", [])

    cond do
      is_list(errors) and errors != [] ->
        {:error,
         %Error{
           type: :graphql,
           message: graphql_message(errors),
           status: status,
           graphql_errors: errors,
           request_id: request_id,
           details: %{body: body}
         }}

      status >= 400 ->
        {:error,
         %Error{
           type: :http,
           message: "GraphQL request failed with HTTP status #{status}",
           status: status,
           graphql_errors: nil,
           request_id: request_id,
           details: %{body: body}
         }}

      true ->
        {:ok,
         %Response{
           status: status,
           data: Map.get(body, "data"),
           errors: errors,
           extensions: Map.get(body, "extensions"),
           headers: headers,
           request_id: request_id
         }}
    end
  end

  defp header_value(headers, name) do
    lowered = String.downcase(name)

    Enum.find_value(headers, fn
      {key, value} when is_binary(key) ->
        if String.downcase(key) == lowered, do: value

      _other ->
        nil
    end)
  end

  defp graphql_message([%{"message" => message} | _rest]) when is_binary(message), do: message
  defp graphql_message(_errors), do: "GraphQL request failed"

  defp auth_error(reason) do
    %Error{
      type: :auth,
      message: "GraphQL request failed during auth setup",
      status: nil,
      graphql_errors: nil,
      request_id: nil,
      details: %{reason: reason}
    }
  end

  defp transport_error(reason) do
    %Error{
      type: :transport,
      message: "GraphQL request failed during transport",
      status: nil,
      graphql_errors: nil,
      request_id: nil,
      details: %{reason: reason}
    }
  end
end
