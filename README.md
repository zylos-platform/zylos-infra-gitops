# zylos-infra-gitops

GitOps bootstrap for the Zylos Kubernetes cluster. Uses Argo CD to
declaratively manage the entire platform layer.

## Stack

| Component               | Version                    | Notes                                |
| ----------------------- | -------------------------- | ------------------------------------ |
| Argo CD                 | chart 9.5.x (app v3.3)     | Server-side apply enabled            |
| Istio                   | 1.24.x                     | **Ambient mode** (no sidecars)       |
| cert-manager            | v1.20.2                    | OCI Helm chart from quay.io/jetstack |
| kube-prometheus-stack   | 65.x                       | Prometheus 3 + Grafana 11            |
| Grafana Tempo           | chart 1.18                 | Traces                               |
| Grafana Loki            | chart 6.21                 | Logs (monolithic mode)               |
| OpenTelemetry Collector | chart 0.108                | OTLP receiver                        |
| Keycloak                | 26.6.x (codecentric chart) | Identity                             |

## Quick Start

```bash
./scripts/bootstrap.sh
```

See [`docs/bootstrap-procedure.md`](docs/bootstrap-procedure.md) for full
procedure.

## Architecture Decisions

- [ADR 0001: App-of-apps pattern](docs/adr/0001-app-of-apps-pattern.md)
- [ADR 0002: Istio ambient mode](docs/adr/0002-istio-ambient-mode.md)
- [ADR 0003: ESO over Sealed Secrets for prod](docs/adr/0003-eso-over-sealed-secrets-for-prod.md)
- [ADR 0004: Helm via Argo CD, not Helm CLI](docs/adr/0004-helm-via-argocd-not-helm-cli.md)
- [ADR 0005: Istio as four charts](docs/adr/0005-managing-istio-as-four-charts.md)

## Repository Layout

```
├── argocd/
│      └─ cluster-bootstrap/
│               └─ projects/     # AppProjects (RBAC scopes)
│               └─ apps/         # Child Applications managed by the root
│      └─ root-app.yaml          # The "app of apps" entrypoint
├── helm-values/                 # Per-chart values files (referenced by Apps via $values)
├── manifests/                   # Plain manifests (not Helm-charted)
├── scripts/                     # bootstrap, teardown, port-forward
├── docs/                        # README, ADRs, runbooks
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Every PR runs `yamllint` and
`kubeconform` validation.
