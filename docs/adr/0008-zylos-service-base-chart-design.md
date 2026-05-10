# ADR 0008: zylos-service-base Chart Design

- **Status:** Accepted
- **Date:** 2026-05-10
- **Related:** ADR 0001 (app-of-apps), ADR 0002 (Istio ambient mode)

## Context

The `zylos-service-base` chart is the single Helm chart used by every Zylos
backend service deployed via Argo CD. It must balance two opposing pressures:

1. **Tight defaults.** Every service inherits the chart's security, observability,
   and resilience defaults; weak defaults compound across 23 services.
2. **Per-service flexibility.** Services have legitimately different needs
   (BFFs need internet egress; gateway needs to be reachable from outside;
   most internal services should be locked down).

## Decision

The chart at v0.2.0 ships these defaults and toggles:

| Concern                              | Default                                                                | Toggle                                        |
| ------------------------------------ | ---------------------------------------------------------------------- | --------------------------------------------- |
| Dedicated ServiceAccount per service | Created                                                                | `serviceAccount.create: true`                 |
| `automountServiceAccountToken`       | `false`                                                                | `serviceAccount.automountServiceAccountToken` |
| PodDisruptionBudget                  | `maxUnavailable: 1` (only when `replicaCount > 1`)                     | `pdb.enabled: true`                           |
| NetworkPolicy                        | Default-deny + Istio ambient + observability + DNS                     | `networkPolicy.enabled: true`                 |
| HorizontalPodAutoscaler              | Off (services opt-in)                                                  | `autoscaling.enabled: false`                  |
| Image digest pinning                 | Tag only by default                                                    | `image.digest` overrides tag when set         |
| OTEL resource attributes             | `service.namespace=zylos`, `deployment.environment`, `service.version` | `otel.extraResourceAttributes` for additions  |
| Pod anti-affinity                    | Soft (preferred) by default                                            | `podAntiAffinity.type: required` for hard     |
| Topology spread constraints          | Empty (anti-affinity covers spread)                                    | `topologySpreadConstraints` list              |
| `prometheus.io/*` annotations        | **Removed**                                                            | n/a; ServiceMonitor is the source of truth    |

### NetworkPolicy structure

A default-deny baseline with declarative allow-rule toggles for the most
common Zylos flows:

- `ingress.fromIstio`: ztunnel + waypoint reach pod (essential for ambient)
- `ingress.fromObservability`: Prometheus scraping
- `ingress.fromIngressNginx`: services with public Ingress
- `egress.toDns`: required for any service that resolves names
- `egress.toIstio`: outbound through waypoint
- `egress.toSamePlatform`: intra-platform (zylos-services namespace)
- `egress.toExternal`: explicit opt-in (BFFs, gateway-to-external-IDP)
- `extra` lists for service-specific raw rules

Services compose by enabling the relevant toggles; raw rules are an escape
hatch, not the default path.

### HPA structure

`autoscaling/v2` with explicit `behavior` block:

- `scaleUp.stabilizationWindowSeconds: 0` (immediate scale-up)
- `scaleDown.stabilizationWindowSeconds: 300` (5-minute cautious scale-down)
- `selectPolicy: Max` for scale-up, `Min` for scale-down

This is the consensus pattern for web-facing services; latency-critical
paths benefit from fast scale-up, while scale-down avoids flapping.

When HPA is enabled, the Deployment's `spec.replicas` is omitted entirely
so the HPA owns the count without a controller fight.

### Image digest pinning

`image.digest` (e.g., `sha256:abc123...`), when non-empty, supersedes
`image.tag`. This produces image references like
`ghcr.io/zylos-platform/foo@sha256:abc...` that are guaranteed-immutable.
Production builds should populate `digest`; dev clusters can stick with
tags. CI's deploy-PR is responsible for emitting both fields.

## Rationale

- **Default-deny NetworkPolicy.** Recent
  guidance from CNCF, Calico, Tigera, and Kubernetes documentation all
  converge on this pattern.
- **Pod-level `automountServiceAccountToken: false`** is the recommended
  default; workloads needing K8s API access opt in explicitly. Reduces
  blast radius if a pod is compromised.
- **HPA `behavior` is opinionated.** The fast-up / slow-down pattern is
  the right default for a customer-facing platform; latency-sensitive
  services that need different behavior override the values.
- **PDB gating on `replicaCount > 1`** prevents accidental
  "PodDisruptionBudget blocks all evictions" misconfiguration that occurs
  when a service unintentionally has only one replica.

## Trade-offs Accepted

- **Chart complexity.** The chart now has 9 templates and more values
  knobs. We accept this complexity because every service inherits, so
  improvements compound. Documentation in `values.yaml` comments and
  `NOTES.txt` mitigates the discoverability cost.
- **Default NetworkPolicy may be too restrictive for some services.**
  Services with unusual networking (e.g., public webhook receivers, agents
  reaching external metadata APIs) must opt-in via `egress.toExternal` or
  the `extra` lists. We prefer this over a permissive default that has to
  be tightened per-service.
- **HPA defaults assume CPU is the primary scaling signal.** For services
  with non-CPU bottlenecks (memory-heavy, queue-depth-driven), values
  override `targetCPUUtilization`, set `targetMemoryUtilization`, or
  add custom metrics via the `behavior` block.

## Migration

Chart v0.2.0 is fully backward-compatible for all
existing values; new templates are gated behind feature toggles that
default to safe values. The only behavioral difference for v0.1.0 consumers:

- `prometheus.io/*` pod annotations are no longer rendered.
- ServiceAccount is now created (was previously using namespace `default`).
- Default NetworkPolicy is rendered (default-deny + sensible allows).

For zylos-service-hello, the migration is captured in this PR's update to
`helm-values/services/zylos-service-hello.yaml` (adds
`networkPolicy.ingress.fromIngressNginx: true`).

## References

- Kubernetes Network Policy docs (current as of K8s 1.32)
- HPA `autoscaling/v2` behavior field guidance
- Pod Security Standards "Restricted" profile
