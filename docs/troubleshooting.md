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

## kind-Specific Issues

### Cluster creation fails with "no space left on device"

Docker is full. Run:

```bash
docker system prune -af --volumes
```

### Pods pending with "Insufficient memory"

Your Docker memory limit is too low. Edit `%UserProfile%\.wslconfig` to set
`memory=12GB` (Windows) or Docker Desktop → Settings → Resources (macOS).
Then `wsl --shutdown` and retry.

### Argo CD "context deadline exceeded" on Helm chart fetch

Network blip. Argo CD will retry automatically. Or force:

```bash
make sync
```

### Keycloak fails to start: "database is locked" or "schema migration failed"

Embedded Postgres on first boot. Wait 5 minutes. If still stuck:

```bash
kubectl -n keycloak rollout restart statefulset/keycloak-postgresql
kubectl -n keycloak rollout restart statefulset/keycloak
```

### NGINX Ingress controller pod stuck Pending

It's pinned to a node with the `ingress-ready=true` label. Verify:

```bash
kubectl get nodes --show-labels | grep ingress-ready
```

The control-plane node should have this label. If not, your kind cluster.yaml
didn't apply that label, recreate the cluster.

### Grafana shows "no data" for Prometheus targets

Wait 60 seconds after bootstrap completes. Prometheus needs to discover and
scrape targets at least once. If it persists past 5 min, port-forward to
Prometheus directly:

```bash
kubectl -n observability port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Open http://localhost:9090/targets — most should be UP.

### "Out of memory" / WSL2 OOM-kills containers

You exceeded WSL's memory budget. Either:

- Switch to lean mode: `LEAN=1 make kind-up`
- Increase WSL2 memory in `.wslconfig`
- Close other applications
