import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

import '../domain/asset_models.dart';
import 'local_database.dart';

class AssetRepository {
  AssetRepository._(this._db);

  final Database _db;

  static final StoreRef<String, Map<String, Object?>> _assetStore =
      stringMapStoreFactory.store('assets');
  static final StoreRef<String, Map<String, Object?>> _eventStore =
      stringMapStoreFactory.store('asset_events');
  static final StoreRef<String, Map<String, Object?>> _outboxStore =
      stringMapStoreFactory.store('sync_outbox');

  static Future<AssetRepository> open() async {
    return AssetRepository._(await openAssetDatabase());
  }

  static Future<AssetRepository> inMemory() async {
    return AssetRepository._(
      await databaseFactoryMemory.openDatabase('lifetrace_assets_test.db'),
    );
  }

  Future<List<AssetItem>> listAssets({bool includeDeleted = false}) async {
    final records = await _assetStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('updatedAt', false)]),
    );
    return records
        .map((record) => AssetItem.fromJson(Map<String, Object?>.from(record.value)))
        .where((asset) => includeDeleted || !asset.isDeleted)
        .toList(growable: false);
  }

  Future<List<AssetEvent>> listEvents({bool includeDeleted = false}) async {
    final records = await _eventStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('date', false)]),
    );
    return records
        .map((record) => AssetEvent.fromJson(Map<String, Object?>.from(record.value)))
        .where((event) => includeDeleted || !event.isDeleted)
        .toList(growable: false);
  }

  Future<int> pendingOutboxCount() => _outboxStore.count(_db);

  Future<List<Map<String, Object?>>> listOutbox() async {
    final records = await _outboxStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('clientModifiedAt')]),
    );
    return records
        .map((record) => Map<String, Object?>.from(record.value))
        .toList(growable: false);
  }

  Future<AssetItem> upsertAsset(AssetItem asset) async {
    final now = DateTime.now();
    final normalized = asset.copyWith(
      updatedAt: now,
      createdAt: asset.createdAt,
      isDeleted: false,
    );
    await _db.transaction((txn) async {
      await _assetStore.record(normalized.id).put(txn, normalized.toJson());
      await _enqueue(
        txn,
        entityType: 'asset.asset',
        entityId: normalized.id,
        operation: 'upsert',
        payload: normalized.toJson(),
        baseServerVersion: normalized.serverVersion,
        modifiedAt: now,
      );
    });
    return normalized;
  }

  Future<void> deleteAsset(String assetId) async {
    final now = DateTime.now();
    await _db.transaction((txn) async {
      final raw = await _assetStore.record(assetId).get(txn);
      if (raw == null) return;
      final asset = AssetItem.fromJson(Map<String, Object?>.from(raw));
      if (asset.isDeleted) return;

      final deleted = asset.copyWith(isDeleted: true, updatedAt: now);
      await _assetStore.record(assetId).put(txn, deleted.toJson());
      await _enqueue(
        txn,
        entityType: 'asset.asset',
        entityId: assetId,
        operation: 'delete',
        payload: null,
        baseServerVersion: asset.serverVersion,
        modifiedAt: now,
      );

      final related = await _eventStore.find(
        txn,
        finder: Finder(filter: Filter.equals('assetId', assetId)),
      );
      for (final record in related) {
        final event = AssetEvent.fromJson(Map<String, Object?>.from(record.value));
        if (event.isDeleted) continue;
        final deletedEvent = event.copyWith(isDeleted: true, updatedAt: now);
        await _eventStore.record(event.id).put(txn, deletedEvent.toJson());
        await _enqueue(
          txn,
          entityType: 'asset.event',
          entityId: event.id,
          operation: 'delete',
          payload: null,
          baseServerVersion: event.serverVersion,
          modifiedAt: now,
        );
      }
    });
  }

  Future<AssetEvent> upsertEvent(AssetEvent event) async {
    final now = DateTime.now();
    final normalized = event.copyWith(
      updatedAt: now,
      createdAt: event.createdAt,
      isDeleted: false,
    );

    await _db.transaction((txn) async {
      final assetRaw = await _assetStore.record(normalized.assetId).get(txn);
      if (assetRaw == null) {
        throw StateError('Cannot add an event to a missing asset.');
      }
      final asset = AssetItem.fromJson(Map<String, Object?>.from(assetRaw));
      if (asset.isDeleted) {
        throw StateError('Cannot add an event to a deleted asset.');
      }

      await _eventStore.record(normalized.id).put(txn, normalized.toJson());
      await _enqueue(
        txn,
        entityType: 'asset.event',
        entityId: normalized.id,
        operation: 'upsert',
        payload: normalized.toJson(),
        baseServerVersion: normalized.serverVersion,
        modifiedAt: now,
      );
      await _recalculateAsset(txn, normalized.assetId, now);
    });

    return normalized;
  }

  Future<void> deleteEvent(String eventId) async {
    final now = DateTime.now();
    await _db.transaction((txn) async {
      final raw = await _eventStore.record(eventId).get(txn);
      if (raw == null) return;
      final event = AssetEvent.fromJson(Map<String, Object?>.from(raw));
      if (event.isDeleted) return;

      final deleted = event.copyWith(isDeleted: true, updatedAt: now);
      await _eventStore.record(eventId).put(txn, deleted.toJson());
      await _enqueue(
        txn,
        entityType: 'asset.event',
        entityId: eventId,
        operation: 'delete',
        payload: null,
        baseServerVersion: event.serverVersion,
        modifiedAt: now,
      );
      await _recalculateAsset(txn, event.assetId, now);
    });
  }

  Future<void> _recalculateAsset(
    Transaction txn,
    String assetId,
    DateTime now,
  ) async {
    final assetRaw = await _assetStore.record(assetId).get(txn);
    if (assetRaw == null) return;
    final asset = AssetItem.fromJson(Map<String, Object?>.from(assetRaw));
    if (asset.isDeleted) return;

    final records = await _eventStore.find(
      txn,
      finder: Finder(
        filter: Filter.equals('assetId', assetId),
        sortOrders: [SortOrder('date')],
      ),
    );
    final events = records
        .map((record) => AssetEvent.fromJson(Map<String, Object?>.from(record.value)))
        .where((event) => !event.isDeleted)
        .toList(growable: false);

    var maintenanceCost = 0.0;
    var recoveredAmount = 0.0;
    var currentValue = asset.currentValue;
    var status = asset.status;

    for (final event in events) {
      final amount = event.amount ?? 0;
      switch (event.type) {
        case AssetEventType.maintenance:
        case AssetEventType.repair:
        case AssetEventType.replacement:
          if (amount > 0) maintenanceCost += amount;
          if (event.type == AssetEventType.repair) {
            status = AssetStatus.repair;
          }
          break;
        case AssetEventType.sell:
          if (amount > 0) recoveredAmount += amount;
          status = AssetStatus.sold;
          break;
        case AssetEventType.valuation:
          if (event.amount != null && event.amount! >= 0) {
            currentValue = event.amount!;
          }
          break;
        case AssetEventType.idle:
          status = AssetStatus.idle;
          break;
        case AssetEventType.lend:
          status = AssetStatus.lent;
          break;
        case AssetEventType.returnItem:
        case AssetEventType.useStart:
          status = AssetStatus.active;
          break;
        case AssetEventType.retire:
          status = AssetStatus.retired;
          break;
        case AssetEventType.purchase:
        case AssetEventType.note:
          break;
      }
    }

    final updated = asset.copyWith(
      maintenanceCost: maintenanceCost,
      recoveredAmount: recoveredAmount,
      currentValue: currentValue,
      status: status,
      updatedAt: now,
    );
    await _assetStore.record(assetId).put(txn, updated.toJson());
    await _enqueue(
      txn,
      entityType: 'asset.asset',
      entityId: assetId,
      operation: 'upsert',
      payload: updated.toJson(),
      baseServerVersion: updated.serverVersion,
      modifiedAt: now,
    );
  }

  Future<void> _enqueue(
    Transaction txn, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?>? payload,
    required int baseServerVersion,
    required DateTime modifiedAt,
  }) async {
    final item = SyncOutboxItem(
      id: newEntityId('change'),
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      baseServerVersion: baseServerVersion,
      clientModifiedAt: modifiedAt,
    );
    await _outboxStore.record(item.id).put(txn, item.toJson());
  }

  Future<void> clearAll() async {
    await _db.transaction((txn) async {
      await _assetStore.delete(txn);
      await _eventStore.delete(txn);
      await _outboxStore.delete(txn);
    });
  }

  Future<void> close() => _db.close();
}
