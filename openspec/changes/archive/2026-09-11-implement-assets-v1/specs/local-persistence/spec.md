# Delta for Local Persistence

## ADDED Requirements

### Requirement: Local-first operation
All core asset operations MUST succeed using local persistence without requiring LifeTrace Cloud.

#### Scenario: Cloud unavailable
- GIVEN the user is offline
- WHEN they create, edit, delete, search, or record an event
- THEN the operation SHALL complete locally without a network error blocking the workflow

### Requirement: Durable mutation queue
Each sync-relevant local mutation MUST create a durable outbox record.

#### Scenario: Process termination
- GIVEN a local mutation has not synced
- WHEN the process terminates and restarts
- THEN the pending mutation SHALL still be available for sync

### Requirement: Cross-platform persistence
Android and Flutter Web MUST both use persistent storage appropriate to their platform.

#### Scenario: Web reload
- GIVEN assets saved in a supported browser
- WHEN the page reloads
- THEN the saved assets SHALL be restored

### Requirement: Failure isolation
A storage initialization or mutation failure MUST surface as recoverable application state rather
than silently falling back to mock data.

#### Scenario: Store fails to open
- GIVEN local persistence cannot initialize
- WHEN the app starts
- THEN an error state SHALL be shown
- AND no fabricated asset data SHALL be displayed


### Requirement: Versioned backup
The application MUST export active local assets and lifecycle events in a versioned JSON envelope
and MUST validate the format before restore.

#### Scenario: Export and restore
- GIVEN local assets and lifecycle events
- WHEN the user exports a backup, clears local data, and restores the same backup
- THEN the active assets and events SHALL be restored
- AND restored entities SHALL be queued for normal synchronization

#### Scenario: Invalid backup
- GIVEN malformed JSON or an unsupported backup version
- WHEN restore is attempted
- THEN the restore SHALL fail without silently importing partial data

### Requirement: Sensitive field display
Sensitive device identifiers MUST be masked in normal detail views while preserving the original
stored value for explicit copy/export actions.

#### Scenario: View serial number
- GIVEN an asset with a serial number
- WHEN its detail page opens
- THEN the serial number SHALL be masked by default
- AND an explicit copy action SHALL copy the complete original value
