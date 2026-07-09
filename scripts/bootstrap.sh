#!/usr/bin/env bash
###############################################################################
# Zylos cluster bootstrap.
#
# Brings up a cluster from zero to "GitOps reconciling" in ~5 minutes.
#
# Steps:
#   1. Install Argo CD via Helm (one-time direct install).
#   2. Apply the Projects Application (establishing boundaries).
#   3. Apply the environment-specific root app-of-apps.
#
# Usage:
#   ./scripts/bootstrap.sh <local|dev>
#   GIT_REPO_URL=https://... ./scripts/bootstrap.sh dev
###############################################################################

set -euo pipefail

cd "$(dirname "$0")/.."

ENV=${1:-}
if [[ "$ENV" != "local" && "$ENV" != "dev" ]]; then
  echo "Usage: $0 <local|dev>" >&2
  echo "Example: $0 local" >&2
  exit 1
fi

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-9.5.5}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/zylos-platform/zylos-infra-gitops.git}"
GIT_REVISION="${GIT_REVISION:-main}"

echo "==============================================="
echo "Zylos Platform Bootstrap [Environment: ${ENV^^}]"
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

# Install Argo CD with Helm.
echo ""
echo "==> [1/4] Adding Argo CD Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo

echo ""
echo "==> [2/4] Installing Argo CD..."

helm upgrade --install argocd argo/argo-cd \
  --version "${ARGOCD_CHART_VERSION}" \
  --namespace "${ARGOCD_NAMESPACE}" \
  --create-namespace \
  --values helm-values/argocd/values.yaml \
  --values "helm-values/argocd/values-${ENV}.yaml" \
  --wait \
  --timeout 10m

echo ""
echo "==> [3/4] Applying Zylos AppProjects..."
# The projects MUST be applied before the root app, otherwise Argo CD
# will reject the root app for referencing a non-existent project.
sed "s|REPO_URL_PLACEHOLDER|${GIT_REPO_URL}|g; s|REVISION_PLACEHOLDER|${GIT_REVISION}|g" \
  bootstrap/projects-app.yaml | kubectl apply -f -

echo ""
echo "==> [4/4] Applying ${ENV} root app-of-apps..."
# Dynamically target the correct root app based on the script parameter
sed "s|REPO_URL_PLACEHOLDER|${GIT_REPO_URL}|g; s|REVISION_PLACEHOLDER|${GIT_REVISION}|g" \
  "bootstrap/root-${ENV}.yaml" | kubectl apply -f -

echo ""
echo "✅ Bootstrap complete! Argo CD is now syncing the ${ENV^^} cluster."
