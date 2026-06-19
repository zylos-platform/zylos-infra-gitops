#!/usr/bin/env bash
# Generates the SealedSecret for the Catalog MongoDB application user.
# Re-run after recreating the kind cluster (the sealing cert changes).
set -euo pipefail

NS=mongodb
OUT=manifests/mongodb/01-sealed-secrets.yaml
PASS="$(openssl rand -base64 24 | tr -d '\n=' )"

# Verify the controller is reachable.
echo "==> Verifying sealed-secrets controller..."
if ! kubectl -n sealed-secrets get deploy sealed-secrets-controller >/dev/null 2>&1; then
  echo "ERROR: sealed-secrets-controller not found in namespace sealed-secrets." >&2
  echo "Wait for Argo CD reconciliation before running this script." >&2
  exit 1
fi

if ! kubectl -n sealed-secrets wait --for=condition=Available --timeout=60s \
    deploy/sealed-secrets-controller >/dev/null 2>&1; then
  echo "ERROR: sealed-secrets-controller is not Available." >&2
  exit 1
fi

if ! command -v kubeseal >/dev/null 2>&1; then
  echo "ERROR: kubeseal CLI not installed. Install via:" >&2
  echo "  brew install kubeseal      # macOS" >&2
  echo "  See https://github.com/bitnami-labs/sealed-secrets/releases for Linux." >&2
  exit 1
fi

# Generate plain Secrets and pipe through kubeseal.
echo "==> Generating SealedSecret for catalog-mongodb-app-user..."
kubectl create secret generic catalog-mongodb-app-user \
  --namespace "$NS" \
  --from-literal=password="$PASS" \
  --dry-run=client -o yaml \
| kubeseal --format yaml \
    --controller-namespace sealed-secrets \
    --format=yaml \
> "$OUT"

echo "Wrote $OUT (catalog-mongodb-app-user)."
