## 1. OpenSpec and Architecture

- [x] 1.1 Add OpenSpec project configuration and Assets v1 change artifacts.
- [x] 1.2 Define asset-library, lifecycle, persistence, analytics, and cloud-sync requirements.
- [ ] 1.3 Split the monolithic UI from domain/data/application responsibilities.

## 2. Local Domain and Persistence

- [ ] 2.1 Add production domain models and JSON serialization.
- [ ] 2.2 Add cross-platform persistent local database adapter.
- [ ] 2.3 Add AssetRepository with CRUD, event mutations, soft delete, and outbox writes.
- [ ] 2.4 Add AssetAppState initialization, loading/error state, and commands.
- [ ] 2.5 Add persistence/repository tests including reopen behavior.

## 3. Real Asset Workflows

- [ ] 3.1 Replace mock data reads on Dashboard, Asset list, Detail, Activity, and Analytics.
- [ ] 3.2 Implement create/edit with validation and real date/channel/serial/warranty fields.
- [ ] 3.3 Implement asset deletion and status changes.
- [ ] 3.4 Implement lifecycle-event creation with type/date/detail/amount.
- [ ] 3.5 Implement search/filter/sort and empty states.
- [ ] 3.6 Implement derived maintenance/recovery costs and lifecycle totals.

## 4. Analytics and Settings

- [ ] 4.1 Remove all hard-coded analytics counters.
- [ ] 4.2 Derive dashboard totals, category mix, status distribution, daily-cost ranking, and
      monthly changes from repository state.
- [ ] 4.3 Add local data/export/reset surfaces and accurate app/version labels.

## 5. LifeTrace Cloud Contract

- [ ] 5.1 Add asset.asset and asset.event contracts to LifeTrace-cloud.
- [ ] 5.2 Add asset scopes and Assets app authorization.
- [ ] 5.3 Add registry/payload/schema generation and regression tests.
- [ ] 5.4 Verify existing finance/execution sync behavior is unchanged.

## 6. Client Sync

- [ ] 6.1 Implement Sync v1 client transport and credential boundary.
- [ ] 6.2 Push local outbox mutations and persist acknowledgements/server versions.
- [ ] 6.3 Implement pull cursor and transactional remote apply.
- [ ] 6.4 Implement snapshot bootstrap/recovery.
- [ ] 6.5 Persist and expose optimistic conflicts without data loss.
- [ ] 6.6 Add manual sync/status UI and offline/error states.

## 7. Verification and Release

- [ ] 7.1 Expand unit/widget tests for all acceptance scenarios.
- [ ] 7.2 Run flutter analyze, flutter test, and release Web build.
- [ ] 7.3 Update README and architecture documentation.
- [ ] 7.4 Run OpenSpec verification against requirements.
- [ ] 7.5 Archive implement-assets-v1 only after all requirements are satisfied.
