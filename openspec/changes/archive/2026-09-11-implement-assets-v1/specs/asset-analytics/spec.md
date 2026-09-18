# Delta for Asset Analytics

## ADDED Requirements

### Requirement: Repository-derived analytics
Dashboard and analytics values MUST be computed from the current non-deleted persisted assets and
events.

#### Scenario: Empty library
- GIVEN no assets
- WHEN analytics opens
- THEN all monetary totals and ratios SHALL render safely as zero/empty values

### Requirement: Current valuation totals
The application MUST compute total purchase value, current valuation, retention, and status counts
from persisted data.

#### Scenario: Asset valuation changes
- GIVEN multiple assets
- WHEN one asset valuation changes
- THEN aggregate valuation and retention metrics SHALL update without restart

### Requirement: Monthly activity
Monthly-added, sold/recovered, and maintenance counts MUST be derived from actual timestamps/events.

#### Scenario: New month
- GIVEN no current-month lifecycle events
- WHEN analytics opens in a new month
- THEN monthly activity SHALL not reuse hard-coded prior values
