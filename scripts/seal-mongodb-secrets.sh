#!/usr/bin/env bash
# Generates the SealedSecrets for the Catalog MongoDB application user.
# One password is sealed into multiple namespaces that must share it:
#   - mongodb        -> catalog-mongodb-app-user   (consumed by the Percona operator)
#   - kafka          -> catalog-mongodb-debezium   (consumed by the Debezium connector)
#   - zylos-services -> catalog-mongodb-app-user   (consumed by catalog service)
# Re-run after recreating the kind cluster (the sealing cert changes).
set -euo pipefail

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
seal() { # <namespace> <secret-name> <out-file>
  local ns="$1" name="$2" out="$3"
  echo "==> Sealing $name into $ns -> $out"
  kubectl create secret generic "$name" \
    --namespace "$ns" \
    --from-literal=password="$PASS" \
    --dry-run=client -o yaml \
  | kubeseal --format yaml --controller-namespace sealed-secrets \
  > "$out"
}

seal mongodb catalog-mongodb-app-user manifests/mongodb/01-sealed-secrets.yaml
seal kafka   catalog-mongodb-debezium  manifests/kafka-connect/03-mongodb-debezium-sealed-secret.yaml
seal zylos-services catalog-mongodb-app-user manifests/zylos-services/01-mongodb-app-user-sealed-secret.yaml

echo "✅ Done."
