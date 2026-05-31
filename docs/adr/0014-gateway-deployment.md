# ADR 0014: Gateway Deployment and In-Cluster Issuer Resolution

- **Status:** Accepted
- **Date:** 2026-05-30
- **Relates to:** ADR 0008 (service-base chart), ADR 0011/0013 (Keycloak); gateway ADR 0001–0003

## Context

The gateway is the first application service deployed to the cluster. It must
validate ingress tokens whose `iss` is `http://keycloak.zylos.local/realms/zylos`
and reach Keycloak for discovery, JWKS, and token exchange — all from inside
the cluster, where `keycloak.zylos.local` does not resolve by default.

## Decision

**Deploy via the `zylos-service-base` chart** with a per-service values file and
an Argo CD Application (dual-source `$values` pattern), consistent with every
other service. Namespace `zylos-services` (Istio ambient enrolled).

**Actuator on management port 9000.** The chart's probes and ServiceMonitor
target the management port; the gateway serves actuator there, keeping
operational endpoints off the Bearer-secured 8080 traffic port.

**External exposure via nginx ingress** at `api.zylos.local` — the API
perimeter. (The kind cluster installs nginx ingress during bootstrap.)

**Client secret via SealedSecret.** `zylos-gateway-secrets` in `zylos-services`
holds the gateway's Keycloak client secret, matching the realm's `zylos-gateway`
client secret. Synced ahead of the gateway (sync wave 19 vs 20).

**In-cluster issuer resolution via CoreDNS rewrite.** `keycloak.zylos.local`
resolves to the Keycloak Service in-cluster:

    rewrite name keycloak.zylos.local keycloak-service.keycloak.svc.cluster.local

The gateway then reaches Keycloak directly while sending `Host: keycloak.zylos.local`
(which Keycloak accepts) and the validated `iss` matches. This rewrite is
provisioned in `zylos-infra-terraform` (it owns kube-system CoreDNS), not in
this app-of-apps.

## Rationale

- **Rewrite over split frontend/backchannel hostnames.** Keycloak's
  dynamic-backchannel mode would let in-cluster clients use the Service URL, but
  Spring Security's `withIssuerLocation` validates that the discovery document's
  `issuer` equals the configured location — which breaks if the gateway calls a
  different URL than the `iss`. A DNS rewrite keeps one hostname everywhere, so
  discovery, JWKS, exchange, and `iss` validation all align with no decoder
  changes. This also unblocks every future in-cluster token-validating service.

- **Cross-namespace egress is explicit.** The chart's default `toSamePlatform`
  egress covers `zylos-services` only; an explicit `egress.extra` rule allows the
  gateway to reach the `keycloak` namespace on 8080.

- **DNS rewrite lives in terraform.** Owning kube-system's CoreDNS ConfigMap from
  the app-of-apps would fight kind's defaults and risk clobbering them on sync.
  Cluster DNS is provisioning, so it belongs with the cluster.

## Trade-offs Accepted

- **Hard dependency on the CoreDNS rewrite.** Without it the gateway can't reach
  Keycloak; readiness stays down. Documented as a prerequisite and verified
  post-merge.

- **Dev secret in the sealing script.** Acceptable for kind reproducibility;
  production uses ESO + AWS Secrets Manager.

- **No HPA in kind.** Metrics-server isn't guaranteed; autoscaling is off for
  dev and enabled per-environment in production.

## Verification

Argo CD syncs the secret (wave 19) then the gateway (wave 20); the
gateway becomes ready once it can resolve and reach Keycloak; an authenticated
request to `api.zylos.local/api/v1/hello/**` is exchanged and routed.

## References

- ADR 0008 (service-base chart), ADR 0011/0013 (Keycloak / act mapper)
- gateway ADR 0003 (token exchange)
