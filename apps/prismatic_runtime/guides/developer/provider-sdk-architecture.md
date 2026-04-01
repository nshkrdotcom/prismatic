# Provider SDK Architecture

Provider SDKs built on `prismatic` should keep a strict package split.

## Package Boundaries

`prismatic` owns:

- runtime execution
- request payload construction
- auth/header composition
- response normalization
- transport, HTTP, and GraphQL error shaping

`prismatic_codegen` owns:

- provider definition loading
- schema and document ingestion
- provider IR
- generated Elixir modules
- generated markdown reference docs

`prismatic_provider_testkit` owns:

- provider freshness and conformance helpers

Provider SDK repos should own:

- committed introspection artifacts
- curated GraphQL documents
- base URL and auth metadata
- a thin provider definition module
- thin handwritten client wrapper defaults
- a small set of handwritten user guides

## What Should Stay Out Of Provider Repos

Do not handwrite large resource surfaces if the operation can be generated from:

- curated GraphQL documents
- schema snapshot
- provider metadata

That work should be pushed back into `prismatic_codegen`.

## What Should Stay Out Of `prismatic`

Do not add provider-specific examples, provider names, or provider-specific
environment contracts to the shared runtime package.

The runtime must stay generic so multiple provider SDKs can share it cleanly.
