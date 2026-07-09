#!/usr/bin/env bash
###############################################################################
#
# kind-up.sh — one-shot local cluster + Argo CD bootstrap.
#
# Combines:
#   1. Create the kind cluster from  zylos-infra-terraform.
#   2. Install NGINX Ingress.
#   3. Run scripts/bootstrap.sh to install Argo CD + apply root app.
#
# Usage:
#   ./scripts/kind-up.sh              # Default (3-node) cluster
#   LEAN=1 ./scripts/kind-up.sh       # Lean (1-node) cluster
#
###############################################################################

set -euo pipefail

cd "$(dirname "$0")/.."

# Find sibling infra repo
#TERRAFORM_REPO="${TERRAFORM_REPO:-$(realpath ../zylos-infra-terraform)}"
#
#if [[ ! -d "${TERRAFORM_REPO}/kubernetes/kind" ]]; then
#  echo "ERROR:  zylos-infra-terraform not found at ${TERRAFORM_REPO}." >&2
#  echo "Set TERRAFORM_REPO=/path/to/ zylos-infra-terraform and rerun." >&2
#  exit 1
#fi

CLUSTER_CONFIG="kind/cluster.yaml"
if [[ "${LEAN:-0}" == "1" ]]; then
  CLUSTER_CONFIG="kind/cluster-lean.yaml"
  echo "Using LEAN single-node cluster."
fi

NGINX_INGRESS_VERSION="controller-v1.11.3"

echo "==============================================="
echo "Zylos Local Cluster Bootstrap"
echo "==============================================="
echo "kind config:    ${CLUSTER_CONFIG}"
echo "Ingress:        nginx ${NGINX_INGRESS_VERSION}"
echo ""

# Step 1: Cluster
if kind get clusters 2>/dev/null | grep -qx "zylos"; then
  echo "==> kind cluster 'zylos' already exists. Reusing."
else
  echo "==> [1/5] Creating kind cluster..."
  kind create cluster --config "${CLUSTER_CONFIG}" --wait 5m
fi

kubectl config use-context kind-zylos

# Step 2: NGINX Ingress
if kubectl get ns ingress-nginx >/dev/null 2>&1; then
  echo "==> NGINX Ingress already installed. Skipping."
else
  echo ""
  echo "==> [2/5] Installing NGINX Ingress controller..."
  kubectl apply -f bootstrap/nginx-kind-deploy.yaml

  echo ""
  echo "==> Waiting for NGINX controller to be ready (up to 3 min)..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=180s
fi
# Step 3: Split-horizon DNS — resolve *.zylos.local in-cluster to the NGINX ingress controller
echo ""
echo "==> [3/5] Configuring CoreDNS rewrite for *.zylos.local..."
COREFILE_TMP="$(mktemp)"
kubectl -n kube-system get cm coredns -o go-template='{{index .data "Corefile"}}' > "${COREFILE_TMP}"
if grep -q 'zylos\\.local' "${COREFILE_TMP}"; then
  echo "    CoreDNS rewrite already present. Skipping."
else
  awk '/forward \. \/etc\/resolv\.conf/ && !done {
        print "    rewrite stop {";
        print "      name regex (.*)\\.zylos\\.local ingress-nginx-controller.ingress-nginx.svc.cluster.local";
        print "      answer auto";
        print "    }";
        done=1
      } { print }' "${COREFILE_TMP}" > "${COREFILE_TMP}.new"
  kubectl -n kube-system create configmap coredns \
    --from-file=Corefile="${COREFILE_TMP}.new" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n kube-system rollout restart deploy/coredns
  kubectl -n kube-system rollout status deploy/coredns --timeout=60s
  echo "    *.zylos.local now resolves to the ingress controller in-cluster."
fi
rm -f "${COREFILE_TMP}" "${COREFILE_TMP}.new" 2>/dev/null || true

# Step 4: Argo CD bootstrap (delegates to existing script)
echo ""
echo "==> [4/5] Bootstrapping Argo CD and platform components..."
./scripts/bootstrap.sh local

# Step 5: Show the user how to monitor
echo ""
echo "==============================================="
echo "✓ Bootstrap initiated."
echo "==============================================="
echo ""
echo "Watch reconciliation progress:"
echo "  kubectl get applications -n argocd -w"
echo ""
echo "Get the Argo CD initial admin password:"
echo "  make password"
echo ""
echo "Open the Argo CD UI:"
echo "  ./scripts/port-forward-argocd.sh"
echo "  Then visit http://localhost:8081"
echo ""
echo "Tear it all down (releases all memory):"
echo "  ./scripts/kind-down.sh"
echo ""
