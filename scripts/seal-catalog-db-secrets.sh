#!/usr/bin/env bash
# Generates environment-specific SealedSecrets for the Catalog Domain.
set -euo pipefail

cd "$(dirname "$0")/.."

# Ensure an environment parameter is passed
ENV=${1:-}
if [[ "$ENV" != "local" && "$ENV" != "dev" ]]; then
  echo "Usage: $0 <local|dev>" >&2
  echo "Example: $0 local" >&2
  exit 1
fi

# Generate strong, random passwords for this execution
APP_PASS="$(openssl rand -hex 24)"
CDC_PASS="$(openssl rand -hex 24)"

echo "==> Verifying sealed-secrets-controller in ${ENV} cluster..."
if ! kubectl -n sealed-secrets get deploy sealed-secrets-controller >/dev/null 2>&1; then
  echo "ERROR: sealed-secrets-controller not found. Ensure your kubectl context is pointed to your ${ENV} cluster." >&2
  exit 1
fi

if ! command -v kubeseal >/dev/null 2>&1; then
  echo "ERROR: kubeseal CLI not installed." >&2
  exit 1
fi

# Helper function to seal passwords into the environment directory
seal_secret() {
  local ns="$1" name="$2" pass="$3" filename="$4"
  echo "    -> Sealing $name into namespace '$ns'..."

  mkdir -p "$(dirname "$filename")"

  kubectl create secret generic "$name" \
    --namespace "$ns" \
    --from-literal=password="$pass" \
    --dry-run=client -o yaml \
  | kubeseal --format yaml --controller-namespace sealed-secrets \
  | kubectl annotate -f - --local \
      "argocd.argoproj.io/sync-wave=-40" \
      -o yaml \
  > "$filename"
}

echo "==> Generating Catalog secrets for [${ENV^^}] environment..."

# The App password for the Percona Operator (Namespace zylos-data-mongodb)
seal_secret \
  "zylos-data-mongodb" \
  "catalog-mongodb-app-user" \
  "$APP_PASS" \
  "components/platform/mongodb/overlays/${ENV}/catalog-db-app-secret.yaml"

# The CDC password for Debezium (Namespace zylos-data-mongodb)
seal_secret \
  "zylos-data-mongodb" \
  "catalog-mongodb-debezium" \
  "$CDC_PASS" \
  "components/platform/mongodb/overlays/${ENV}/catalog-cdc-secret.yaml"

# The App password twin for the catalog Service
seal_secret \
  "zylos-services" \
  "catalog-mongodb-app-user" \
  "$APP_PASS" \
  "components/services/zylos-service-catalog/overlays/${ENV}/catalog-mongodb-app-secret.yaml"

# The CDC password for Debezium
seal_secret \
  "zylos-data-kafka" \
  "catalog-mongodb-debezium" \
  "$CDC_PASS" \
  "components/platform/kafka-connect/overlays/${ENV}/catalog-cdc-secret.yaml"

echo "✅ Success!"
