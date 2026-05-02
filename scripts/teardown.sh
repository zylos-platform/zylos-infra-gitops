#!/usr/bin/env bash
###############################################################################
# Tear down everything Argo CD manages, then Argo CD itself.
# WARNING: deletes EVERYTHING in the cluster managed by Zylos GitOps.
###############################################################################

set -euo pipefail

read -p "This will delete ALL Zylos GitOps-managed resources. Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

echo "==> Removing root Application..."
kubectl delete application -n argocd zylos-root --ignore-not-found

echo "==> Removing remaining child Applications..."
kubectl delete applications -n argocd --all --ignore-not-found

echo "==> Uninstalling Argo CD..."
helm uninstall argocd -n argocd || true

echo "==> Deleting argocd namespace..."
kubectl delete namespace argocd --ignore-not-found

echo "✓ Teardown complete. CRDs and PVCs may persist; clean those manually if needed."
