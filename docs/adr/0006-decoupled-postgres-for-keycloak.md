# ADR 0006: Decoupled Postgres for Keycloak (Not Embedded Sub-chart, Not H2)

- **Status:** Accepted
- **Date:** 2026-05
- **Supersedes:** Original choice in ADR 0001 (implicitly used embedded Postgres)

## Context

Keycloak needs a backing database. Four options were considered:

1. **H2** (Keycloak's default if no DB configured)
2. **Embedded Postgres** as a sub-chart of the Keycloak Helm release
3. **Decoupled Postgres** as a separate Argo CD Application in the same namespace
4. **External Postgres** (e.g., reuse the Docker Compose Postgres from
   `zylos-local-env`)

## Decision

Use **option 3: a decoupled Postgres in the cluster**, deployed as a separate
Argo CD Application (`keycloak-postgres`), running the Bitnami Postgres chart.
The `keycloak` Helm release has `postgresql.enabled: false` and points at the
external Postgres via cluster DNS.

## Rationale

- **Production parity.** In AWS, Keycloak's database is Aurora — a separate,
  managed service. Locally, decoupled Postgres mirrors that boundary.
- **Independent lifecycles.** Keycloak can be redeployed without touching the
  database, and vice versa. The PVC retention policy explicitly preserves
  data on StatefulSet recreation.
- **Migration story.** Switching to Aurora later is a single-line change to
  Keycloak's `database.hostname` plus an External Secret reference.
- **Demonstrates separation of concerns.** A real architectural pattern
  and real production work.

## Why Not H2

- **Officially unsupported by Keycloak in production.** "Works on H2" is a
  classic antipattern — different SQL dialect, different concurrency model.
- Even in development, schema/behavior differences mask issues that surface
  only in production.

## Why Not the Embedded Sub-chart

- Couples Keycloak chart upgrades to Postgres lifecycle.
- Doesn't reflect production architecture.
- Less reusable (the Postgres can't easily serve another use case).

## Why Not Reuse zylos-local-env Compose Postgres

- The kind cluster should be self-contained. Mixing Compose-host networking
  with cluster networking is fragile (`host.docker.internal`, gateway tricks).
- Conceptually wrong: Compose is for developing services _outside_ the
  cluster; the cluster has its own data layer.

## Trade-offs Accepted

- One extra Argo CD Application to maintain.
