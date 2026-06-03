import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger_demo/core/logging/demo_log_hub.dart';
import 'package:scout_logger_demo/features/demo/presentation/widgets/demo_stats_bar.dart';

void main() {
  testWidgets('demo stats bar renders', (WidgetTester tester) async {
    final DemoLogHub hub = DemoLogHub.instance;
    hub.clear();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: DemoStatsBar(hub: hub))),
    );

    expect(find.textContaining('Batches'), findsOneWidget);
    expect(find.textContaining('Urgent'), findsOneWidget);
  });
}
