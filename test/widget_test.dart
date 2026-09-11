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
  });
}
