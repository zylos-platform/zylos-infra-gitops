#!/usr/bin/env bash
set -euo pipefail
echo "Port-forwarding Argo CD UI to http://localhost:8081"
echo "Stop with Ctrl+C."
kubectl port-forward -n argocd svc/argocd-server 8081:80
