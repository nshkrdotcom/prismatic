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
8. rendered-doc assertions when the provider publishes a generated reference site

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

## Schema-Reference Verification

If the provider publishes a schema-derived API reference in HexDocs, add a
small post-doc assertion script that checks the rendered output for:

- required key pages
- absence of internal implementation namespaces
- absence of stale legacy doc sections

That keeps the public docs honest even when the internal generated code surface
changes.

## What `prismatic_provider_testkit` Is For

The provider testkit is the right place for shared freshness and conformance
helpers that are too provider-generic to keep rewriting in every SDK repo.
