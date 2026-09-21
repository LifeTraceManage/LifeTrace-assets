import 'dart:convert';
import 'dart:typed_data';

import 'package:sembast_web/sembast_web.dart';

import 'attachment_binary_store_contract.dart';

Future<AttachmentBinaryStore> openAttachmentBinaryStore() async {
  final database =
      await databaseFactoryWeb.openDatabase('lifetrace_assets_attachments.db');
  return _WebAttachmentBinaryStore(database);
}

class _WebAttachmentBinaryStore implements AttachmentBinaryStore {
  _WebAttachmentBinaryStore(this._database);

  final Database _database;
  static final StoreRef<String, String> _store =
      StoreRef<String, String>('attachment_binary_objects');

  @override
  Future<void> write(String objectKey, Uint8List bytes) async {
    await _store.record(objectKey).put(_database, base64Encode(bytes));
  }

  @override
  Future<Uint8List?> read(String objectKey) async {
    final encoded = await _store.record(objectKey).get(_database);
    if (encoded == null) return null;
    return Uint8List.fromList(base64Decode(encoded));
  }

  @override
  Future<bool> exists(String objectKey) async =>
      await _store.record(objectKey).get(_database) != null;

  @override
  Future<void> delete(String objectKey) async {
    await _store.record(objectKey).delete(_database);
  }

  @override
  Future<void> clearAll() async {
    await _store.delete(_database);
  }

  @override
  Future<void> close() => _database.close();
}
