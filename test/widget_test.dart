import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_assets/main.dart';
import 'package:lifetrace_assets/src/data/asset_repository.dart';

void main() {
  testWidgets('renders empty local-first dashboard and primary navigation', (tester) async {
    final repository = await AssetRepository.inMemory();

    await tester.pumpWidget(LifeTraceAssetsApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('我的资产'), findsOneWidget);
    expect(find.text('添加第一件资产'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('资产'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);
    expect(find.text('分析'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
