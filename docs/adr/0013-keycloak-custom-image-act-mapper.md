# ADR 0013: Custom Keycloak Image for ActClaimMapper

- **Status:** Accepted
- **Date:** 2026-05-27
- **Relates to:** ADR 0011 (RFC 8693 Token Exchange V2)
- **Supersedes:** Original ADR 0011's implicit assumption of native `act` support

## Context

The Architecture (and now the refinement) relies on the RFC 8693 `act` claim being present on every
exchanged token. The starter's `ActorChainEvaluator` extracts this claim; the `actor-chains.yaml`-driven
`AuthorizationManager` matches it against permitted chains for sensitive endpoints.

PR through all shipped assuming Keycloak would populate `act`. During integration test
development, this assumption was tested directly against real Keycloak 26.6.1: **the `act` claim does not appear on
tokens produced by V2 Standard Token Exchange.** Upstream
issue [keycloak/keycloak#38279](https://github.com/keycloak/keycloak/issues/38279) tracks this — as of March 2025 it
remains open.

Without `act`, every chain-sensitive endpoint would reject every request under `allowEmptyChain: false` — a self-DoS.
The platform needs `act` populated before `zylos-service-secured-hello` consumes the starter against the
real cluster's Keycloak.

## Decision

Ship a **custom Keycloak image** containing the Zylos ActClaimMapper protocol mapper, built and published from a
dedicated repo (`zylos-infra-keycloak-extensions`).

### Image: `ghcr.io/zylos-platform/keycloak:26.6.1-zylos-act-{version}`

- Base: `quay.io/keycloak/keycloak:26.6.1` (the same base we previously used directly)
- Layered: the `zylos-keycloak-extensions-{version}.jar` provider in `/opt/keycloak/providers/`
- Pre-built: `kc.sh build` runs in the builder stage so `start --optimized` works at runtime (~5s startup vs ~30s for
  `start-dev`)
- Multi-arch: linux/amd64, linux/arm64

The Keycloak Operator's `spec.image` field references this image; `spec.startOptimized: true` because the image is
pre-built.

### Mapper attachment

The ActClaimMapper is attached via `protocolMappers` on each client that can be the target of a token exchange. In Phase
1 these are the 4 clients with `serviceAccountsEnabled: true`:

| Client                  | Role                        | Mapper attached              |
|-------------------------|-----------------------------|------------------------------|
| `zylos-mobile-bff`      | Mobile BFF service identity | ✓                            |
| `zylos-gateway`         | Spring Cloud Gateway        | ✓                            |
| `zylos-internal-hello`  | Reference internal service  | ✓                            |
| `zylos-internal-caller` | Test/stub internal service  | ✓                            |
| `zylos-web-storefront`  | Customer-facing BFF         | ✗ (never an exchange target) |
| `zylos-web-admin`       | Admin console BFF           | ✗ (never an exchange target) |

Each mapper is configured to populate the **access token only** — not the ID token (no semantic meaning for a delegation
chain) and not UserInfo (not relevant to service-to-service flow). Configuration:

```yaml
protocolMappers:
  - name: zylos-act-claim
    protocol: openid-connect
    protocolMapper: zylos-act-claim-mapper
    consentRequired: false
    config:
      access.token.claim: "true"
      id.token.claim: "false"
      userinfo.token.claim: "false"
```

The mapper has no other configuration — its behavior is fixed (detect exchange flow, write `act.client_id`).

## Rationale

### Why a custom image over a JAR-mount initContainer

A common alternative is to mount the provider JAR via an initContainer that copies it into the Keycloak pod at startup.
The trade-offs:

| Approach                  | Startup time                                   | Build pipeline                               | Operator support                              | Decision |
|---------------------------|------------------------------------------------|----------------------------------------------|-----------------------------------------------|----------|
| **Custom image (chosen)** | ~5s (`--optimized`)                            | Build once on release; image cached on nodes | `spec.image` is first-class                   | ✓        |
| InitContainer + JAR mount | ~30s (`start-dev` rebuilds at every pod start) | No image build needed                        | Requires `unsupported.podTemplate` workaround | ✗        |

For production grade — which Zylos targets even
as a learning vehicle — the custom image is the standard pattern. Faster pod startup matters for HPA scale-up and node
failure recovery; the image build pipeline is a one-time setup.

### Why ship the mapper from a separate repo

The ActClaimMapper:

- Compiles to Java 21 bytecode (Keycloak's Quarkus runtime), not Java 25 (Zylos Spring services)
- Uses Keycloak SPI (`AbstractOIDCProtocolMapper`), not Spring
- Has a release cadence tied to Keycloak versions, not Zylos services
- Is consumed via a Docker image, not a Maven dependency

These differences justify a separate repo (`zylos-infra-keycloak-extensions`) with its own POM, its own CI, its own
release process. This keeps `zylos-infra-gitops` focused on cluster manifests and `zylos-infra-security-starter` focused
on Spring Boot.

### Why attach the mapper only to the 4 service-account clients

The mapper is a no-op when the requesting client equals the target client (e.g., on a direct client_credentials grant).
Attaching it everywhere would be harmless but adds churn to the realm config for clients (the customer-facing BFFs) that
can never be targets of exchange.

The 4 clients with `serviceAccountsEnabled: true` are precisely the set that can be exchange targets. Documenting this
attachment pattern (in CONTRIBUTING and the realm config comments) gives future services a clear rule: **if your client
has `serviceAccountsEnabled: true`, attach the act-claim mapper.**

## Trade-offs Accepted

### Single-hop chains only

The mapper records only the immediate requesting client. A token exchanged twice — first by gateway, then by an
intermediate service — loses the gateway from its `act` claim. Only the most recent actor is preserved.

**Under the model this is acceptable** because chain-sensitive endpoints typically care about the immediate
caller, and audit material for full call paths comes from distributed traces (traceId/spanId in MDC via the starter).

If multi-hop chain preservation becomes required, the upgrade path is: replace the protocol mapper with a custom
`TokenExchangeProvider` SPI implementation (which has access to the subject_token's existing `act` claim and can chain
recursively). The Spring side already handles nested chains correctly — no client-side changes needed.

### Custom image maintenance burden

We now own a Docker image. Concerns:

- **Base image security updates** — when Keycloak 26.6.2/26.7 ships with security patches, we must rebuild. Mitigated by
  CI rebuilding nightly against the latest 26.6.x tag; CVE scanning catches missed updates.
- **Provider compatibility** — Keycloak's internal SPI is private. A future Keycloak version could break our mapper.
  Mitigated by the integration test in `zylos-infra-keycloak-extensions` running against the pinned version; bumping
  requires running the suite.
- **Image size** — the multi-stage Dockerfile's final image is ~510 MB. Vanilla Keycloak is ~480 MB. The 30 MB delta is
  acceptable.

### Image registry dependency

The cluster now depends on GHCR being reachable. Mitigations:

- For kind dev clusters: image is pulled once during bootstrap; cached locally
- For prod: image should be mirrored to the cluster's preferred registry (deferred to production deployment ADR)

### V2 vs V1 token exchange

We continue using V2 Standard Token Exchange (per ADR 0011). The mapper works with V2 specifically because V2 fires
protocol mappers on the exchanged token. V1's separate code path may not work the same way; if we ever needed V1 we'd
need to verify. This is deferred — V1 is legacy and slated for removal upstream.

## Operational Notes

### Bumping the mapper version

When `zylos-infra-keycloak-extensions` releases a new version:

1. The release triggers `publish.yaml` to publish `ghcr.io/zylos-platform/keycloak:26.6.1-zylos-act-{new-version}`
2. Open a PR in `zylos-infra-gitops` updating `manifests/keycloak/02-keycloak.yaml` `spec.image`
3. Argo CD detects the change; rolls the Keycloak Statefulset
4. Validation: run the security-starter integration test suite against the cluster

### Bumping the Keycloak version

1. Update `zylos-infra-keycloak-extensions/Dockerfile` build arg `KEYCLOAK_VERSION`
2. Update `zylos-infra-keycloak-extensions/pom.xml` `keycloak.version` property
3. Run integration tests; address any SPI breaking changes
4. Release; then bump the GitOps image reference

Keycloak's SPI is stable across minor versions; only major bumps (26.x → 27.x) typically require code changes.

### Verifying the mapper is active

After deployment, verify via curl + JWT inspection:

```bash
# Exchange a token and inspect the result
GATEWAY_TOKEN=$(curl -s -X POST "$KC/realms/zylos/protocol/openid-connect/token" \
  -d "grant_type=client_credentials&client_id=zylos-gateway&client_secret=$SECRET" \
  | jq -r .access_token)

EXCHANGED=$(curl -s -X POST "$KC/realms/zylos/protocol/openid-connect/token" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange&client_id=zylos-gateway&client_secret=$SECRET&subject_token=$GATEWAY_TOKEN&subject_token_type=urn:ietf:params:oauth:token-type:access_token&audience=zylos-internal-hello" \
  | jq -r .access_token)

echo "$EXCHANGED" | cut -d. -f2 | base64 -d 2>/dev/null | jq .act
# Expected: { "client_id": "zylos-gateway" }
```

This is also automated by the security-starter's `ActorChainIntegrationIT` running against this cluster.

## References

- ADR 0011: RFC 8693 Token Exchange V2 (refined by this ADR)
- `zylos-infra-keycloak-extensions/docs/adr/0001-act-claim-mapper-design.md`
- Keycloak issue #38279: <https://github.com/keycloak/keycloak/issues/38279>
- Keycloak server containers guide: <https://www.keycloak.org/server/containers>
- Architectural pivot (Sub-phase 1.2 retrospective in conversation)
