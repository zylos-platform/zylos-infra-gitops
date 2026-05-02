# ADR 0005: Istio as Four Separate Helm Charts (Not IstioOperator)

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

Istio offers two installation methods:

1. **`istioctl`** with the `IstioOperator` CRD: single-command install,
   in-cluster operator manages components.
2. **Four Helm charts**: `base`, `cni`, `istiod`, `ztunnel` — managed
   independently.

## Decision

Use **the four Helm charts**, deployed as separate Argo CD Applications.

## Rationale

- **GitOps-friendly:** Helm charts integrate cleanly with Argo CD; the
  IstioOperator approach requires a separate operator that fights Argo CD
  for ownership.
- **Granular upgrades:** ztunnel and istiod can be upgraded on different
  cadences (per Istio's recommended upgrade flow).
- **Officially recommended for production**.

## Trade-offs Accepted

- Four Applications instead of one. Sync waves enforce ordering. Less
  ergonomic for a quick demo but correct for our long-term operations.

## References

- https://istio.io/latest/docs/ambient/install/helm/
