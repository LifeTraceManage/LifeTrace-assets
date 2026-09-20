# LifeTrace Assets Architecture V1

## 1. Architectural goal

LifeTrace Assets V1 is a local-first asset lifecycle application. The network is an optional replication channel, not a prerequisite for core CRUD, lifecycle history, analytics, reminders, backup, or already-authorized EntityLink local mutations.

The foundational Assets v1 and follow-up EntityLink changes are archived. The active `implement-asset-attachments-v1` change adds the attachment subsystem without coupling binary transfer to Sync v1.

## 2. Layers

### UI

`lib/main.dart` contains the current screen/widget composition and delegates stateful business operations to `AssetAppState`. Widgets do not open databases or invoke Cloud HTTP endpoints directly.

### Application

`lib/src/application/asset_app_state.dart` owns application-visible state:

- assets, lifecycle events, persisted EntityLinks, and AssetAttachments
- attachment binary access and durable transfer-operation diagnostics
- loading/error state
- pending sync count
- Cloud session and sync progress
- persisted conflicts
- backup/reset commands

### Domain

`lib/src/domain/asset_models.dart` defines `AssetItem`, `AssetEvent`, `AssetEntityLink`, `AssetCategory`, `AssetStatus`, `AssetEventType`, `SyncOutboxItem`, and `AssetSyncConflict`. `AssetEntityLink` converts its local flattened representation to the generic LifeTrace Cloud EntityLink wire shape.

Server versions are modeled as opaque strings to match LifeTrace Sync v1.

`lib/src/domain/asset_attachment.dart` separately defines attachment metadata, transfer states, Cloud storage state, and durable upload/delete operation records. Files are not modeled as Sync v1 entities.

### Data

`lib/src/data/asset_repository.dart` is the transaction boundary. It owns asset/event/link CRUD, lifecycle aggregation, soft-delete/tombstone preparation, outbox creation, cursor/snapshot state, conflict persistence, accepted-change rebase, and backup import/export.

Storage adapters live under `lib/src/data/local_database_*.dart`:

- native/Android: Sembast file under application support storage
- Web: Sembast Web / IndexedDB
- tests: in-memory Sembast

Attachment bytes use a separate `AttachmentBinaryStore`:

- native/Android: opaque object keys under the application-support `asset_attachments` directory
- Web: a dedicated IndexedDB/Sembast database
- tests: deterministic in-memory bytes

Attachment metadata and transfer intent live in `asset_attachments` and `asset_attachment_operations`. Creation persists exact bytes before metadata is committed; asset/event deletion cascades attachment cleanup.

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

## 5. Asset photos and attachment boundary

Asset photos are local-first. The current implementation supports image selection, SHA-256 validation, persistent bytes, multiple photos per asset, local previews, first-photo thumbnails, removal, deletion cascade, and durable upload/delete intent.

Binary attachment transfer is deliberately separate from Sync v1. The next part of the active OpenSpec change will connect the durable operations to the LifeTrace Cloud Files API using the `assets_attachments` domain. Until that coordinator is implemented, pending attachment operations remain local and retryable rather than being embedded into entity payloads.

## 6. Sync v1

Entity types:

- `asset.asset`
- `asset.event`
- `entity.link`

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

Legacy Assets sessions without `links:read` / `links:write` continue syncing asset entities. EntityLink outbox entries remain durable until link authorization becomes available.

## 7. Conflict behavior

A persisted conflict stores the entity type/id, originating local change id, current server version, local payload, server payload/deleted state, reason, and creation time.

The UI exposes two explicit resolutions:

- 采用云端: discard pending local mutations for that entity and apply server state.
- 保留本地: retain local mutations, rebase the head mutation to current serverVersion, unblock, then push again.

No timestamp-based last-write-wins heuristic is used.

## 8. Cloud account safety and link authorization

The local sync state binds a local dataset to the first Cloud user that syncs it. A different Cloud account cannot silently reuse the same local dataset; the user must first back up or clear local data.

Generic `entity.link` uses dedicated `links:read` / `links:write` scopes in LifeTrace Cloud. Assets does not receive `account:write` merely to create cross-application references, and the Assets UI does not fetch target product bodies solely to render a link.

## 9. Backup and recovery

Backups use a versioned JSON envelope. Version 3 contains active assets, events, EntityLinks, and attachment manifest metadata while restore remains compatible with versions 1 and 2. Binary bytes are not base64-embedded into JSON. Cloud-backed attachments restore as remote-only; local-only entries without exported bytes restore as unavailable.

## 10. Verification

The Flutter CI gate runs:

- OpenSpec strict validation
- `flutter analyze`
- domain/repository tests, including attachment persistence/cascade/backup behavior
- sync tests
- widget acceptance tests, including persisted EntityLink and asset-photo behavior
- `flutter build web --release`

The Cloud repository independently verifies authorization and contracts with Rust format/tests/clippy, contract crate tests, generic sync regression tests, generated-contract drift checks, and container-image build.

The EntityLink change was merged only after exact-head CI and was archived only after successful post-merge verification in both repositories.
