# ADR 0009: keycloak-config-cli for Realm Reconciliation

- **Status:** Accepted
- **Date:** 2026-05-10
- **Related:** ADR 0006 (Keycloak Operator), ADR 0007 (sealed-secrets)

## Context

The Keycloak Operator's `KeycloakRealmImport` controller is **create-only**:
it imports a realm if absent but does not reconcile updates to an existing
realm. From the upstream operator source: "no need to restart Keycloak as
we're only importing new realms and are not overwriting existing realms."

Zylos identity spine requires the realm to evolve frequently:
adding clients, tweaking client policies, modifying token-exchange
permissions, adjusting signing-key policies, adding users. Without
reconciliation, each change forces one of:

1. Delete and recreate the realm (loses all runtime state — sessions, etc.)
2. Manual edits in the admin console (configuration drift; not GitOps)
3. Imperative `kcadm.sh` scripts (not declarative; CI-hostile)

None of these are acceptable for a GitOps-first platform.

## Decision

Use **adorsys/keycloak-config-cli** as the realm reconciliation tool, run as
a Kubernetes Job triggered by Argo CD `Sync` hooks.

Responsibilities are split cleanly:

| Reconciler                       | Owns                                                                                          |
| -------------------------------- | --------------------------------------------------------------------------------------------- |
| `KeycloakRealmImport` (Operator) | The bare realm shell (`realm: zylos`, `enabled: true`) — created if absent                    |
| `keycloak-config-cli` (Job)      | All realm content: clients, roles, users, client policies, token settings, signing-key policy |

Two reconcilers never write to the same field. The shell ensures Keycloak
has the realm; config-cli evolves its content on every Argo CD sync.

## Architecture

The Job is defined at `manifests/keycloak/05-config-cli-job.yaml` with:

- `argocd.argoproj.io/hook: Sync` — runs as part of every keycloak app sync
- `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation` — fresh Job per sync
- Mounts the realm YAML from `keycloak-realm-config` ConfigMap at `/config`
- Authenticates to Keycloak with the bootstrap admin credentials (managed via SealedSecret)
- Injects client secrets via env vars (referenced as `${VAR_NAME}` in realm YAML)
- `IMPORT_MANAGED_NO_DELETE=true` for safety
- `IMPORT_CACHE_ENABLED=true` for idempotent re-runs (checksum-cached)

Realm YAML uses Keycloak's native realm-export format — the same shape the
admin console exports — making round-trip editing straightforward.

## Image Pinning

Pinned to `docker.io/adorsys/keycloak-config-cli:6.5.0-26.5.4`. Each
keycloak-config-cli release is built against a specific Keycloak version;
this image targets KC 26.5.4. Our deployed Keycloak is 26.6.1, a one-minor
skew.

The realm-import schema is backward-compatible across 26.x minor versions.
When `6.x-26.6.x` is published (track
[adorsys/keycloak-config-cli releases](https://github.com/adorsys/keycloak-config-cli/releases)),
bump the image tag.

If a schema incompatibility surfaces before then, the fallback is the
`edge-build` tag (`adorsys/keycloak-config-cli:edge-build`) with
`KEYCLOAK_VERSION=26.6.1` env override, which compiles the CLI against the
exact target version at container startup. Slower startup but exact match.

## Rationale

- **Idempotent reconciliation.** config-cli stores SHA256 checksums of
  imported configs as realm attributes; unchanged configs complete in
  seconds. CI-friendly and developer-friendly.
- **Native export-format compatibility.** No DSL to learn; the YAML is
  what admins already know from realm exports. Round-trip editing
  (export → edit → re-import) works out of the box.
- **Variable substitution.** Client secrets stay in SealedSecrets;
  realm YAML references them as `${VAR}` placeholders, substituted at
  import time. Secrets never appear in the ConfigMap or Git.
- **State tracking inside Keycloak.** config-cli marks managed resources
  with an annotation. Hand-created resources (alice, bob,
  `zylos-internal`) are not touched until we explicitly opt into managing
  them. Migration is incremental and safe.
- **GitOps-native.** Runs as an Argo CD Sync hook; sync failures surface
  as Application unhealthy. Standard troubleshooting workflow.

## Alternatives Considered

| Alternative                               | Why rejected                                                                                                                                                                           |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Terraform `mrparkers/keycloak` provider   | Introduces a second IaC tool inside our cluster-config flow. Would require Terraform state management for cluster-internal resources, conflicting with Argo CD's source-of-truth role. |
| Custom Keycloak Admin API scripts         | Imperative, not declarative; CI-hostile; no drift detection; no idempotency guarantees.                                                                                                |
| Delete-and-recreate realm on every change | Loses runtime state (sessions, dynamically created users). Catastrophic for production.                                                                                                |
| Keycloak Operator extension (custom CRD)  | Significant Java development. config-cli already solves this.                                                                                                                          |

## Trade-offs Accepted

- **Job-per-sync overhead.** Every Argo CD sync runs the Job, even on
  unchanged config. Mitigated by `IMPORT_CACHE_ENABLED=true`; cache hits
  complete in seconds. ~5-second overhead per sync.
- **Sync hook coupling.** A config-cli failure blocks the keycloak app
  from achieving Synced status. This is the correct behavior — failed
  realm reconciliation should not be silently ignored — but operators
  need to watch for it.
- **Minor version skew with KC.** Documented above; acceptable
  short-term; tracked via image-bump cadence.

## Production Migration

Same pattern in AWS, with three differences:

- Secrets sourced from AWS Secrets Manager via ESO (per ADR 0007)
- Keycloak URL uses internal AWS DNS, e.g. `https://keycloak.internal.zylos.app`
- Realm YAML may reference different OIDC redirect URIs (per-environment values)

The Job spec is the same; per-environment overrides live in environment-
specific Argo CD ApplicationSet generators.

## References

- adorsys/keycloak-config-cli: <https://github.com/adorsys/keycloak-config-cli>
- Keycloak Operator realm import limitation: <https://github.com/keycloak/keycloak/blob/26.6.1/operator/src/main/java/org/keycloak/operator/controllers/KeycloakRealmImportController.java>
- ADR 0006: Bitnami removal and Keycloak Operator
- ADR 0007: Sealed Secrets for kind dev, ESO for production
