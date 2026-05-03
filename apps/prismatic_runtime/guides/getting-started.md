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
    credential_ref: "credential://provider/graphql",
    credential_lease_ref: "lease://provider/graphql",
    target_ref: "target://provider/graphql",
    operation_policy_ref: "operation-policy://provider/read",
    redaction_ref: "redaction://provider/default",
    credential_headers: [{"authorization", "Bearer materialized-token"}]
  )

client =
  Prismatic.Client.new!(
    governed_authority: authority
  )
```
