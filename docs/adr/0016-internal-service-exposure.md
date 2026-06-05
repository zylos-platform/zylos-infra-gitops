# ADR 0016: Internal Service Exposure (Gateway-Only)

- **Status:** Accepted
- **Date:** 2026-06-02
- **Relates to:** ADR 0014 (gateway deployment); gateway ADR 0003; hello ADR 0001

## Context

Internal services (e.g. `zylos-service-hello`) validate audience and, for
sensitive endpoints, the delegation chain (`act = zylos-gateway`). If a service
is also directly reachable via its own ingress, a caller could bypass the
gateway and reach it without an exchanged token.

## Decision

Internal services are not directly exposed. They have no external ingress and
their NetworkPolicy admits only mesh traffic (ztunnel/istio-system) and
observability scraping. External traffic enters exclusively through the gateway
at `api.zylos.local`, which performs the audience exchange. Services egress to
the `keycloak` namespace for token validation.

## Rationale

- **The chain-sensitive policy needs a closed perimeter.** Marking greeting
  `chainSensitive: [[zylos-gateway]]` only means something if there is no
  non-gateway route to the service. Removing direct ingress closes that gap at
  the network layer, defence-in-depth alongside the application-layer check.
- **Single, audited entry point.** All ingress flows through the gateway, where
  exchange, correlation, and (future) edge authorization happen.

## Trade-offs

- **No direct service access for debugging.** Use `kubectl port-forward` for
  local inspection rather than a standing ingress.
- **Ambient + NetworkPolicy coupling.** Gateway→service relies on `fromIstio`
  admitting ztunnel-tunneled traffic. If a future CNI/ambient change alters how
  source identity is presented, a same-platform ingress rule may be needed; the
  egress side already trusts `zylos-services`.

## References

- ADR 0014 (gateway deployment), gateway ADR 0003 (token exchange)
- hello ADR 0001 (security integration; chain-sensitive greeting)
