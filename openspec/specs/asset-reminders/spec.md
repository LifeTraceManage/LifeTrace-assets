# Asset Reminders Specification

## Purpose
Defines deterministic in-app asset reminder behavior and ensures all reminder surfaces use the same persisted-state-derived reminder rules.

## Requirements

### Requirement: Deterministic in-app reminders
The application MUST derive in-app reminders from persisted asset state without requiring Cloud
connectivity.

#### Scenario: Warranty reminder
- GIVEN an asset whose warranty expires within the configured reminder window
- WHEN reminders are evaluated
- THEN a warranty reminder SHALL be produced with the asset identity and remaining time

#### Scenario: Idle reminder
- GIVEN an asset whose current status is idle
- WHEN reminders are evaluated
- THEN an idle review reminder SHALL be produced

#### Scenario: Repair reminder
- GIVEN an asset whose current status is repair
- WHEN reminders are evaluated
- THEN a repair follow-up reminder SHALL be produced

#### Scenario: No actionable state
- GIVEN an active asset with no near warranty expiry
- WHEN reminders are evaluated
- THEN no reminder SHALL be fabricated for that asset

### Requirement: Shared reminder rules
The home reminder indicator and the reminder center MUST use the same deterministic reminder
calculation.

#### Scenario: Reminder count
- GIVEN a set of persisted assets
- WHEN the home reminder indicator and reminder center are rendered
- THEN both SHALL be based on the same reminder result set
