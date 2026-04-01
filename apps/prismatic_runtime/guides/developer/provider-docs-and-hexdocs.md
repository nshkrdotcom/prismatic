# Provider Docs And HexDocs

Provider SDK docs should be split into two kinds of content.

## Handwritten Docs

Keep these handwritten:

- package README
- getting-started guide
- client-configuration guide
- generation and upstream-artifact guide

These explain provider-specific workflow and ergonomics.

## Generated Docs

Generate these from `prismatic_codegen`:

- provider overview
- operations index and per-operation pages
- models index and per-model pages
- enums index and per-enum pages

Reserve a dedicated subtree for generated reference docs:

- `guides/generated/`

That makes cleanup, verification, and HexDocs inclusion deterministic.

## HexDocs Integration Pattern

The provider repo should include generated docs in `mix.exs` via deterministic
lists or sorted wildcards.

Typical menu shape:

- `Overview`
- `User Guides`
- `Generated Reference`
- `Examples`
- `Project`

The generated reference section should point directly at the committed markdown
files under `guides/generated/`.

## Why This Split Matters

It keeps provider repos thin while still giving users professional docs:

- curated human guides where judgement matters
- generated reference where structure and completeness matter
