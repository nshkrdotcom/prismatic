defmodule Prismatic.GovernedAuthorityTest do
  use ExUnit.Case, async: false

  import Mox

  alias Prismatic.Client
  alias Prismatic.Error
  alias Prismatic.GovernedAuthority
  alias Prismatic.Operation
  alias Prismatic.Response
  alias Prismatic.TestTelemetryHandler
  alias Prismatic.Transport.LowerSimulation

  @simulation_config_key :graphql_simulation_profiles

  setup :verify_on_exit!

  test "governed client executes with authority endpoint and credential headers" do
    operation =
      Operation.new!(
        id: "viewer",
        name: "Viewer",
        kind: :query,
        document: "query Viewer { viewer { id name } }",
        root_field: "viewer"
      )

    expect(Prismatic.TransportMock, :execute, fn context, payload, opts ->
      assert context.base_url == "https://governed.example/graphql"
      assert {"authorization", "Bearer governed-token"} in context.headers
      assert {"x-provider-scope", "workspace-1"} in context.headers
      assert payload["operationName"] == "Viewer"
      refute Keyword.has_key?(opts, :operation_name)

      {:ok,
       %{
         status: 200,
         headers: [{"x-request-id", "req-governed"}],
         body: %{"data" => %{"viewer" => %{"id" => "user_1", "name" => "Ada"}}}
       }}
    end)

    client =
      Client.new!(
        governed_authority: authority(),
        transport: Prismatic.TransportMock
      )

    assert {:ok,
            %Response{
              request_id: "req-governed",
              data: %{"viewer" => %{"id" => "user_1", "name" => "Ada"}}
            }} = Client.execute_operation(client, operation)
  end

  test "governed client rejects unmanaged construction inputs" do
    rejected_options = [
      base_url: "https://env.example/graphql",
      auth: {:bearer, "bypass-token"},
      headers: [{"authorization", "Bearer bypass-token"}],
      oauth2: [
        token_source:
          {Prismatic.Adapters.TokenSource.Static,
           token: %Prismatic.OAuth2.Token{access_token: "oauth-bypass"}}
      ]
    ]

    Enum.each(rejected_options, fn {key, value} ->
      error =
        assert_raise ArgumentError, fn ->
          Client.new!(
            [governed_authority: authority(), transport: Prismatic.TransportMock]
            |> Keyword.put(key, value)
          )
        end

      assert String.contains?(Exception.message(error), "governed Prismatic clients")
      assert String.contains?(Exception.message(error), Atom.to_string(key))
    end)
  end

  test "governed client rejects request option auth endpoint and policy smuggling" do
    client =
      Client.new!(
        governed_authority: authority(),
        transport: Prismatic.TransportMock
      )

    rejected_options = [
      headers: [{"authorization", "Bearer request-bypass"}],
      auth: {:bearer, "request-bypass"},
      oauth2: [token_source: Prismatic.Adapters.TokenSource.Static],
      base_url: "https://request.example/graphql",
      url: "https://request.example/graphql",
      endpoint_url: "https://request.example/graphql",
      operation_policy: "operation-policy://bypass"
    ]

    Enum.each(rejected_options, fn {key, value} ->
      assert {:error, %Error{type: :auth, details: %{reason: reason}}} =
               Client.execute_document(
                 client,
                 "query Viewer { viewer { id } }",
                 %{},
                 [{key, value}]
               )

      assert reason == {:governed_request_option_forbidden, key}
    end)
  end

  test "governed telemetry carries policy context without auth values" do
    handler_id = "prismatic-governed-handler-#{System.unique_integer([:positive])}"
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

    expect(Prismatic.TransportMock, :execute, fn _context, _payload, _opts ->
      {:ok, %{status: 200, headers: [], body: %{"data" => %{"viewer" => %{"id" => "x"}}}}}
    end)

    client =
      Client.new!(
        governed_authority: authority(),
        transport: Prismatic.TransportMock
      )

    assert {:ok, _response} =
             Client.execute_document(client, "query Viewer { viewer { id } }")

    assert_receive {:telemetry, [:prismatic, :execute, :start], _measurements, start_metadata}
    assert_receive {:telemetry, [:prismatic, :execute, :stop], _measurements, stop_metadata}

    assert start_metadata.operation_policy_ref == "operation-policy://example/read"
    assert stop_metadata.operation_policy_ref == "operation-policy://example/read"

    start_text = inspect(start_metadata)
    stop_text = inspect(stop_metadata)

    refute String.contains?(start_text, "governed-token")
    refute String.contains?(stop_text, "governed-token")
    refute String.contains?(start_text, "Bearer")
    refute String.contains?(stop_text, "Bearer")
    refute String.contains?(start_text, "credential://")
    refute String.contains?(stop_text, "credential://")
  end

  test "governed lower simulation does not read application configured profiles" do
    previous_config = Application.get_env(:prismatic, @simulation_config_key)

    on_exit(fn ->
      restore_simulation_config(previous_config)
    end)

    Application.put_env(:prismatic, @simulation_config_key,
      required?: true,
      profiles: %{
        "EnvConfigured" => [
          scenario_ref: "phase-env20://prismatic/app-env-profile",
          response: %{"data" => %{"viewer" => %{"id" => "env-profile"}}}
        ]
      }
    )

    client =
      Client.new!(
        governed_authority: authority(),
        transport: LowerSimulation
      )

    assert {:error,
            %Error{
              type: :transport,
              details: %{reason: {:prismatic_simulation_profile_required, keys}}
            }} = Client.execute_document(client, "query EnvConfigured { viewer { id } }")

    assert "EnvConfigured" in keys
  end

  defp authority do
    GovernedAuthority.new!(
      base_url: "https://governed.example/graphql",
      credential_ref: "credential://example/graphql",
      credential_lease_ref: "lease://example/graphql",
      target_ref: "target://example/graphql",
      operation_policy_ref: "operation-policy://example/read",
      redaction_ref: "redaction://example/default",
      headers: [{"x-provider-scope", "workspace-1"}],
      credential_headers: [{"authorization", "Bearer governed-token"}]
    )
  end

  defp restore_simulation_config(nil),
    do: Application.delete_env(:prismatic, @simulation_config_key)

  defp restore_simulation_config(config),
    do: Application.put_env(:prismatic, @simulation_config_key, config)
end
