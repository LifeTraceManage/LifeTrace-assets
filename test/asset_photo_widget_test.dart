import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_assets/main.dart';
import 'package:lifetrace_assets/src/data/asset_repository.dart';
import 'package:lifetrace_assets/src/domain/asset_models.dart';

AssetItem _asset() {
  final now = DateTime(2026, 9, 20);
  return AssetItem(
    id: 'asset-photo-widget',
    name: 'Photo Camera',
    brand: 'LifeTrace',
    model: 'P1',
    category: AssetCategory.camera,
    status: AssetStatus.active,
    purchasePrice: 5000,
    currentValue: 4200,
    purchaseDate: DateTime(2026, 1, 1),
    warrantyUntil: null,
    spec: 'Black',
    serialNumber: '',
    location: 'Desk',
    targetDailyCost: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('asset detail renders persisted photo and can remove it',
      (tester) async {
    final repository =
        await AssetRepository.inMemory('asset-photo-widget-test.db');
    await repository.clearAll();
    await repository.upsertAsset(_asset());

    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2dFQAAAAASUVORK5CYII=',
    );
    await repository.addAttachmentBytes(
      ownerType: 'asset.asset',
      ownerId: 'asset-photo-widget',
      originalName: 'asset_photo.png',
      mimeType: 'image/png',
      bytes: png,
    );

    await tester.pumpWidget(LifeTraceAssetsApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo Camera').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('asset_photo.png'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('资产照片'), findsOneWidget);
    expect(find.text('asset_photo.png'), findsOneWidget);
    expect(find.byTooltip('删除照片'), findsOneWidget);

    await tester.tap(find.byTooltip('删除照片'));
    await tester.pumpAndSettle();
    expect(find.text('删除照片？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('asset_photo.png'), findsNothing);
    expect(
      await repository.listAttachments(ownerId: 'asset-photo-widget'),
      isEmpty,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await repository.close();
  });
}
