# ADR 0007: Sealed Secrets for Kind Dev, ESO for AWS Production

- **Status:** Accepted
- **Date:** 2026-05-10
- **Supersedes:** [ADR 0003](./0003-eso-over-sealed-secrets-for-prod.md)

## Context

ADR 0003 originally accepted **plain Kubernetes `Secret` manifests** in Git
for kind dev clusters, with External Secrets Operator (ESO) for production.
The justification was: kind clusters are ephemeral; only sample data is in
them; plain secrets in Git are tolerable.

This justification was wrong. The cluster is ephemeral; the **repository is
permanent**. Plain secrets committed to Git remain in the history forever:

- After rotation, prior values are still recoverable from `git log`.
- Anyone who clones the repo (current or future contributors, CI runners,
  forks) gets every dev secret ever committed.
- Dev passwords often get reused inadvertently in pre-prod environments,
  amplifying impact.

The original ADR 0003 conflated cluster ephemerality with repository
ephemerality. They are not the same.

Phase 1 (Identity & Security Spine) compounds the issue: it introduces
multiple confidential clients, JWE encryption keys, OAuth client secrets,
and S2S service credentials. The number of secrets grows; the cost of plain
text in Git grows with it.

## Decision

| Environment           | Secrets management                                                            |
| --------------------- | ----------------------------------------------------------------------------- |
| **Kind dev clusters** | **Sealed Secrets** (`bitnami-labs/sealed-secrets`, original Apache 2 project) |
| **AWS production**    | **External Secrets Operator + AWS Secrets Manager** (unchanged from ADR 0003) |

The Sealed Secrets controller deploys via Argo CD to the `sealed-secrets`
namespace at sync wave `-49` (right after Argo CD itself). Developers seal
secrets locally with the `kubeseal` CLI against the cluster's controller
public key; the resulting `SealedSecret` resources are committed.

## Rationale

- **Encrypted-at-rest in Git.** A leaked clone or fork yields ciphertext
  only. Decryption requires the cluster's private key, which never leaves
  the cluster.
- **Production parity in workflow.** Both environments commit
  encrypted-secrets-references to Git and have a controller materialize
  real Secrets at runtime. The encryption backend differs (cluster-local key
  in kind, AWS KMS in production); the workflow shape is consistent.
- **Distinct from Bitnami removal (ADR 0006).** The `bitnami-labs`
  organization is the original Apache 2 sealed-secrets project. It is **not**
  the deprecated `bitnami/*` Helm catalog Broadcom commercialized.
  ADR 0006 explicitly preserves `bitnami-labs/sealed-secrets` as acceptable.

## Trade-offs Accepted

- **Master key per cluster.** Each fresh kind cluster generates a new
  encryption key. Sealed values are not portable across cluster
  instantiations; developers regenerate when they recreate the cluster
  via `make kind-down && make kind-up`. Mitigation: helper script
  `scripts/seal-keycloak-secrets.sh` (and similar future scripts) makes
  regeneration a one-line command.
- **No team-wide shared sealed values for dev.** Each developer's cluster
  has its own key, so committed sealed values work only for the cluster
  that sealed them.
- **kubeseal CLI dependency.** Adds one more local tool to install.

## Workflow Notes

The chart installs the controller named `sealed-secrets` by default, but
the `kubeseal` CLI looks for `sealed-secrets-controller` by default. We
override `fullnameOverride: sealed-secrets-controller` in the Helm values
so `kubeseal` works without `--controller-name=` flags.

CLI invocation pattern:

```bash
kubeseal --controller-namespace=sealed-secrets \
  --format=yaml < secret.yaml > sealed-secret.yaml
```

## References

- ADR 0003 (superseded): plain Secrets for kind, ESO for production
- ADR 0006: Bitnami removal preserved `bitnami-labs/sealed-secrets`
- <https://github.com/bitnami-labs/sealed-secrets>
