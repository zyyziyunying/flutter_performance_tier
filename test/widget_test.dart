import 'package:flutter/widgets.dart';
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
    await tester.scrollUntilVisible(
      find.text('Runtime State'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Frame Drop State'), findsOneWidget);
    expect(find.text('Frame Drop Rate'), findsOneWidget);
    expect(find.text('Runtime State'), findsOneWidget);
    expect(find.text('Runtime Trigger'), findsOneWidget);
    expect(find.text('Event Log'), findsOneWidget);
  });
}
