import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'src/application/asset_app_state.dart';
import 'src/data/asset_repository.dart';
import 'src/domain/asset_models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LifeTraceAssetsApp());
}

class LifeTraceAssetsApp extends StatefulWidget {
  const LifeTraceAssetsApp({this.repository, super.key});

  final AssetRepository? repository;

  @override
  State<LifeTraceAssetsApp> createState() => _LifeTraceAssetsAppState();
}

class _LifeTraceAssetsAppState extends State<LifeTraceAssetsApp> {
  late final Future<AssetAppState> _bootstrap = _createState();

  Future<AssetAppState> _createState() async {
    final repository = widget.repository ?? await AssetRepository.open();
    final state = AssetAppState(repository);
    await state.initialize();
    return state;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LifeTrace Assets',
      theme: _buildTheme(),
      home: FutureBuilder<AssetAppState>(
        future: _bootstrap,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _BootstrapError(error: snapshot.error!);
          }
          final state = snapshot.data;
          if (state == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return AssetScope(notifier: state, child: const AssetShell());
        },
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storage_outlined, size: 42),
              const SizedBox(height: 12),
              Text('本地数据初始化失败', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

ThemeData _buildTheme() {
  // LifeTrace Assets: white surfaces, black hierarchy, yellow emphasis.
  const primary = Color(0xFFF5C400);
  const ink = Color(0xFF111111);
  const background = Color(0xFFF8F8F4);
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: primary,
      onPrimary: ink,
      primaryContainer: const Color(0xFFFFF0A3),
      onPrimaryContainer: ink,
      secondary: ink,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFF0F0EA),
      onSecondaryContainer: ink,
      tertiary: const Color(0xFFB98500),
      onTertiary: ink,
      surface: Colors.white,
      onSurface: ink,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF4F4EF),
      surfaceContainer: const Color(0xFFF2F2ED),
      outline: const Color(0xFFD2D2C8),
      outlineVariant: const Color(0xFFE6E6DF),
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFFFE071),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: ink,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: ink,
    ),
    fontFamilyFallback: const [
      'Noto Sans SC',
      'PingFang SC',
      'Microsoft YaHei',
      'sans-serif',
    ],
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
      headlineMedium: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45),
      bodyMedium: TextStyle(fontSize: 13, height: 1.4),
      bodySmall: TextStyle(fontSize: 11, height: 1.35),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE6E6DE)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF2F2EC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
  );
}

List<AssetItem> _assets(BuildContext context) => AssetScope.of(context).assets;
List<AssetEvent> _events(BuildContext context) => AssetScope.of(context).events;

class AssetShell extends StatefulWidget {
  const AssetShell({super.key});

  @override
  State<AssetShell> createState() => _AssetShellState();
}

class _AssetShellState extends State<AssetShell> {
  int _index = 0;

