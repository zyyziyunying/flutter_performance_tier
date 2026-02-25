import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_performance_tier/main.dart';

void main() {
  testWidgets('renders performance tier demo with refresh action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PerformanceTierDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('Performance Tier Demo'), findsOneWidget);
    expect(find.byTooltip('Refresh decision'), findsOneWidget);
    expect(find.text('Current Decision'), findsOneWidget);
    expect(find.text('Event Log'), findsOneWidget);
  });
}
