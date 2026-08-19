#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

RESOURCE_GROUP="zylos-rg"
CLUSTER_NAME="zylos"
LOCATION="eastus"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

DNS_ZONE_NAME="dev.zylos.app"
IDENTITY_NAME="cert-manager-identity"

echo "==============================================="
echo "Zylos AKS Cluster Bootstrap"
echo "==============================================="

echo "==> [1/6] Creating Azure Resource Group..."
az group create --name $RESOURCE_GROUP --location $LOCATION -o none

echo "==> [2/6] Creating Azure DNS Zone (if it doesn't exist)..."
az network dns zone create --resource-group $RESOURCE_GROUP --name $DNS_ZONE_NAME -o none

echo "==> [3/6] Creating AKS cluster..."
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-vm-size Standard_D4ds_v7 \
  --node-count 1 \
  --tier free \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --network-dataplane cilium \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --generate-ssh-keys \
  --yes

echo ""
echo "==> [4/6] Connecting to AKS..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

echo ""
echo "==> [5/6] Configuring Azure Workload Identity for cert-manager..."
# Create the Managed Identity
az identity create --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP -o none

# Get both the Client ID (for Kubernetes) and Principal ID (for Azure Role Assignment)
CLIENT_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query clientId -o tsv)
PRINCIPAL_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query principalId -o tsv)

echo "    -> Managed Identity Client ID: $CLIENT_ID"
echo "    -> Managed Identity Principal ID: $PRINCIPAL_ID"

# Grant DNS Zone Contributor role (Bypassing Graph API Lookup)
az role assignment create \
  --role "DNS Zone Contributor" \
  --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/dnszones/$DNS_ZONE_NAME" \
  -o none

# Get the AKS OIDC Issuer URL
AKS_OIDC_ISSUER=$(az aks show -n $CLUSTER_NAME -g $RESOURCE_GROUP --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create the Federated Credential binding
az identity federated-credential create \
  --name cert-manager-federated-cred \
  --identity-name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --issuer "$AKS_OIDC_ISSUER" \
  --subject "system:serviceaccount:cert-manager:cert-manager" \
  --audience "api://AzureADTokenExchange" \
  -o none

echo ""
echo "==> [6/6] Installing Kubernetes Gateway API CRDs..."
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

echo ""
echo "==============================================="
echo "✓ Cluster Live."
echo "==============================================="
