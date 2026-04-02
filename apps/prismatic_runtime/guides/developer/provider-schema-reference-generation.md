# Provider Schema Reference Generation

Provider SDKs should treat upstream schema artifacts as committed source.

## Preferred Inputs

When the upstream provider makes them available, vendor these files into the
provider repo:

- `priv/upstream/schema/schema.json`
- `priv/upstream/schema/schema.graphql`

The provider definition should point `prismatic_codegen` at those committed
files, not at an external checkout or a remote URL.

## Why Commit Both

`schema.json` is the generator's machine-readable source of truth.

`schema.graphql` is useful for:

- human inspection and review
- provenance in generated docs
- future validation or diff tooling

## Public Docs Surface

The generated public reference should be schema-centric, not build-centric.

Prefer this shape:

- `guides/api/graph-reference.md`
- `guides/api/queries.md`
- `guides/api/mutations.md`
- `guides/api/subscriptions.md`
- `guides/api/objects/*.md`
- `guides/api/input-objects/*.md`
- `guides/api/interfaces/*.md`
- `guides/api/unions/*.md`
- `guides/api/enums/*.md`
- `guides/api/scalars/*.md`

Do not expose internal codegen labels such as `Generated` to end users.

## Internal Generated Code

Providers may still generate internal support modules for curated operations,
typed roots, or helpers.

Those modules should stay implementation-oriented and can be hidden from the
public docs surface when they are not the intended user entrypoint.

## Curated Documents

Curated `.graphql` documents still have value:

- smoke coverage for generated execution helpers
- examples for provider authors
- regression coverage for the codegen path

But they should not replace the full schema-derived public reference when the
goal is to document the upstream graph.
