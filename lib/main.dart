import 'dart:async';

import 'package:flutter/material.dart';

import 'performance_tier/performance_tier.dart';

void main() {
  runApp(const PerformanceTierDemoApp());
}

class PerformanceTierDemoApp extends StatelessWidget {
  const PerformanceTierDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Performance Tier Demo',
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
  final DefaultPerformanceTierService _service =
      DefaultPerformanceTierService();
  final List<String> _logs = <String>[];

  StreamSubscription<TierDecision>? _subscription;
  TierDecision? _decision;
  String? _error;
  bool _initializing = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _subscription = _service.watchDecision().listen(
      _onDecision,
      onError: (Object error, StackTrace stackTrace) {
        _appendLog('watchDecision error: $error');
        if (!mounted) {
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
    unawaited(_subscription?.cancel());
    unawaited(_service.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    _appendLog('Initializing service...');
    try {
      await _service.initialize();
      _appendLog('Initialization completed.');
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
      });
    } catch (error) {
      _appendLog('Initialization failed: $error');
      if (!mounted) {
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
    _appendLog('Manual refresh requested.');

    try {
      await _service.refresh();
      _appendLog('Manual refresh completed.');
    } catch (error) {
      _appendLog('Manual refresh failed: $error');
      if (mounted) {
        setState(() {
          _error = 'Refresh failed: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  void _onDecision(TierDecision decision) {
    _appendLog(
      'Decision updated: tier=${decision.tier.name}, '
      'confidence=${decision.confidence.name}, '
      'platform=${decision.deviceSignals.platform}',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _decision = decision;
      _error = null;
      _initializing = false;
    });
  }

  void _appendLog(String message) {
    final now = DateTime.now();
    final stamp = _formatTime(now);
    _logs.insert(0, '[$stamp] $message');
    if (_logs.length > 60) {
      _logs.removeRange(60, _logs.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Tier Demo'),
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
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isWide
            ? Row(
                children: <Widget>[
                  Expanded(flex: 3, child: _buildDecisionPanel()),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildLogsPanel()),
                ],
              )
            : Column(
                children: <Widget>[
                  Expanded(flex: 3, child: _buildDecisionPanel()),
                  const SizedBox(height: 16),
                  Expanded(flex: 2, child: _buildLogsPanel()),
                ],
              ),
      ),
    );
  }

  Widget _buildDecisionPanel() {
    if (_initializing && _decision == null) {
      return const Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Waiting for first decision...'),
            ],
          ),
        ),
      );
    }

    if (_decision == null) {
      return Card(child: Center(child: Text(_error ?? 'No decision yet.')));
    }

    final decision = _decision!;
    final signals = decision.deviceSignals;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: <Widget>[
            Text(
              'Current Decision',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildValueRow('Tier', decision.tier.name),
            _buildValueRow('Confidence', decision.confidence.name),
            _buildValueRow('Platform', signals.platform),
            _buildValueRow('Device Model', signals.deviceModel ?? '-'),
            _buildValueRow('Decided At', decision.decidedAt.toIso8601String()),
            _buildValueRow(
              'Total RAM',
              signals.totalRamBytes == null
                  ? '-'
                  : '${_formatBytes(signals.totalRamBytes!)} (${signals.totalRamBytes})',
            ),
            _buildValueRow(
              'isLowRamDevice',
              '${signals.isLowRamDevice ?? '-'}',
            ),
            _buildValueRow(
              'Media Performance Class',
              '${signals.mediaPerformanceClass ?? '-'}',
            ),
            _buildValueRow('SDK Int / OS Major', '${signals.sdkInt ?? '-'}'),
            const Divider(height: 28),
            Text('Reasons', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (decision.reasons.isEmpty)
              const Text('-')
            else
              ...decision.reasons.map((String reason) => Text('- $reason')),
            const Divider(height: 28),
            Text(
              'Applied Policies',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (decision.appliedPolicies.isEmpty)
              const Text('-')
            else
              ...decision.appliedPolicies.entries.map(
                (MapEntry<String, Object?> entry) =>
                    _buildValueRow(entry.key, '${entry.value}'),
              ),
            if (_error != null) ...<Widget>[
              const Divider(height: 28),
              Text(
                'Last Error: $_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogsPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Event Log', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Newest first'),
            const SizedBox(height: 8),
            Expanded(
              child: _logs.isEmpty
                  ? const Center(child: Text('No logs yet'))
                  : ListView.separated(
                      itemCount: _logs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        return SelectableText(_logs[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    const unit = 1024 * 1024 * 1024;
    final gb = bytes / unit;
    return '${gb.toStringAsFixed(2)} GB';
  }

  static String _formatTime(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}
