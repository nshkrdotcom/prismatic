# Provider Docs And HexDocs

Provider SDK docs should be split into two kinds of content.

## Handwritten Docs

Keep these handwritten:

- package README
- getting-started guide
- client-configuration guide
- document-execution guide
- generation and upstream-artifact guide

These explain provider-specific workflow and ergonomics.

## Generated Docs

Generate these from `prismatic_codegen`:

- schema-reference landing page
- queries index and per-query-field pages
- mutations index and per-mutation-field pages
- subscriptions index and per-subscription-field pages
- object, input-object, interface, union, enum, and scalar reference pages

Reserve a dedicated subtree for generated schema-reference docs:

- `guides/api/`

That makes cleanup, verification, and HexDocs inclusion deterministic.

## HexDocs Integration Pattern

The provider repo should include generated docs in `mix.exs` via deterministic
lists or sorted wildcards.

Typical menu shape:

- `Overview`
- `User Guides`
- `API Reference`
- `Examples`
- `Project`

The API reference section should point directly at the committed markdown files
under `guides/api/`.

## Why This Split Matters

It keeps provider repos thin while still giving users professional docs:

- curated human guides where judgement matters
- generated schema reference where structure and completeness matter
