import 'dart:async';

import 'package:flutter/material.dart';

import 'performance_tier_demo_controller.dart';
import 'performance_tier_diagnostics_scaffold.dart';

class PerformanceTierDemoApp extends StatelessWidget {
  const PerformanceTierDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Performance Tier Diagnostics',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B6E4F),
        ),
        useMaterial3: true,
      ),
      home: const PerformanceTierDemoPage(),
    );
  }
}

class PerformanceTierDemoPage extends StatefulWidget {
  const PerformanceTierDemoPage({super.key});

  @override
  State<PerformanceTierDemoPage> createState() =>
      _PerformanceTierDemoPageState();
}

class _PerformanceTierDemoPageState extends State<PerformanceTierDemoPage> {
  late final PerformanceTierDemoController _controller =
      PerformanceTierDemoController();

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    unawaited(_controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return PerformanceTierDiagnosticsScaffold(
          title: 'Performance Tier Diagnostics',
          introText:
              'Structured diagnostics demo only. Internal upload validation '
              'has been moved to a separate entrypoint.',
          headline: _controller.buildHeadline(),
          report: _controller.buildAiReport(),
          error: _controller.error,
          isRefreshing: _controller.refreshing,
          onRefresh: _controller.refreshDecision,
          onCopyAiReport: () => _controller.copyAiReport(context),
          onCopyLatestLogLine: () => _controller.copyLatestLogLine(context),
        );
      },
    );
  }
}
