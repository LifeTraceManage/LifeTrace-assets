## 1. OpenSpec and Architecture

- [x] 1.1 Add OpenSpec project configuration and Assets v1 change artifacts.
- [x] 1.2 Define asset-library, lifecycle, persistence, analytics, and cloud-sync requirements.
- [x] 1.3 Split UI from domain/data/application responsibilities.

## 2. Local Domain and Persistence

- [x] 2.1 Add production domain models and JSON serialization.
- [x] 2.2 Add cross-platform persistent local database adapter.
- [x] 2.3 Add AssetRepository with CRUD, event mutations, soft delete, and outbox writes.
- [x] 2.4 Add AssetAppState initialization, loading/error state, and commands.
- [x] 2.5 Add persistence/repository tests including reopen behavior.

## 3. Real Asset Workflows

- [x] 3.1 Replace mock data reads on Dashboard, Asset list, Detail, Activity, and Analytics.
- [x] 3.2 Implement create/edit with validation and real date/channel/serial/warranty fields.
- [x] 3.3 Implement asset deletion and status changes.
- [x] 3.4 Implement lifecycle-event creation with type/date/detail/amount.
- [x] 3.5 Implement search/filter/sort and empty states.
- [x] 3.6 Implement derived maintenance/recovery costs and lifecycle totals.

## 4. Analytics and Settings

- [x] 4.1 Remove all hard-coded analytics counters.
- [x] 4.2 Derive dashboard totals, category mix, status distribution, daily-cost ranking, and
      monthly changes from repository state.
- [x] 4.3 Add local data/export/reset surfaces and accurate app/version labels.
- [x] 4.4 Add versioned JSON backup/restore and real in-app warranty/idle/repair reminders.

## 5. LifeTrace Cloud Contract

- [x] 5.1 Add asset.asset and asset.event contracts to LifeTrace-cloud.
- [x] 5.2 Add asset scopes and Assets app authorization.
- [x] 5.3 Add registry/payload validation and contract regression tests.
- [x] 5.4 Verify existing finance/execution sync behavior is unchanged.

## 6. Client Sync

- [x] 6.1 Implement Sync v1 client transport and secure credential boundary.
- [x] 6.2 Push local outbox mutations and persist acknowledgements/server versions.
- [x] 6.3 Implement pull cursor and transactional remote apply.
- [x] 6.4 Implement snapshot bootstrap/recovery.
- [x] 6.5 Persist and expose optimistic conflicts without data loss.
- [x] 6.6 Add manual sync/status UI and offline/error states.
- [x] 6.7 Add accepted-change rebase, Cloud account binding, and explicit keep-local/use-server conflict resolution.

## 7. Verification and Release

- [x] 7.1 Expand unit/widget tests for acceptance scenarios.
- [x] 7.2 Run flutter analyze, flutter test, and release Web build.
- [x] 7.3 Update README and architecture documentation.
- [x] 7.4 Run OpenSpec strict validation against the active change.
- [ ] 7.5 Archive implement-assets-v1 only after all requirements are satisfied.
