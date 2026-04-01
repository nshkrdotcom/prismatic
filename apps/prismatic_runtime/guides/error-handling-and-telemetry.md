# Error Handling And Telemetry

`Prismatic` normalizes three failure classes:

- transport failures
- HTTP failures without GraphQL data
- GraphQL response errors

It also emits execution telemetry under the `[:prismatic, :execute, ...]`
event prefix.
