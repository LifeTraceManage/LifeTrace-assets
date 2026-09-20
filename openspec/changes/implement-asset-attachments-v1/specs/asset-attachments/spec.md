# Delta for Asset Attachments

## ADDED Requirements

### Requirement: Durable local attachment creation
The Assets application MUST persist attachment bytes and attachment metadata locally before reporting
an attachment create as successful.

#### Scenario: Create attachment offline
- GIVEN an existing asset and no Cloud connectivity
- WHEN the user selects a supported file
- THEN the file bytes SHALL be persisted locally
- AND attachment metadata SHALL be persisted locally
- AND a durable pending-upload operation SHALL be queued
- AND the attachment SHALL remain visible after application restart

#### Scenario: Local byte persistence fails
- GIVEN a selected file
- WHEN local binary persistence fails
- THEN no successful attachment record SHALL be exposed
- AND no upload operation SHALL be queued for missing bytes

### Requirement: Stable attachment ownership
Every attachment MUST reference exactly one supported owner using a stable entity type and entity ID.

#### Scenario: Asset-owned attachment
- GIVEN an attachment added from asset detail
- WHEN it is persisted
- THEN `ownerType` SHALL equal `asset.asset`
- AND `ownerId` SHALL equal the asset ID

#### Scenario: Unsupported owner type
- GIVEN an attachment create request with an owner type other than `asset.asset` or `asset.event`
- WHEN validation runs
- THEN the attachment SHALL be rejected

### Requirement: Durable transfer operations
Upload and remote-delete intent MUST survive process restart and temporary network failure independently
of the Sync v1 entity outbox.

#### Scenario: Upload interrupted
- GIVEN a pending attachment upload
- WHEN prepare, PUT, or complete fails
- THEN the local attachment bytes SHALL remain available
- AND the transfer operation SHALL remain durable and retryable
- AND core asset/event synchronization SHALL remain usable

### Requirement: Cloud Files API compatibility
Assets attachments MUST use the LifeTrace Cloud Files API and the `assets_attachments` domain rather
than embedding binary payloads in Sync v1 entities.

#### Scenario: Normal upload
- GIVEN a local pending attachment
- WHEN Cloud prepare succeeds and returns an upload target
- THEN the client SHALL upload the exact persisted bytes to the signed target
- AND SHALL call complete only after the upload succeeds
- AND SHALL remove the pending upload operation only after Cloud completion succeeds

#### Scenario: Deduplicated prepare
- GIVEN a local attachment whose SHA-256 already exists as an available Cloud file in the same domain
- WHEN Cloud prepare returns the available file without requiring upload
- THEN the client SHALL bind the local attachment to that Cloud file ID
- AND SHALL not upload duplicate bytes

### Requirement: Remote metadata reconciliation
The client MUST reconcile Cloud attachment metadata without automatically downloading every binary.

#### Scenario: Unknown remote attachment
- GIVEN an available `assets_attachments` Cloud file for a known asset
- WHEN attachment reconciliation runs
- THEN a local metadata row SHALL be created in `remoteOnly` state
- AND binary content SHALL not be downloaded until requested

#### Scenario: Open remote-only attachment
- GIVEN a remote-only attachment
- WHEN the user opens or downloads it
- THEN the client SHALL obtain a signed download URL
- AND SHALL cache the downloaded bytes locally on success
- AND the attachment SHALL remain retryable on download failure

### Requirement: Offline-safe deletion
Deleting an attachment MUST hide it immediately and eventually remove the corresponding Cloud file
without resurrecting it after transient failures.

#### Scenario: Delete local-only attachment
- GIVEN an attachment that has never reached Cloud
- WHEN the user removes it
- THEN local metadata, local bytes, and its pending upload operation SHALL be removed
- AND no Cloud delete request SHALL be required

#### Scenario: Delete uploaded attachment offline
- GIVEN an attachment with a Cloud file ID and no connectivity
- WHEN the user removes it
- THEN the attachment SHALL disappear from normal UI immediately
- AND a durable pending-delete operation SHALL be queued
- AND retry SHALL continue after connectivity returns

### Requirement: Asset deletion cascades attachments
Deleting an asset MUST cascade attachment cleanup for all attachments owned by that asset.

#### Scenario: Delete asset with mixed attachment states
- GIVEN an asset with local-only, uploaded, and remote-only attachments
- WHEN the asset is deleted
- THEN all attachment rows SHALL disappear from normal asset UI
- AND local-only bytes SHALL be removed
- AND required remote delete operations SHALL be queued durably

### Requirement: Supported file policy
The client MUST validate attachment size and type before transfer and MUST NOT silently upload
unsupported or oversized content.

#### Scenario: Unsupported file
- GIVEN a selected file with an unsupported MIME type
- WHEN it is added
- THEN the client SHALL reject it with a user-visible validation error
- AND SHALL not enqueue upload work

#### Scenario: Oversized file
- GIVEN a selected file larger than the supported Cloud limit
- WHEN it is added
- THEN the client SHALL reject it before upload

### Requirement: Least-privilege file domain
Assets attachment traffic MUST be limited server-side to the Cloud `assets_attachments` domain and
supported Assets owner entity types.

#### Scenario: Assets client requests another file domain
- GIVEN an authenticated `lifetrace-assets` client
- WHEN it attempts to list, prepare, download, or delete a file in another product domain
- THEN Cloud SHALL reject the operation even if the token contains generic file scopes

### Requirement: Attachment UI reflects real state
The asset-detail attachment section MUST render persisted attachment data and transfer state rather
than placeholder rows.

#### Scenario: Failed upload
- GIVEN an attachment whose upload operation failed
- WHEN asset detail renders
- THEN the row SHALL show a failed/retryable state
- AND the locally persisted file SHALL remain accessible when available

### Requirement: Backup compatibility
Versioned JSON backup MUST preserve attachment manifest metadata without embedding binary payloads and
MUST continue accepting earlier backup versions.

#### Scenario: Restore older backup
- GIVEN a valid backup created before attachment support
- WHEN it is restored
- THEN assets/events/links SHALL restore normally
- AND the attachment collection SHALL be empty

#### Scenario: Restore attachment manifest without local bytes
- GIVEN a backup containing attachment metadata but no binary payload
- WHEN it is restored
- THEN the client SHALL NOT pretend local bytes exist
- AND a Cloud-backed entry MAY be restored as remote-only
- AND a local-only entry SHALL be marked unavailable rather than queued as a fake upload

### Requirement: Core synchronization isolation
Attachment transfer errors MUST NOT make otherwise successful core Sync v1 asset synchronization fail.

#### Scenario: Attachment Cloud outage
- GIVEN asset/event/link synchronization succeeds
- AND the Cloud file endpoint is unavailable
- WHEN a combined user sync action runs
- THEN core entity sync success SHALL be retained
- AND attachment work SHALL remain pending with a separate error state