  void _openAsset(AssetItem asset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AssetDetailScreen(asset: asset)),
    );
  }

  void _openEditor([AssetItem? asset]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AssetEditorScreen(asset: asset)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DashboardScreen(
        onOpenAsset: _openAsset,
        onAddAsset: () => _openEditor(),
        onSeeAll: () => setState(() => _index = 1),
      ),
      AssetListScreen(onOpenAsset: _openAsset, onAddAsset: () => _openEditor()),
      ActivityScreen(onOpenAsset: _openAsset),
      const AnalyticsScreen(),
      const ProfileScreen(),
    ];

    final scaffold = Scaffold(
      body: SafeArea(child: screens[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: '资产'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: '记录'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: '分析'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) return scaffold;
        final height = math.min(900.0, constraints.maxHeight - 32);
        return ColoredBox(
          color: const Color(0xFFF1F1EA),
          child: Center(
            child: Container(
              width: 430,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFD9D9D0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x22111111), blurRadius: 32, offset: Offset(0, 14)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: scaffold,
            ),
          ),
        );
      },
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.onOpenAsset,
    required this.onAddAsset,
    required this.onSeeAll,
    super.key,
  });

  final ValueChanged<AssetItem> onOpenAsset;
  final VoidCallback onAddAsset;
  final VoidCallback onSeeAll;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AssetCategory? _category;

  @override
  Widget build(BuildContext context) {
    final totalPurchase = _assets(context).fold<double>(0, (sum, item) => sum + item.purchasePrice);
    final totalValue = _assets(context).fold<double>(0, (sum, item) => sum + item.currentValue);
    final visible = _category == null ? _assets(context) : _assets(context).where((e) => e.category == _category).toList();
    final expiring = _assets(context).where((e) {
      final warranty = e.warrantyUntil;
      if (warranty == null) return false;
      final days = warranty.difference(DateTime.now()).inDays;
      return days >= 0 && days <= 365;
    }).length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _BrandHeader(onAddAsset: widget.onAddAsset),
              const SizedBox(height: 22),
              Text('我的资产', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 4),
              Text('记录你拥有的一切，也记录它们为生活创造的价值', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 18),
              _SummaryPanel(
                assetCount: _assets(context).length,
                totalPurchase: totalPurchase,
                totalValue: totalValue,
                expiringCount: expiring,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterPill(label: '全部', selected: _category == null, onTap: () => setState(() => _category = null)),
                    for (final c in AssetCategory.values.take(5)) ...[
                      const SizedBox(width: 8),
                      _FilterPill(label: c.label, selected: _category == c, onTap: () => setState(() => _category = c)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: '常用设备', action: '查看全部', onTap: widget.onSeeAll),
              const SizedBox(height: 10),
              for (final asset in visible.take(4)) ...[
                _AssetCard(asset: asset, onTap: () => widget.onOpenAsset(asset)),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),
              _SectionHeader(title: '资产提醒'),
              const SizedBox(height: 10),
              _ReminderCard(
                icon: Icons.verified_user_outlined,
                title: '保修与维护',
                body: expiring == 0 ? '目前没有即将到期的保修' : '$expiring 件资产将在一年内过保，建议提前检查设备状态',
                tint: const Color(0xFFF5C400),
              ),
              const SizedBox(height: 10),
              const _ReminderCard(
                icon: Icons.auto_graph_outlined,
                title: '资产复盘',
                body: '无线耳机 Pro 已闲置一段时间，可以考虑继续使用或出售',
                tint: Color(0xFFD29B00),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class AssetListScreen extends StatefulWidget {
  const AssetListScreen({required this.onOpenAsset, required this.onAddAsset, super.key});

  final ValueChanged<AssetItem> onOpenAsset;
  final VoidCallback onAddAsset;

  @override
  State<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends State<AssetListScreen> {
  final _search = TextEditingController();
  AssetStatus? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final items = _assets(context).where((asset) {
      final matchQuery = query.isEmpty || asset.name.toLowerCase().contains(query) || asset.brand.toLowerCase().contains(query);
      final matchStatus = _status == null || asset.status == _status;
      return matchQuery && matchStatus;
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('全部资产', style: Theme.of(context).textTheme.headlineMedium)),
              IconButton.filled(onPressed: widget.onAddAsset, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '搜索资产名称、品牌或型号'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterPill(label: '全部', selected: _status == null, onTap: () => setState(() => _status = null)),
                for (final s in AssetStatus.values) ...[
                  const SizedBox(width: 8),
                  _FilterPill(label: s.label, selected: _status == s, onTap: () => setState(() => _status = s)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('共 ${items.length} 件资产', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const Spacer(),
              TextButton.icon(onPressed: () {}, icon: const Icon(Icons.swap_vert, size: 16), label: const Text('按购买时间')),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 18),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final asset = items[index];
                return _AssetCard(asset: asset, onTap: () => widget.onOpenAsset(asset), compact: true);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AssetDetailScreen extends StatelessWidget {
  const AssetDetailScreen({required this.asset, super.key});

  final AssetItem asset;

  @override
  Widget build(BuildContext context) {
    final events = _events(context).where((e) => e.assetId == asset.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    final warrantyDays = asset.warrantyUntil?.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产详情'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssetEditorScreen(asset: asset))),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AssetThumbnail(category: asset.category, size: 92),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.name, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [_CategoryBadge(asset.category), _StatusBadge(asset.status)],
                    ),
                    const SizedBox(height: 10),
                    Text(asset.spec, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _DetailMetric(label: '购买价格', value: _money(asset.purchasePrice))),
                      _VLine(),
                      Expanded(child: _DetailMetric(label: '当前估值', value: _money(asset.currentValue))),
                      _VLine(),
                      Expanded(child: _DetailMetric(label: '日均成本', value: '¥${asset.dailyCost.toStringAsFixed(2)}/天', accent: true)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: asset.serviceProgress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: const Color(0xFFE8E8E0),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('已持有 ${asset.heldDays} 天', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                      const Spacer(),
                      Text('保值率 ${(asset.retentionRate * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionHeader(title: '设备信息'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _InfoRow(label: '品牌', value: asset.brand),
                _InfoRow(label: '型号', value: asset.model),
                _InfoRow(label: '规格', value: asset.spec),
                _InfoRow(label: '序列号', value: asset.serialNumber, trailing: const Icon(Icons.copy, size: 16)),
                _InfoRow(label: '所在位置', value: asset.location, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionHeader(title: '使用与保修'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _InfoRow(label: '购买日期', value: _date(asset.purchaseDate)),
                _InfoRow(
                  label: '保修截止',
                  value: asset.warrantyUntil == null ? '未记录' : _date(asset.warrantyUntil!),
                  trailing: warrantyDays == null ? null : Text(warrantyDays >= 0 ? '剩 $warrantyDays 天' : '已过保', style: TextStyle(fontSize: 11, color: warrantyDays >= 0 ? const Color(0xFF8A6A00) : Colors.red)),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionHeader(title: '关联内容'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: const [
                _LinkRow(icon: Icons.receipt_long_outlined, label: '购买账单', value: 'Finance · ¥5,999'),
                _LinkRow(icon: Icons.image_outlined, label: '发票图片', value: 'Collection · 1 张'),
                _LinkRow(icon: Icons.notifications_none, label: '保修提醒', value: 'Calendar · 已创建'),
                _LinkRow(icon: Icons.task_alt_outlined, label: '维护任务', value: 'Execute · 暂无', isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: '生命周期', action: '添加记录', onTap: () => _showAddEvent(context, asset)),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const _EmptyPanel(icon: Icons.history, text: '还没有生命周期记录')
          else
            for (var i = 0; i < events.length; i++) _TimelineRow(event: events[i], isLast: i == events.length - 1),
        ],
      ),
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showAddEvent(context, asset),
              icon: const Icon(Icons.add),
              label: const Text('添加生命周期记录'),
            ),
          ),
        ),
      ),
    );
  }
}

class AssetEditorScreen extends StatefulWidget {
  const AssetEditorScreen({this.asset, super.key});

  final AssetItem? asset;

  @override
  State<AssetEditorScreen> createState() => _AssetEditorScreenState();
}

class _AssetEditorScreenState extends State<AssetEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _spec;
  late final TextEditingController _price;
  late final TextEditingController _value;
  late final TextEditingController _purchaseChannel;
  late final TextEditingController _serialNumber;
  late final TextEditingController _location;
  late final TextEditingController _targetDailyCost;
  late DateTime _purchaseDate;
  DateTime? _warrantyUntil;
  AssetCategory _category = AssetCategory.phone;
  AssetStatus _status = AssetStatus.active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _name = TextEditingController(text: asset?.name ?? '');
    _brand = TextEditingController(text: asset?.brand ?? '');
    _model = TextEditingController(text: asset?.model ?? '');
    _spec = TextEditingController(text: asset?.spec ?? '');
    _price = TextEditingController(text: asset == null ? '' : asset.purchasePrice.toStringAsFixed(0));
    _value = TextEditingController(text: asset == null ? '' : asset.currentValue.toStringAsFixed(0));
    _purchaseChannel = TextEditingController(text: asset?.purchaseChannel ?? '');
    _serialNumber = TextEditingController(text: asset?.serialNumber ?? '');
    _location = TextEditingController(text: asset?.location ?? '');
    _targetDailyCost = TextEditingController(
      text: asset == null || asset.targetDailyCost <= 0 ? '' : asset.targetDailyCost.toStringAsFixed(2),
    );
    _purchaseDate = asset?.purchaseDate ?? DateTime.now();
    _warrantyUntil = asset?.warrantyUntil;
    _category = asset?.category ?? AssetCategory.phone;
    _status = asset?.status ?? AssetStatus.active;
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _model.dispose();
    _spec.dispose();
    _price.dispose();
    _value.dispose();
    _purchaseChannel.dispose();
    _serialNumber.dispose();
    _location.dispose();
    _targetDailyCost.dispose();
    super.dispose();
  }

  Future<void> _pickPurchaseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) {
      setState(() => _purchaseDate = selected);
    }
  }

  Future<void> _pickWarrantyDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _warrantyUntil ?? _purchaseDate.add(const Duration(days: 365)),
      firstDate: _purchaseDate,
      lastDate: DateTime.now().add(const Duration(days: 3650 * 3)),
    );
    if (selected != null && mounted) {
      setState(() => _warrantyUntil = selected);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim());
    final value = double.tryParse(_value.text.trim());
    final targetDailyCost = double.tryParse(_targetDailyCost.text.trim()) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入资产名称')));
      return;
    }
    if (price == null || price < 0 || value == null || value < 0 || targetDailyCost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('价格与成本目标必须是非负数字')));
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final old = widget.asset;
    final asset = AssetItem(
      id: old?.id ?? newEntityId('asset'),
      name: name,
      brand: _brand.text.trim(),
      model: _model.text.trim(),
      category: _category,
      status: _status,
      purchasePrice: price,
      currentValue: value,
      purchaseDate: _purchaseDate,
      warrantyUntil: _warrantyUntil,
      spec: _spec.text.trim(),
      serialNumber: _serialNumber.text.trim(),
      location: _location.text.trim(),
      targetDailyCost: targetDailyCost,
      purchaseChannel: _purchaseChannel.text.trim(),
      maintenanceCost: old?.maintenanceCost ?? 0,
      recoveredAmount: old?.recoveredAmount ?? 0,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
      serverVersion: old?.serverVersion ?? 0,
    );

    try {
      await AssetScope.of(context).saveAsset(asset);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.asset == null ? '新增资产' : '编辑资产'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
        children: [
          Container(
            height: 118,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F0),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDCDCD2), style: BorderStyle.solid),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_outlined, size: 30, color: Color(0xFF5A5A5A)),
                SizedBox(height: 6),
                Text('资产图片', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('图片与附件将在文件能力阶段接入', style: TextStyle(fontSize: 11, color: Color(0xFF737373))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _FormSectionTitle('基础信息'),
          const SizedBox(height: 10),
          _Field(controller: _name, label: '名称', hint: '例如 Xiaomi 17 Pro'),
          _DropdownField<AssetCategory>(
            label: '分类',
            value: _category,
            items: AssetCategory.values,
            itemLabel: (v) => v.label,
            onChanged: (v) => setState(() => _category = v),
          ),
          _Field(controller: _brand, label: '品牌', hint: '例如 Xiaomi'),
          _Field(controller: _model, label: '型号', hint: '例如 17 Pro'),
          _Field(controller: _spec, label: '规格', hint: '例如 16GB + 512GB · 黑色'),
          _Field(controller: _location, label: '所在位置', hint: '例如 随身、书桌'),
          const SizedBox(height: 18),
          const _FormSectionTitle('购买与价值'),
          const SizedBox(height: 10),
          _Field(controller: _price, label: '购买价格', hint: '0', keyboardType: const TextInputType.numberWithOptions(decimal: true), prefix: '¥'),
          _Field(controller: _value, label: '当前估值', hint: '0', keyboardType: const TextInputType.numberWithOptions(decimal: true), prefix: '¥'),
          _Field(controller: _targetDailyCost, label: '目标日成本', hint: '可选', keyboardType: const TextInputType.numberWithOptions(decimal: true), prefix: '¥'),
          _DateField(label: '购买日期', value: _date(_purchaseDate), onTap: _pickPurchaseDate),
          _Field(controller: _purchaseChannel, label: '购买渠道', hint: '例如 官方商城'),
          const SizedBox(height: 18),
          const _FormSectionTitle('设备与保修'),
          const SizedBox(height: 10),
          _Field(controller: _serialNumber, label: '序列号 / SN', hint: '可选'),
          _DateField(
            label: '保修截止',
            value: _warrantyUntil == null ? '未设置' : _date(_warrantyUntil!),
            onTap: _pickWarrantyDate,
            onClear: _warrantyUntil == null ? null : () => setState(() => _warrantyUntil = null),
          ),
          const SizedBox(height: 18),
          const _FormSectionTitle('当前状态'),
          const SizedBox(height: 10),
          _DropdownField<AssetStatus>(
            label: '资产状态',
            value: _status,
            items: AssetStatus.values,
            itemLabel: (v) => v.label,
            onChanged: (v) => setState(() => _status = v),
          ),
        ],
      ),
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : widget.asset == null ? '保存资产' : '保存修改'),
            ),
          ),
        ),
      ),
    );
  }
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({required this.onOpenAsset, super.key});

  final ValueChanged<AssetItem> onOpenAsset;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _filter = '全部';

  @override
  Widget build(BuildContext context) {
    final events = [..._events(context)]..sort((a, b) => b.date.compareTo(a.date));
    final shown = _filter == '全部'
        ? events
        : events.where((event) {
            if (_filter == '购买') return event.title.contains('购入');
            if (_filter == '维护') return event.title.contains('更换') || event.title.contains('保修');
            if (_filter == '状态') return event.title.contains('闲置') || event.title.contains('主力');
            return true;
          }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Text('资产记录', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text('每一次购入、维护和流转，都会成为资产的生命周期', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 16),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final label in ['全部', '购买', '维护', '状态']) ...[
                if (label != '全部') const SizedBox(width: 8),
                _FilterPill(label: label, selected: _filter == label, onTap: () => setState(() => _filter = label)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < shown.length; i++)
          Builder(
            builder: (context) {
              final event = shown[i];
              final asset = _assets(context).firstWhere((a) => a.id == event.assetId);
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => widget.onOpenAsset(asset),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: _GlobalTimelineRow(asset: asset, event: event, isLast: i == shown.length - 1),
                ),
              );
            },
          ),
      ],
    );
  }
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final totalPurchase = _assets(context).fold<double>(0, (sum, item) => sum + item.purchasePrice);
    final totalValue = _assets(context).fold<double>(0, (sum, item) => sum + item.currentValue);
    final categories = <AssetCategory, double>{};
    for (final asset in _assets(context)) {
      categories.update(asset.category, (value) => value + asset.currentValue, ifAbsent: () => asset.currentValue);
    }
    final ranking = [..._assets(context)]..sort((a, b) => b.dailyCost.compareTo(a.dailyCost));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Text('资产分析', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        _PillTabs(labels: const ['总览', '分类', '成本', '状态'], selected: _tab, onChanged: (v) => setState(() => _tab = v)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _StatCard(label: '资产总值', value: _money(totalValue), helper: '当前估值', icon: Icons.account_balance_wallet_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: '累计购入', value: _money(totalPurchase), helper: '${_assets(context).length} 件资产', icon: Icons.shopping_bag_outlined)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatCard(label: '总体保值率', value: '${(totalValue / totalPurchase * 100).round()}%', helper: '按当前估值', icon: Icons.trending_up)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: '使用中', value: '${_assets(context).where((e) => e.status == AssetStatus.active).length} 件', helper: '闲置 ${_assets(context).where((e) => e.status == AssetStatus.idle).length} 件', icon: Icons.devices_other)),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: '分类占比'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CustomPaint(
                    painter: _DonutPainter(values: categories.values.toList()),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${_assets(context).length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                          const Text('件资产', style: TextStyle(fontSize: 10, color: Color(0xFF666666))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: categories.entries.map((entry) {
                      final ratio = totalValue == 0 ? 0.0 : entry.value / totalValue;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: _categoryColor(entry.key), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(entry.key.label, style: const TextStyle(fontSize: 12))),
                            Text('${(ratio * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: '日均成本排行'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < ranking.length; i++)
                Padding(
                  padding: EdgeInsets.fromLTRB(14, i == 0 ? 14 : 8, 14, i == ranking.length - 1 ? 14 : 8),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: i < 3 ? const Color(0xFFFFF5CC) : const Color(0xFFF2F2EC), borderRadius: BorderRadius.circular(8)),
                        child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: i < 3 ? const Color(0xFFF5C400) : const Color(0xFF6B6B6B))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(ranking[i].name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                      Text('¥${ranking[i].dailyCost.toStringAsFixed(2)}/天', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF8A6A00))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: '本月变化'),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(child: _MiniChangeCard(icon: Icons.add_circle_outline, label: '新增', value: '2 件')),
            SizedBox(width: 8),
            Expanded(child: _MiniChangeCard(icon: Icons.sell_outlined, label: '出售', value: '1 件')),
            SizedBox(width: 8),
            Expanded(child: _MiniChangeCard(icon: Icons.build_outlined, label: '维护', value: '1 件')),
          ],
        ),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Text('我的', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFFFF5CC),
                  child: const Text('L', style: TextStyle(color: Color(0xFF111111), fontSize: 22, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LifeTrace User', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('LifeTrace Cloud · 待接入', style: TextStyle(fontSize: 11, color: Color(0xFF666666))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: '数据'),
        const SizedBox(height: 8),
        const Card(
          child: Column(
            children: [
              _SettingsRow(icon: Icons.cloud_outlined, title: 'LifeTrace Cloud', subtitle: '账号、同步与跨端恢复'),
              _SettingsRow(icon: Icons.link_outlined, title: 'LifeTrace 关联', subtitle: 'Finance / Execute / Calendar / Collection'),
              _SettingsRow(icon: Icons.backup_outlined, title: '数据与备份', subtitle: '导入、导出与本地备份', isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: '偏好与隐私'),
        const SizedBox(height: 8),
        const Card(
          child: Column(
            children: [
              _SettingsRow(icon: Icons.notifications_none, title: '提醒', subtitle: '保修、维护和复盘提醒'),
              _SettingsRow(icon: Icons.visibility_off_outlined, title: '敏感字段', subtitle: 'SN / IMEI / 订单号默认遮罩'),
              _SettingsRow(icon: Icons.palette_outlined, title: '外观', subtitle: '主题与显示方式'),
              _SettingsRow(icon: Icons.info_outline, title: '关于 LifeTrace Assets', subtitle: '版本 0.1 UI Prototype', isLast: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onAddAsset});
  final VoidCallback onAddAsset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LifeTrace', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 16)),
            Text('记录，让生活更有迹可循', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
          ],
        ),
        const Spacer(),
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
        const SizedBox(width: 4),
        IconButton.filled(onPressed: onAddAsset, icon: const Icon(Icons.add)),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.assetCount, required this.totalPurchase, required this.totalValue, required this.expiringCount});

  final int assetCount;
  final double totalPurchase;
  final double totalValue;
  final int expiringCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFD84D), Color(0xFFF5C400)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x33F5C400), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(child: _SummaryMetric(icon: Icons.inventory_2_outlined, value: '$assetCount', label: '件资产')),
          Expanded(child: _SummaryMetric(icon: Icons.payments_outlined, value: _compactMoney(totalPurchase), label: '总购入')),
          Expanded(child: _SummaryMetric(icon: Icons.account_balance_wallet_outlined, value: _compactMoney(totalValue), label: '当前估值')),
          Expanded(child: _SummaryMetric(icon: Icons.verified_user_outlined, value: '$expiringCount', label: '件即将过保')),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF111111).withValues(alpha: 0.86), size: 18),
        const SizedBox(height: 8),
        FittedBox(child: Text(value, style: const TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w900, fontSize: 14))),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: TextStyle(color: const Color(0xFF111111).withValues(alpha: 0.68), fontSize: 9)),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Theme.of(context).colorScheme.primary : const Color(0xFFF0F3F7),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF111111) : const Color(0xFF666666))),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (action != null)
          TextButton(onPressed: onTap, child: Text(action!, style: const TextStyle(fontSize: 11))),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset, required this.onTap, this.compact = false});
  final AssetItem asset;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Row(
            children: [
              _AssetThumbnail(category: asset.category, size: compact ? 62 : 68),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                        _StatusBadge(asset.status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text('${asset.category.label} · ${asset.brand}', style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Text('购入 ${_money(asset.purchasePrice)}', style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                        const SizedBox(width: 8),
                        Text('估值 ${_money(asset.currentValue)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('¥${asset.dailyCost.toStringAsFixed(2)}/天', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF8A6A00))),
                    if (!compact) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(value: asset.serviceProgress, minHeight: 4, backgroundColor: const Color(0xFFEAEAE2)),
                      ),
                      const SizedBox(height: 4),
                      Text('已使用 ${asset.heldDays} 天 · 保值率 ${(asset.retentionRate * 100).round()}%', style: const TextStyle(fontSize: 9, color: Color(0xFF7A7A7A))),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9A9A9A)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetThumbnail extends StatelessWidget {
  const _AssetThumbnail({required this.category, required this.size});
  final AssetCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.25)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Icon(_categoryIcon(category), color: color, size: size * 0.48),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final AssetStatus status;

  @override
  Widget build(BuildContext context) {
    final active = status == AssetStatus.active;
    final color = active ? const Color(0xFF111111) : status == AssetStatus.idle ? const Color(0xFFB98500) : const Color(0xFF6B6B6B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(7)),
      child: Text(status.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge(this.category);
  final AssetCategory category;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
      child: Text(category.label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF111111))),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.icon, required this.title, required this.body, required this.tint});
  final IconData icon;
  final String title;
  final String body;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: tint, size: 21)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(fontSize: 10, height: 1.4, color: Color(0xFF666666))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value, this.accent = false});
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF7A7A7A))),
        const SizedBox(height: 6),
        FittedBox(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: accent ? const Color(0xFF8A6A00) : const Color(0xFF111111)))),
      ],
    );
  }
}

