defmodule Prismatic.Client do
  @moduledoc """
  Public runtime client for GraphQL providers.
  """

  alias Prismatic.Context
  alias Prismatic.Error
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
      {:ok, %__MODULE__{context: with_auth_headers(context)}}
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
    metadata = %{
      base_url: context.base_url,
      operation: operation.name,
      kind: operation.kind
    }

    execute_payload(
      context,
      build_payload(operation.document, variables, operation.name),
      metadata,
      opts
    )
  end

  @spec execute_document(t(), String.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def execute_document(client, document, variables \\ %{}, opts \\ []) when is_binary(document) do
    selected_operation = Document.select_operation!(document, Keyword.get(opts, :operation_name))

    metadata = %{
      base_url: client.context.base_url,
      operation: selected_operation.name,
      kind: selected_operation.kind
    }

    execute_payload(
      client.context,
      build_payload(document, variables, selected_operation.name),
      metadata,
      opts
    )
  end

  defp with_auth_headers(%Context{} = context) do
    %{context | headers: Headers.merge_auth(context.headers, context.auth)}
  end

  defp execute_payload(%Context{} = context, payload, metadata, opts) do
    Telemetry.span(context.telemetry_prefix, metadata, fn ->
      case context.transport.execute(context, payload, transport_opts(opts)) do
        {:ok, raw_response} -> normalize_response(raw_response)
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

  defp transport_opts(opts), do: Keyword.drop(opts, [:operation_name])

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
