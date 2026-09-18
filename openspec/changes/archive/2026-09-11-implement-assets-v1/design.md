## Context

The existing Flutter app is a single-file UI prototype with mock lists. LifeTrace Cloud already
provides generic Sync v1 semantics (push, pull, snapshot, optimistic conflict handling), but its
entity registry and authorization map do not contain an asset domain.

## Architecture

```text
Flutter UI
  -> AssetAppState (application state / commands)
    -> AssetRepository
      -> LocalAssetDatabase
      -> SyncOutbox
      -> AssetSyncCoordinator
        -> LifeTrace Cloud Sync v1
```

Widgets SHALL read state and invoke commands; they SHALL NOT directly access database or HTTP.

## Domain Model

### Asset

Stable fields include id, name, category, status, brand, model, spec, purchase date, purchase
price, purchase channel, current value, warranty date, serial number, location, maintenance cost,
recovered amount, createdAt, updatedAt.

Derived values:
- heldDays = max(1, today - purchaseDate)
- dailyCost = max(0, purchasePrice + maintenanceCost - recoveredAmount) / heldDays
- retentionRate = currentValue / purchasePrice when purchasePrice > 0

### AssetEvent

Stable fields include id, assetId, type, occurredAt, title, detail, amount, createdAt, updatedAt.
Event types cover purchase, use/start, maintenance, repair, replacement, lend, return, idle,
valuation, sell, retire, and note.

Repository event writes update the asset's denormalized maintenance/recovery totals in the same
logical transaction.

## Local Persistence

Use a repository-owned embedded store with platform-specific adapters:
- Web: IndexedDB-backed storage.
- Android/native: application-support persistent storage.
- Tests: in-memory implementation.

The persistence API is abstracted so the store can be replaced without changing widgets. Every
local mutation writes both the entity and an outbox record atomically at repository level.

## Deletion

Assets use soft-delete semantics internally for sync correctness. The normal UI hides deleted
records. Deleting an asset also hides its lifecycle events locally and enqueues delete operations.
Hard cleanup is deferred until cloud acknowledgement and retention policy allow it.

## Application State

AssetAppState owns the loaded asset/event collections, loading/error state, active sync state, and
commands. It emits changes after repository mutations. Empty databases show actionable empty
states rather than demo/mock rows.

## Analytics

All values are derived from current repository state. Monthly changes use createdAt/event dates;
no hard-coded counters remain. Zero-value denominators MUST be guarded.

## Sync

Client entity types:
- asset.asset
- asset.event

Optional later types:
- asset.valuation_snapshot
- asset.attachment_relation

Sync uses existing LifeTrace Cloud v1:
1. local write -> outbox with baseServerVersion
2. push pending operations
3. apply accepted server versions
4. persist conflicts for explicit resolution
5. pull from cursor
6. apply remote changes transactionally
7. snapshot for bootstrap/recovery

The client MUST remain fully usable with Cloud disabled or unreachable.

## LifeTrace Cloud Changes

LifeTrace-cloud must add:
- EntityType constants and registry descriptors for asset.asset and asset.event
- asset:read and asset:write scopes
- an Assets app id (or an explicitly approved shared app id)
- payload validation types for both entities
- generated contract/schema updates
- authorization and sync regression tests

No asset-specific persistence table is required because the existing generic sync_entities and
sync_change_log stores already support registered user-owned entities.

## Backup and Restore

Backups use a versioned JSON envelope containing active assets and lifecycle events. Restore
validates the format/version, clears stale local sync/conflict metadata, restores active entities,
and enqueues fresh outbox mutations so restored data re-enters the normal synchronization path.

## Reminders

Reminder rules are deterministic domain calculations over persisted asset state. V1 creates
in-app reminders for:
- warranty expiry inside the configured reminder window
- idle assets that should be reviewed
- assets currently marked as repair

The home indicator and reminder center share the same domain reminder function.

## Sensitive Fields

Serial-number-like identifiers are stored in full locally and in the encrypted Cloud transport
payload, but normal detail views show a masked representation. Copy is an explicit action that
uses the original stored value.

## Migration Strategy

Local schema starts at version 1. Future changes use explicit migrations. Model decoding accepts
missing optional fields with safe defaults. Cloud entity schemaVersion starts at 1.

## Testing

- domain calculation tests
- repository CRUD/event transaction tests
- persistence reopen tests
- application-state tests
- widget tests for empty/create/edit/event flows
- cloud contract registry/scope tests
- sync push/pull/conflict integration tests

## Security / Privacy

Sensitive serial/IMEI-like values stay masked in normal display. Authentication tokens are never
stored in asset entity payloads. Cloud access follows least-privilege asset scopes.
