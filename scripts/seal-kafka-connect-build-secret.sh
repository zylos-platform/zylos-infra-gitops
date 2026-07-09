#!/usr/bin/env bash
# Generates the SealedSecret used by Strimzi to PUSH the built Connect image to GHCR.
# Export GHCR_USER and GHCR_PAT (a PAT with write:packages) first.
set -euo pipefail

cd "$(dirname "$0")/.."

# Ensure an environment parameter is passed
ENV=${1:-}
if [[ "$ENV" != "local" && "$ENV" != "dev" ]]; then
  echo "Usage: $0 <local|dev>" >&2
  echo "Example: $0 local" >&2
  exit 1
fi

NS="zylos-data-kafka"
OUT_DIR="components/platform/kafka-connect/overlays/${ENV}"
OUT_FILE="${OUT_DIR}/kafka-connect-build-secret.yaml"

mkdir -p "$OUT_DIR"

# Verify the controller is reachable.
echo "==> Verifying sealed-secrets-controller in ${ENV} cluster..."
if ! kubectl -n sealed-secrets get deploy sealed-secrets-controller >/dev/null 2>&1; then
  echo "ERROR: sealed-secrets-controller not found. Verify your current kubectl context." >&2
    exit 1
fi

if ! command -v kubeseal >/dev/null 2>&1; then
  echo "ERROR: kubeseal CLI not installed." >&2
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
| kubeseal --format yaml --controller-namespace sealed-secrets \
| kubectl annotate -f - --local \
    "argocd.argoproj.io/sync-wave=-40" \
    -o yaml \
> "$OUT_FILE"

echo "✅ Success!"
