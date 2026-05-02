# Troubleshooting

## Argo CD applies but child Apps stuck "OutOfSync"

Check the Application's events:
```bash
kubectl describe application <name> -n argocd
```

Common causes:
- Helm chart version no longer exists upstream (chart was deleted).
- A required CRD hasn't been installed yet — check sync waves.
- `ServerSideApply=true` is missing from `syncPolicy.syncOptions`.

## Istio ztunnel pods crash-loop

Most often: the `cni` chart wasn't installed (or wasn't installed first).
Verify:
```bash
kubectl get pods -n istio-system
```

## kube-prometheus-stack ServiceMonitor CRD not found

The Prometheus Operator CRDs come bundled in the chart. If you see
"no matches for kind ServiceMonitor", the CRDs haven't been applied yet
— let Argo CD retry.

## Loki gateway pod can't talk to Loki backend

Confirm `deploymentMode: SingleBinary` in `helm-values/loki.yaml`. Don't
mix monolithic and microservices modes.

## Keycloak realm import fails

The realm ConfigMap must exist before Keycloak boots. Sync wave 9 (realm)
runs before sync wave 10 (Keycloak). If realm CM is missing:
```bash
kubectl get cm -n keycloak zylos-realm
```
