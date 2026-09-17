# LifeTrace Assets Architecture V1

## 1. Architectural goal

LifeTrace Assets V1 is a local-first asset lifecycle application. The network is an optional replication channel, not a prerequisite for core CRUD, lifecycle history, analytics, reminders, or backup.

Assets v1 is archived. The active implementation change is openspec/changes/implement-asset-entity-links-v1.

## 2. Layers

### UI

lib/main.dart contains the current screen/widget composition and delegates stateful business operations to AssetAppState. Widgets do not open databases or invoke Cloud HTTP endpoints directly.

### Application

lib/src/application/asset_app_state.dart owns application-visible state:

- assets, lifecycle events, and persisted EntityLinks
- loading/error state
- pending sync count
- Cloud session and sync progress
- persisted conflicts
- backup/reset commands

### Domain

lib/src/domain/asset_models.dart defines AssetItem, AssetEvent, AssetEntityLink, AssetCategory, AssetStatus, AssetEventType, SyncOutboxItem, and AssetSyncConflict. AssetEntityLink converts its local flattened representation to the generic LifeTrace Cloud EntityLink wire shape.

Server versions are modeled as opaque strings to match LifeTrace Sync v1.

### Data

lib/src/data/asset_repository.dart is the transaction boundary. It owns asset/event/link CRUD, lifecycle aggregation, soft-delete/tombstone preparation, outbox creation, cursor/snapshot state, conflict persistence, accepted-change rebase, and backup import/export.

Storage adapters live under lib/src/data/local_database_*.dart:

- native/Android: Sembast file under application support storage
- Web: Sembast Web / IndexedDB
- tests: in-memory Sembast

## 3. Asset calculations

~~~text
effectiveCost = max(0, purchasePrice + maintenanceCost - recoveredAmount)
heldDays      = max(1, today - purchaseDate)
dailyCost     = effectiveCost / heldDays
retentionRate = currentValue / purchasePrice  (0 when purchasePrice <= 0)
~~~

Maintenance, repair, and replacement events contribute to maintenance cost. Sale events contribute to recovered amount and move status to sold. Valuation events update current value.

## 4. Local mutation semantics

A user mutation is not considered complete only because widget state changed. Repository writes persist the entity and a corresponding sync outbox mutation in the same repository transaction.

Delete is sync-safe:

- normal UI stops showing the entity
- a durable delete mutation is retained
- related lifecycle events are hidden and receive delete mutations
- active source EntityLinks are tombstoned and receive `entity.link` delete mutations

## 5. Sync v1

Entity types:

- asset.asset
- asset.event
- entity.link

The coordinator performs:

~~~text
missing cursor
    -> snapshot bootstrap/recovery
    -> push local outbox heads
    -> acknowledge accepted mutations
    -> rebase next mutation for the same entity
    -> persist conflicts/rejections
    -> pull incrementally to current cursor
~~~

Remote changes are skipped when the same entity still has unsynced local intent, preventing Pull from silently overwriting a pending local edit.

## 6. Conflict behavior

A persisted conflict stores the entity type/id, originating local change id, current server version, local payload, server payload/deleted state, reason, and creation time.

The UI exposes two explicit resolutions:

- 采用云端: discard pending local mutations for that entity and apply server state.
- 保留本地: retain local mutations, rebase the head mutation to current serverVersion, unblock, then push again.

No timestamp-based last-write-wins heuristic is used.

## 7. Cloud account safety

The local sync state binds a local dataset to the first Cloud user that syncs it. A different Cloud account cannot silently reuse the same local dataset; the user must first back up or clear local data.

## 8. Backup and recovery

Backups use a versioned JSON envelope. Version 2 contains active assets, events, and EntityLinks while restore remains compatible with version 1. Restored entities reset server versions and create fresh outbox operations.

## 9. Verification

The Flutter CI gate runs:

- OpenSpec strict validation
- flutter analyze
- flutter test
- flutter build web --release

The Cloud repository independently verifies the asset contract with Rust format/tests/clippy, contract crate tests, generic sync regression tests, and generated-contract drift checks.

The active EntityLink OpenSpec change must not be archived until exact-head Flutter CI, the companion Cloud authorization CI, merge, and post-merge verification are complete.
