# ADR 0002: Istio Ambient Mode (Sidecar-less)

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

Istio's traditional sidecar mode injects an Envoy proxy into every
application pod. This works but adds CPU/memory overhead per workload,
breaks pods that don't tolerate sidecars well, and requires application
restarts on Istio upgrades.

Ambient mode:
- Runs a per-node `ztunnel` daemon for L4 (mTLS, telemetry).
- Provisions `waypoint` proxies only when L7 features are needed.
- Eliminates per-pod sidecars entirely.

## Decision

Use **Istio ambient mode** for the Zylos cluster.

## Rationale

- **~70% lower resource overhead** than sidecars at our service count.
- **No app pod restarts** on Istio upgrades — ztunnel is a DaemonSet.
- **Cleaner pod definitions** — no injected sidecar containers.
- **L4 mTLS for free** — every pod in an ambient-enrolled namespace gets
  mutual TLS automatically.

## Trade-offs Accepted

- **Newer surface area** — Mitigated by the official Istio docs being thorough.
- **Per-node ztunnel** — slightly different operational model from sidecars.
  Each cluster node must run a ztunnel pod.

## Implementation

Four Helm charts, in order: `base`, `cni`, `istiod` (with `profile=ambient`),
`ztunnel`. Namespaces opt in via the label
`istio.io/dataplane-mode: ambient`.

## References

- https://istio.io/v1.25/blog/2024/ambient-reaches-ga/
- https://istio.io/latest/docs/ambient/install/helm/
