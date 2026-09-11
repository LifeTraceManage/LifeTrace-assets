## Why

LifeTrace Assets currently behaves as a UI prototype: asset rows, lifecycle events, analytics,
editor actions, and profile/cloud status are driven by in-memory mock data or no-op controls.
Users cannot reliably create, update, delete, or retain asset data across restarts, and the
LifeTrace Cloud sync registry does not yet contain an asset domain.

The application should become a real local-first product while preserving the approved
information architecture and white/black/yellow visual design.

## What Changes

- Introduce explicit asset and lifecycle-event domain models with stable IDs and JSON contracts.
- Introduce a persistent local data store and repository boundary for Android and Web.
- Replace all mock reads with repository-backed application state.
- Implement asset create, edit, soft-delete, search, filter, sort, warranty, valuation, and
  lifecycle-event workflows.
- Compute dashboard and analytics values from persisted data, including maintenance spend,
  recovered value, retention, daily cost, status counts, category mix, and monthly changes.
- Add a durable outbox/sync metadata model so local writes are sync-ready and never depend on
  network availability.
- Extend LifeTrace Cloud with asset.* contracts, registry entries, authorization scopes, and
  sync tests before enabling real Push/Pull/Snapshot/Conflict in the client.
- Add tests for persistence, repository behavior, calculations, empty states, and critical UI
  flows.
- Update project documentation and CI expectations from "UI prototype" to production-capable
  local-first Assets v1.

## Capabilities

- asset-library
- asset-lifecycle
- local-persistence
- asset-analytics
- asset-cloud-sync
- asset-reminders

## In Scope

Android and Flutter Web, local CRUD, persistent lifecycle history, calculated analytics,
sync-ready local metadata/outbox, and LifeTrace Cloud Sync v1 support for asset entities.

## Out of Scope

Automatic market-price scraping, AI image recognition/background removal, binary image/file
attachments, cross-application EntityLink creation, configurable app themes, background/system
notifications, collaborative asset ownership, and finance-side automatic transaction creation.
These require separate OpenSpec changes after Assets v1 is stable.

## Rollback

The implementation is isolated on a feature branch. Local schema versions are additive and
migration-aware. Cloud asset entity registration is additive to the existing generic sync store,
so disabling the Assets client does not alter existing finance/execution data.
