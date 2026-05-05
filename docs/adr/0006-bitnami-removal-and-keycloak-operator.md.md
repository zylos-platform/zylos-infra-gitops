# ADR 0006: Remove Bitnami Charts; Use Keycloak Operator + CloudNativePG

- **Status:** Accepted
- **Date:** 2026-05

## Context

Initial work referenced the Codecentric `keycloakx` Helm chart
with an embedded Bitnami-style Postgres sub-chart, and listed the Bitnami
charts repo as an allowed source.

Two problems surfaced:

1. **Bitnami charts are no longer free.** Effective August 28, 2025 (Broadcom
   acquisition of Bitnami), the public catalog at `docker.io/bitnami/*` was
   moved to `bitnamilegacy/*` (frozen, unsupported) or removed entirely.
   Continued production use requires Bitnami Secure Images.
2. **The Codecentric chart's start mode was inconsistent.** The chart used
   `start --optimized` in some configurations but the docs and our Compose
   stack used `start-dev`. This created a parity gap between local Compose
   and cluster deployment.

## Decision

### Replace Bitnami chart references with non-Bitnami alternatives

| Removed                                                          | Replaced with                                                                                         |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `bitnami/keycloak` Helm chart                                    | **Keycloak Operator** (official upstream, `keycloak-k8s-resources` repo, v26.6.1)                     |
| Bitnami Postgres sub-chart                                       | **CloudNativePG operator** (CNCF Sandbox, free)                                                       |
| Bitnami `sealed-secrets`                                         | **`bitnami-labs/sealed-secrets`** — **the original Apache 2 project**, NOT the Broadcom-Bitnami chart |
| `https://charts.bitnami.com/bitnami` in AppProject `sourceRepos` | **Removed entirely**                                                                                  |

### Use Keycloak production mode (`start --optimized --import-realm`) in all cluster deployments

`start-dev` remains acceptable in the Docker Compose stack for
ergonomic local development outside the cluster. In the kind cluster and in
AWS, Keycloak runs in production mode with PostgreSQL.

### Use decoupled PostgreSQL via CloudNativePG, NOT embedded Postgres

The Keycloak `Cluster` CR connects to a separate CloudNativePG `Cluster` CR.
This mirrors the AWS production pattern (Keycloak → Aurora), where Keycloak
sees a connection string and is unaware whether the Postgres beneath it is
locally-operator-managed or AWS-managed.

## Rationale

- **Production parity:** Same start mode, same DB-decoupling pattern, same
  realm-import workflow in kind and AWS.
- **Operator pattern:** The Keycloak Operator is the official upstream, used
  by Red Hat in Red Hat build of Keycloak. CRD-based config means realm
  changes are declarative GitOps changes.
- **CloudNativePG** mirrors managed Postgres semantics (HA, backups,
  PITR, monitoring) and is widely adopted.

## Trade-offs

- **More moving parts:** Three Argo CD Applications (CloudNativePG operator,
  Keycloak operator, Keycloak instance) instead of one Helm release.
- **CRD-based config:** Slightly different mental model than Helm values.

## References

- https://github.com/bitnami/charts/issues/35164 (Bitnami deprecation announcement)
- https://www.keycloak.org/operator/installation
- https://cloudnative-pg.io/
- https://github.com/bitnami-labs/sealed-secrets (the _original_ sealed-secrets)
