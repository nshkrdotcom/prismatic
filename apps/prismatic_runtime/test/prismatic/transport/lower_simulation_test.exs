defmodule Prismatic.Transport.LowerSimulationTest do
  use ExUnit.Case, async: false

  alias Prismatic.{Client, Error, Operation, Response}
  alias Prismatic.Transport.LowerSimulation

  @config_key :graphql_simulation_profiles

  setup do
    previous_config = Application.get_env(:prismatic, @config_key)

    on_exit(fn ->
      restore_env(previous_config)
    end)

    Application.delete_env(:prismatic, @config_key)
    :ok
  end

  test "execute_operation returns Linear-shaped data through Pristine lower simulation" do
    Application.put_env(:prismatic, @config_key,
      required?: true,
      profiles: %{
        "LinearIssue" => [
          scenario_ref: "phase5prelim://prismatic/linear/issue",
          response: %{
            "data" => %{
              "issue" => %{"id" => "LIN-1", "title" => "Wire simulation"}
            }
          },
          headers: %{"x-request-id" => "req-linear-1"}
        ]
      }
    )

    client =
      Client.new!(
        base_url: "http://127.0.0.1:1/graphql",
        auth: {:bearer, "secret"},
        transport: LowerSimulation
      )

    operation =
      Operation.new!(
        id: "linear.issue",
        name: "LinearIssue",
        kind: :query,
        document: "query LinearIssue($id: ID!) { issue(id: $id) { id title } }"
      )

    assert {:ok, %Response{} = response} =
             Client.execute_operation(client, operation, %{"id" => "LIN-1"})

    assert response.status == 200
    assert response.request_id == "req-linear-1"
    assert response.data == %{"issue" => %{"id" => "LIN-1", "title" => "Wire simulation"}}
  end

  test "execute_document preserves GraphQL error shaping over simulated lower HTTP" do
    Application.put_env(:prismatic, @config_key,
      required?: true,
      profiles: %{
        "LinearViewer" => [
          scenario_ref: "phase5prelim://prismatic/linear/graphql-error",
          response: %{
            "errors" => [
              %{"message" => "Not authorized", "extensions" => %{"code" => "FORBIDDEN"}}
            ]
          },
          headers: %{"x-request-id" => "req-linear-error"}
        ]
      }
    )

    client =
      Client.new!(
        base_url: "http://127.0.0.1:1/graphql",
        transport: LowerSimulation
      )

    assert {:error,
            %Error{
              type: :graphql,
              status: 200,
              request_id: "req-linear-error",
              graphql_errors: [
                %{"message" => "Not authorized", "extensions" => %{"code" => "FORBIDDEN"}}
              ]
            }} =
             Client.execute_document(client, "query LinearViewer { viewer { id } }")
  end

  test "missing required profile fails before any HTTP egress" do
    Application.put_env(:prismatic, @config_key, required?: true, profiles: %{})

    client =
      Client.new!(
        base_url: "http://127.0.0.1:1/graphql",
        transport: LowerSimulation
      )

    assert {:error,
            %Error{
              type: :transport,
              details: %{reason: {:prismatic_simulation_profile_required, keys}}
            }} = Client.execute_document(client, "query MissingProfile { viewer { id } }")

    assert "MissingProfile" in keys
  end

  test "invalid lower descriptor fails closed before HTTP egress" do
    Application.put_env(:prismatic, @config_key,
      required?: true,
      profiles: %{
        "InvalidLower" => [
          scenario_ref: "phase5prelim://prismatic/invalid-lower",
          side_effect_policy: "allow_external_egress",
          response: %{"data" => %{"viewer" => %{"id" => "ignored"}}}
        ]
      }
    )

    context =
      Prismatic.Context.new!(
        base_url: "http://127.0.0.1:1/graphql",
        transport: LowerSimulation
      )

    payload = %{
      "query" => "query InvalidLower { viewer { id } }",
      "variables" => %{},
      "operationName" => "InvalidLower"
    }

    assert {:error, {:execution_plane_transport, failure, raw_payload}} =
             LowerSimulation.execute(context, payload, [])

    assert failure.failure_class == :route_unresolved
    assert raw_payload.side_effect_result == "blocked_before_dispatch"
    assert raw_payload.error =~ "deny_external_egress"
  end

  test "context req_options can supply GraphQL simulation profiles without request options" do
    client =
      Client.new!(
        base_url: "http://127.0.0.1:1/graphql",
        transport: LowerSimulation,
        req_options: [
          graphql_simulation_profiles: [
            required?: true,
            profiles: %{
              "LinearViewer" => [
                scenario_ref: "phase5prelim://prismatic/context-config",
                response: %{"data" => %{"viewer" => %{"id" => "viewer-1"}}}
              ]
            }
          ]
        ]
      )

    assert {:ok, %Response{data: %{"viewer" => %{"id" => "viewer-1"}}}} =
             Client.execute_document(client, "query LinearViewer { viewer { id } }")
  end

  defp restore_env(nil), do: Application.delete_env(:prismatic, @config_key)
  defp restore_env(config), do: Application.put_env(:prismatic, @config_key, config)
end
