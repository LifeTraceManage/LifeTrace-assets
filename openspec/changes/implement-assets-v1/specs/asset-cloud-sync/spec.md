# Delta for Asset Cloud Sync

## ADDED Requirements

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
