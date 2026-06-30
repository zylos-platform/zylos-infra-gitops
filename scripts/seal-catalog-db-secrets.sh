#!/usr/bin/env bash
# Generates environment-specific SealedSecrets for the Catalog Domain.
set -euo pipefail

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

  kubectl create secret generic "$name" \
    --namespace "$ns" \
    --from-literal=password="$pass" \
    --dry-run=client -o yaml \
  | kubeseal --format yaml --controller-namespace sealed-secrets \
  > "$filename"
}

echo "==> Generating Catalog secrets for [${ENV^^}] environment..."

# The App password for the Percona Operator (Data Namespace)
seal_secret "data" "catalog-mongodb-app-user" "$APP_PASS" "components/mongodb/overlays/${ENV}/catalog-db-app-secret.yaml"

# The App password twin for the catalog Service (Services Namespace)
seal_secret "zylos-services" "catalog-mongodb-app-user" "$APP_PASS" "components/zylos-services-secrets/overlays/${ENV}/catalog-svc-app-secret.yaml"

# The CDC password for Debezium (Data Namespace)
seal_secret "data" "catalog-mongodb-debezium" "$CDC_PASS" "components/kafka-connect/overlays/${ENV}/catalog-cdc-secret.yaml"

echo "✅ Success!"
