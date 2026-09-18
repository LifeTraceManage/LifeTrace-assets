# Asset Lifecycle Specification

## Purpose
Defines persisted asset lifecycle-history behavior, cost accounting, event integrity, offline writes, and validation of lifecycle event dates.

## Requirements

### Requirement: Lifecycle history
The application MUST persist lifecycle events linked to a stable asset ID.

#### Scenario: Add maintenance event
- GIVEN an existing asset
- WHEN the user adds a maintenance event with date, detail, and cost
- THEN the event SHALL appear in both asset detail and global activity history

### Requirement: Cost accounting
The application MUST include maintenance spend and recovered amount in daily-cost calculations.

#### Scenario: Maintenance and sale recovery
- GIVEN an asset with purchase price, maintenance events, and a sale/recovery amount
- WHEN daily cost is calculated
- THEN it SHALL use (purchase + maintenance - recovered) / effective held days
- AND SHALL never return a negative daily cost

### Requirement: Event integrity
Deleting or hiding an asset MUST prevent orphan lifecycle events from appearing in normal views.

#### Scenario: Deleted asset
- GIVEN an asset with events
- WHEN the asset is deleted
- THEN its events SHALL not appear in the global activity feed

### Requirement: Offline lifecycle writes
Lifecycle events MUST be creatable without network access.

#### Scenario: Add event offline
- GIVEN Cloud is unavailable
- WHEN an event is saved
- THEN the local write SHALL succeed
- AND a durable sync operation SHALL be queued


### Requirement: Lifecycle event date validation
Lifecycle history MUST represent events that have already occurred.

#### Scenario: Future lifecycle date
- GIVEN the lifecycle-event editor
- WHEN the user selects an event date later than today
- THEN the date SHALL be rejected by the editor