class _VLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 34, color: const Color(0xFFE6E6DE));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.trailing, this.isLast = false});
  final String label;
  final String value;
  final Widget? trailing;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFECECE5)))),
      child: Row(
        children: [
          SizedBox(width: 78, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF666666)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.value, this.isLast = false});
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFECECE5)))),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF5C400), size: 19),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          Text(value, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
          const SizedBox(width: 3),
          const Icon(Icons.chevron_right, size: 17, color: Color(0xFF9A9A9A)),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});
  final AssetEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(width: 28, height: 28, decoration: const BoxDecoration(color: Color(0xFFFFF5CC), shape: BoxShape.circle), child: Icon(_eventIcon(event.type), size: 15, color: Color(0xFFF5C400))),
                if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFE8E1BA))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_date(event.date), style: const TextStyle(fontSize: 10, color: Color(0xFF7A7A7A))),
                  const SizedBox(height: 4),
                  Text(event.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(event.detail, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalTimelineRow extends StatelessWidget {
  const _GlobalTimelineRow({required this.asset, required this.event, required this.isLast});
  final AssetItem asset;
  final AssetEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Container(width: 30, height: 30, decoration: const BoxDecoration(color: Color(0xFFFFF5CC), shape: BoxShape.circle), child: Icon(_eventIcon(event.type), size: 16, color: Color(0xFFF5C400))),
                if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFE4E4DC))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      _AssetThumbnail(category: asset.category, size: 46),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_date(event.date), style: const TextStyle(fontSize: 9, color: Color(0xFF7A7A7A))),
                            const SizedBox(height: 3),
                            Text(event.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('${asset.name} · ${event.detail}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 17, color: Color(0xFF9A9A9A)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(99))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, required this.hint, this.keyboardType, this.prefix});
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 82, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF525252)))),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(hintText: hint, prefixText: prefix == null ? null : '$prefix '),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticField extends StatelessWidget {
  const _StaticField({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 82, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF525252)))),
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: const Color(0xFFF2F2EC), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [Expanded(child: Text(value, style: const TextStyle(fontSize: 12))), Icon(icon, size: 17, color: const Color(0xFF666666))]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({required this.label, required this.value, required this.items, required this.itemLabel, required this.onChanged});
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 82, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF525252)))),
          Expanded(
            child: DropdownButtonFormField<T>(
              initialValue: value,
              isExpanded: true,
              decoration: const InputDecoration(),
              items: items.map((item) => DropdownMenuItem<T>(value: item, child: Text(itemLabel(item), style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PillTabs extends StatelessWidget {
  const _PillTabs({required this.labels, required this.selected, required this.onChanged});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF0F3F7), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                color: i == selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(labels[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: i == selected ? const Color(0xFF111111) : const Color(0xFF666666))),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.helper, required this.icon});
  final String label;
  final String value;
  final String helper;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 18, color: const Color(0xFFF5C400)), const Spacer(), const Icon(Icons.show_chart, size: 18, color: Color(0xFFE3B500))]),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
            const SizedBox(height: 3),
            FittedBox(child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            const SizedBox(height: 3),
            Text(helper, style: const TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))),
          ],
        ),
      ),
    );
  }
}

