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
  String? _selectedScenarioId;
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
    final runtimeStatus = decision.runtimeObservation.status.wireName;
    _appendLog(
      'Decision updated: tier=${decision.tier.name}, '
      'confidence=${decision.confidence.name}, '
      'platform=${decision.deviceSignals.platform}, '
      'runtimeState=$runtimeStatus',
    );
    final selectedScenarioId = _resolveSelectedScenarioId(decision);
    if (!mounted) {
      return;
    }
    setState(() {
      _decision = decision;
      _selectedScenarioId = selectedScenarioId;
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
    final runtimeObservation = decision.runtimeObservation;
    final resolvedPolicy = _readAppliedPolicy(decision);
    final selectedScenario = _resolveSelectedScenario(resolvedPolicy);

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
            _buildValueRow('Thermal State', signals.thermalState ?? '-'),
            _buildValueRow(
              'Thermal State Level',
              '${signals.thermalStateLevel ?? '-'}',
            ),
            _buildValueRow(
              'Low Power Mode',
              '${signals.isLowPowerModeEnabled ?? '-'}',
            ),
            _buildValueRow(
              'Memory Pressure State',
              signals.memoryPressureState ?? '-',
            ),
            _buildValueRow(
              'Memory Pressure Level',
              '${signals.memoryPressureLevel ?? '-'}',
            ),
            _buildValueRow(
              'Runtime State',
              _formatRuntimeState(runtimeObservation.status),
            ),
            _buildValueRow(
              'Runtime Trigger',
              runtimeObservation.triggerReason ?? '-',
            ),
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
            const Divider(height: 28),
            Text(
              'Scenario Policy Hit',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (resolvedPolicy == null)
              const Text('Unable to parse applied policy payload.')
            else if (resolvedPolicy.scenarioPolicies.isEmpty)
              const Text('-')
            else ...<Widget>[
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('scenario-hit-selector'),
                initialValue: selectedScenario!.id,
                decoration: const InputDecoration(
                  labelText: 'Scenario',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: resolvedPolicy.scenarioPolicies
                    .map(
                      (ScenarioPolicy policy) => DropdownMenuItem<String>(
                        value: policy.id,
                        child: Text('${policy.displayName} (${policy.id})'),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value == null || value == _selectedScenarioId) {
                    return;
                  }
                  _appendLog('Scenario policy preview switched: $value.');
                  setState(() {
                    _selectedScenarioId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildScenarioMapSection('Knobs', selectedScenario.knobs),
              const SizedBox(height: 12),
              _buildScenarioMapSection(
                'Acceptance Targets',
                selectedScenario.acceptanceTargets,
              ),
              const SizedBox(height: 8),
              Text(
                'Business sample: policy.scenarioById(\'${selectedScenario.id}\')',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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

  Widget _buildScenarioMapSection(String title, Map<String, Object> values) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (values.isEmpty)
              const Text('-')
            else
              ...values.entries.map(
                (entry) =>
                    _buildValueRow(entry.key, _formatPolicyValue(entry.value)),
              ),
          ],
        ),
      ),
    );
  }

  String? _resolveSelectedScenarioId(TierDecision decision) {
    final policy = _readAppliedPolicy(decision);
    if (policy == null || policy.scenarioPolicies.isEmpty) {
      return null;
    }
    if (_selectedScenarioId != null &&
        policy.scenarioById(_selectedScenarioId!) != null) {
      return _selectedScenarioId;
    }
    return policy.scenarioPolicies.first.id;
  }

  ScenarioPolicy? _resolveSelectedScenario(PerformancePolicy? policy) {
    if (policy == null || policy.scenarioPolicies.isEmpty) {
      return null;
    }
    if (_selectedScenarioId == null) {
      return policy.scenarioPolicies.first;
    }
    return policy.scenarioById(_selectedScenarioId!) ??
        policy.scenarioPolicies.first;
  }

  PerformancePolicy? _readAppliedPolicy(TierDecision decision) {
    if (decision.appliedPolicies.isEmpty) {
      return null;
    }
    try {
      return PerformancePolicy.fromMap(
        Map<String, Object?>.from(decision.appliedPolicies),
      );
    } on FormatException {
      return null;
    }
  }

  static String _formatPolicyValue(Object value) {
    if (value is Map<Object?, Object?> || value is List<Object?>) {
      return value.toString();
    }
    return '$value';
  }

  static String _formatRuntimeState(RuntimeTierStatus status) {
    if (status == RuntimeTierStatus.inactive) {
      return '-';
    }
    return status.wireName;
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
