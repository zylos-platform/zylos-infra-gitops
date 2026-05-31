# Zylos Platform Bootstrap — Developer Guide

GitOps bootstrap for the Zylos Kubernetes cluster.
This repo's manifests are reconciled by Argo CD against any cluster.

## What's Inside

| Component               | Purpose                                                |
|-------------------------|--------------------------------------------------------|
| Argo CD                 | GitOps controller                                      |
| Istio (ambient mode)    | Service mesh                                           |
| cert-manager            | TLS certificate automation                             |
| kube-prometheus-stack   | Metrics + alerting (Prometheus, Grafana, Alertmanager) |
| Grafana Tempo           | Distributed traces                                     |
| Grafana Loki            | Log aggregation                                        |
| OpenTelemetry Collector | OTLP receiver, fan-out to Tempo/Prom/Loki              |
| Keycloak                | Identity provider                                      |

## Bootstrap Procedure

See [`bootstrap-procedure.md`](./bootstrap-procedure.md).

## Architecture Decisions

- [ADR 0001: App-of-apps pattern](adr/0001-app-of-apps-pattern.md)
- [ADR 0002: Istio ambient mode](adr/0002-istio-ambient-mode.md)
- [ADR 0003: ESO over Sealed Secrets for prod](adr/0003-eso-over-sealed-secrets-for-prod.md)
- [ADR 0004: Helm via Argo CD, not Helm CLI](adr/0004-helm-via-argocd-not-helm-cli.md)
- [ADR 0005: Istio as four charts, not IstioOperator](adr/0005-managing-istio-as-four-charts.md)
- [ADR 0006: Bitnami removal and Keycloak Operator](adr/0006-bitnami-removal-and-keycloak-operator.md)
- [ADR 0007: Sealed Secrets for kind dev, ESO for production](adr/0007-sealed-secrets-for-kind-dev.md)
- [ADR 0008: zylos-service-base chart design](adr/0008-zylos-service-base-chart-design.md)
- [ADR 0009: keycloak-config-cli for realm reconciliation](adr/0009-keycloak-config-cli-for-realm-reconciliation.md)
- [ADR 0010: OAuth 2.1 flow selection per client type](adr/0010-oauth-flows-per-client-type.md)
- [ADR 0011: RFC 8693 token exchange (V2) for audience downscoping](adr/0011-rfc-8693-token-exchange.md)
- [ADR 0012: Refresh token reuse detection](adr/0012-refresh-token-reuse-detection.md)
- [ADR 0013: Keycloak custom image act mapper](adr/0013-keycloak-custom-image-act-mapper.md)
- [ADR 0014: Gateway deployment](adr/0014-gateway-deployment.md)

## Troubleshooting

See [`troubleshooting.md`](./troubleshooting.md).
