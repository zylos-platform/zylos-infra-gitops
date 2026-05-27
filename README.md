# zylos-infra-gitops

GitOps bootstrap for the Zylos Kubernetes cluster. Uses Argo CD to
declaratively manage the entire platform layer.

## Stack

| Component               | Version                    | Notes                                |
|-------------------------|----------------------------|--------------------------------------|
| Argo CD                 | chart 9.5.x (app v3.3)     | Server-side apply enabled            |
| Istio                   | 1.24.x                     | **Ambient mode** (no sidecars)       |
| cert-manager            | v1.20.2                    | OCI Helm chart from quay.io/jetstack |
| kube-prometheus-stack   | 65.x                       | Prometheus 3 + Grafana 11            |
| Grafana Tempo           | chart 1.18                 | Traces                               |
| Grafana Loki            | chart 6.21                 | Logs (monolithic mode)               |
| OpenTelemetry Collector | chart 0.108                | OTLP receiver                        |
| Keycloak                | 26.6.1 (custom GHCR image) | Identity + Zylos ActClaimMapper      |

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
- [ADR 0006: Bitnami removal; Keycloak Operator adoption](docs/adr/0006-bitnami-removal-and-keycloak-operator.md)
- [ADR 0007: Sealed Secrets for kind dev](docs/adr/0007-sealed-secrets-for-kind-dev.md)
- [ADR 0008: zylos-service-base chart design](docs/adr/0008-zylos-service-base-chart-design.md)
- [ADR 0009: keycloak-config-cli for realm reconciliation](docs/adr/0009-keycloak-config-cli-for-realm-reconciliation.md)
- [ADR 0010: OAuth flows per client type](docs/adr/0010-oauth-flows-per-client-type.md)
- [ADR 0011: RFC 8693 Token Exchange V2](docs/adr/0011-rfc-8693-token-exchange.md)
- [ADR 0012: Refresh token reuse detection](docs/adr/0012-refresh-token-reuse-detection.md)
- [ADR 0013: Custom Keycloak image for ActClaimMapper](docs/adr/0013-keycloak-custom-image-act-mapper.md)

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
