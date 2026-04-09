# Error Handling And Telemetry

`Prismatic` normalizes three failure classes:

- transport failures
- HTTP failures without GraphQL data
- GraphQL response errors

Those failure classes are preserved even though the default lower unary HTTP
execution now runs through the shared `pristine` lane.

It also emits execution telemetry under the `[:prismatic, :execute, ...]`
event prefix.
