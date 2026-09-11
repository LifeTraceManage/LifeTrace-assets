# Asset Cloud Sync Specification

## Purpose
Defines the Assets client's observable LifeTrace Cloud Sync v1 behavior, including registration, least-privilege authorization, offline synchronization, conflict handling, recovery, ordering, and rejected-change visibility.

## Requirements

### Requirement: Registered asset entities
LifeTrace Cloud MUST register asset.asset and asset.event as user-owned bidirectional Sync v1
entities using optimistic conflicts.

#### Scenario: Capabilities
- GIVEN a compatible LifeTrace Cloud deployment
- WHEN the client requests sync capabilities
- THEN both asset entity types SHALL be reported as supported

### Requirement: Least-privilege authorization
The Assets client MUST receive asset read/write scopes without automatically receiving unrelated
finance, notes, or mail write scopes.

#### Scenario: Assets token
- GIVEN an authenticated Assets app session
- WHEN scopes are issued
- THEN asset:read and asset:write SHALL be available
- AND unrelated product scopes SHALL not be granted unless explicitly required

### Requirement: Offline-first push/pull
Cloud connectivity MUST synchronize durable local operations without becoming a prerequisite for
local use.

#### Scenario: Reconnect
- GIVEN local changes created offline
- WHEN connectivity returns and sync succeeds
- THEN pending operations SHALL be acknowledged
- AND accepted server versions SHALL be stored locally

### Requirement: Conflict preservation
Optimistic conflicts MUST preserve both local intent and server state for resolution.

#### Scenario: Concurrent edit
- GIVEN the same asset was edited on two devices from the same base version
- WHEN the second edit is pushed
- THEN the conflict SHALL be persisted and exposed
- AND neither version SHALL be silently discarded

### Requirement: Snapshot recovery
The client MUST be able to rebuild sync state from a server snapshot without losing newer local
pending mutations.

#### Scenario: Cursor recovery
- GIVEN an invalid or unavailable incremental cursor
- WHEN snapshot recovery is performed
- THEN server entities SHALL be restored
- AND unsynced local operations SHALL remain queued


### Requirement: Per-entity outbox ordering
The client MUST preserve mutation order for each entity and MUST NOT push a later mutation when the
head mutation for that entity is blocked.

#### Scenario: Rejected head mutation
- GIVEN two pending local mutations for the same asset
- AND the first mutation is rejected and blocked
- WHEN the next sync push batch is selected
- THEN the later mutation SHALL NOT leapfrog the blocked head
- AND the blocked mutation SHALL be exposed as a sync issue with its error code and message

### Requirement: Rejected change visibility
Rejected or otherwise blocked outbox changes MUST remain visible in the Cloud status UI until the
underlying issue is resolved by a later product flow.

#### Scenario: Server rejects payload
- GIVEN the server rejects a pushed asset mutation
- WHEN the Cloud status surface opens
- THEN the user SHALL see the affected entity, error code, and error message
