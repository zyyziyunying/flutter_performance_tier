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

class DefaultPerformanceTierService implements PerformanceTierService {
  DefaultPerformanceTierService({
    DeviceSignalCollector? signalCollector,
    TierEngine? engine,
    PolicyResolver? policyResolver,
    ConfigProvider? configProvider,
  }) : _signalCollector =
           signalCollector ?? MethodChannelDeviceSignalCollector(),
       _engine = engine ?? const RuleBasedTierEngine(),
       _policyResolver = policyResolver ?? const DefaultPolicyResolver(),
       _configProvider = configProvider ?? const DefaultConfigProvider();

  final DeviceSignalCollector _signalCollector;
  final TierEngine _engine;
  final PolicyResolver _policyResolver;
  final ConfigProvider _configProvider;
  final StreamController<TierDecision> _decisionController =
      StreamController<TierDecision>.broadcast();

  TierDecision? _currentDecision;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    await _recomputeDecision();
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

    await _recomputeDecision();
  }

  Future<void> dispose() async {
    await _decisionController.close();
  }

  Future<void> _recomputeDecision() async {
    final config = await _configProvider.load();
    DeviceSignals signals;
    try {
      signals = await _signalCollector.collect();
    } catch (error) {
      final fallbackDecision = _buildFallbackDecision(error);
      _currentDecision = fallbackDecision;
      _decisionController.add(fallbackDecision);
      return;
    }

    final baseDecision = _engine.evaluate(signals: signals, config: config);
    final policy = _policyResolver.resolve(baseDecision.tier);
    final reasons = <String>[
      ...baseDecision.reasons,
      'Resolved policy for tier=${baseDecision.tier.name}.',
    ];
    final decision = baseDecision.copyWith(
      reasons: reasons,
      appliedPolicies: policy.toMap(),
    );

    _currentDecision = decision;
    _decisionController.add(decision);
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
