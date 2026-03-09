import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../performance_tier/performance_tier.dart';

class PerformanceTierDemoController extends ChangeNotifier {
  PerformanceTierDemoController({PerformanceTierService? service})
      : _providedService = service;

  final PerformanceTierService? _providedService;
  final List<String> _structuredLogs = <String>[];

  late final JsonLinePerformanceTierLogger _structuredLogger =
      JsonLinePerformanceTierLogger(
    prefix: 'PERF_TIER_LOG',
    emitter: _recordStructuredLog,
  );
  late final PerformanceTierService _service = _providedService ??
      DefaultPerformanceTierService(logger: _structuredLogger);

  StreamSubscription<TierDecision>? _subscription;
  Future<void>? _startInFlight;
  bool _started = false;
  bool _disposed = false;

  TierDecision? _decision;
  String? _error;
  bool _initializing = true;
  bool _refreshing = false;

  TierDecision? get decision => _decision;
  String? get error => _error;
  bool get initializing => _initializing;
  bool get refreshing => _refreshing;
  List<String> get structuredLogs => List<String>.unmodifiable(_structuredLogs);

  Future<void> start() {
    if (_disposed || _started) {
      return Future<void>.value();
    }

    final inFlight = _startInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final next = _startSafely().whenComplete(() {
      _startInFlight = null;
    });
    _startInFlight = next;
    return next;
  }

  Future<void> refreshDecision() async {
    if (_disposed || _refreshing) {
      return;
    }

    _refreshing = true;
    _notifySafely();
    try {
      await _service.refresh();
    } catch (error) {
      _error = 'Refresh failed: $error';
    } finally {
      _refreshing = false;
      _notifySafely();
    }
  }

  Future<void> copyAiReport(
    BuildContext context, {
    Map<String, Object?> extraSections = const <String, Object?>{},
  }) async {
    await _copyToClipboard(
      context,
      buildAiReport(extraSections: extraSections),
      successMessage: 'AI report copied.',
    );
  }

  Future<void> copyLatestLogLine(BuildContext context) async {
    final latest = _structuredLogs.isEmpty ? '' : _structuredLogs.first;
    await _copyToClipboard(
      context,
      latest,
      successMessage: 'Latest log line copied.',
    );
  }

  void recordDiagnosticLog(String line) {
    _recordStructuredLog(line);
  }

  String buildAiReport({
    Map<String, Object?> extraSections = const <String, Object?>{},
  }) {
    final report = <String, Object?>{
      'status': _error == null ? 'ok' : 'error',
      'generatedAt': DateTime.now().toIso8601String(),
      'initializing': _initializing,
      if (_decision != null) 'decision': _decision!.toMap(),
      if (_error != null) 'error': _error,
      'recentStructuredLogs': _structuredLogs.take(40).toList(),
    };
    report.addAll(extraSections);
    return const JsonEncoder.withIndent('  ').convert(report);
  }

  String buildHeadline() {
    if (_initializing && _decision == null) {
      return 'Initializing service and waiting for first decision...';
    }
    if (_decision == null) {
      return _error ?? 'No decision yet.';
    }

    final currentDecision = _decision!;
    return 'tier=${currentDecision.tier.name}, '
        'confidence=${currentDecision.confidence.name}, '
        'runtime=${currentDecision.runtimeObservation.status.wireName}';
  }

  Future<void> close() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    final subscription = _subscription;
    _subscription = null;
    final disposeFuture = _service.dispose();
    await subscription?.cancel();
    await disposeFuture;
    super.dispose();
  }

  Future<void> _startSafely() async {
    _started = true;
    _subscription = _service.watchDecision().listen(
      _onDecision,
      onError: (Object error, StackTrace stackTrace) {
        if (_disposed) {
          return;
        }
        _initializing = false;
        _error = 'watchDecision failed: $error';
        _notifySafely();
      },
    );

    try {
      await _service.initialize();
      if (_disposed || _decision != null) {
        return;
      }
      _initializing = false;
      _notifySafely();
    } catch (error) {
      if (_disposed) {
        return;
      }
      _initializing = false;
      _error = 'Initialization failed: $error';
      _notifySafely();
    }
  }

  Future<void> _copyToClipboard(
    BuildContext context,
    String text, {
    required String successMessage,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: text));
    if (_disposed || messenger == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(successMessage)));
  }

  void _onDecision(TierDecision decision) {
    if (_disposed) {
      return;
    }
    _decision = decision;
    _error = null;
    _initializing = false;
    _notifySafely();
  }

  void _recordStructuredLog(String line) {
    debugPrint(line);
    _structuredLogs.insert(0, line);
    if (_structuredLogs.length > 200) {
      _structuredLogs.removeRange(200, _structuredLogs.length);
    }
    _notifySafely();
  }

  void _notifySafely() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }
}
