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
  CATALOG_VALKEY_PASS="catalog_valkey_local_pass_2026"
  CART_VALKEY_PASS="cart_valkey_local_pass_2026"
else
  echo "==> Generating strong distinct random credentials for ${ENV} environment..."
  CATALOG_VALKEY_PASS="$(openssl rand -hex 24)"
  CART_VALKEY_PASS="$(openssl rand -hex 24)"

  echo "[!] DEV Catalog Valkey Password: ${CATALOG_VALKEY_PASS}"
  echo "[!] DEV Cart Valkey Password:    ${CART_VALKEY_PASS}"
fi

# Helper function for sealing
seal_valkey_secret() {
  local ns="$1" name="$2" pass="$3" filename="$4"
  echo "    -> Sealing '$name' into namespace '$ns'..."

  # Ensure the target directory exists before writing
  mkdir -p "$(dirname "$filename")"

  kubectl create secret generic "$name" \
    --namespace "$ns" \
    --from-literal=valkey-password="$pass" \
    --dry-run=client -o yaml \
  | kubeseal --format yaml --controller-namespace sealed-secrets \
  | kubectl annotate -f - --local "argocd.argoproj.io/sync-wave=-40" -o yaml \
  > "$filename"
}

echo "==> Generating Valkey secrets for [${ENV^^}] environment..."

# Catalog Service Valkey Secret
seal_valkey_secret \
  "zylos-catalog" \
  "catalog-valkey-secret" \
  "$CATALOG_VALKEY_PASS" \
  "components/services/zylos-service-catalog/overlays/${ENV}/catalog-valkey-secret.yaml"

# Cart Service Valkey Secret
seal_valkey_secret \
  "zylos-cart" \
  "cart-valkey-secret" \
  "$CART_VALKEY_PASS" \
  "components/services/zylos-service-cart/overlays/${ENV}/cart-valkey-secret.yaml"

echo "✅ Success!"
