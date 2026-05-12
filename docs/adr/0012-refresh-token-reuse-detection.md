# ADR 0012: Refresh Token Reuse Detection

- **Status:** Accepted
- **Date:** 2026-05-10

## Context

Refresh tokens are long-lived (30-day sliding window)
and high-value: a stolen refresh token allows an attacker to obtain
access tokens for as long as the refresh remains valid. Standard rotation
(issue a new refresh token on each use, invalidate the old one) defeats
_future_ uses of a stolen token but doesn't detect _past_ theft.

Refresh-token reuse detection adds the missing signal: if a refresh
token is presented after its successor has been issued, the entire token
family is revoked. The attacker holding a stolen earlier refresh token
triggers full session destruction the moment they (or the legitimate
user) attempt to use it.

## Decision

Enable at the realm level in `zylos-realm.yaml`:

```yaml
revokeRefreshToken: true
refreshTokenMaxReuse: 0
```

- `revokeRefreshToken: true` — refresh tokens are single-use; a new one
  is issued on each refresh.
- `refreshTokenMaxReuse: 0` — zero re-uses permitted. Any reuse triggers
  family revocation.

## Rationale

- **Detects stolen refresh tokens, not just future-prevents them.** A
  stolen refresh token's first reuse attempt (after the legitimate user
  has refreshed) destroys the entire session — the legitimate user must
  re-authenticate, and the attacker loses access.
- **Zero false-positive risk in normal use.** Legitimate clients refresh
  exactly once per refresh token; reuse is genuinely anomalous.
- **Integrates with Web BFF revocation flow.** The Next.js BFF
  catches Keycloak's `invalid_grant` response on reuse
  detection and immediately destroys the Redis session, forcing
  re-authentication.

## Trade-offs Accepted

- **Concurrent refresh requests can trigger false revocation.** If the
  client makes two simultaneous refresh requests with the same refresh
  token (e.g., two browser tabs refreshing at the same instant), one
  succeeds and the second is interpreted as reuse. The BFF must
  serialize refresh attempts — handled by the Next.js refresh middleware
  (PR scope outside this ADR).
- **Network blip during refresh requires re-authentication.** If a
  refresh succeeds at Keycloak but the response is lost, the client
  retries with the original (now-invalidated) refresh token; reuse
  detection fires; session is destroyed. The user re-authenticates.
  Acceptable trade-off for detection capability.

## Observability

Reuse detection events emit Keycloak audit events of type
`REFRESH_TOKEN_REUSE`. These flow through the audit pipeline
to OpenSearch. Alertmanager rules from architecture alert on
non-baseline reuse-detection counts; any non-zero count
over baseline warrants investigation.

## References

- Keycloak refresh-token settings: <https://www.keycloak.org/docs/latest/server_admin/#refresh_token>
