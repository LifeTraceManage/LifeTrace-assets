import 'package:uuid/uuid.dart';

import 'cloud_contract.dart';
import 'cloud_http_transport.dart';
import 'sync_models.dart';

class LifeTraceSyncClient {
  LifeTraceSyncClient({CloudHttpTransport? transport, Uuid? uuid})
      : _transport = transport ?? CloudHttpTransport(),
        _uuid = uuid ?? const Uuid();

  final CloudHttpTransport _transport;
  final Uuid _uuid;

  Future<PushBatchResult> push({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required List<OutgoingSyncChange> changes,
  }) async {
    final root = await _transport.requestJson(
      method: 'POST',
      baseUrl: baseUrl,
      path: '/api/v1/sync/push',
      accessToken: accessToken,
      body: {
        'requestId': _uuid.v4(),
        'client': _clientJson(client),
        'changes': changes.map((change) => {
              'changeId': change.changeId,
              'entityType': change.entityType,
              'entityId': change.entityId,
              'operation': change.operation,
              'baseServerVersion': change.baseServerVersion,
              'entitySchemaVersion': change.entitySchemaVersion,
              'clientModifiedAt': change.clientModifiedAt,
              'payload': change.payload,
              'atomicGroupId': null,
              'dependencies': const [],
            }).toList(growable: false),
      },
    );
    return PushBatchResult(
      latestCursor: root['latestCursor'] as String,
      results: (root['results'] as List<dynamic>)
          .map((value) => _parsePushResult(_map(value)))
          .toList(growable: false),
    );
  }

  Future<PullBatchResult> pull({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required String? afterCursor,
    int limit = 100,
  }) async {
    final root = await _transport.requestJson(
      method: 'POST',
      baseUrl: baseUrl,
      path: '/api/v1/sync/pull',
      accessToken: accessToken,
      body: {
        'requestId': _uuid.v4(),
        'client': _clientJson(client),
        'afterCursor': afterCursor,
        'limit': limit,
        'entityTypes': CloudContract.requiredSyncEntityTypes.toList(),
      },
    );
    return PullBatchResult(
      changes: (root['changes'] as List<dynamic>)
          .map((value) {
            final json = _map(value);
            return PulledChange(
              cursor: json['cursor'] as String,
              entityType: json['entityType'] as String,
              entityId: json['entityId'] as String,
              operation: json['operation'] as String,
              serverVersion: json['serverVersion'] as String,
              serverModifiedAt: json['serverModifiedAt'] as String,
              payload: _nullableMap(json['payload']),
            );
          })
          .toList(growable: false),
      nextCursor: root['nextCursor'] as String,
      hasMore: root['hasMore'] as bool,
    );
  }

  Future<SnapshotPageResult> snapshot({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    String? snapshotId,
    String? pageToken,
    int pageSize = 200,
  }) async {
    final root = await _transport.requestJson(
      method: 'POST',
      baseUrl: baseUrl,
      path: '/api/v1/sync/snapshot',
      accessToken: accessToken,
      body: {
        'requestId': _uuid.v4(),
        'client': _clientJson(client),
        'snapshotId': snapshotId,
        'pageToken': pageToken,
        'entityTypes': CloudContract.requiredSyncEntityTypes.toList(),
        'pageSize': pageSize,
      },
    );
    return SnapshotPageResult(
      snapshotId: root['snapshotId'] as String,
      snapshotCursor: root['snapshotCursor'] as String,
      items: (root['items'] as List<dynamic>).map((value) {
        final json = _map(value);
        return SnapshotItem(
          entityType: json['entityType'] as String,
          entityId: json['entityId'] as String,
          serverVersion: json['serverVersion'] as String,
          payload: _map(json['payload']),
        );
      }).toList(growable: false),
      nextPageToken: root['nextPageToken'] as String?,
      completed: root['completed'] as bool,
    );
  }

  Map<String, dynamic> _clientJson(SyncClientContext client) => {
        'appId': CloudContract.appId,
        'clientVersion': client.clientVersion,
        'platform': CloudContract.platform,
        'protocolVersion': CloudContract.protocolVersion,
        'schemaVersion': client.schemaVersion,
        'deviceId': client.deviceId,
      };

  PushChangeResult _parsePushResult(Map<String, dynamic> json) {
    final status = json['status'] as String;
    return switch (status) {
      'accepted' || 'duplicate' => PushAccepted(
          changeId: json['changeId'] as String,
          entityType: json['entityType'] as String,
          entityId: json['entityId'] as String,
          serverVersion: json['serverVersion'] as String,
          cursor: json['cursor'] as String,
          serverModifiedAt: json['serverModifiedAt'] as String,
          duplicate: status == 'duplicate',
        ),
      'conflict' => PushConflict(
          changeId: json['changeId'] as String,
          entityType: json['entityType'] as String,
          entityId: json['entityId'] as String,
          conflictId: json['conflictId'] as String,
          clientBaseServerVersion: json['clientBaseServerVersion'] as String,
          currentServerVersion: json['currentServerVersion'] as String,
          serverEntity: _nullableMap(json['serverEntity']),
          serverDeleted: json['serverDeleted'] as bool,
          reason: json['reason'] as String,
        ),
      'rejected' => PushRejected(
          changeId: json['changeId'] as String,
          entityType: json['entityType'] as String,
          entityId: json['entityId'] as String,
          code: json['code'] as String,
          message: json['message'] as String,
        ),
      _ => throw StateError('Unknown push result status: $status'),
    };
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Expected JSON object');
  }

  static Map<String, dynamic>? _nullableMap(Object? value) =>
      value == null ? null : _map(value);
}
