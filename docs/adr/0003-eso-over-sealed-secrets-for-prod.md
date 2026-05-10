# ADR 0003: External Secrets Operator (Production), Sealed Secrets (Local)

- **Status:** Accepted
- **Date:** 2026-05-02
- **Superseded by:** [ADR 0007](./0007-sealed-secrets-for-kind-dev.md)
- **Supersession date:** 2026-05-10

> **Note:** The "plain Secrets in Git for kind" portion of this ADR is no
> longer in effect. ADR 0007 reverses that decision in favor of Sealed
> Secrets for kind dev clusters. The ESO-for-production portion of this
> ADR remains accepted and is reaffirmed by ADR 0007.

## Context

Two patterns for managing Kubernetes secrets via GitOps:

- **Sealed Secrets:** Encrypt secrets with the cluster's public key, commit
  the encrypted form to Git, controller decrypts on apply.
- **External Secrets Operator (ESO):** Define a `SecretStore` (e.g., AWS
  Secrets Manager) and an `ExternalSecret` resource. ESO pulls the secret
  at runtime; **the actual secret value is never in Git.**

## Decision

- **Production (AWS):** External Secrets Operator + AWS Secrets Manager.
- **Local development:** No secret management needed (plain k8s `Secret`
  manifests are fine — these clusters are ephemeral and contain only
  sample data). Sealed Secrets is **available** if needed but not the
  default.

## Rationale

- **ESO never stores secrets in Git** — even encrypted ones. Encrypted
  secrets in Git are still a long-term liability if a key leaks.
- **AWS-native:** Secrets Manager handles rotation, audit logs, IAM-based
  access. We benefit from those without writing the same logic.
- **Per-region/per-environment** secret scoping is built in.
- **Local dev simplicity:** Sealed Secrets adds a controller and a CLI
  workflow that's friction for ephemeral local clusters. Plain Secrets
  with dev-only values are fine.

## Trade-offs Accepted

- ESO requires AWS IRSA setup in production. We document this in the
  prod runbook.
