# ADR 0015: Token Exchange Claim Model (act-default / audience-optional)

- **Status:** Accepted
- **Date:** 2026-06-01
- **Supersedes the mapper-placement aspects of:** ADR 0011 (Token Exchange V2),
  ADR 0013 (ActClaimMapper image attachment)
- **Relates to:** gateway ADR 0003; starter ADR 0003 

## Context

Keycloak Standard Token Exchange (V2) builds the exchanged token from the
**calling** client's protocol mappers and client scopes, not the target's; the
`audience` parameter restricts the result. Our earlier configuration attached
the ActClaimMapper directly to each service client and relied (in tests) on a
target-side audience mapper. Under V2 that places the audience mapper on the
wrong client, so the exchanged token never received `aud=zylos-internal-hello`.

## Decision

Express exchange-time claims as realm client scopes on the **calling** client:

- **`zylos-actor` — shared, DEFAULT.** Holds the ActClaimMapper, which emits
  `act` only during exchange and is otherwise a no-op. Assigned as a default
  scope to every exchange-capable client. Defined once.
- **`<target>-aud` — per-service, OPTIONAL.** One scope per callable service
  (`hello-aud`, later `order-aud`, …), each adding that service's audience.
  Assigned optional to clients permitted to call that service and requested
  per-route via `scope` at exchange time.

Per-client act mappers are removed. The target client carries **no**
self-audience mapper, so it is reachable only through an exchange.

## Rationale

- **Correctness:** mappers must be on the calling client for V2 to apply them.
- **Least privilege / downscoping:** audience is optional and per-route, so a
  base token names no internal audience; blast radius on interception is minimal.
- **DRY at scale:** the act mapper lives in one shared scope, not duplicated
  across N clients; each new service adds exactly one optional `*-aud` scope.
- **Opposite bloat profiles:** act is safe as a default (no-op off-exchange);
  audience must be optional (else every token carries it). The split follows
  from that asymmetry.

## Trade-offs

- **More scopes to manage** (one optional per service) — but each is trivial and
  the actor scope is shared.
- **Callers must request the right scope per route.** Misconfiguration fails
  safe (downstream rejects on `aud`). A **Client Policy** restricting which
  `*-aud` scopes each client may request on exchange is the planned hardening so
  downscoping is enforced at the IdP, not merely chosen by the caller.

## Verification

Apply the realm, then from an in-cluster pod: a gateway exchange with
`scope=hello-aud` yields a token with `aud=[zylos-internal-hello]` **and**
`act.client_id=zylos-gateway`; a plain gateway `client_credentials` token has
**neither**. Mirrored hermetically by `FullSliceSecurityIT` in zylos-service-hello.

## References

- Keycloak token exchange (V2): calling-client mappers; optional requester scopes
- gateway ADR 0003 (exchanger sends subject_token_type + scope)
