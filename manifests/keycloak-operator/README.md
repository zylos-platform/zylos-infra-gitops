# Keycloak Operator Manifests

Pinned to **v26.6.1**, sourced from upstream:
<https://github.com/keycloak/keycloak-k8s-resources/tree/26.6.1/kubernetes>

Rather than fetch at sync-time (network-dependent, reproducibility risk), we
commit the rendered manifests here. Argo CD applies all three via the
directory source.

## Files in This Directory

| File                       | Source upstream                                | Purpose                                              |
| -------------------------- | ---------------------------------------------- | ---------------------------------------------------- |
| `01-crd-keycloaks.yaml`    | `keycloaks.k8s.keycloak.org-v1.yml`            | CRD: `Keycloak` (server instance)                    |
| `02-crd-realmimports.yaml` | `keycloakrealmimports.k8s.keycloak.org-v1.yml` | CRD: `KeycloakRealmImport` (declarative realm shell) |
| `03-operator.yaml`         | `kubernetes.yml`                               | Operator Deployment + RBAC                           |

The CRDs serve **v2beta1 only** as of v26.6.1. The previous `v2alpha1` is
removed; manifests using it must be migrated.

## Updating to a New Operator Version

```bash
VERSION=26.6.1   # set to the target
BASE=https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/${VERSION}/kubernetes

curl ${BASE}/keycloaks.k8s.keycloak.org-v1.yml          > 01-crd-keycloaks.yaml
curl ${BASE}/keycloakrealmimports.k8s.keycloak.org-v1.yml > 02-crd-realmimports.yaml
curl ${BASE}/kubernetes.yml                              > 03-operator.yaml
```

After updating, verify the served `versions` in each CRD; if `v2alpha1` is
also dropped you may need to migrate downstream resources accordingly.
