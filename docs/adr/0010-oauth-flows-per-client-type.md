# ADR 0010: OAuth 2.1 Flow Selection per Client Type

- **Status:** Accepted
- **Date:** 2026-05-10
- **Relates to:** ADR 0011

## Context

OAuth 2.1 defines several grant types; choosing the right grant
per client type is the single most consequential authentication-design decision.

OAuth 2.1 (the consolidated successor to 2.0) forbids the Implicit and
ROPC (Resource Owner Password Credentials) grants and mandates PKCE for
all Authorization Code flows.

## Decision

| Client                  | Type         | Grant                               | Notes                                            |
| ----------------------- | ------------ | ----------------------------------- | ------------------------------------------------ |
| `zylos-web-storefront`  | Confidential | Authorization Code + PKCE           | Next.js BFF; server-side token storage           |
| `zylos-web-admin`       | Confidential | Authorization Code + PKCE           | Internal admin console; same shape as storefront |
| `zylos-mobile-bff`      | Confidential | Token Exchange (RFC 8693)           | Receives mobile tokens; downscopes for gateway   |
| `zylos-gateway`         | Confidential | Token Exchange (RFC 8693)           | Cluster perimeter; downscopes per service        |
| `zylos-internal-hello`  | Confidential | Client Credentials + Token Exchange | Service identity for pure S2S and delegated S2S  |
| `zylos-internal-caller` | Confidential | Client Credentials + Token Exchange | Stub service for `act` chain testing             |

Per the architecture:

- Browser clients: Auth Code + PKCE on a **confidential** server-side BFF.
  No tokens reach the browser; only an opaque session cookie.
- Mobile clients: Auth Code + PKCE on the **public** mobile app via the
  system browser, tokens in native secure storage. Mobile app is defined
  but not deployed; mobile-bff is the in-cluster receiver.
- Service-to-service: Client Credentials for pure M2M; Token Exchange
  (RFC 8693) for delegated S2S preserving user context.

## Rationale

- **Confidential storefront BFF.** Next.js BFF is a
  confidential client; the browser holds only an opaque session ID, the
  server holds tokens in Redis (PR scope outside this ADR).
- **PKCE everywhere, even for confidential clients.** OAuth 2.1 mandates
  it; it's a no-op for confidential clients but defends against any
  future migration to public-client posture.
- **No ROPC, no Implicit.** Forbidden by OAuth 2.1 and explicitly disabled
  per-client via `directAccessGrantsEnabled: false` and
  `implicitFlowEnabled: false`.
- **`fullScopeAllowed: false`** on every client. Scopes are explicit;
  clients never inherit the realm's full scope set.

## Trade-offs Accepted

- **Mobile-side complexity not addressed.** The mobile app
  itself is out of scope. Its OAuth integration will be defined when the
  mobile workstream begins; mobile-bff is ready to receive `aud=zylos-mobile-bff`
  tokens whenever the mobile app starts producing them.
- **No social IdP federation.**

## References

- OAuth 2.1 draft: <https://datatracker.ietf.org/doc/draft-ietf-oauth-v2-1/>
