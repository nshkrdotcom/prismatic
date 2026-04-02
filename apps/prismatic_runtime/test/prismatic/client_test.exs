defmodule Prismatic.ClientTest do
  use ExUnit.Case, async: true

  import Mox

  alias Prismatic.Client
  alias Prismatic.Error
  alias Prismatic.Operation
  alias Prismatic.Response

  setup :verify_on_exit!

  test "executes an operation through the configured transport" do
    operation =
      Operation.new!(
        id: "viewer",
        name: "Viewer",
        kind: :query,
        document: "query Viewer { viewer { id name } }",
        root_field: "viewer"
      )

    expect(Prismatic.TransportMock, :execute, fn context, payload, _opts ->
      assert context.base_url == "https://api.example.com/graphql"
      assert payload["operationName"] == "Viewer"
      assert payload["variables"] == %{}
      assert payload["query"] == operation.document

      assert Enum.any?(context.headers, fn {key, value} ->
               key == "authorization" and value == "Bearer secret"
             end)

      {:ok,
       %{
         status: 200,
         headers: [{"x-request-id", "req-123"}],
         body: %{"data" => %{"viewer" => %{"id" => "user_1", "name" => "Ada"}}}
       }}
    end)

    client =
      Client.new!(
        base_url: "https://api.example.com/graphql",
        auth: {:bearer, "secret"},
        transport: Prismatic.TransportMock
      )

    assert {:ok,
            %Response{
              status: 200,
              request_id: "req-123",
              data: %{"viewer" => %{"id" => "user_1", "name" => "Ada"}}
            }} = Client.execute_operation(client, operation)
  end

  test "returns a normalized graphql error when the body contains errors" do
    operation =
      Operation.new!(
        id: "viewer",
        name: "Viewer",
        kind: :query,
        document: "query Viewer { viewer { id } }"
      )

    expect(Prismatic.TransportMock, :execute, fn _context, _payload, _opts ->
      {:ok,
       %{
         status: 200,
         headers: [{"x-request-id", "req-graph"}],
         body: %{
           "errors" => [
             %{"message" => "Not authorized", "extensions" => %{"code" => "FORBIDDEN"}}
           ]
         }
       }}
    end)

    client =
      Client.new!(
        base_url: "https://api.example.com/graphql",
        transport: Prismatic.TransportMock
      )

    assert {:error,
            %Error{
              type: :graphql,
              status: 200,
              request_id: "req-graph",
              graphql_errors: [
                %{"message" => "Not authorized", "extensions" => %{"code" => "FORBIDDEN"}}
              ]
            }} = Client.execute_operation(client, operation)
  end

  test "returns a transport error when the adapter fails" do
    operation =
      Operation.new!(
        id: "viewer",
        name: "Viewer",
        kind: :query,
        document: "query Viewer { viewer { id } }"
      )

    expect(Prismatic.TransportMock, :execute, fn _context, _payload, _opts ->
      {:error, :timeout}
    end)

    client =
      Client.new!(
        base_url: "https://api.example.com/graphql",
        transport: Prismatic.TransportMock
      )

    assert {:error, %Error{type: :transport, details: %{reason: :timeout}}} =
             Client.execute_operation(client, operation)
  end

  test "execute_document/4 uses the document's declared operation name" do
    expect(Prismatic.TransportMock, :execute, fn _context, payload, opts ->
      assert payload["operationName"] == "Viewer"
      refute Keyword.has_key?(opts, :operation_name)

      {:ok,
       %{
         status: 200,
         headers: [],
         body: %{"data" => %{"viewer" => %{"id" => "user_1"}}}
       }}
    end)

    client =
      Client.new!(
        base_url: "https://api.example.com/graphql",
        transport: Prismatic.TransportMock
      )

    assert {:ok, %Response{data: %{"viewer" => %{"id" => "user_1"}}}} =
             Client.execute_document(client, "query Viewer { viewer { id } }")
  end

  test "execute_document/4 omits operationName for an anonymous operation" do
    expect(Prismatic.TransportMock, :execute, fn _context, payload, opts ->
      refute Map.has_key?(payload, "operationName")
      refute Keyword.has_key?(opts, :operation_name)

      {:ok,
       %{
         status: 200,
         headers: [],
         body: %{"data" => %{"viewer" => %{"id" => "user_1"}}}
       }}
    end)

    client =
      Client.new!(
        base_url: "https://api.example.com/graphql",
        transport: Prismatic.TransportMock
      )

    assert {:ok, %Response{data: %{"viewer" => %{"id" => "user_1"}}}} =
             Client.execute_document(client, "{ viewer { id } }")
  end

  test "execute_document/4 accepts operation_name for multi-operation documents" do
    expect(Prismatic.TransportMock, :execute, fn _context, payload, opts ->
      assert payload["operationName"] == "Viewer"
      refute Keyword.has_key?(opts, :operation_name)

      {:ok,
       %{
         status: 200,
         headers: [],
         body: %{"data" => %{"viewer" => %{"id" => "user_1"}}}
       }}
    end)

    client =
      Client.new!(
        base_url: "https://api.example.com/graphql",
        transport: Prismatic.TransportMock
      )

    document = """
    query Viewer { viewer { id } }
    mutation UpdateViewer { viewerUpdate(input: {name: "Ada"}) { success } }
    """

    assert {:ok, %Response{data: %{"viewer" => %{"id" => "user_1"}}}} =
             Client.execute_document(client, document, %{}, operation_name: "Viewer")
  end
end
