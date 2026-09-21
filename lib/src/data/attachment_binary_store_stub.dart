import 'dart:typed_data';

import 'attachment_binary_store_contract.dart';

Future<AttachmentBinaryStore> openAttachmentBinaryStore() async =>
    _UnsupportedAttachmentBinaryStore();

class _UnsupportedAttachmentBinaryStore implements AttachmentBinaryStore {
  Never _unsupported() =>
      throw UnsupportedError('Attachment binary storage is unavailable.');

  @override
  Future<void> write(String objectKey, Uint8List bytes) async => _unsupported();

  @override
  Future<Uint8List?> read(String objectKey) async => _unsupported();

  @override
  Future<bool> exists(String objectKey) async => _unsupported();

  @override
  Future<void> delete(String objectKey) async => _unsupported();

  @override
  Future<void> clearAll() async => _unsupported();

  @override
  Future<void> close() async {}
}
