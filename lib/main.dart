import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'performance_tier/performance_tier.dart';

void main() {
  runApp(const PerformanceTierDemoApp());
}

class PerformanceTierDemoApp extends StatelessWidget {
  const PerformanceTierDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Performance Tier Logs',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
  final List<String> _structuredLogs = <String>[];

  late final JsonLinePerformanceTierLogger _logger =
      JsonLinePerformanceTierLogger(
        prefix: 'PERF_TIER_LOG',
        emitter: _onStructuredLogLine,
      );
  late final DefaultPerformanceTierService _service =
      DefaultPerformanceTierService(logger: _logger);

  StreamSubscription<TierDecision>? _subscription;
  TierDecision? _decision;
  String? _error;
  bool _initializing = true;
  bool _refreshing = false;
  bool _allowUiUpdates = true;

  @override
  void initState() {
    super.initState();
    _subscription = _service.watchDecision().listen(
      _onDecision,
      onError: (Object error, StackTrace stackTrace) {
        if (!_canUpdateUi) {
          return;
        }
        setState(() {
          _initializing = false;
          _error = 'watchDecision failed: $error';
        });
      },
    );
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _allowUiUpdates = false;
    unawaited(_subscription?.cancel());
    unawaited(_service.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _service.initialize();
      if (!_canUpdateUi) {
        return;
      }
      setState(() {
        _initializing = false;
      });
    } catch (error) {
      if (!_canUpdateUi) {
        return;
      }
      setState(() {
        _initializing = false;
        _error = 'Initialization failed: $error';
      });
    }
  }

  Future<void> _refreshDecision() async {
    if (_refreshing) {
      return;
    }
    setState(() {
      _refreshing = true;
    });
    try {
      await _service.refresh();
    } catch (error) {
      if (!_canUpdateUi) {
        return;
      }
      setState(() {
        _error = 'Refresh failed: $error';
      });
    } finally {
      if (_canUpdateUi) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  void _onDecision(TierDecision decision) {
    if (!_canUpdateUi) {
      return;
    }
    setState(() {
      _decision = decision;
      _error = null;
      _initializing = false;
    });
  }

  void _onStructuredLogLine(String line) {
    debugPrint(line);
    _structuredLogs.insert(0, line);
    if (_structuredLogs.length > 200) {
      _structuredLogs.removeRange(200, _structuredLogs.length);
    }
    if (!_canUpdateUi) {
      return;
    }
    setState(() {});
  }

  Future<void> _copyAiReport() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final report = _buildAiReport();
    await Clipboard.setData(ClipboardData(text: report));
    if (!_canUpdateUi || messenger == null) {
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('AI report copied.')));
  }

  Future<void> _copyLatestLogLine() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final latest = _structuredLogs.isEmpty ? '' : _structuredLogs.first;
    await Clipboard.setData(ClipboardData(text: latest));
    if (!_canUpdateUi || messenger == null) {
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Latest log line copied.')),
    );
  }

  bool get _canUpdateUi => _allowUiUpdates && mounted;

  String _buildAiReport() {
    final report = <String, Object?>{
      'status': _error == null ? 'ok' : 'error',
      'generatedAt': DateTime.now().toIso8601String(),
      'initializing': _initializing,
      if (_decision != null) 'decision': _decision!.toMap(),
      if (_error != null) 'error': _error,
      'recentStructuredLogs': _structuredLogs.take(40).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(report);
  }

  String _buildHeadline() {
    if (_initializing && _decision == null) {
      return 'Initializing service and waiting for first decision...';
    }
    if (_decision == null) {
      return _error ?? 'No decision yet.';
    }
    final decision = _decision!;
    return 'tier=${decision.tier.name}, '
        'confidence=${decision.confidence.name}, '
        'runtime=${decision.runtimeObservation.status.wireName}';
  }

  @override
  Widget build(BuildContext context) {
    final report = _buildAiReport();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Tier Logs'),
        actions: <Widget>[
          IconButton(
            onPressed: _refreshing ? null : _refreshDecision,
            tooltip: 'Refresh decision',
            icon: _refreshing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _copyAiReport,
            tooltip: 'Copy AI report',
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Panel mode removed. Structured output only.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_buildHeadline()),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Last Error: $_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _copyLatestLogLine,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy latest log'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'AI Diagnostics JSON',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    report,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
