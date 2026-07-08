#!/usr/bin/env bash
# Generates environment-specific SealedSecrets for the OpenSearch Domain.
set -euo pipefail

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
  ADMIN_PASS="admin"
  APP_PASS="catalog"
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

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running. Required to generate OpenSearch bcrypt hashes." >&2
  exit 1
fi

# Uses the official OpenSearch image to generate the hash, and a strict regex
# to extract ONLY the bcrypt hash string.
hash_password() {
  local pass="$1"
  docker run --rm -i opensearchproject/opensearch:latest \
    /usr/share/opensearch/plugins/opensearch-security/tools/hash.sh -p "$pass" 2>/dev/null \
    | grep -Eo '\$2[ayb]\$[0-9]{2}\$[./A-Za-z0-9]{53}' | head -n 1
}

echo "==> Generating Bcrypt hashes (this takes a few seconds)..."
ADMIN_HASH=$(hash_password "$ADMIN_PASS")
APP_HASH=$(hash_password "$APP_PASS")

if [[ -z "$ADMIN_HASH" || -z "$APP_HASH" ]]; then
  echo "ERROR: Failed to generate bcrypt hashes." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Generate internal_users.yml
# -----------------------------------------------------------------------------
INTERNAL_USERS_FILE=$(mktemp)
trap 'rm -f "$INTERNAL_USERS_FILE"' EXIT

cat <<EOF > "$INTERNAL_USERS_FILE"
_meta:
  type: "internalusers"
  config_version: 2

admin:
  hash: "${ADMIN_HASH}"
  reserved: true
  backend_roles:
  - "admin"
  description: "Cluster Admin"

catalog_service:
  hash: "${APP_HASH}"
  reserved: false
  backend_roles:
  - "kibana_user"
  description: "Service account for catalog microservice"
EOF

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
  | kubectl annotate -f - --local "argocd.argoproj.io/hook=PreSync" -o yaml \
  > "$filename"
}

seal_file() {
  local ns="$1" name="$2" key="$3" filepath="$4" filename="$5"
  echo "    -> Sealing config file '$name' into namespace '$ns'..."

  mkdir -p "$(dirname "$filename")"

  kubectl create secret generic "$name" \
    --namespace "$ns" \
    --from-file="${key}=${filepath}" \
    --dry-run=client -o yaml \
  | kubeseal --format yaml --controller-namespace sealed-secrets \
  | kubectl annotate -f - --local "argocd.argoproj.io/hook=PreSync" -o yaml \
  > "$filename"
}

echo "==> Generating OpenSearch secrets for [${ENV^^}] environment..."

# The Hashed Users File (For the OpenSearch Helm Chart core config)
seal_file \
  "zylos-data-opensearch" \
  "opensearch-internal-users" \
  "internal_users.yml" \
  "$INTERNAL_USERS_FILE" \
  "components/platform/opensearch/overlays/${ENV}/opensearch-internal-users-secret.yaml"

# The Raw Admin Password (For the Argo CD Bootstrap Job)
seal_literal \
  "zylos-data-opensearch" \
  "opensearch-admin-credentials" \
  "$ADMIN_PASS" \
  "components/platform/opensearch/overlays/${ENV}/opensearch-admin-secret.yaml"

# The Raw App Password (For the Catalog Service to authenticate)
seal_literal \
  "zylos-services" \
  "catalog-opensearch-app-user" \
  "$APP_PASS" \
  "components/services/zylos-service-catalog/overlays/${ENV}/catalog-opensearch-secret.yaml"

echo "✅ Success!"