class _MiniChangeCard extends StatelessWidget {
  const _MiniChangeCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [Icon(icon, size: 22, color: const Color(0xFFF5C400)), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900))]),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.title, required this.subtitle, this.isLast = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFECECE5)))),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFFFF5CC), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 19, color: const Color(0xFFF5C400))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF7A7A7A)))])),
          const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9A9A9A)),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: const Color(0xFFF4F4EE), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [Icon(icon, color: const Color(0xFF9A9A9A)), const SizedBox(height: 8), Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF666666)))]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values});
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;
    const colors = [Color(0xFFF5C400), Color(0xFFD9A900), Color(0xFFE0B100), Color(0xFF4A4A4A), Color(0xFFFFE07A), Color(0xFF8A8A8A)];
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    const stroke = 18.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.values != values;
}

void _showAddEvent(BuildContext context, AssetItem asset) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('添加资产记录', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(asset.name, style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
            const SizedBox(height: 14),
            const TextField(decoration: InputDecoration(labelText: '发生了什么？', hintText: '例如：更换电池、送修、借出、出售')),
            const SizedBox(height: 10),
            const TextField(maxLines: 3, decoration: InputDecoration(labelText: '补充说明', hintText: '费用、渠道、状态变化等')),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('保存记录'))),
          ],
        ),
      );
    },
  );
}

