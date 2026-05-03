#!/usr/bin/env bash
###############################################################################
# kind-down.sh — delete the entire kind cluster, releasing all memory.
###############################################################################

set -euo pipefail

if ! kind get clusters 2>/dev/null | grep -qx "zylos"; then
  echo "kind cluster 'zylos' does not exist. Nothing to do."
  exit 0
fi

kind delete cluster --name zylos
echo "✓ Cluster deleted."
