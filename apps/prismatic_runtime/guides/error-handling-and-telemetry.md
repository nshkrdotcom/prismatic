# Error Handling And Telemetry

`Prismatic` normalizes three failure classes:

- transport failures
- HTTP failures without GraphQL data
- GraphQL response errors

Those failure classes are preserved even though the default lower unary HTTP
execution now runs through the shared `pristine` lane.

It also emits execution telemetry under the `[:prismatic, :execute, ...]`
event prefix.

For governed clients, telemetry metadata includes the operation policy,
target, and redaction references. It does not include credential refs, lease
refs, materialized auth headers, bearer tokens, API keys, OAuth tokens, or
saved-token file paths.
