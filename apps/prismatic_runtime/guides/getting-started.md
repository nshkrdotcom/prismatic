# Getting Started

Create a standalone client:

```elixir
client =
  Prismatic.Client.new!(
    base_url: "https://api.example.com/graphql",
    auth: {:bearer, System.fetch_env!("EXAMPLE_API_TOKEN")}
  )
```

Execute an operation:

```elixir
operation =
  Prismatic.Operation.new!(
    id: "viewer",
    name: "Viewer",
    kind: :query,
    document: "query Viewer { viewer { id name } }"
  )

{:ok, response} = Prismatic.Client.execute_operation(client, operation)
```

For providers that use OAuth2, you can let the runtime resolve the bearer token
from a token source in standalone mode:

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

Governed provider integrations pass an authority value instead of direct env,
local config, or token-source inputs:

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
    credential_headers: [{"authorization", "[REDACTED_BY_AUTHORITY]"}]
  )

client =
  Prismatic.Client.new!(
    governed_authority: authority
  )
```
