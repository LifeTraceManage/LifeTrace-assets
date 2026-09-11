import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_assets/src/cloud/asset_sync_coordinator.dart';
import 'package:lifetrace_assets/src/cloud/cloud_session_manager.dart';
import 'package:lifetrace_assets/src/cloud/secure_session_store.dart';
import 'package:lifetrace_assets/src/cloud/sync_models.dart';
import 'package:lifetrace_assets/src/cloud/lifetrace_sync_client.dart';
import 'package:lifetrace_assets/src/data/asset_repository.dart';
import 'package:lifetrace_assets/src/domain/asset_models.dart';

class _FakeSessionAccess implements CloudSessionAccess {
  _FakeSessionAccess()
      : session = const StoredCloudSession(
          baseUrl: 'https://cloud.example.com',
          accessToken: 'token',
          accessTokenExpiresAtEpochSeconds: 4102444800,
          userId: 'user-1',
          email: 'user@example.com',
          sessionId: 'session-1',
          scopes: ['sync:read', 'sync:write', 'assets:read', 'assets:write'],
          schemaVersion: 1,
        );

  final StoredCloudSession session;

  @override
  Future<T> authorized<T>(
    Future<T> Function(StoredCloudSession session) block,
  ) =>
      block(session);

  @override
  Future<StoredCloudSession?> currentSession() async => session;

  @override
  Future<StoredCloudSession> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async =>
      session;

  @override
  Future<void> logout() async {}
}

class _FakeSyncClient implements SyncClient {
  _FakeSyncClient({this.conflict = false});

  final bool conflict;
  int pushCalls = 0;
  int snapshotCalls = 0;
  int pullCalls = 0;

  @override
  Future<SnapshotPageResult> snapshot({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    String? snapshotId,
    String? pageToken,
    int pageSize = 200,
  }) async {
    snapshotCalls++;
    return const SnapshotPageResult(
      snapshotId: 'snapshot-1',
      snapshotCursor: 'cursor-snapshot',
      items: [],
      completed: true,
    );
  }

  @override
  Future<PushBatchResult> push({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required List<OutgoingSyncChange> changes,
  }) async {
    pushCalls++;
    final change = changes.single;
    if (conflict) {
      return PushBatchResult(
        latestCursor: 'cursor-conflict',
        results: [
          PushConflict(
            changeId: change.changeId,
            entityType: change.entityType,
            entityId: change.entityId,
            conflictId: 'conflict-1',
            clientBaseServerVersion: change.baseServerVersion,
            currentServerVersion: '4',
            serverDeleted: false,
            reason: 'version_mismatch',
            serverEntity: {
              ...?change.payload,
              'currentValue': 650.0,
              'serverVersion': '4',
            },
          ),
        ],
      );
    }
    return PushBatchResult(
      latestCursor: 'cursor-push',
      results: [
        PushAccepted(
          changeId: change.changeId,
          entityType: change.entityType,
          entityId: change.entityId,
          serverVersion: '1',
          cursor: 'cursor-push',
          serverModifiedAt: '2026-09-11T00:00:00Z',
          duplicate: false,
        ),
      ],
    );
  }

  @override
  Future<PullBatchResult> pull({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required String? afterCursor,
    int limit = 100,
  }) async {
    pullCalls++;
    return const PullBatchResult(
      changes: [],
      nextCursor: 'cursor-pull',
      hasMore: false,
    );
  }
}

AssetItem _asset() {
  final now = DateTime(2026, 9, 11);
  return AssetItem(
    id: 'asset-1',
    name: 'Phone',
    brand: 'LifeTrace',
    model: 'V1',
    category: AssetCategory.phone,
    status: AssetStatus.active,
    purchasePrice: 1000,
    currentValue: 800,
    purchaseDate: DateTime(2026, 1, 1),
    warrantyUntil: DateTime(2027, 1, 1),
    spec: '',
    serialNumber: '',
    location: '',
    targetDailyCost: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('coordinator performs snapshot push and pull and acknowledges local change',
      () async {
    final repository =
        await AssetRepository.inMemory('sync-coordinator-accepted.db');
    await repository.clearAll();
    await repository.upsertAsset(_asset());

    final syncClient = _FakeSyncClient();
    final coordinator = AssetSyncCoordinator(
      repository: repository,
      sessionManager: _FakeSessionAccess(),
      syncClient: syncClient,
      deviceIdLoader: () async => 'device-1',
    );

    final summary = await coordinator.syncNow();

    expect(syncClient.snapshotCalls, 1);
    expect(syncClient.pushCalls, 1);
    expect(syncClient.pullCalls, 1);
    expect(summary.snapshotItems, 0);
    expect(summary.pushed, 1);
    expect(summary.pulled, 0);
    expect(summary.conflicts, 0);
    expect(await repository.pendingOutboxCount(), 0);
    expect((await repository.listAssets()).single.serverVersion, '1');
    expect((await repository.getSyncState()).cursor, 'cursor-pull');

    await repository.close();
  });

  test('coordinator persists optimistic conflict without losing local intent',
      () async {
    final repository =
        await AssetRepository.inMemory('sync-coordinator-conflict.db');
    await repository.clearAll();
    await repository.upsertAsset(_asset());

    final syncClient = _FakeSyncClient(conflict: true);
    final coordinator = AssetSyncCoordinator(
      repository: repository,
      sessionManager: _FakeSessionAccess(),
      syncClient: syncClient,
      deviceIdLoader: () async => 'device-1',
    );

    final summary = await coordinator.syncNow();

    expect(summary.conflicts, 1);
    expect(syncClient.pushCalls, 1);
    expect(await repository.listConflicts(), hasLength(1));
    expect(await repository.listSyncIssues(), hasLength(1));
    final outbox = await repository.listOutbox();
    expect(outbox, hasLength(1));
    expect(outbox.single['blocked'], isTrue);
    expect(outbox.single['payload'], isNotNull);

    await repository.close();
  });
}
