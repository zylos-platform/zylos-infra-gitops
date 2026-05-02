#!/usr/bin/env bash
###############################################################################
# Lint all YAML in this repo.
# - yamllint for syntax
# - kubeconform for k8s schema validation (with CRDs registered)
###############################################################################

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v yamllint &>/dev/null; then
  echo "yamllint required. Install: pip install yamllint"
  exit 1
fi

echo "==> yamllint..."
yamllint -c .yamllint.yaml argocd/ helm-values/ manifests/

echo "==> kubeconform..."
if ! command -v kubeconform &>/dev/null; then
  echo "kubeconform not installed; skipping schema validation."
  echo "Install: https://github.com/yannh/kubeconform/releases"
else
  kubeconform -strict -ignore-missing-schemas \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
    argocd/ manifests/
fi

echo "✓ Lint passed."
