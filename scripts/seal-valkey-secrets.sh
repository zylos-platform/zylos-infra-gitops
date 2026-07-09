#!/usr/bin/env bash
# Generates environment-specific SealedSecrets for Valkey.
set -euo pipefail

cd "$(dirname "$0")/.."

# Ensure an environment parameter is passed
ENV=${1:-}
if [[ "$ENV" != "local" && "$ENV" != "dev" ]]; then
  echo "Usage: $0 <local|dev>" >&2
  echo "Example: $0 dev" >&2
  exit 1
fi

echo "==> Verifying sealed-secrets-controller in ${ENV} cluster..."

if ! kubectl -n sealed-secrets get deploy sealed-secrets-controller >/dev/null 2>&1; then
  echo "ERROR: sealed-secrets-controller not found. Ensure your kubectl context is pointed to your ${ENV} cluster." >&2
  exit 1
fi

if ! command -v kubeseal >/dev/null 2>&1; then
  echo "ERROR: kubeseal CLI not installed." >&2
  exit 1
fi

if [[ "$ENV" == "local" ]]; then
  echo "==> Using stable reproducible credentials for ${ENV} environment..."
  VALKEY_PASS="valkey_local_pass_2026"
else
  echo "==> Generating strong random credentials for ${ENV} environment..."
  VALKEY_PASS="$(openssl rand -hex 24)"

  # Print the password so the platform engineer can save it
  echo "[!] DEV Valkey Password generated: ${VALKEY_PASS}"
fi

# Helper function for sealing
seal_literal() {
  local ns="$1" name="$2" pass="$3" filename="$4"
  echo "    -> Sealing '$name' into namespace '$ns' (Fetching key from cluster)..."

  # Ensure the target directory exists before writing
  mkdir -p "$(dirname "$filename")"

  kubectl create secret generic "$name" \
    --namespace "$ns" \
    --from-literal=password="$pass" \
    --dry-run=client -o yaml \
  | kubeseal --format yaml --controller-namespace sealed-secrets \
  | kubectl annotate -f - --local "argocd.argoproj.io/sync-wave=-40" -o yaml \
  > "$filename"
}

echo "==> Generating Valkey secrets for [${ENV^^}] environment..."

seal_literal \
  "zylos-data-valkey" \
  "valkey-auth-secret" \
  "$VALKEY_PASS" \
  "components/platform/valkey/overlays/${ENV}/valkey-auth-secret.yaml"

seal_literal \
  "zylos-services" \
  "catalog-valkey-app-user" \
  "$VALKEY_PASS" \
  "components/services/zylos-service-catalog/overlays/${ENV}/catalog-valkey-secret.yaml"

echo "✅ Success!"
