# Changelog

All notable changes to this repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this repository adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- zylos-service-hello is now an internal, gateway-only service: removed its
  direct nginx ingress, added Keycloak egress (+DNS/Istio) for token validation,
  and set ZYLOS_ISSUER_URI. Reachable only via api.zylos.local/api/v1/hello/me.
  ADR 0016.
