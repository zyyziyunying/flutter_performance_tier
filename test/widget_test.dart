import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_performance_tier/main.dart';

void main() {
  testWidgets('renders structured diagnostics demo with refresh action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PerformanceTierDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('Performance Tier Diagnostics'), findsOneWidget);
    expect(find.byTooltip('Refresh decision'), findsOneWidget);
    expect(find.byTooltip('Copy AI report'), findsOneWidget);
    expect(
      find.textContaining('Structured diagnostics demo only.'),
      findsOneWidget,
    );
    expect(find.text('AI Diagnostics JSON'), findsOneWidget);
    expect(find.textContaining('"recentStructuredLogs"'), findsOneWidget);
  });
}
