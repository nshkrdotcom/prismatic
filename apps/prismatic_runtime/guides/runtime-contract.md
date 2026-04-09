# Runtime Contract

The runtime intentionally stays small.

Provider SDKs should depend on:

- `Prismatic.Client`
- `Prismatic.Operation`
- `Prismatic.Response`
- `Prismatic.Error`

The lower HTTP lane stays an implementation detail. `prismatic` remains the
GraphQL semantic layer above the shared `pristine` HTTP family kit.

They should not treat lower-level helper modules as part of the public
provider-facing contract.
