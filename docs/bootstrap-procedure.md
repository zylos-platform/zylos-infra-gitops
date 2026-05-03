# Cluster Bootstrap Procedure

## Prerequisites

- A running Kubernetes cluster (kind, k3d, EKS, etc.)
- `kubectl` context pointing to the target cluster.
- `helm` CLI v3.6+.
- This repo cloned locally.

## One-Command Bootstrap

```bash
./scripts/bootstrap.sh
```

The script:

1. Installs Argo CD via Helm (one-time direct install).
2. Applies `argocd/root-app.yaml`.
3. Argo CD reconciles every child Application from `argocd/cluster-bootstrap/apps/`.

## Watch Progress

```bash
kubectl get applications -n argocd -w
```

Healthy state:

| NAME                    | SYNC STATUS | HEALTH STATUS |
| ----------------------- | ----------- | ------------- |
| cert-manager            | Synced      | Healthy       |
| istio-base              | Synced      | Healthy       |
| istio-cni               | Synced      | Healthy       |
| istiod                  | Synced      | Healthy       |
| ztunnel                 | Synced      | Healthy       |
| kube-prometheus-stack   | Synced      | Healthy       |
| loki                    | Synced      | Healthy       |
| tempo                   | Synced      | Healthy       |
| opentelemetry-collector | Synced      | Healthy       |
| keycloak                | Synced      | Healthy       |
| argocd                  | Synced      | Healthy       |
| zylos-root              | Synced      | Healthy       |

Initial reconciliation takes ~5–10 minutes (Helm chart pulls, image pulls).

## Access the Argo CD UI

```bash
# Port-forward
./scripts/port-forward-argocd.sh

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

Open http://localhost:8081 and log in as `admin`.

## Tear Down

```bash
./scripts/teardown.sh
```

## Daily Workflow

### Morning: Bring the cluster up

```bash
cd ~/zylos/zylos-platform-bootstrap
make kind-up                  # Full bootstrap
# OR
LEAN=1 make kind-up           # Lean (no observability)
```

Wait ~15 minutes the first time; ~5 minutes on subsequent days (images cached).

### Evening: Tear it down

```bash
make kind-down
```

Releases all memory. Cluster state is gone but Argo CD definitions in Git are
preserved — the next morning's `kind-up` rebuilds the same cluster identically.

### When the cluster gets weird

```bash
make kind-down && make kind-up
```

5-minute reset to a known-good state. Don't waste hours debugging an
ephemeral local cluster — recreate it.

### Check what's running

```bash
make apps                     # Argo CD Applications
kubectl get pods --all-namespaces
```
