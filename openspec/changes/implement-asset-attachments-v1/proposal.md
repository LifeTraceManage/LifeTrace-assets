## Why

LifeTrace Assets v1 is now usable as a local-first asset manager, but real-world asset records still
cannot carry the evidence users need most often: photos, invoices, warranty documents, manuals, and
other files. The Cloud already provides a generic file metadata + signed object-storage transfer API,
so Assets should reuse that platform rather than create a second storage service.

The change must preserve the existing local-first contract: adding or deleting an attachment while
offline must be durable locally and must reconcile with Cloud later without blocking normal asset
CRUD or entity synchronization.

## What Changes

- Add an `AssetAttachment` local model and dedicated persistence for attachment metadata and transfer state.
- Persist selected file bytes locally through a platform storage abstraction so offline-created attachments survive restart.
- Add an attachment operation queue for upload and remote delete work that is independent from Sync v1 entity outbox.
- Integrate LifeTrace Cloud Files API for prepare, signed upload/download, complete, fail, list, and delete operations.
- Use Cloud file domain `assets_attachments` with owners restricted to `asset.asset` or `asset.event`.
- Reconcile Cloud attachment metadata after normal asset/entity synchronization without making binary transfer a Sync v1 entity.
- Download remote-only attachments on demand and cache them locally.
- Cascade attachment deletion when an asset is deleted.
- Add a real attachment section to asset detail for add, inspect, open/download, retry, and remove actions.
- Support common images, PDF, and common office/text document MIME types in v1.
- Preserve existing JSON backup compatibility while adding an attachment manifest; binary payload export is explicitly deferred to a later archive/export change.

## Capabilities

- asset-attachments

## In Scope

Local-first attachment metadata and binary persistence, offline-safe upload/delete queueing, Cloud file
metadata reconciliation, signed transfer, image/document attachment UI, owner validation, retry/error
states, and attachment manifest backup/restore behavior.

## Out of Scope

AI background removal, OCR, automatic invoice extraction, image editing, video transcoding, full binary
ZIP backup/export, sharing/public URLs, cross-user file sharing, and a new Assets-specific object-storage service.

## Rollback

The change is additive. Attachments are stored separately from core asset/event records. Disabling the
attachment coordinator or Cloud file domain leaves asset/event CRUD and Sync v1 unchanged. Local files
can remain available even if Cloud transfer is unavailable.
