import 'dart:async';

import '../config/config_provider.dart';
import '../engine/rule_based_tier_engine.dart';
import '../engine/tier_engine.dart';
import '../model/device_signals.dart';
import '../model/tier_confidence.dart';
import '../model/tier_decision.dart';
import '../model/tier_level.dart';
import '../performance_tier_service.dart';
import '../policy/policy_resolver.dart';
import 'device_signal_collector.dart';
import 'method_channel_device_signal_collector.dart';
import 'runtime_tier_controller.dart';

class DefaultPerformanceTierService implements PerformanceTierService {
  DefaultPerformanceTierService({
    DeviceSignalCollector? signalCollector,
    TierEngine? engine,
    PolicyResolver? policyResolver,
    ConfigProvider? configProvider,
    RuntimeTierController? runtimeTierController,
    Duration runtimeSignalRefreshInterval = const Duration(seconds: 15),
  }) : _signalCollector =
           signalCollector ?? MethodChannelDeviceSignalCollector(),
       _engine = engine ?? const RuleBasedTierEngine(),
       _policyResolver = policyResolver ?? const DefaultPolicyResolver(),
       _configProvider = configProvider ?? const DefaultConfigProvider(),
       _runtimeTierController =
           runtimeTierController ?? RuntimeTierController(),
       _runtimeSignalRefreshInterval = runtimeSignalRefreshInterval;

  final DeviceSignalCollector _signalCollector;
  final TierEngine _engine;
  final PolicyResolver _policyResolver;
  final ConfigProvider _configProvider;
  final RuntimeTierController _runtimeTierController;
  final Duration _runtimeSignalRefreshInterval;
  final StreamController<TierDecision> _decisionController =
      StreamController<TierDecision>.broadcast();

  TierDecision? _currentDecision;
  Future<void>? _recomputeInFlight;
  Timer? _runtimeSignalTimer;
  bool _initialized = false;
  bool _disposed = false;

  @override
  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }

    _initialized = true;
    _startRuntimeSignalPolling();
    await _recomputeDecisionSafely();
  }

  @override
  Future<TierDecision> getCurrentDecision() async {
    if (!_initialized) {
      await initialize();
    }
    return _currentDecision!;
  }

  @override
  Stream<TierDecision> watchDecision() async* {
    if (_currentDecision != null) {
      yield _currentDecision!;
    } else if (!_initialized) {
      await initialize();
      yield _currentDecision!;
    }

    yield* _decisionController.stream;
  }

  @override
  Future<void> refresh() async {
    if (!_initialized) {
      await initialize();
      return;
    }

    await _recomputeDecisionSafely();
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _runtimeSignalTimer?.cancel();
    await _decisionController.close();
  }

  void _startRuntimeSignalPolling() {
    _runtimeSignalTimer?.cancel();
    if (_runtimeSignalRefreshInterval <= Duration.zero) {
      return;
    }
    _runtimeSignalTimer = Timer.periodic(_runtimeSignalRefreshInterval, (_) {
      if (!_initialized || _disposed) {
        return;
      }
      unawaited(_recomputeDecisionSafely());
    });
  }

  Future<void> _recomputeDecisionSafely() {
    if (_disposed) {
      return Future<void>.value();
    }
    final inFlight = _recomputeInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final next = _recomputeDecision().whenComplete(() {
      _recomputeInFlight = null;
    });
    _recomputeInFlight = next;
    return next;
  }

  Future<void> _recomputeDecision() async {
    final config = await _configProvider.load();
    DeviceSignals signals;
    try {
      signals = await _signalCollector.collect();
    } catch (error) {
      final fallbackDecision = _buildFallbackDecision(error);
      _currentDecision = fallbackDecision;
      if (!_disposed && !_decisionController.isClosed) {
        _decisionController.add(fallbackDecision);
      }
      return;
    }

    final baseDecision = _engine.evaluate(signals: signals, config: config);
    final runtimeAdjustment = _runtimeTierController.adjust(
      baseTier: baseDecision.tier,
      signals: signals,
    );
    final resolvedTier = runtimeAdjustment.tier;
    final policy = _policyResolver.resolve(resolvedTier);
    final reasons = <String>[
      ...baseDecision.reasons,
      ...runtimeAdjustment.reasons,
      'Resolved policy for tier=${resolvedTier.name}.',
    ];
    final decision = baseDecision.copyWith(
      tier: resolvedTier,
      reasons: reasons,
      appliedPolicies: policy.toMap(),
      runtimeObservation: runtimeAdjustment.observation,
    );

    _currentDecision = decision;
    if (!_disposed && !_decisionController.isClosed) {
      _decisionController.add(decision);
    }
  }

  TierDecision _buildFallbackDecision(Object error) {
    final now = DateTime.now();
    final fallbackSignals = DeviceSignals(
      platform: 'unknown',
      collectedAt: now,
    );
    return TierDecision(
      tier: TierLevel.t1Mid,
      confidence: TierConfidence.low,
      deviceSignals: fallbackSignals,
      reasons: <String>['Failed to collect platform signals: $error'],
      appliedPolicies: _policyResolver.resolve(TierLevel.t1Mid).toMap(),
    );
  }
}
