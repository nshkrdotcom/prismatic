# Provider Testing And CI

Provider SDK repositories should treat generated artifacts as committed source.

## Recommended CI Order

1. format check
2. compile with warnings as errors
3. generated-artifact verification
4. tests
5. Credo
6. Dialyzer
7. docs

That ordering catches stale generated code and docs before deeper checks run.

## Runtime Testing

The normal execution seam is a transport mock.

Example shape:

```elixir
client =
  ExampleSDK.Client.new!(
    auth: {:bearer, "token"},
    transport: ExampleSDK.TransportMock
  )
```

That keeps provider tests focused on:

- request payload correctness
- header behavior
- typed response shaping

## Generated Artifact Verification

Provider SDKs should expose generation and verification tasks such as:

```bash
mix example.generate
mix example.verify
```

The verification task should run in CI before tests.

## What `prismatic_provider_testkit` Is For

The provider testkit is the right place for shared freshness and conformance
helpers that are too provider-generic to keep rewriting in every SDK repo.
