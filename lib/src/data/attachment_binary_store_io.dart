import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'attachment_binary_store_contract.dart';

Future<AttachmentBinaryStore> openAttachmentBinaryStore() async {
  final support = await getApplicationSupportDirectory();
  final root = Directory(p.join(support.path, 'asset_attachments'));
  if (!await root.exists()) {
    await root.create(recursive: true);
  }
  return _NativeAttachmentBinaryStore(root);
}

class _NativeAttachmentBinaryStore implements AttachmentBinaryStore {
  _NativeAttachmentBinaryStore(this._root);

  final Directory _root;

  File _file(String objectKey) {
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(objectKey)) {
      throw const FormatException('Invalid attachment object key.');
    }
    return File(p.join(_root.path, objectKey));
  }

  @override
  Future<void> write(String objectKey, Uint8List bytes) async {
    await _file(objectKey).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> read(String objectKey) async {
    final file = _file(objectKey);
    if (!await file.exists()) return null;
    return Uint8List.fromList(await file.readAsBytes());
  }

  @override
  Future<bool> exists(String objectKey) => _file(objectKey).exists();

  @override
  Future<void> delete(String objectKey) async {
    final file = _file(objectKey);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> clearAll() async {
    if (await _root.exists()) {
      await _root.delete(recursive: true);
    }
    await _root.create(recursive: true);
  }

  @override
  Future<void> close() async {}
}
