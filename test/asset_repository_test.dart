import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_assets/src/data/asset_repository.dart';
import 'package:lifetrace_assets/src/domain/asset_models.dart';

AssetItem makeAsset({
  String id = 'asset-1',
  double purchasePrice = 1000,
  double currentValue = 800,
}) {
  final now = DateTime(2026, 9, 11, 12);
  return AssetItem(
    id: id,
    name: 'Test Asset',
    brand: 'LifeTrace',
    model: 'V1',
    category: AssetCategory.other,
    status: AssetStatus.active,
    purchasePrice: purchasePrice,
    currentValue: currentValue,
    purchaseDate: DateTime(2026, 1, 1),
    warrantyUntil: DateTime(2027, 1, 1),
    spec: 'test',
    serialNumber: 'SN-1',
    location: 'desk',
    targetDailyCost: 5,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('AssetRepository', () {
    late AssetRepository repository;

    setUp(() async {
      repository = await AssetRepository.inMemory();
      await repository.clearAll();
    });

    tearDown(() async {
      await repository.close();
    });

    test('persists asset and queues sync mutation', () async {
      final saved = await repository.upsertAsset(makeAsset());

      final assets = await repository.listAssets();
      final outbox = await repository.listOutbox();

      expect(assets, hasLength(1));
      expect(assets.single.id, saved.id);
      expect(outbox, hasLength(1));
      expect(outbox.single['entityType'], 'asset.asset');
      expect(outbox.single['operation'], 'upsert');
    });

    test('lifecycle maintenance and sale update derived asset totals', () async {
      await repository.upsertAsset(makeAsset());
      final now = DateTime(2026, 9, 11, 13);

      await repository.upsertEvent(
        AssetEvent(
          id: 'event-maintenance',
          assetId: 'asset-1',
          type: AssetEventType.maintenance,
          date: now,
          title: 'Maintenance',
          detail: 'battery',
          amount: 100,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.upsertEvent(
        AssetEvent(
          id: 'event-sale',
          assetId: 'asset-1',
          type: AssetEventType.sell,
          date: now.add(const Duration(hours: 1)),
          title: 'Sold',
          detail: 'marketplace',
          amount: 300,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final asset = (await repository.listAssets()).single;
      expect(asset.maintenanceCost, 100);
      expect(asset.recoveredAmount, 300);
      expect(asset.status, AssetStatus.sold);
      expect(asset.effectiveCost, 800);
      expect(await repository.pendingOutboxCount(), 5);
    });

    test('deleting asset hides asset and its events but retains tombstones', () async {
      await repository.upsertAsset(makeAsset());
      final now = DateTime(2026, 9, 11, 13);
      await repository.upsertEvent(
        AssetEvent(
          id: 'event-1',
          assetId: 'asset-1',
          type: AssetEventType.note,
          date: now,
          title: 'Note',
          detail: 'detail',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.deleteAsset('asset-1');

      expect(await repository.listAssets(), isEmpty);
      expect(await repository.listEvents(), isEmpty);
      final allAssets = await repository.listAssets(includeDeleted: true);
      final allEvents = await repository.listEvents(includeDeleted: true);
      expect(allAssets.single.isDeleted, isTrue);
      expect(allEvents.single.isDeleted, isTrue);
      expect((await repository.listOutbox()).where((item) => item['operation'] == 'delete'), hasLength(2));
    });
  });

  group('AssetItem calculations', () {
    test('effective cost never becomes negative', () {
      final asset = makeAsset().copyWith(
        maintenanceCost: 50,
        recoveredAmount: 5000,
      );

      expect(asset.effectiveCost, 0);
      expect(asset.dailyCost, 0);
    });

    test('retention is zero for zero purchase price', () {
      final asset = makeAsset(purchasePrice: 0, currentValue: 100);
      expect(asset.retentionRate, 0);
    });
  });
}