String _money(double value) => '¥${value.toStringAsFixed(0)}';
String _compactMoney(double value) => value >= 10000 ? '¥${(value / 10000).toStringAsFixed(1)}万' : _money(value);
String _date(DateTime value) => '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

IconData _categoryIcon(AssetCategory category) {
  return switch (category) {
    AssetCategory.phone => Icons.smartphone_outlined,
    AssetCategory.tablet => Icons.tablet_mac_outlined,
    AssetCategory.computer => Icons.laptop_mac_outlined,
    AssetCategory.wearable => Icons.watch_outlined,
    AssetCategory.audio => Icons.headphones_outlined,
    AssetCategory.camera => Icons.photo_camera_outlined,
    AssetCategory.home => Icons.home_work_outlined,
    AssetCategory.other => Icons.category_outlined,
  };
}

Color _categoryColor(AssetCategory category) {
  return switch (category) {
    AssetCategory.phone => const Color(0xFFB98500),
    AssetCategory.tablet => const Color(0xFF8A6A00),
    AssetCategory.computer => const Color(0xFF111111),
    AssetCategory.wearable => const Color(0xFF6F5900),
    AssetCategory.audio => const Color(0xFFD29B00),
    AssetCategory.camera => const Color(0xFF4D4D4D),
    AssetCategory.home => const Color(0xFF9A7300),
    AssetCategory.other => const Color(0xFF6B6B6B),
  };
}
