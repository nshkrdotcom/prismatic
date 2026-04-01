defmodule Prismatic.TelemetryTest do
  use ExUnit.Case, async: false

  import Mox

  alias Prismatic.Client
  alias Prismatic.Operation
  alias Prismatic.TestTelemetryHandler

  setup :verify_on_exit!

  test "emits start and stop telemetry events" do
    handler_id = "prismatic-test-handler-#{System.unique_integer([:positive])}"
    test_pid = self()

    :ok =
      :telemetry.attach_many(
        handler_id,
        [
          [:prismatic, :execute, :start],
          [:prismatic, :execute, :stop]
        ],
        &TestTelemetryHandler.handle_event/4,
        test_pid
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    operation =
      Operation.new!(
        id: "viewer",
        name: "Viewer",
        kind: :query,
        document: "query Viewer { viewer { id } }"
      )

    expect(Prismatic.TransportMock, :execute, fn _context, _payload, _opts ->
      {:ok, %{status: 200, headers: [], body: %{"data" => %{"viewer" => %{"id" => "x"}}}}}
    end)

    client =
      Client.new!(
        base_url: "https://api.example.com/graphql",
        transport: Prismatic.TransportMock
      )

    assert {:ok, _response} = Client.execute_operation(client, operation)

    assert_receive {:telemetry, [:prismatic, :execute, :start], _measurements,
                    %{operation: "Viewer"}}

    assert_receive {:telemetry, [:prismatic, :execute, :stop], _measurements,
                    %{operation: "Viewer"}}
  end
end
