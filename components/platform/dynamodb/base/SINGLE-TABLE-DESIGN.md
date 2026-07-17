# `zylos-cart` — Single-Table Design

This document is the **source of truth** for the Cart DynamoDB table. There is
no Terraform yet (local/dev only); `cart-table-bootstrap-configmap.yaml`'s
`zylos-cart-table.json` is this design executed via the CreateTable API — the
same shape prod IaC will submit later. See `zylos-service-cart` ADR-0001.

## Table

- **Name:** `zylos-cart`
- **Billing:** on-demand (`PAY_PER_REQUEST`)
- **Primary key:** `PK` (partition, S) + `SK` (sort, S)
- **TTL attribute:** `expiresAt` (Number, epoch seconds) — **backstop only**;
  the reaper performs authoritative expiry (emits `CartExpired` through the
  outbox, then deletes), because DynamoDB TTL deletion is silent under the
  relay-based outbox (no Streams).

## Item collections

| Entity                    | PK                     | SK                     | Notes                                                                                                                                                                                                    |
|---------------------------|------------------------|------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Cart** (aggregate root) | `CART#<cartId>`        | `CART#<cartId>`        | Single item; `lines` embedded as a List attribute (bounded ≤100, well under the 400 KB item limit). Embedding is required so the whole aggregate is written under one conditional-write `version` guard. |
| **Outbox record**         | `OUTBOX#<shardId>`     | `<outboxId>` (UUIDv7)  | Written in the **same** `TransactWriteItems` as the Cart item. `shardId = hash(cartId) % N` keeps per-cart ordering; UUIDv7 SK gives chronological drain order within a shard.                           |
| **Relay lease**           | `RELAYLEASE#<shardId>` | `RELAYLEASE#<shardId>` | One drainer per shard at a time, claimed via conditional write with a TTL lease (`leaseExpiresAt`) — preserves ordering.                                                                                 |
| **Idempotency**           | `IDEM#<key>`           | `IDEM#<key>`           | `requestFingerprint` (subject+path+bodyHash) + stored response; `expiresAt` = +24h. Conditional put to claim.                                                                                            |
| **Merge marker**          | `MERGE#<guestCartId>`  | `MERGE#<guestCartId>`  | Idempotent guest→customer merge; `targetCartId`; short TTL.                                                                                                                                              |

## Global secondary indexes

| Index           | GSI1PK / GSI2PK                     | GSI1SK / GSI2SK        | Projection | Serves                                                                                                                                                                                   |
|-----------------|-------------------------------------|------------------------|------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **GSI1-owner**  | `OWNER#<ownerType>#<ownerId>`       | `CART#<cartId>`        | KEYS_ONLY  | "Find this owner's cart" — login active-cart lookup and guest→customer merge. Sparse: only Cart items set `GSI1PK`. Rare path, so KEYS_ONLY + `GetItem` beats projecting the whole cart. |
| **GSI2-expiry** | `EXP#<bucket>` (sharded epoch-hour) | `<expiresAt>#<cartId>` | KEYS_ONLY  | Reaper sweep of expiring carts (Phase 3.8). Sharded bucket PK avoids a hot partition. Sparse: only Cart items set `GSI2PK`.                                                              |

## Access patterns

1. **Get cart by id** (hot path; also internal `GetCart` gRPC): `GetItem PK=CART#<id>, SK=CART#<id>`.
2. **Mutate cart + publish event** (atomic): `TransactWriteItems` = conditional
   `Put` of the Cart item on `version` + `Put` of the Outbox record.
3. **Owner's active cart / merge**: `Query GSI1-owner` → `GetItem`.
4. **Idempotency check**: `GetItem PK=IDEM#<key>` / conditional `Put`.
5. **Relay drain**: claim `RELAYLEASE#<shard>` → `Query PK=OUTBOX#<shard>` ascending → publish (fan-out to both
   topics) → delete.
6. **Expiry sweep**: `Query GSI2-expiry` for buckets ≤ now (dev may parallel-scan instead).

## Outbox → topic fan-out

One outbox record per state change. The relay publishes each record to **both**
`cart.cart.events.v1` (always) and `cart.cart.snapshot.v1` (full state, or a
null-value **tombstone** on `CartConverted`/`CartExpired`). Both carry
`CartEvent`. Per-key ordering is preserved by shard affinity on `cartId`.

## Prod translation (deferred, not designed-away)

When IaC returns, the CreateTable JSON gains: `SSESpecification` (KMS envelope
encryption), point-in-time recovery, deletion protection, resource tags, and
RF/throughput left implicit under on-demand. The **key schema, GSIs, and TTL
attribute do not change** — that is the whole point of pinning them here.
