# Runtime Contract

The runtime intentionally stays small.

Provider SDKs should depend on:

- `Prismatic.Client`
- `Prismatic.Operation`
- `Prismatic.Response`
- `Prismatic.Error`

They should not treat lower-level helper modules as part of the public
provider-facing contract.
