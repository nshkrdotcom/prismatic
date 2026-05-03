defmodule Prismatic.Phase6ContractsTest do
  use ExUnit.Case, async: true

  alias Prismatic.AdapterSelectionPolicy
  alias Prismatic.Client
  alias Prismatic.Context
  alias Prismatic.Error
  alias Prismatic.LowerSimulationScenario
  alias Prismatic.Operation
  alias Prismatic.Transport.LowerSimulation

  test "lower simulation transport declares the Prismatic GraphQL lower scenario contract" do
    scenario =
      LowerSimulation.lower_simulation_scenario!(
        "lower-scenario://prismatic/graphql/linear-issue-query"
      )

    dump = LowerSimulationScenario.dump(scenario)

    assert scenario.contract_version == "ExecutionPlane.LowerSimulationScenario.v1"
    assert scenario.scenario_id == "lower-scenario://prismatic/graphql/linear-issue-query"
    assert scenario.owner_repo == "prismatic"
    assert scenario.protocol_surface == "graphql"
    assert scenario.matcher_class == "deterministic_over_input"
    assert scenario.no_egress_assertion["external_egress"] == "deny"
    assert scenario.no_egress_assertion["process_spawn"] == "deny"

    assert scenario.bounded_evidence_projection["contract_version"] ==
             "ExecutionPlane.LowerSimulationEvidence.v1"

    assert scenario.bounded_evidence_projection["raw_payload_persistence"] == "shape_only"
    assert_json_safe(dump)
    assert LowerSimulationScenario.new!(dump) == scenario
  end

  test "Prismatic GraphQL lower scenarios reject bad owner, unsupported enums, egress, and raw evidence" do
    assert_argument_error_contains(["owner_repo", "prismatic"], fn ->
      LowerSimulationScenario.new!(scenario_attrs(%{owner_repo: "pristine"}))
    end)

    assert_argument_error_contains(["protocol_surface", "unsupported"], fn ->
      LowerSimulationScenario.new!(scenario_attrs(%{protocol_surface: "http"}))
    end)

    assert_argument_error_contains(["matcher_class", "unsupported"], fn ->
      LowerSimulationScenario.new!(scenario_attrs(%{matcher_class: "semantic_provider"}))
    end)

    assert_argument_error_contains(["semantic provider policy"], fn ->
      LowerSimulationScenario.new!(Map.put(scenario_attrs(), :model_refs, ["claude"]))
    end)

    assert_argument_error_contains(["no_egress_assertion", "external_egress", "deny"], fn ->
      LowerSimulationScenario.new!(
        scenario_attrs(%{no_egress_assertion: %{"external_egress" => "allow"}})
      )
    end)

    assert_argument_error_contains(["raw_payload_persistence", "shape_only"], fn ->
      LowerSimulationScenario.new!(
        scenario_attrs(%{
          bounded_evidence_projection: %{
            "contract_version" => "ExecutionPlane.LowerSimulationEvidence.v1",
            "raw_payload_persistence" => "raw_graphql_body"
          }
        })
      )
    end)

    assert_argument_error_contains(
      ["ExecutionOutcome.v1.raw_payload", "must not be narrowed"],
      fn ->
        LowerSimulationScenario.new!(
          scenario_attrs(%{
            bounded_evidence_projection: %{
              "contract_version" => "ExecutionPlane.LowerSimulationEvidence.v1",
              "target_contract" => "ExecutionOutcome.v1.raw_payload",
              "raw_payload_persistence" => "shape_only"
            }
          })
        )
      end
    )
  end

  test "lower simulation transport declares app-config adapter selection only" do
    policy = LowerSimulation.adapter_selection_policy()
    dump = AdapterSelectionPolicy.dump(policy)

    assert policy.contract_version == "ExecutionPlane.AdapterSelectionPolicy.v1"
    assert policy.owner_repo == "prismatic"
    assert policy.selection_surface == "application_config"
    assert policy.config_key == "prismatic.graphql_simulation_profiles"
    assert policy.default_value_when_unset == "normal_graphql_transport"
    assert policy.fail_closed_action_when_misconfigured == "reject_required_or_invalid_profile"
    assert_json_safe(dump)
    assert AdapterSelectionPolicy.new!(dump) == policy

    assert_argument_error_contains(["public simulation selector"], fn ->
      AdapterSelectionPolicy.new!(Map.put(adapter_policy_attrs(), :simulation, "service_mode"))
    end)

    assert_argument_error_contains(["config_key", "public simulation selector"], fn ->
      AdapterSelectionPolicy.new!(adapter_policy_attrs(%{config_key: "request.simulation"}))
    end)
  end

  test "public simulation request selectors are rejected before transport selection" do
    client =
      Client.new!(
        base_url: "http://127.0.0.1:1/graphql",
        transport: LowerSimulation
      )

    operation =
      Operation.new!(
        id: "linear.issue",
        name: "LinearIssue",
        kind: :query,
        document: "query LinearIssue($id: ID!) { issue(id: $id) { id title } }"
      )

    assert {:error,
            %Error{
              type: :transport,
              details: %{reason: {:public_simulation_selector_forbidden, :prismatic}}
            }} =
             Client.execute_operation(client, operation, %{"id" => "LIN-1"},
               simulation: :service_mode
             )
  end

  test "transport config simulation selectors are rejected before profile lookup" do
    context =
      Context.new!(
        base_url: "http://127.0.0.1:1/graphql",
        transport: LowerSimulation,
        req_options: [simulation: :service_mode]
      )

    payload = %{
      "query" => "query LinearIssue { issue(id: \"LIN-1\") { id title } }",
      "variables" => %{},
      "operationName" => "LinearIssue"
    }

    assert {:error, {:public_simulation_selector_forbidden, :prismatic}} =
             LowerSimulation.execute(context, payload, [])
  end

  defp scenario_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        scenario_id: "lower-scenario://prismatic/graphql/linear-issue-query",
        version: "1.0.0",
        owner_repo: "prismatic",
        route_kind: "graphql_operation",
        protocol_surface: "graphql",
        matcher_class: "deterministic_over_input",
        status_or_exit_or_response_or_stream_or_chunk_or_fault_shape: %{
          "status_code" => "configured",
          "headers" => "configured",
          "data" => "configured",
          "errors" => "configured",
          "extensions" => "configured"
        },
        no_egress_assertion: %{
          "external_egress" => "deny",
          "process_spawn" => "deny",
          "side_effect_result" => "not_attempted"
        },
        bounded_evidence_projection: %{
          "contract_version" => "ExecutionPlane.LowerSimulationEvidence.v1",
          "raw_payload_persistence" => "shape_only",
          "fingerprints" => ["operation", "variables_shape", "response_shape"]
        },
        input_fingerprint_ref: "fingerprint://prismatic/graphql/lower-simulation/input",
        cleanup_behavior: %{
          "runtime_artifacts" => "delete",
          "durable_payload" => "deny_raw"
        }
      },
      overrides
    )
  end

  defp adapter_policy_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        selection_surface: "application_config",
        owner_repo: "prismatic",
        config_key: "prismatic.graphql_simulation_profiles",
        default_value_when_unset: "normal_graphql_transport",
        fail_closed_action_when_misconfigured: "reject_required_or_invalid_profile"
      },
      overrides
    )
  end

  defp assert_json_safe(value) when is_binary(value) or is_boolean(value) or is_nil(value),
    do: :ok

  defp assert_json_safe(value) when is_integer(value) or is_float(value), do: :ok

  defp assert_json_safe(value) when is_list(value), do: Enum.each(value, &assert_json_safe/1)

  defp assert_json_safe(value) when is_map(value) do
    assert Enum.all?(Map.keys(value), &is_binary/1)
    Enum.each(value, fn {_key, nested} -> assert_json_safe(nested) end)
  end

  defp assert_argument_error_contains(required_fragments, fun) do
    error = assert_raise ArgumentError, fun
    downcased_message = String.downcase(error.message)

    for fragment <- required_fragments do
      assert String.contains?(downcased_message, String.downcase(fragment))
    end
  end
end
