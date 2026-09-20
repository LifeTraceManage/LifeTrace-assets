import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_assets/src/data/asset_repository.dart';
import 'package:lifetrace_assets/src/domain/asset_attachment.dart';
import 'package:lifetrace_assets/src/domain/asset_models.dart';

AssetItem _asset(String id) {
  final now = DateTime(2026, 9, 20);
  return AssetItem(
    id: id,
    name: 'Camera',
    brand: 'LifeTrace',
    model: 'Photo',
    category: AssetCategory.camera,
    status: AssetStatus.active,
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

void main() {
  test('attachment create persists exact bytes and durable upload operation',
      () async {
    final repository =
        await AssetRepository.inMemory('attachment-create-test.db');
    await repository.clearAll();
    await repository.upsertAsset(_asset('asset-photo'));

    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 255]);
    final attachment = await repository.addAttachmentBytes(
      ownerType: 'asset.asset',
      ownerId: 'asset-photo',
      originalName: 'device.jpg',
      mimeType: 'image/jpeg',
      bytes: bytes,
    );

    final attachments =
        await repository.listAttachments(ownerId: 'asset-photo');
    expect(attachments, hasLength(1));
    expect(attachments.single.id, attachment.id);
    expect(
      attachments.single.transferState,
      AssetAttachmentTransferState.pendingUpload,
    );
    expect(attachments.single.sha256, hasLength(64));
    expect(
      await repository.readAttachmentBytes(attachment.id),
      orderedEquals(bytes),
    );

    final operations = await repository.listAttachmentOperations();
    expect(operations, hasLength(1));
    expect(operations.single.attachmentId, attachment.id);
    expect(operations.single.type, AssetAttachmentOperationType.upload);

    await repository.close();
  });

  test('deleting a local-only attachment removes bytes and queued upload',
      () async {
    final repository =
        await AssetRepository.inMemory('attachment-delete-test.db');
    await repository.clearAll();
    await repository.upsertAsset(_asset('asset-delete'));

    final attachment = await repository.addAttachmentBytes(
      ownerType: 'asset.asset',
      ownerId: 'asset-delete',
      originalName: 'delete.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList(<int>[9, 8, 7]),
    );

    await repository.deleteAttachment(attachment.id);

    expect(
      await repository.listAttachments(
        ownerId: 'asset-delete',
        includeHidden: true,
      ),
      isEmpty,
    );
    expect(await repository.readAttachmentBytes(attachment.id), isNull);
    expect(await repository.listAttachmentOperations(), isEmpty);

    await repository.close();
  });

  test('deleting an asset cascades its local attachments and operations',
      () async {
    final repository =
        await AssetRepository.inMemory('attachment-cascade-test.db');
    await repository.clearAll();
    await repository.upsertAsset(_asset('asset-cascade'));

    final attachment = await repository.addAttachmentBytes(
      ownerType: 'asset.asset',
      ownerId: 'asset-cascade',
      originalName: 'cascade.webp',
      mimeType: 'image/webp',
      bytes: Uint8List.fromList(<int>[4, 3, 2, 1]),
    );

    await repository.deleteAsset('asset-cascade');

    expect(
      await repository.listAttachments(
        ownerId: 'asset-cascade',
        includeHidden: true,
      ),
      isEmpty,
    );
    expect(await repository.readAttachmentBytes(attachment.id), isNull);
    expect(await repository.listAttachmentOperations(), isEmpty);

    await repository.close();
  });

  test('backup v3 keeps attachment manifest without local binary payload',
      () async {
    final source = await AssetRepository.inMemory('attachment-backup-src.db');
    await source.clearAll();
    await source.upsertAsset(_asset('asset-backup'));
    await source.addAttachmentBytes(
      ownerType: 'asset.asset',
      ownerId: 'asset-backup',
      originalName: 'backup.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[10, 20, 30, 40]),
    );

    final raw = await source.exportBackupJson();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    expect(json['version'], 3);
    final manifest = json['attachments'] as List<dynamic>;
    expect(manifest, hasLength(1));
    final entry = manifest.single as Map<String, dynamic>;
    expect(entry['originalName'], 'backup.jpg');
    expect(entry['localObjectKey'], isNull);
    expect(entry.containsKey('bytes'), isFalse);

    final restored =
        await AssetRepository.inMemory('attachment-backup-dst.db');
    await restored.clearAll();
    await restored.importBackupJson(raw);

    final attachments =
        await restored.listAttachments(ownerId: 'asset-backup');
    expect(attachments, hasLength(1));
    expect(
      attachments.single.transferState,
      AssetAttachmentTransferState.unavailable,
    );
    expect(
      await restored.readAttachmentBytes(attachments.single.id),
      isNull,
    );
    expect(await restored.listAttachmentOperations(), isEmpty);

    await source.close();
    await restored.close();
  });

  test('rejects unsupported MIME and oversized photo before persistence',
      () async {
    final repository =
        await AssetRepository.inMemory('attachment-policy-test.db');
    await repository.clearAll();
    await repository.upsertAsset(_asset('asset-policy'));

    expect(
      () => repository.addAttachmentBytes(
        ownerType: 'asset.asset',
        ownerId: 'asset-policy',
        originalName: 'script.exe',
        mimeType: 'application/x-msdownload',
        bytes: Uint8List.fromList(<int>[1]),
      ),
      throwsA(isA<FormatException>()),
    );

    expect(
      () => repository.addAttachmentBytes(
        ownerType: 'asset.asset',
        ownerId: 'asset-policy',
        originalName: 'huge.jpg',
        mimeType: 'image/jpeg',
        bytes: Uint8List(AssetRepository.maxAttachmentBytes + 1),
      ),
      throwsA(isA<FormatException>()),
    );

    expect(await repository.listAttachments(), isEmpty);
    expect(await repository.listAttachmentOperations(), isEmpty);

    await repository.close();
  });
}
