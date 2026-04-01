# Getting Started

Install dependencies and run the full workspace checks:

```bash
mix deps.get
mix ci
```

Useful focused commands:

```bash
mix monorepo.test
mix monorepo.credo --strict
mix monorepo.dialyzer
mix monorepo.docs
```
