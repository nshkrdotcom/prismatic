# Maintaining The Monorepo

The root workspace uses `blitz` for coordinated tasks across all packages.

The working rule is simple:

- if a concern is reusable across providers, move it down into the shared
  packages
- if a concern is provider-specific, keep it out of the platform workspace

This keeps `prismatic` generic and prevents provider-specific behavior from
leaking into the shared core.
