#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

RESOURCE_GROUP="zylos-rg"
CLUSTER_NAME="zylos"
LOCATION="eastus"

echo "==============================================="
echo "Zylos Remote AKS Cluster Bootstrap (Istio-Ready)"
echo "==============================================="

echo "==> [1/4] Creating Azure Resource Group..."
az group create --name $RESOURCE_GROUP --location $LOCATION -o none

echo "==> [2/4] Creating AKS cluster (Free Tier, 1x D4ds_v7 Node)..."
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-vm-size Standard_D4ds_v7 \
  --node-count 1 \
  --tier free \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --network-dataplane cilium \
  --generate-ssh-keys \
  --yes

echo ""
echo "==> [3/4] Connecting to AKS..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

echo ""
echo "==> [4/4] Installing Kubernetes Gateway API CRDs..."
# Istio Ambient Mesh REQUIRES these CRDs to be installed before Istio boots.
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

echo ""
echo "==> [5/5] Bootstrapping Argo CD..."
./scripts/bootstrap.sh dev

echo ""
echo "==============================================="
echo "✓ Cluster Live."
echo "==============================================="
echo "To access Argo CD, run:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "==============================================="
