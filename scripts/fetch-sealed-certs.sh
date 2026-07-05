#!/usr/bin/env bash
# Fetches the public certificate from the Sealed Secrets controller for offline sealing.
set -euo pipefail

# Ensure an environment parameter is passed
ENV=${1:-}
if [[ "$ENV" != "local" && "$ENV" != "dev" ]]; then
  echo "Usage: $0 <local|dev>" >&2
  echo "Example: $0 local" >&2
  exit 1
fi

# Define path configurations
CERT_DIR="infra/certs"
CERT_FILE="${CERT_DIR}/pub-cert-${ENV}.pem"

# Controller configuration
CONTROLLER_NAME="sealed-secrets-controller"
CONTROLLER_NS="sealed-secrets"

echo "==> Verifying sealed-secrets-controller in ${ENV} cluster..."

# Verify kubectl can reach the cluster and the controller deployment exists
if ! kubectl -n "$CONTROLLER_NS" get deploy "$CONTROLLER_NAME" >/dev/null 2>&1; then
  echo "ERROR: sealed-secrets-controller not found. Ensure your kubectl context is pointed to your ${ENV} cluster." >&2
  exit 1
fi

if ! command -v kubeseal >/dev/null 2>&1; then
  echo "ERROR: kubeseal CLI is not installed locally." >&2
  exit 1
fi

# Ensure target directory exists
mkdir -p "$CERT_DIR"

echo "==> Fetching public certificate..."
if kubeseal --fetch-cert \
  --controller-name="$CONTROLLER_NAME" \
  --controller-namespace="$CONTROLLER_NS" \
  > "$CERT_FILE"; then

  echo "✅ Success! Public certificate stored at: $CERT_FILE"
else
  echo "ERROR: Failed to fetch certificate from the controller." >&2
  exit 1
fi
