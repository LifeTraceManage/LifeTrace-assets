## Why

Assets v1 deliberately shipped without fabricated cross-application relations. LifeTrace Cloud
already defines a typed `entity.link` contract, but the Assets client does not persist, display,
edit, delete, back up, or synchronize these links.

The next step is to make asset relations real while keeping the Assets app local-first and
least-privilege.

## What Changes

- Add a local EntityLink model compatible with LifeTrace Cloud `entity.link`.
- Persist links in Sembast and include them in backup/restore/reset.
- Add durable outbox operations for link create/update/delete.
- Include `entity.link` in snapshot, push, pull, conflict, and acknowledgement flows.
- Cascade link deletion when the source asset is deleted.
- Replace the current placeholder "关联内容" panel with real link rows and add/remove actions.
- Allow relation creation against a stable target entity type + entity ID, with an optional
  user-visible target label stored in link metadata.
- Keep target dereferencing out of scope so Assets does not need unrelated Finance/Execution/Notes
  read scopes.

## Capabilities

- asset-entity-links

## In Scope

Local-first link persistence, link CRUD, Cloud Sync v1, backup/restore, conflict-safe synchronization,
and real asset-detail relation UI.

## Out of Scope

Reading target product payloads, cross-app search/pickers, deep-link routing into other apps,
binary attachments, automatic relation inference, and server-side graph traversal APIs.

## Rollback

The change is additive. `entity.link` already exists in LifeTrace Cloud. The client stores links
in a separate local store and can stop requesting/syncing them without changing asset/event data.
