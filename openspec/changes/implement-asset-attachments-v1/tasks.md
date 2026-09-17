## 1. Contract and persistence

- [ ] 1.1 Add `AssetAttachment`, transfer-state, and durable attachment-operation models.
- [ ] 1.2 Add dedicated local stores for attachment metadata and attachment operations.
- [ ] 1.3 Add `AttachmentBinaryStore` abstraction with native persistent-file and Web IndexedDB implementations.
- [ ] 1.4 Add repository CRUD/query APIs and validate owner type, MIME, size, SHA-256, and local-byte durability.
- [ ] 1.5 Add cascade cleanup for asset deletion and event deletion where supported.

## 2. Cloud file client

- [ ] 2.1 Add `AssetFilesApi` wrapper for list/prepare/complete/fail/delete/download-url operations.
- [ ] 2.2 Implement signed PUT/GET binary transfer without leaking local paths into Cloud metadata.
- [ ] 2.3 Request only the file scopes required by the approved Cloud companion change.
- [ ] 2.4 Handle deduplicated prepare responses and Cloud storage-state transitions.

## 3. Attachment coordinator

- [ ] 3.1 Implement durable pending-upload processing with retry and exact-byte upload.
- [ ] 3.2 Implement durable pending-delete processing.
- [ ] 3.3 Implement remote metadata reconciliation for `assets_attachments`.
- [ ] 3.4 Implement on-demand download and local caching for remote-only files.
- [ ] 3.5 Isolate attachment failures from Sync v1 entity success/failure state.

## 4. Backup and restore

- [ ] 4.1 Advance backup format with an attachment manifest and retain compatibility with older backups.
- [ ] 4.2 Restore Cloud-backed manifest entries as remote-only when local bytes are absent.
- [ ] 4.3 Restore local-only manifest entries without fabricating missing bytes or fake upload work.
- [ ] 4.4 Include attachment metadata/operation counts in local-data diagnostics where useful.

## 5. UI integration

- [ ] 5.1 Replace/add asset-detail attachment section backed by repository state.
- [ ] 5.2 Add file picker flow for supported V1 images/PDF/documents.
- [ ] 5.3 Add transfer-state, retry, open/download, and remove actions.
- [ ] 5.4 Add local image preview where bytes are available and non-fabricated document rows otherwise.
- [ ] 5.5 Surface attachment errors separately from core entity sync state.

## 6. Tests

- [ ] 6.1 Add model/state-transition tests before production implementation.
- [ ] 6.2 Add repository persistence, reopen, cascade, and operation-durability tests.
- [ ] 6.3 Add binary-store contract tests for native/web implementations or deterministic platform fakes.
- [ ] 6.4 Add Files API/coordinator tests for normal upload, deduplication, retry, delete, reconciliation, and download.
- [ ] 6.5 Add backup compatibility tests.
- [ ] 6.6 Add widget tests for add/fail/retry/open/remove states.
- [ ] 6.7 Add regression test proving attachment outage does not fail successful core Sync v1.

## 7. Verification and release

- [ ] 7.1 `flutter analyze` passes.
- [ ] 7.2 `flutter test` passes.
- [ ] 7.3 `flutter build web --release` passes.
- [ ] 7.4 OpenSpec strict validation passes.
- [ ] 7.5 Companion LifeTrace Cloud change is merged and its CI is green before enabling Cloud attachment transfer in the production branch.
- [ ] 7.6 Update README/architecture/UI docs with actual supported attachment behavior and limitations.
- [ ] 7.7 Merge to `feature/flutter-ui-v1`, verify post-merge CI, then archive this OpenSpec change and publish the live spec.
