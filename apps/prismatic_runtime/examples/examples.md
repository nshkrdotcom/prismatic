# Examples

These examples stay intentionally small because `prismatic` is a runtime
package, not a provider SDK.

The direct auth snippets below are standalone examples. Governed integrations
pass `Prismatic.GovernedAuthority` and do not source auth or endpoints from
env at the runtime boundary.

## Bearer Auth

```elixir
client =
  Prismatic.Client.new!(
    base_url: "https://api.example.com/graphql",
    auth: {:bearer, System.fetch_env!("EXAMPLE_API_TOKEN")}
  )
```

## Custom Header Auth

```elixir
client =
  Prismatic.Client.new!(
    base_url: "https://api.example.com/graphql",
    auth: {:header, "x-api-key", System.fetch_env!("EXAMPLE_API_KEY")}
  )
```

## Execute A Named Operation

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

## Execute An Ad Hoc Document

```elixir
{:ok, response} =
  Prismatic.Client.execute_document(
    client,
    "query Viewer { viewer { id name } }"
  )
```

## Select An Operation From A Multi-Operation Document

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
