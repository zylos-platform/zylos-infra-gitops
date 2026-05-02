#!/usr/bin/env bash
###############################################################################
# Zylos cluster bootstrap.
#
# Brings up a cluster from zero to "GitOps reconciling" in ~5 minutes.
#
# Steps:
#   1. Install Argo CD via Helm (one-time direct install).
#   2. Apply the root app-of-apps Application.
#   3. Argo CD takes over and pulls everything else from this repo.
#
# Usage:
#   ./scripts/bootstrap.sh                       # Defaults to current kubectl context
#   GIT_REPO_URL=https://... ./scripts/bootstrap.sh
###############################################################################

set -euo pipefail

cd "$(dirname "$0")/.."

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-9.5.5}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/zylos-platform/zylos-platform-bootstrap.git}"
GIT_REVISION="${GIT_REVISION:-main}"

echo "==============================================="
echo "Zylos Platform Bootstrap"
echo "==============================================="
echo "Cluster context: $(kubectl config current-context)"
echo "Argo CD chart:   ${ARGOCD_CHART_VERSION}"
echo "Source repo:     ${GIT_REPO_URL}@${GIT_REVISION}"
echo ""

read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

# Step 1: Install Argo CD with Helm.
echo "==> [1/3] Adding Argo CD Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo

echo "==> [2/3] Installing Argo CD..."
helm upgrade --install argocd argo/argo-cd \
  --version "${ARGOCD_CHART_VERSION}" \
  --namespace "${ARGOCD_NAMESPACE}" \
  --create-namespace \
  --values helm-values/argocd/argocd-values.yaml \
  --wait \
  --timeout 10m

echo "==> [3/3] Applying root app-of-apps..."
# Substitute the Git repo URL into the root app at apply time.
sed "s|REPO_URL_PLACEHOLDER|${GIT_REPO_URL}|g; s|REVISION_PLACEHOLDER|${GIT_REVISION}|g" \
  argocd/root-app.yaml | kubectl apply -f -

echo ""
echo "✓ Bootstrap initiated."
echo ""
echo "Argo CD will now reconcile every component declared in argocd/apps/."
echo ""
echo "Watch progress:"
echo "  kubectl get applications -n ${ARGOCD_NAMESPACE} -w"
echo ""
echo "Open the Argo CD UI:"
echo "  ./scripts/port-forward-argocd.sh"
echo "  Then visit http://localhost:8081"
echo ""
echo "Get the initial admin password:"
echo "  kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret \\"
echo "    -o jsonpath='{.data.password}' | base64 -d && echo"
