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

## What this package owns

- GraphQL-over-HTTP execution
- auth and header composition
- OAuth2 helpers and token-source resolution
- request payload normalization
- response normalization
- transport, HTTP, and GraphQL error shaping
- lightweight execution telemetry

## What this package does not own

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
    {:prismatic, "~> 0.1.0"}
  ]
end
```

## Create a client

```elixir
client =
  Prismatic.Client.new!(
    base_url: "https://api.example.com/graphql",
    auth: {:bearer, System.fetch_env!("EXAMPLE_API_TOKEN")}
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
