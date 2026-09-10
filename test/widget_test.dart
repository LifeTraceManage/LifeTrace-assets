import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_assets/main.dart';

void main() {
  testWidgets('renders asset dashboard and primary navigation', (tester) async {
    await tester.pumpWidget(const LifeTraceAssetsApp());
    await tester.pumpAndSettle();

    expect(find.text('我的资产'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('资产'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);
    expect(find.text('分析'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
