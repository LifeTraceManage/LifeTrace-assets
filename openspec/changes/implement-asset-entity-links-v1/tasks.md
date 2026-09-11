## 1. OpenSpec and Contract Alignment

- [x] 1.1 Create a dedicated EntityLink OpenSpec change.
- [x] 1.2 Confirm the existing LifeTrace Cloud EntityLink wire contract.
- [ ] 1.3 Add least-privilege Cloud link authorization in the companion Cloud change.

## 2. Domain and Persistence

- [ ] 2.1 Add AssetEntityLink domain model and wire conversion.
- [ ] 2.2 Add local entity_links persistence.
- [ ] 2.3 Implement link create/update/delete and asset-delete cascade.
- [ ] 2.4 Include links in backup/restore/reset.

## 3. Sync

- [ ] 3.1 Add entity.link to Assets sync entity types.
- [ ] 3.2 Support link acknowledgement/rebase and server-version updates.
- [ ] 3.3 Support snapshot/pull/conflict application for links.
- [ ] 3.4 Add sync regression tests.

## 4. UI

- [ ] 4.1 Replace the placeholder relation panel with persisted links.
- [ ] 4.2 Implement add-link validation and save flow.
- [ ] 4.3 Implement delete-link flow.
- [ ] 4.4 Add widget acceptance coverage.

## 5. Verification

- [ ] 5.1 Run OpenSpec strict validation.
- [ ] 5.2 Run flutter analyze and tests.
- [ ] 5.3 Run Web release build.
- [ ] 5.4 Merge only after exact-head CI is green.
- [ ] 5.5 Archive after post-merge verification.
