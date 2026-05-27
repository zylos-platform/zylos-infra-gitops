# Changelog

All notable changes to this repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this repository adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Keycloak image switched to `ghcr.io/zylos-platform/keycloak:26.6.1-zylos-act-0.1.0`
  — a pre-built custom image with the Zylos ActClaimMapper installed and
  `kc.sh build` baked in.
- Keycloak operator's `startOptimized` set to `true` (image is pre-built).
- Realm config: ActClaimMapper attached to the 4 service-account clients
  (zylos-mobile-bff, zylos-gateway, zylos-internal-hello, zylos-internal-caller).

### Added

- ADR 0013: Custom Keycloak image for ActClaimMapper, including operational
  notes for version bumps and verification procedure.
- Refinement section on ADR 0011 documenting the Keycloak `act` gap and its
  resolution via the custom mapper.
