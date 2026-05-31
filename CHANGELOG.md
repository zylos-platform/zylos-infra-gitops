# Changelog

All notable changes to this repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this repository adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Initial `zylos-infra-gateway` Argo CD application and corresponding Helm values for deployment based on the
  `zylos-service-base` pattern.
- Ingress support for `api.zylos.local` external exposure of the gateway via nginx ingress.
- `zylos-services-secrets` Argo CD application for managing sealed secrets within the `zylos-services` namespace.
- `seal-zylos-services-secrets.sh` script to generate gateway's Keycloak client credentials.
- Gateway's development client credentials provisioned automatically as a SealedSecret.
- ADR 0014 documenting the Gateway deployment, including in-cluster issuer resolution with CoreDNS.
- Added references to ADR 0013 and ADR 0014 in the docs README.
