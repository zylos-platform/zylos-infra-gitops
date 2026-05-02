# ADR 0001: App-of-Apps GitOps Pattern

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

Zylos cluster needs a way to declaratively manage all platform components
(Istio, observability, cert-manager, Keycloak, etc.) and application
services from Git. Argo CD's `Application` CRD provides the building block.

## Decision

Use the **app-of-apps pattern**: a single root `Application` (`zylos-root`)
points at a Git directory containing other `Application` manifests. Each
child Application then deploys a Helm chart or directory of plain manifests.

## Rationale

- **One-command bootstrap:** Install Argo CD → apply root → done.
- **Declarative everything:** Adding a new platform component is a PR that
  adds a YAML file under `argocd/apps/`.
- **Sync waves** (`argocd.argoproj.io/sync-wave: "-10"` etc.) provide explicit
  ordering for dependencies (CRDs first, then operators, then workloads).

## Alternatives Rejected

- **ApplicationSet only:** Generates Apps from templates. Powerful but
  adds complexity; the app-of-apps pattern is the foundation. We may use
  ApplicationSet for service-level Apps later.
- **Flux's `HelmRelease`:** Equivalent feature; we picked Argo CD for its
  superior UI and ecosystem.
