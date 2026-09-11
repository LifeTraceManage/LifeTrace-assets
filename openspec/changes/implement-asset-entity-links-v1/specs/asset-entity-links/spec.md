# Delta for Asset Entity Links

## ADDED Requirements

### Requirement: Persistent cross-app references
The Assets application MUST persist cross-application references as real EntityLink records rather
than fabricated UI data.

#### Scenario: Create link
- GIVEN an existing asset and a known bound LifeTrace Cloud user
- WHEN the user creates a valid reference to another entity
- THEN the link SHALL be persisted locally
- AND the link SHALL remain visible after restart
- AND a durable entity.link outbox mutation SHALL be queued

### Requirement: Stable source and target identity
Every Assets link MUST use `asset.asset` as its source entity type and MUST preserve the target
entity type and target entity ID exactly.

#### Scenario: Invalid target
- GIVEN the add-link form
- WHEN the target entity type or target entity ID is empty
- THEN the link SHALL not be saved

#### Scenario: Self reference
- GIVEN an asset
- WHEN the target is the same `asset.asset` and asset ID
- THEN the link SHALL be rejected

### Requirement: Least-privilege reference display
The Assets application MUST NOT fabricate or fetch target product data solely to render a link.

#### Scenario: Target label unavailable
- GIVEN a persisted link without a target label
- WHEN asset detail renders
- THEN the target entity type and entity ID SHALL be shown
- AND no invented target title SHALL be displayed

### Requirement: Offline-safe mutation
A previously Cloud-bound Assets installation MUST allow link create/delete while offline.

#### Scenario: Offline link create
- GIVEN a persisted bound user ID and no network
- WHEN a valid link is created
- THEN the local write SHALL succeed
- AND synchronization SHALL remain pending in the durable outbox

### Requirement: Asset deletion cascades source links
Deleting an asset MUST hide and synchronize deletion of its active source links.

#### Scenario: Delete linked asset
- GIVEN an asset with two active links
- WHEN the asset is deleted
- THEN both links SHALL disappear from normal UI
- AND entity.link delete mutations SHALL be queued for both links

### Requirement: Cloud EntityLink compatibility
Assets links MUST serialize to the existing LifeTrace Cloud `entity.link` contract and participate
in normal Sync v1 snapshot, push, pull, acknowledgement, and optimistic conflict flows.

#### Scenario: Accepted link push
- GIVEN a pending entity.link upsert
- WHEN Cloud accepts it with a new server version
- THEN the local link SHALL store that server version
- AND the next queued mutation for the same link SHALL be rebased to it

### Requirement: Versioned backup compatibility
Assets backup MUST preserve entity links without breaking existing version-1 backups.

#### Scenario: Restore v1 backup
- GIVEN a valid version-1 Assets backup
- WHEN it is restored by the link-capable client
- THEN assets and events SHALL be restored
- AND the link collection SHALL be empty

#### Scenario: Restore v2 backup
- GIVEN a version-2 backup containing links
- WHEN it is restored
- THEN links SHALL be restored with serverVersion zero
- AND fresh entity.link outbox mutations SHALL be queued

### Requirement: Existing session compatibility
An existing Assets Cloud session that predates dedicated link scopes MUST continue syncing core
asset entities instead of failing the entire sync cycle.

#### Scenario: Legacy session without link scopes
- GIVEN a valid session with asset read/write scopes but without links:read or links:write
- WHEN Assets synchronizes
- THEN Snapshot and Pull SHALL request only asset.asset and asset.event
- AND asset/event outbox mutations SHALL continue to push
- AND pending entity.link mutations SHALL remain durable and unblocked until link write scope is available
