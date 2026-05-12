# ADR 0011: RFC 8693 Token Exchange (V2) for Audience Downscoping

- **Status:** Accepted
- **Date:** 2026-05-10
- **Relates to:** ADR 0010

## Context

The security architecture mandates **audience downscoping**:
each hop in a service call chain holds a token bound to its own audience.
Service B receives a token with `aud=zylos-B`, never one with `aud=zylos-A`.
This is enforced by strict `aud == self` validation at every hop and
ensures a stolen token cannot be replayed laterally.

RFC 8693 Token Exchange provides the mechanism: at each hop, the caller
exchanges its inbound token for one with the next target's audience.

Keycloak supports two token-exchange implementations:

- **V1 (legacy):** Configured via fine-grained admin permissions (FGAP) on
  each target client. Authorization controlled by per-client permission
  policies. Requires `--features=admin-fine-grained-authz,token-exchange`.
- **V2 (standard):** Configured per requester-client via the
  `oauth2.token.exchange.grant.enabled` attribute. Authorization via realm
  Client Policies (optional; default allows any audience). Built-in to
  Keycloak 26.2+; no feature flag.

## Decision

Use **V2 Standard Token Exchange exclusively.** All six clients
enable per-client token exchange via:

```yaml
attributes:
  oauth2.token.exchange.grant.enabled: "true"
```

V1 feature flags are **removed** from the Keycloak CR.

**no realm Client Policies are configured for token-exchange
restriction.** Any client with the V2 toggle on can request exchange to
any audience. Defense relies on:

1. Strict `aud == self` validation at every hop.
2. The `act` claim chain validation in services.

Client Policy restrictions on source→target combinations are **deferred**
to a later phase as defense-in-depth.

## Rationale

- **V2 is the strategic direction.** Keycloak documentation states V2 is
  the future; V1 is preview/legacy.
- **V2 uses a per-client toggle, not realm-level permissions.** Simpler
  configuration; each client owns its own ability to request exchange.
- **aud-validation at every hop is the primary control.** Even with
  unrestricted exchange in Keycloak, a token issued for `aud=zylos-A`
  will be rejected by anything that isn't `zylos-A`. The exchange
  permission graph in Keycloak is a secondary defense layer; we accept
  deferring it for Phase 1.

## Trade-offs Accepted

- **No graph-level enforcement.** A compromised confidential
  client (with its secret leaked) could request any audience. Mitigated
  by aud-validation at the next hop and the `act` chain audit signal.
  Client secrets are managed via sealed-secrets / ESO, with rotation
  procedures documented separately.
- **Keycloak-config-cli image version skew.** The CLI we use is built
  against KC 26.5.4; our Keycloak is 26.6.1. V2 token exchange schema is
  stable across this skew. Documented in ADR 0009.

## Forward Path

When Client Policies are added:

```yaml
clientPolicies:
  profiles:
    - name: token-exchange-zylos
      executors:
        - executor: confidential-client
        - executor: token-exchange-permission
          configuration:
            allowed-target-audiences:
              - "zylos-gateway"
              - "zylos-internal-*"
  policies:
    - name: gateway-can-exchange
      conditions:
        - condition: client-roles
          configuration:
            roles: ["zylos-gateway"]
      profiles:
        - token-exchange-zylos
```

## References

- RFC 8693: <https://datatracker.ietf.org/doc/html/rfc8693>
- Keycloak V2 token exchange: <https://www.keycloak.org/securing-apps/token-exchange>
