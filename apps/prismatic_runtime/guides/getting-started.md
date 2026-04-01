# Getting Started

Create a client:

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
