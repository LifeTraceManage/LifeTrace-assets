# Delta for Asset Library

## ADDED Requirements

### Requirement: Persistent asset library
The application MUST persist user-created assets and MUST restore them after application restart.

#### Scenario: Create and restart
- GIVEN an empty local library
- WHEN the user creates a valid asset and restarts the application
- THEN the asset SHALL still appear with the same stable ID and saved fields

### Requirement: Asset editing
The application MUST allow an existing asset to be edited without changing its stable ID.

#### Scenario: Edit valuation
- GIVEN an existing asset
- WHEN the user changes its current valuation and saves
- THEN the list, detail, dashboard, and analytics SHALL reflect the new value

### Requirement: Asset deletion
The application MUST remove a deleted asset from normal UI while retaining sync-safe deletion
metadata.

#### Scenario: Delete offline
- GIVEN an existing asset and no network
- WHEN the user deletes the asset
- THEN it SHALL disappear from normal views
- AND a durable pending delete operation SHALL remain available for future sync

### Requirement: Querying
The asset list MUST support search, status filtering, and deterministic sorting.

#### Scenario: Search by brand
- GIVEN assets from multiple brands
- WHEN the user searches for a brand name
- THEN only matching assets SHALL be shown

### Requirement: Empty state
The application MUST show an actionable empty state when no assets exist.

#### Scenario: First launch
- GIVEN a fresh installation with no stored assets
- WHEN the home or asset library opens
- THEN the UI SHALL not fabricate demo assets
- AND SHALL offer a clear action to add the first asset


### Requirement: Purchase date validation
Asset creation and editing MUST reject purchase dates later than the current local day and warranty
dates earlier than the purchase date.

#### Scenario: Future purchase date
- GIVEN the asset editor
- WHEN a future purchase date is submitted
- THEN the asset SHALL not be saved

#### Scenario: Invalid warranty order
- GIVEN a purchase date
- WHEN the warranty end date is earlier than the purchase date
- THEN the asset SHALL not be saved
