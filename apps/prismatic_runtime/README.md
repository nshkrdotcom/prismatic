<p align="center">
  <img src="assets/prismatic.svg" alt="Prismatic" width="200"/>
</p>

<p align="center">
  <a href="https://hex.pm/packages/prismatic"><img src="https://img.shields.io/hexpm/v/prismatic.svg" alt="Hex.pm"/></a>
  <a href="https://hexdocs.pm/prismatic"><img src="https://img.shields.io/badge/hex-docs-blue.svg" alt="HexDocs"/></a>
  <a href="https://github.com/nshkrdotcom/prismatic"><img src="https://img.shields.io/badge/GitHub-repo-black?logo=github" alt="GitHub"/></a>
</p>

# Prismatic

`Prismatic` is the shared GraphQL runtime package in the `prismatic` family.

It exists for thin, configuration-driven provider SDKs that need a stable,
minimal GraphQL-over-HTTP foundation without dragging provider-specific logic
into the runtime layer.

The package stays GraphQL-native while converging on the shared lower HTTP
lane. Unary HTTP execution now runs through the `pristine` family kit and its
Execution Plane-backed transport substrate instead of a repo-local HTTP owner.

## What this package owns

- GraphQL-over-HTTP execution
- auth and header composition
- OAuth2 helpers and token-source resolution
- request payload normalization
- response normalization
- HTTP and GraphQL error shaping
- lightweight execution telemetry

## What this package does not own

- repo-local unary HTTP transport mechanics
- provider-specific operation catalogs
- schema-derived code generation
- provider artifact verification

Those concerns stay in the sibling packages:

- `prismatic_codegen`
- `prismatic_provider_testkit`

## Install

```elixir
def deps do
  [
    {:prismatic, "~> 0.2.0"}
  ]
end
```

## Create a client

Standalone clients can pass a direct endpoint and direct auth. Provider SDKs
may still pass explicitly loaded local development credentials for direct
developer use.

```elixir
client =
  Prismatic.Client.new!(
    base_url: "https://api.example.com/graphql",
    auth: {:bearer, load_local_development_token()}
  )
```

Or create a client that resolves a persisted OAuth token at execution time:

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

Governed clients use an authority-selected endpoint and credential handle.
They do not accept direct `base_url:`, `auth:`, `headers:`, or `oauth2:`
options, and request-time auth or endpoint overrides fail closed.

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
    token_family_ref: "token-family://tenant-1/linear/api-token",
    subject_ref: "subject://tenant-1/operator/ada",
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

The governed authority binds GraphQL operation name, provider account,
workspace, token family, tenant, and subject before transport. This preserves
standalone GraphQL SDK behavior while giving higher control planes a ref-only
operation-admission shape.

## Execute an operation

```elixir
operation =
  Prismatic.Operation.new!(
    id: "viewer",
    name: "Viewer",
    kind: :query,
    document: "query Viewer { viewer { id name } }",
    root_field: "viewer"
  )

{:ok, response} = Prismatic.Client.execute_operation(client, operation)
```

## Execute an ad hoc document

```elixir
{:ok, response} =
  Prismatic.Client.execute_document(
    client,
    "query Viewer { viewer { id name } }"
  )
```

For documents that declare more than one operation, select the operation
explicitly:

```elixir
document = """
query Viewer { viewer { id name } }
mutation UpdateViewer { viewerUpdate(input: {name: "Ada"}) { success } }
"""

{:ok, response} =
  Prismatic.Client.execute_document(
    client,
    document,
    %{},
    operation_name: "Viewer"
  )
```

## Docs Map

- [Getting Started](guides/getting-started.md): install, client creation, and first execution
- [Client Configuration](guides/client-configuration.md): base URL, auth, transport, and runtime options
- [OAuth And Token Sources](guides/oauth-and-token-sources.md): generic OAuth2 helpers, file-backed tokens, and refreshable sources
- [Runtime Contract](guides/runtime-contract.md): public runtime boundary and expected provider usage
- [Error Handling And Telemetry](guides/error-handling-and-telemetry.md): normalized failures and event emission
- [Examples](examples/examples.md): concise runtime-oriented snippets
- [Provider SDK Architecture](guides/developer/provider-sdk-architecture.md): package boundaries for provider authors
- [Provider Testing And CI](guides/developer/provider-testing-and-ci.md): verification, mocks, and clean CI wiring
- [Provider Docs And HexDocs](guides/developer/provider-docs-and-hexdocs.md): schema reference docs and HexDocs integration
- [Provider Schema Reference Generation](guides/developer/provider-schema-reference-generation.md): vendored schema artifacts, generator inputs, and public-doc surface design

## Quality Bar

```bash
mix test
mix credo --strict
mix dialyzer --force-check
mix docs
```
