#!/usr/bin/env bash
# Generates the SealedSecret used by Strimzi to PUSH the built Connect image to GHCR.
# Export GHCR_USER and GHCR_PAT (a PAT with write:packages) first.
set -euo pipefail

NS=kafka
OUT=manifests/kafka-connect/01-sealed-secrets.yaml

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
echo "==> Generating SealedSecret for kafka-connect-build-secret..."
kubectl create secret docker-registry kafka-connect-build-secret \
  --namespace "$NS" \
  --docker-server=ghcr.io \
  --docker-username="${GHCR_USER:?set GHCR_USER}" \
  --docker-password="${GHCR_PAT:?set GHCR_PAT (write:packages)}" \
  --dry-run=client -o yaml \
| kubeseal --format yaml \
    --controller-namespace sealed-secrets \
> "$OUT"

echo "Wrote $OUT (kafka-connect-build-secret)."
