## Context

LifeTrace Assets currently persists `asset.asset`, `asset.event`, and `entity.link` locally and
synchronizes the entity types through LifeTrace Cloud Sync v1. Binary file transfer is a different
problem: LifeTrace Cloud already exposes a file platform with metadata records, signed object-storage
PUT/GET URLs, SHA-256 deduplication, upload completion/failure state, and file deletion.

Attachments therefore should not be forced into Sync v1 payloads. The Assets client needs a local
attachment subsystem that composes with, but remains independent from, entity synchronization.

## Architecture

The attachment subsystem is split into four units:

1. `AssetAttachmentRepository`
   - owns attachment metadata and durable transfer-operation persistence
   - exposes attachment CRUD/query APIs to app state
   - never performs HTTP directly
2. `AttachmentBinaryStore`
   - persists local file bytes behind a platform-neutral interface
   - native implementation stores files in application support storage
   - web implementation persists bytes in IndexedDB so offline-created attachments survive reload
3. `AssetFilesApi`
   - wraps the LifeTrace Cloud Files API
   - understands `assets_attachments`, signed upload/download, list, complete/fail, and delete calls
   - does not own local retry state
4. `AssetAttachmentCoordinator`
   - drains durable attachment operations when Cloud access is available
   - reconciles remote metadata into the local repository
   - downloads remote-only content only when requested

The existing `AssetSyncCoordinator` remains responsible only for Sync v1 entities. The application may
run core entity sync first and attachment reconciliation second; failure in the attachment phase MUST
NOT roll back or mark core entity sync as failed.

## Local Model

`AssetAttachment` stores at least:

- `id`: stable local attachment ID
- `ownerType`: `asset.asset` or `asset.event`
- `ownerId`
- `originalName`
- `mimeType`
- `sizeBytes`
- `sha256`
- `localObjectKey`: optional opaque key understood by `AttachmentBinaryStore`
- `cloudFileId`: optional LifeTrace Cloud file ID
- `cloudStorageState`: pending / available / failed when known
- `transferState`: localOnly / pendingUpload / uploading / available / pendingDelete / failed / remoteOnly
- `lastError`: optional diagnostic string for retry UI
- `createdAt` / `updatedAt`

Local filesystem paths MUST NOT be serialized to Cloud and MUST NOT be treated as stable identifiers.

A separate durable operation record stores ordered upload/delete intent. Upload operations point to an
attachment ID; delete operations preserve the remote file ID long enough to complete deletion even if
the visible attachment row has already been hidden.

## Offline Create Flow

1. User selects a supported file.
2. The client computes SHA-256 and validates size/MIME before accepting it.
3. Bytes are persisted through `AttachmentBinaryStore`.
4. Attachment metadata and a pending-upload operation are committed locally.
5. UI immediately shows the attachment as local/pending.
6. When Cloud access exists, the coordinator calls Files API prepare with:
   - `domain = assets_attachments`
   - original name / MIME / size / SHA-256
   - `entityType = ownerType`
   - `entityId = ownerId`
7. If Cloud returns an already-available deduplicated file, the local row binds to that file ID and
   becomes available without uploading duplicate bytes.
8. Otherwise the client PUTs bytes to the signed upload URL and calls complete.
9. Only after completion is confirmed is the upload operation removed.

A failure keeps both local bytes and the operation durable and exposes retry state.

## Remote Reconciliation

After successful core entity synchronization, the coordinator lists Cloud files in
`assets_attachments` and reconciles metadata:

- matching `cloudFileId` updates storage state and metadata
- unknown available Cloud files become `remoteOnly` local rows
- local pending uploads are not deleted merely because they are absent remotely
- remotely deleted files remove or tombstone matching local metadata only when there is no newer
  pending local mutation

Remote-only files do not download automatically. Opening one requests a signed download URL, stores the
bytes locally, and converts the row to cached/available state.

## Delete Semantics

Deleting an attachment hides it immediately from normal UI and removes local bytes when safe.

- local-only attachment: delete metadata, bytes, and pending upload operation locally
- uploaded attachment: mark pendingDelete and enqueue remote deletion
- remote delete failure: keep a retryable tombstone/operation but do not resurrect the visible row

Deleting an asset cascades the same behavior to all `asset.asset` attachments. Deleting an event
cascades its `asset.event` attachments if event deletion is supported by the repository operation.

## Cloud Authorization Boundary

The Assets application must not gain general visibility into every LifeTrace file domain merely to
store asset files. A companion LifeTrace Cloud OpenSpec change adds `assets_attachments` and enforces a
domain/application authorization boundary.

For the dedicated `lifetrace-assets` client:

- file operations are allowed only for `assets_attachments`
- prepare requests may reference only `asset.asset` or `asset.event`
- requests for finance, notes, backups, photos, or other domains are rejected

The implementation may reuse existing generic `files:read` / `files:write` token scopes internally,
but server-side domain enforcement is mandatory. Client-side filtering alone is insufficient.

## File Type and Size Policy

V1 accepts:

- common images: JPEG, PNG, WebP, HEIC/HEIF where the platform can provide bytes
- PDF
- plain text and common office document formats supported by Cloud policy

Unsupported MIME types are rejected before persistence when determinable. The client MUST respect the
Cloud maximum file size and SHOULD expose the configured/default limit in validation messaging rather
than attempting oversized uploads.

## UI

Asset detail gains a data-driven attachment section.

Each row shows:

- file name
- file type/size summary
- transfer state
- retry action when failed
- open/download action when available or remote-only
- remove action

Images may render a local thumbnail/preview when bytes are available. Non-image documents use a file
row/icon and platform open/download behavior. No fake preview is generated.

The add action uses a platform file picker and accepts only the supported V1 categories.

## Backup and Restore

The existing JSON backup advances to a new version that includes an attachment manifest containing
metadata but not binary payloads.

On restore:

- attachment manifest entries without binary content are restored as metadata only
- remote-backed entries may become `remoteOnly` if `cloudFileId` exists
- local-only entries whose bytes were not exported MUST be marked unavailable rather than pretending
  content exists
- existing older backups remain accepted

A future explicit binary archive/export change may introduce ZIP or another container format; this
change must not silently inflate JSON backups with base64 binaries.

## Error Handling

Attachment failures are isolated from core asset state:

- picker/storage failure: no attachment metadata is committed unless bytes are durable
- Cloud prepare/upload/complete failure: retain local bytes and retry operation
- download failure: retain metadata and leave the row remote-only/retryable
- authorization/domain rejection: surface a non-destructive sync error and retain local intent
- missing local bytes for pending upload: mark failed with a diagnostic; never create a zero-byte fake

## Testing

Tests must cover:

- attachment model serialization and state transitions
- repository create/list/delete and cascade behavior
- operation durability across repository reopen
- native/web binary-store contract through fakes or platform-specific tests
- offline create followed by successful prepare/upload/complete
- deduplicated Cloud prepare response
- failed upload retry without metadata loss
- remote-only reconciliation and on-demand download
- local-only and uploaded delete flows
- unsupported MIME/oversize rejection
- backup compatibility and manifest semantics
- widget acceptance for add/retry/open/remove states
- regression that attachment failure does not fail core Sync v1

## Non-Goals

AI processing, OCR, background removal, semantic classification, media transcoding, and public sharing
are intentionally deferred so file lifecycle correctness can be proven independently first.
