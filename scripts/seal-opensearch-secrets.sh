#!/usr/bin/env bash
# Generates environment-specific SealedSecrets for the OpenSearch Domain.
set -euo pipefail

cd "$(dirname "$0")/.."

# Ensure an environment parameter is passed
ENV=${1:-}
if [[ "$ENV" != "local" && "$ENV" != "dev" ]]; then
  echo "Usage: $0 <local|dev>" >&2
  echo "Example: $0 local" >&2
  exit 1
fi

# Differentiate local (stable) vs dev (random) credentials
if [[ "$ENV" == "local" ]]; then
  echo "==> Using stable reproducible credentials for ${ENV} environment..."
  ADMIN_PASS="ZylosPlatform@123!"
  APP_PASS="LocalCatalog@123!"
else
  echo "==> Generating strong random credentials for ${ENV} environment..."
  ADMIN_PASS="$(openssl rand -hex 16)"
  APP_PASS="$(openssl rand -hex 16)"

  echo "[!] DEV Admin Password generated: ${ADMIN_PASS}"
  echo "[!] DEV Catalog App Password generated: ${APP_PASS}"
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

# -----------------------------------------------------------------------------
# Sealing Helpers
# -----------------------------------------------------------------------------
seal_literal() {
  local ns="$1" name="$2" pass="$3" filename="$4"
  echo "    -> Sealing raw password '$name' into namespace '$ns'..."

  mkdir -p "$(dirname "$filename")"

  kubectl create secret generic "$name" \
    --namespace "$ns" \
    --from-literal=password="$pass" \
    --dry-run=client -o yaml \
  | kubeseal --format yaml --controller-namespace sealed-secrets \
  | kubectl annotate -f - --local "argocd.argoproj.io/sync-wave=-40" -o yaml \
  > "$filename"
}

echo "==> Generating OpenSearch secrets for [${ENV^^}] environment..."

# The Raw Admin Password (For the Argo CD Bootstrap Job)
seal_literal \
  "zylos-data-opensearch" \
  "opensearch-admin-credentials" \
  "$ADMIN_PASS" \
  "components/platform/opensearch/overlays/${ENV}/opensearch-admin-secret.yaml"

seal_literal \
  "zylos-data-opensearch" \
  "catalog-opensearch-app-user" \
  "$APP_PASS" \
  "components/platform/opensearch/overlays/${ENV}/catalog-opensearch-app-secret.yaml"

# The Raw App Password (For the Catalog Service to authenticate)
seal_literal \
  "zylos-services" \
  "catalog-opensearch-app-user" \
  "$APP_PASS" \
  "components/services/zylos-service-catalog/overlays/${ENV}/catalog-opensearch-secret.yaml"

echo "✅ Success!"
