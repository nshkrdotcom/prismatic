# Client Configuration

`Prismatic.Client` is intentionally small, but it still defines the generic
runtime contract that provider SDKs build on.

## Required Input

At minimum, the runtime needs a GraphQL endpoint:

```elixir
client =
  Prismatic.Client.new!(
    base_url: "https://api.example.com/graphql"
  )
```

Provider SDKs usually wrap this and supply a default `base_url`, so end users
only need to provide auth.

## Auth Options

The runtime supports three generic auth modes today.

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

It should not grow provider-specific environment discovery or provider-specific
policy logic.
