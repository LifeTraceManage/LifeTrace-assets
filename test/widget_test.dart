import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_assets/main.dart';
import 'package:lifetrace_assets/src/application/asset_app_state.dart';
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
    warrantyUntil: null,
    spec: '',
    serialNumber: '',
    location: '',
    targetDailyCost: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Future<AssetAppState> _pumpTestApp(
  WidgetTester tester,
  AssetRepository repository,
) async {
  final state = AssetAppState(repository, null, null, false);
  await tester.runAsync(state.initialize);
  await tester.pumpWidget(
    AssetScope(
      notifier: state,
      child: const MaterialApp(home: AssetShell()),
    ),
  );
  await tester.pump();
  return state;
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _disposeTestApp(
  WidgetTester tester,
  AssetAppState state,
  AssetRepository repository,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  state.dispose();
  await repository.close();
}

void main() {
  testWidgets('renders empty local-first dashboard and primary navigation', (tester) async {
    final repository = await AssetRepository.inMemory('widget-empty.db');

    final state = await _pumpTestApp(tester, repository);

    expect(find.text('我的资产'), findsOneWidget);
    expect(find.text('添加第一件资产'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('资产'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);
    expect(find.text('分析'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    await _disposeTestApp(tester, state, repository);
  });

  testWidgets('masks serial number in asset detail by default', (tester) async {
    final repository = await AssetRepository.inMemory('widget-sensitive.db');
    await tester.runAsync(() => repository.upsertAsset(_assetWithSerial()));

    final state = await _pumpTestApp(tester, repository);

    await tester.tap(find.text('Secret Phone').first);
    await _pumpRouteTransition(tester);

    expect(find.text('1234••••7890'), findsOneWidget);
    expect(find.text('1234567890'), findsNothing);
    expect(find.byTooltip('复制完整序列号'), findsOneWidget);

    await _disposeTestApp(tester, state, repository);
  });

  testWidgets('renders persisted EntityLink and opens real add-link form',
      (tester) async {
    final repository = await AssetRepository.inMemory('widget-links.db');
    await tester.runAsync(() => repository.upsertAsset(_assetWithSerial()));
    await tester.runAsync(() => repository.bindCloudUser('user-1'));
    final now = DateTime(2026, 9, 11);
    await tester.runAsync(
      () => repository.upsertLink(
        AssetEntityLink(
          id: 'link-widget',
          userId: 'user-1',
          sourceAssetId: 'asset-secret',
          targetEntityType: 'execution.project',
          targetEntityId: 'project-42',
          relationType: 'references',
          targetLabel: 'Project 42',
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );

    final state = await _pumpTestApp(tester, repository);

    await tester.tap(find.text('Secret Phone').first);
    await _pumpRouteTransition(tester);
    await tester.scrollUntilVisible(
      find.text('Project 42'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Project 42'), findsOneWidget);
    expect(find.textContaining('execution.project'), findsOneWidget);
    expect(find.textContaining('project-42'), findsOneWidget);
    expect(find.byTooltip('删除关联'), findsOneWidget);

    await tester.tap(find.text('添加关联').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('添加跨应用关联'), findsOneWidget);
    expect(find.text('目标实体 ID'), findsOneWidget);
    expect(find.text('显示名称（可选）'), findsOneWidget);
    expect(find.text('关联关系'), findsOneWidget);
    expect(
      find.textContaining('Assets 只保存目标类型与 ID'),
      findsOneWidget,
    );

    Navigator.of(tester.element(find.text('添加跨应用关联'))).pop();
    await tester.pump();
    await _disposeTestApp(tester, state, repository);
  });

  testWidgets('asset library supports brand search and status filtering', (tester) async {
    final repository = await AssetRepository.inMemory('widget-query.db');
    await tester.runAsync(
      () => repository.upsertAsset(
        _queryAsset(
          id: 'xiaomi',
          name: 'Xiaomi Phone',
          brand: 'Xiaomi',
          status: AssetStatus.active,
        ),
      ),
    );
    await tester.runAsync(
      () => repository.upsertAsset(
        _queryAsset(
          id: 'sony',
          name: 'Sony Camera',
          brand: 'Sony',
          status: AssetStatus.idle,
        ),
      ),
    );

    final state = await _pumpTestApp(tester, repository);

    await tester.tap(find.text('资产').last);
    await tester.pump(const Duration(milliseconds: 400));

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
    await tester.tap(find.text('闲置').first);
    await tester.pump();

    expect(find.text('Sony Camera'), findsOneWidget);
    expect(find.text('Xiaomi Phone'), findsNothing);
    expect(find.text('共 1 件资产'), findsOneWidget);

    await _disposeTestApp(tester, state, repository);
  });
}
