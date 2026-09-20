import 'dart:typed_data';

abstract interface class AttachmentBinaryStore {
  Future<void> write(String objectKey, Uint8List bytes);

  Future<Uint8List?> read(String objectKey);

  Future<bool> exists(String objectKey);

  Future<void> delete(String objectKey);

  Future<void> clearAll();

  Future<void> close();
}
