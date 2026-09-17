## Context

The Assets client currently syncs only `asset.asset` and `asset.event`. LifeTrace Cloud already
contains a typed generic `entity.link` DTO:

- `meta`: EntityMeta
- `source`: EntityRef
- `target`: EntityRef
- `relationType`: stable extensible relation string
- `metadata`: optional JSON

The Cloud currently authorizes `entity.link` through account scopes, which is too broad for the
least-privilege Assets app. A companion Cloud change introduces dedicated link scopes.

## Local Model

`AssetEntityLink` stores:

- id
- userId
- sourceAssetId
- targetEntityType
- targetEntityId
- relationType
- targetLabel
- createdAt / updatedAt
- localVersion
- serverVersion
- isDeleted

The local model is intentionally asset-oriented. Wire serialization converts it to the generic
Cloud EntityLink shape with `source.entityType = asset.asset`.

## Ownership

Creating a cross-app link requires a known bound LifeTrace Cloud user ID. This can come from the
current session or the repository's persisted Cloud binding. Therefore a previously bound user can
create links while offline.

The client MUST NOT request unrelated product read/write scopes merely to create a reference.

## Persistence

Add a dedicated Sembast `entity_links` store. Link writes and outbox writes occur in the same
repository transaction.

Deleting an asset soft-deletes all active source links and enqueues matching `entity.link`
deletes.

## Sync

Add `entity.link` to the Assets sync allow-list.

Read/write participation is derived from the currently granted session scopes:
- `asset.asset` and `asset.event` remain the core entity set.
- `entity.link` is included in Snapshot/Pull only with `links:read`.
- `entity.link` outbox heads are pushable only with `links:write`.
- A legacy session without link scopes continues core asset/event synchronization and leaves link
  mutations pending rather than failing the whole sync cycle.

For wire payloads:
- `meta.serverVersion` carries the Cloud version.
- local repository bookkeeping may remain flattened.
- acknowledgement/rebase logic must update nested `meta.serverVersion` for link payloads.

Snapshot and pull apply link payloads through strict parsing. Remote links whose source is not an
`asset.asset` are ignored by the Assets repository rather than exposed as local asset links.

## UI

The asset detail "关联内容" section becomes data-driven.

Each row shows:
- optional target label
- target entity type
- target entity ID
- relation type
- delete action

The add flow collects:
- target domain/entity type
- target entity ID
- relation type
- optional display label

No fake target title or target payload is invented.

## Backup

Backup format advances from version 1 to version 2 and includes `links`. Restore accepts both
version 1 and version 2; version 1 restores with an empty link set. Restored links reset
serverVersion to `0` and are re-enqueued.

## Testing

- model wire serialization/parsing
- repository CRUD and asset-delete cascade
- backup v1/v2 compatibility
- accepted acknowledgement and rebase for nested link server version
- snapshot/pull of entity.link
- widget acceptance for add/remove relation
