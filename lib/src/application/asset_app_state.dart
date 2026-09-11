import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/asset_repository.dart';
import '../domain/asset_models.dart';

class AssetAppState extends ChangeNotifier {
  AssetAppState(this.repository);

  final AssetRepository repository;

  bool _loading = true;
  Object? _error;
  List<AssetItem> _assets = const [];
  List<AssetEvent> _events = const [];
  int _pendingSyncCount = 0;

  bool get loading => _loading;
  Object? get error => _error;
  List<AssetItem> get assets => _assets;
  List<AssetEvent> get events => _events;
  int get pendingSyncCount => _pendingSyncCount;

  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _reload(notify: false);
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  AssetItem? assetById(String id) {
    for (final asset in _assets) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  List<AssetEvent> eventsFor(String assetId) {
    return _events.where((event) => event.assetId == assetId).toList(growable: false);
  }

  Future<void> saveAsset(AssetItem asset) async {
    await repository.upsertAsset(asset);
    await _reload();
  }

  Future<void> deleteAsset(String assetId) async {
    await repository.deleteAsset(assetId);
    await _reload();
  }

  Future<void> saveEvent(AssetEvent event) async {
    await repository.upsertEvent(event);
    await _reload();
  }

  Future<void> deleteEvent(String eventId) async {
    await repository.deleteEvent(eventId);
    await _reload();
  }

  Future<void> resetLocalData() async {
    await repository.clearAll();
    await _reload();
  }

  Future<void> retryLoad() => initialize();

  Future<void> _reload({bool notify = true}) async {
    _assets = await repository.listAssets();
    final validAssetIds = _assets.map((asset) => asset.id).toSet();
    _events = (await repository.listEvents())
        .where((event) => validAssetIds.contains(event.assetId))
        .toList(growable: false);
    _pendingSyncCount = await repository.pendingOutboxCount();
    _error = null;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    repository.close();
    super.dispose();
  }
}

class AssetScope extends InheritedNotifier<AssetAppState> {
  const AssetScope({
    required AssetAppState notifier,
    required super.child,
    super.key,
  }) : super(notifier: notifier);

  static AssetAppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AssetScope>();
    assert(scope != null, 'AssetScope is missing above this context.');
    return scope!.notifier!;
  }
}
