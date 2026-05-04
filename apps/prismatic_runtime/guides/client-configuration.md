# Client Configuration

`Prismatic.Client` is intentionally small, but it still defines the generic
runtime contract that provider SDKs build on.

## Required Input

At minimum, a standalone runtime client needs a GraphQL endpoint:

```elixir
client =
  Prismatic.Client.new!(
    base_url: "https://api.example.com/graphql"
  )
```

Provider SDKs usually wrap this and supply a default `base_url`, so standalone
end users only need to provide auth.

## Auth Options

The runtime supports three generic auth modes today.

These modes are standalone compatibility inputs. They can be backed by local
env or saved token files in provider SDKs, but they are not governed authority.

Bearer token:

```elixir
client =
  Prismatic.Client.new!(
    base_url: "https://api.example.com/graphql",
    auth: {:bearer, System.fetch_env!("EXAMPLE_API_TOKEN")}
  )
```

Custom header:

```elixir
client =
  Prismatic.Client.new!(
    base_url: "https://api.example.com/graphql",
    auth: {:header, "x-api-key", System.fetch_env!("EXAMPLE_API_KEY")}
  )
```

This is generic runtime behavior and belongs in `prismatic`.

Environment-variable names, token discovery policy, and provider-specific auth
defaults belong in the provider SDK.

OAuth token source:

```elixir
client =
  Prismatic.Client.new!(
    base_url: "https://api.example.com/graphql",
    oauth2: [
      token_source:
        {Prismatic.Adapters.TokenSource.File,
         path: "/tmp/provider-oauth.json"}
    ]
  )
```

This is the generic path for provider SDKs that want runtime-managed bearer
resolution from a persisted or refreshable OAuth token source.

Do not pass both `auth:` and `oauth2:` to the same runtime client.

## Governed Authority

Governed mode is explicit. Pass a `Prismatic.GovernedAuthority` instead of
direct endpoint or auth options:

```elixir
authority =
  Prismatic.GovernedAuthority.new!(
    base_url: "https://api.example.com/graphql",
    tenant_ref: "tenant://tenant-1",
    workspace_ref: "workspace://tenant-1/product",
    organization_ref: "organization://linear/org-1",
    provider_account_ref: "provider-account://tenant-1/linear/api-token",
    connector_instance_ref: "connector-instance://tenant-1/linear/default",
    credential_handle_ref: "credential-handle://tenant-1/linear/api-token",
    credential_lease_ref: "credential-lease://tenant-1/linear/api-token",
    target_ref: "target://provider/graphql",
    request_scope_ref: "request-scope://tenant-1/linear/viewer",
    operation_policy_ref: "operation-policy://provider/read",
    operation_name: "Viewer",
    operation_document_ref: "graphql-document://tenant-1/linear/viewer",
    allowed_variable_names: [],
    identity_kind: "api_token",
    redaction_ref: "redaction://provider/default",
    headers: [{"x-provider-version", "2026-05-03"}],
    credential_headers: [{"authorization", "[REDACTED_BY_AUTHORITY]"}]
  )

client =
  Prismatic.Client.new!(
    governed_authority: authority
  )
```

When `governed_authority:` is present, `Prismatic.Client` rejects direct
`base_url:`, `headers:`, `auth:`, `oauth2:`, API-token, env, default-client,
endpoint, middleware, token-source, client-auth, operation-auth, and provider
payload construction inputs. It also rejects request-time `headers:`, `auth:`,
`oauth2:`, `base_url:`, `url:`, `endpoint_url:`, `operation_policy:`,
`operation_policy_ref:`, API-token, env, default-client, middleware,
token-source, client-auth, operation-auth, and provider payload overrides.

The operation policy is carried as a reference for telemetry and downstream
provider wrappers. Credential refs and materialized credential headers are not
emitted in telemetry metadata.

## Transport Overrides

The default runtime transport is a `pristine`-backed adapter, which keeps
GraphQL semantics in `prismatic` while delegating lower unary HTTP execution
through the shared HTTP family lane.

The `transport` option still lets provider SDKs or tests replace that default
runtime transport.

```elixir
client =
  Prismatic.Client.new!(
    base_url: "https://api.example.com/graphql",
    transport: ExampleSDK.TransportMock
  )
```

This is the normal test seam for provider SDKs.

## `new/1` vs `new!/1`

- `new/1` returns `{:ok, client}` or `{:error, exception}`
- `new!/1` raises on invalid configuration

Provider-facing convenience wrappers generally use `new!/1`.

## Runtime Boundary

`Prismatic.Client` should own only generic runtime configuration:

- endpoint selection
- auth/header composition
- transport choice
- governed authority materialization

It should not grow provider-specific environment discovery or provider-specific
policy logic.
