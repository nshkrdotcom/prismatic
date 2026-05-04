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

  test "governed authority requires credential-handle, tenant, workspace, and operation refs" do
    authority =
      GovernedAuthority.new!(
        phase7_authority(
          operation_name: "Viewer",
          operation_document_ref: "graphql-document://tenant-1/linear/viewer",
          allowed_variable_names: ["includeTeams"]
        )
      )

    assert authority.credential_handle_ref == "credential-handle://tenant-1/linear/api-token"
    assert authority.tenant_ref == "tenant://tenant-1"
    assert authority.workspace_ref == "workspace://tenant-1/product"
    assert authority.organization_ref == "organization://linear/org-1"
    assert authority.provider_account_ref == "provider-account://tenant-1/linear/api-token"
    assert authority.request_scope_ref == "request-scope://tenant-1/linear/viewer"
    assert authority.operation_name == "Viewer"
    assert authority.operation_document_ref == "graphql-document://tenant-1/linear/viewer"
    assert authority.allowed_variable_names == ["includeTeams"]
  end

  test "governed authority rejects unmanaged standalone GraphQL auth inputs" do
    unmanaged_inputs = [
      api_token: "raw-linear-api-token",
      env: %{"LINEAR_API_KEY" => "raw-env-token"},
      default_client: :linear_default_client,
      endpoint_url: "https://api.linear.app/graphql",
      headers: [{"authorization", "Bearer raw-header-token"}],
      oauth2: [
        token_source:
          {Prismatic.Adapters.TokenSource.Static,
           token: %Prismatic.OAuth2.Token{access_token: "oauth-bypass"}}
      ]
    ]

    for {key, value} <- unmanaged_inputs do
      error =
        assert_raise ArgumentError, fn ->
          phase7_authority([{key, value}])
          |> GovernedAuthority.new!()
        end

      assert String.contains?(error.message, "governed authority rejects unmanaged #{key}")
    end
  end

  test "governed operation scope rejects mismatch and undeclared variables before transport" do
    client =
      Client.new!(
        governed_authority:
          phase7_authority(operation_name: "Viewer", allowed_variable_names: []),
        transport: Prismatic.TransportMock
      )

    assert {:error, %Error{type: :auth, details: %{reason: reason}}} =
             Client.execute_document(client, "query Other { viewer { id } }", %{})

    assert reason == {:governed_operation_scope_forbidden, :operation_name}

    assert {:error, %Error{type: :auth, details: %{reason: variable_reason}}} =
             Client.execute_document(
               client,
               "query Viewer($includeTeams: Boolean) { viewer { id } }",
               %{"includeTeams" => true}
             )

    assert variable_reason == {:governed_operation_scope_forbidden, :variables}
  end

  test "linear OAuth app user and API token governed identities stay distinct" do
    oauth_user =
      GovernedAuthority.new!(
        phase7_authority(
          credential_handle_ref: "credential-handle://tenant-1/linear/oauth-app-user",
          provider_account_ref: "provider-account://tenant-1/linear/oauth-app-user",
          identity_kind: "oauth_app_user"
        )
      )

    api_token =
      GovernedAuthority.new!(
        phase7_authority(
          credential_handle_ref: "credential-handle://tenant-1/linear/api-token",
          provider_account_ref: "provider-account://tenant-1/linear/api-token",
          identity_kind: "api_token"
        )
      )

    assert oauth_user.identity_kind == "oauth_app_user"
    assert api_token.identity_kind == "api_token"
    refute oauth_user.credential_handle_ref == api_token.credential_handle_ref
    refute oauth_user.provider_account_ref == api_token.provider_account_ref
  end

  test "governed authority inspection redacts GraphQL credential headers" do
    authority =
      phase7_authority(credential_headers: [{"authorization", "Bearer graphql-secret"}])
      |> GovernedAuthority.new!()

    rendered = inspect(authority)

    refute String.contains?(rendered, "graphql-secret")
    assert String.contains?(rendered, "[REDACTED]")
  end

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
      ],
      api_token: "raw-api-token",
      env: %{"LINEAR_API_KEY" => "raw-env-token"},
      default_client: :linear_default_client,
      endpoint_url: "https://api.linear.app/graphql",
      operation_auth: {:bearer, "operation-bypass"},
      client_auth: {:bearer, "client-bypass"},
      provider_payload: %{"authorization" => "Bearer raw-provider-token"},
      middleware: [:auth_middleware],
      token_source: Prismatic.Adapters.TokenSource.Static
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
      operation_policy: "operation-policy://bypass",
      api_token: "raw-api-token",
      env: %{"LINEAR_API_KEY" => "raw-env-token"},
      default_client: :linear_default_client,
      operation_auth: {:bearer, "operation-bypass"},
      client_auth: {:bearer, "client-bypass"},
      provider_payload: %{"authorization" => "Bearer raw-provider-token"},
      middleware: [:auth_middleware],
      token_source: Prismatic.Adapters.TokenSource.Static
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

  test "governed operation scope is revalidated on every execution attempt" do
    viewer =
      Operation.new!(
        id: "viewer",
        name: "Viewer",
        kind: :query,
        document: "query Viewer { viewer { id } }",
        root_field: "viewer"
      )

    other =
      Operation.new!(
        id: "other",
        name: "Other",
        kind: :query,
        document: "query Other { viewer { id } }",
        root_field: "viewer"
      )

    expect(Prismatic.TransportMock, :execute, fn _context, _payload, _opts ->
      {:ok, %{status: 200, headers: [], body: %{"data" => %{"viewer" => %{"id" => "x"}}}}}
    end)

    client =
      Client.new!(
        governed_authority: authority(),
        transport: Prismatic.TransportMock
      )

    assert {:ok, %Response{data: %{"viewer" => %{"id" => "x"}}}} =
             Client.execute_operation(client, viewer)

    assert {:error, %Error{type: :auth, details: %{reason: reason}}} =
             Client.execute_operation(client, other)

    assert reason == {:governed_operation_scope_forbidden, :operation_name}
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
        governed_authority:
          phase7_authority(
            operation_name: "EnvConfigured",
            request_scope_ref: "request-scope://tenant-1/linear/env-configured",
            operation_policy_ref: "operation-policy://example/env-configured",
            operation_document_ref: "graphql-document://tenant-1/linear/env-configured"
          ),
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
    GovernedAuthority.new!(phase7_authority())
  end

  defp phase7_authority(overrides \\ []) do
    [
      base_url: "https://governed.example/graphql",
      tenant_ref: "tenant://tenant-1",
      workspace_ref: "workspace://tenant-1/product",
      organization_ref: "organization://linear/org-1",
      provider_account_ref: "provider-account://tenant-1/linear/api-token",
      connector_instance_ref: "connector-instance://tenant-1/linear/default",
      credential_handle_ref: "credential-handle://tenant-1/linear/api-token",
      credential_lease_ref: "credential-lease://tenant-1/linear/api-token",
      target_ref: "target://tenant-1/linear/graphql",
      request_scope_ref: "request-scope://tenant-1/linear/viewer",
      operation_policy_ref: "operation-policy://example/read",
      operation_name: "Viewer",
      operation_document_ref: "graphql-document://tenant-1/linear/viewer",
      allowed_variable_names: [],
      identity_kind: "api_token",
      redaction_ref: "redaction://example/default",
      headers: [{"x-provider-scope", "workspace-1"}],
      credential_headers: [{"authorization", "Bearer governed-token"}]
    ]
    |> Keyword.merge(overrides)
  end

  defp restore_simulation_config(nil),
    do: Application.delete_env(:prismatic, @simulation_config_key)

  defp restore_simulation_config(config),
    do: Application.put_env(:prismatic, @simulation_config_key, config)
end
