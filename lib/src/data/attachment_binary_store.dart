import 'dart:typed_data';

import 'attachment_binary_store_contract.dart';
import 'attachment_binary_store_stub.dart'
    if (dart.library.io) 'attachment_binary_store_io.dart'
    if (dart.library.js_interop) 'attachment_binary_store_web.dart' as platform;

export 'attachment_binary_store_contract.dart';

Future<AttachmentBinaryStore> openAttachmentBinaryStore() =>
    platform.openAttachmentBinaryStore();

class MemoryAttachmentBinaryStore implements AttachmentBinaryStore {
  final Map<String, Uint8List> _objects = <String, Uint8List>{};

  @override
  Future<void> write(String objectKey, Uint8List bytes) async {
    _objects[objectKey] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List?> read(String objectKey) async {
    final bytes = _objects[objectKey];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<bool> exists(String objectKey) async => _objects.containsKey(objectKey);

  @override
  Future<void> delete(String objectKey) async {
    _objects.remove(objectKey);
  }

  @override
  Future<void> clearAll() async {
    _objects.clear();
  }

  @override
  Future<void> close() async {}
}
