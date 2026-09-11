import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_assets/main.dart';
import 'package:lifetrace_assets/src/data/asset_repository.dart';
import 'package:lifetrace_assets/src/domain/asset_models.dart';

AssetItem _assetWithSerial() {
  final now = DateTime(2026, 9, 11);
  return AssetItem(
    id: 'asset-secret',
    name: 'Secret Phone',
    brand: 'LifeTrace',
    model: 'V1',
    category: AssetCategory.phone,
    status: AssetStatus.active,
    purchasePrice: 5999,
    currentValue: 4500,
    purchaseDate: DateTime(2026, 1, 1),
    warrantyUntil: DateTime(2027, 1, 1),
    spec: '16GB + 512GB',
    serialNumber: '1234567890',
    location: '随身',
    targetDailyCost: 10,
    createdAt: now,
    updatedAt: now,
  );
}

AssetItem _queryAsset({
  required String id,
  required String name,
  required String brand,
  required AssetStatus status,
}) {
  final now = DateTime(2026, 9, 11);
  return AssetItem(
    id: id,
    name: name,
    brand: brand,
    model: 'Model',
    category: AssetCategory.other,
    status: status,
    purchasePrice: 1000,
    currentValue: 800,
    purchaseDate: DateTime(2026, 1, 1),
    spec: '',
    serialNumber: '',
    location: '',
    targetDailyCost: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('renders empty local-first dashboard and primary navigation', (tester) async {
    final repository = await AssetRepository.inMemory('widget-empty.db');
    await repository.clearAll();

    await tester.pumpWidget(LifeTraceAssetsApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('我的资产'), findsOneWidget);
    expect(find.text('添加第一件资产'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('资产'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);
    expect(find.text('分析'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('masks serial number in asset detail by default', (tester) async {
    final repository = await AssetRepository.inMemory('widget-sensitive.db');
    await repository.clearAll();
    await repository.upsertAsset(_assetWithSerial());

    await tester.pumpWidget(LifeTraceAssetsApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Secret Phone').first);
    await tester.pumpAndSettle();

    expect(find.text('1234••••7890'), findsOneWidget);
    expect(find.text('1234567890'), findsNothing);
    expect(find.byTooltip('复制完整序列号'), findsOneWidget);
  });  testWidgets('asset library supports brand search and status filtering', (tester) async {
    final repository = await AssetRepository.inMemory('widget-query.db');
    await repository.clearAll();
    await repository.upsertAsset(
      _queryAsset(
        id: 'xiaomi',
        name: 'Xiaomi Phone',
        brand: 'Xiaomi',
        status: AssetStatus.active,
      ),
    );
    await repository.upsertAsset(
      _queryAsset(
        id: 'sony',
        name: 'Sony Camera',
        brand: 'Sony',
        status: AssetStatus.idle,
      ),
    );

    await tester.pumpWidget(LifeTraceAssetsApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('资产').last);
    await tester.pumpAndSettle();

    expect(find.text('Xiaomi Phone'), findsOneWidget);
    expect(find.text('Sony Camera'), findsOneWidget);

    final search = find.byType(TextField).first;
    await tester.enterText(search, 'xiaomi');
    await tester.pump();

    expect(find.text('Xiaomi Phone'), findsOneWidget);
    expect(find.text('Sony Camera'), findsNothing);
    expect(find.text('共 1 件资产'), findsOneWidget);

    await tester.enterText(search, '');
    await tester.pump();
    await tester.tap(find.text('闲置'));
    await tester.pump();

    expect(find.text('Sony Camera'), findsOneWidget);
    expect(find.text('Xiaomi Phone'), findsNothing);
    expect(find.text('共 1 件资产'), findsOneWidget);
  });


}
