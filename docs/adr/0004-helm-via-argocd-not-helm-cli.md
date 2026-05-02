# ADR 0004: Helm Charts Deployed via Argo CD, Not Helm CLI

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

Helm can deploy charts directly (`helm install`). But once a chart is
installed, Argo CD has no GitOps control over it.

## Decision

After bootstrap, **all Helm charts are deployed via Argo CD `Application`
resources** with `chart`/`targetRevision` references. The exception: Argo
CD itself, which has to be installed by `helm install` once during
bootstrap.

## Rationale

- **Single reconciliation loop:** Argo CD diffs Git vs. live state; drift is
  detected and corrected.
- **Audit trail:** Every change to a chart's values or version is a Git
  commit.
- **Multi-source Applications** let us reference
  a chart from one repo and values files from another, keeping our values
  in `helm-values/` while the charts come from upstream.

## Trade-offs Accepted

- Helm hooks behave slightly differently under Argo CD; documented in
  Argo CD's Helm guide.
