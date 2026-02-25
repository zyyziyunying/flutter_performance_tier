import 'dart:async';

import '../config/config_provider.dart';
import '../engine/rule_based_tier_engine.dart';
import '../engine/tier_engine.dart';
import '../logging/performance_tier_logger.dart';
import '../model/device_signals.dart';
import '../model/tier_confidence.dart';
import '../model/tier_decision.dart';
import '../model/tier_level.dart';
import '../performance_tier_service.dart';
import '../policy/policy_resolver.dart';
import 'device_signal_collector.dart';
import 'frame_drop_signal_sampler.dart';
import 'method_channel_device_signal_collector.dart';
import 'runtime_tier_controller.dart';

class DefaultPerformanceTierService implements PerformanceTierService {
  DefaultPerformanceTierService({
    DeviceSignalCollector? signalCollector,
    TierEngine? engine,
    PolicyResolver? policyResolver,
    ConfigProvider? configProvider,
    RuntimeTierController? runtimeTierController,
    FrameDropSignalSampler? frameDropSignalSampler,
    Duration runtimeSignalRefreshInterval = const Duration(seconds: 15),
    bool enableFrameDropSignal = false,
    PerformanceTierLogger? logger,
  }) : _signalCollector =
           signalCollector ?? MethodChannelDeviceSignalCollector(),
       _engine = engine ?? const RuleBasedTierEngine(),
       _policyResolver = policyResolver ?? const DefaultPolicyResolver(),
       _configProvider = configProvider ?? const DefaultConfigProvider(),
       _runtimeTierController =
           runtimeTierController ??
           RuntimeTierController(
             config: RuntimeTierControllerConfig(
               enableFrameDropSignal: enableFrameDropSignal,
             ),
           ),
       _frameDropSignalSampler =
           frameDropSignalSampler ??
           (enableFrameDropSignal
               ? SchedulerFrameDropSignalSampler()
               : const DisabledFrameDropSignalSampler()),
       _runtimeSignalRefreshInterval = runtimeSignalRefreshInterval,
       _logger = logger ?? const SilentPerformanceTierLogger(),
       _sessionId = _buildSessionId();

  final DeviceSignalCollector _signalCollector;
  final TierEngine _engine;
  final PolicyResolver _policyResolver;
  final ConfigProvider _configProvider;
  final RuntimeTierController _runtimeTierController;
  final FrameDropSignalSampler _frameDropSignalSampler;
  final Duration _runtimeSignalRefreshInterval;
  final PerformanceTierLogger _logger;
  final String _sessionId;
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
      _logEvent('service.initialize.skipped', <String, Object?>{
        'initialized': _initialized,
        'disposed': _disposed,
      });
      return;
    }

    _logEvent('service.initialize.started', <String, Object?>{
      'runtimeSignalRefreshIntervalMs':
          _runtimeSignalRefreshInterval.inMilliseconds,
      'frameDropSignalEnabled':
          _runtimeTierController.config.enableFrameDropSignal,
    });
    _initialized = true;
    _frameDropSignalSampler.start();
    _startRuntimeSignalPolling();
    await _recomputeDecisionSafely(trigger: _RecomputeTrigger.initialize);
    _logEvent('service.initialize.completed', <String, Object?>{
      'hasDecision': _currentDecision != null,
      'tier': _currentDecision?.tier.name,
    });
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
      _logEvent('service.refresh.beforeInitialize');
      await initialize();
      return;
    }

    _logEvent('service.refresh.requested');
    await _recomputeDecisionSafely(trigger: _RecomputeTrigger.manualRefresh);
    _logEvent('service.refresh.completed', <String, Object?>{
      'tier': _currentDecision?.tier.name,
    });
  }

  Future<void> dispose() async {
    if (_disposed) {
      _logEvent('service.dispose.skipped', const <String, Object?>{
        'reason': 'alreadyDisposed',
      });
      return;
    }
    _logEvent('service.dispose.started', <String, Object?>{
      'hasDecision': _currentDecision != null,
    });
    _disposed = true;
    _runtimeSignalTimer?.cancel();
    _frameDropSignalSampler.stop();
    await _decisionController.close();
    _logEvent('service.dispose.completed');
  }

  void _startRuntimeSignalPolling() {
    _runtimeSignalTimer?.cancel();
    if (_runtimeSignalRefreshInterval <= Duration.zero) {
      _logEvent('runtime.polling.disabled', <String, Object?>{
        'intervalMs': _runtimeSignalRefreshInterval.inMilliseconds,
      });
      return;
    }
    _logEvent('runtime.polling.started', <String, Object?>{
      'intervalMs': _runtimeSignalRefreshInterval.inMilliseconds,
    });
    _runtimeSignalTimer = Timer.periodic(_runtimeSignalRefreshInterval, (_) {
      if (!_initialized || _disposed) {
        return;
      }
      unawaited(
        _recomputeDecisionSafely(trigger: _RecomputeTrigger.runtimePolling),
      );
    });
  }

  Future<void> _recomputeDecisionSafely({required _RecomputeTrigger trigger}) {
    if (_disposed) {
      _logEvent('decision.recompute.skipped', <String, Object?>{
        'trigger': trigger.wireName,
        'reason': 'disposed',
      });
      return Future<void>.value();
    }
    final inFlight = _recomputeInFlight;
    if (inFlight != null) {
      _logEvent('decision.recompute.coalesced', <String, Object?>{
        'trigger': trigger.wireName,
      });
      return inFlight;
    }

    final next = _recomputeDecision(trigger: trigger).whenComplete(() {
      _recomputeInFlight = null;
    });
    _recomputeInFlight = next;
    return next;
  }

  Future<void> _recomputeDecision({required _RecomputeTrigger trigger}) async {
    _logEvent('decision.recompute.started', <String, Object?>{
      'trigger': trigger.wireName,
    });
    final config = await _configProvider.load();
    DeviceSignals signals;
    try {
      signals = await _signalCollector.collect();
    } catch (error) {
      final fallbackDecision = _buildFallbackDecision(error);
      final previousDecision = _currentDecision;
      _currentDecision = fallbackDecision;
      _logEvent('decision.recompute.fallback', <String, Object?>{
        'trigger': trigger.wireName,
        'error': '$error',
        'transition': _buildTransition(
          previous: previousDecision,
          current: fallbackDecision,
        ),
        'decision': fallbackDecision.toMap(),
      });
      if (!_disposed && !_decisionController.isClosed) {
        _decisionController.add(fallbackDecision);
      }
      return;
    }
    signals = _mergeFrameDropSignals(signals);

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

    final previousDecision = _currentDecision;
    _currentDecision = decision;
    _logEvent('decision.recompute.completed', <String, Object?>{
      'trigger': trigger.wireName,
      'transition': _buildTransition(
        previous: previousDecision,
        current: decision,
      ),
      'decision': decision.toMap(),
    });
    if (!_disposed && !_decisionController.isClosed) {
      _decisionController.add(decision);
    }
  }

  DeviceSignals _mergeFrameDropSignals(DeviceSignals signals) {
    final snapshot = _frameDropSignalSampler.currentSnapshot();
    if (!snapshot.hasSignal) {
      return signals;
    }
    return signals.copyWith(
      frameDropState: snapshot.state,
      frameDropLevel: snapshot.level,
      frameDropRate: snapshot.dropRate,
      frameDroppedCount: snapshot.droppedFrameCount,
      frameSampledCount: snapshot.sampledFrameCount,
    );
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

  Map<String, Object?> _buildTransition({
    required TierDecision? previous,
    required TierDecision current,
  }) {
    if (previous == null) {
      return <String, Object?>{
        'type': 'initial',
        'toTier': current.tier.name,
        'toRuntimeStatus': current.runtimeObservation.status.wireName,
      };
    }

    final tierChanged = previous.tier != current.tier;
    final runtimeStatusChanged =
        previous.runtimeObservation.status != current.runtimeObservation.status;
    return <String, Object?>{
      'type': tierChanged || runtimeStatusChanged ? 'changed' : 'stable',
      'tierChanged': tierChanged,
      'runtimeStatusChanged': runtimeStatusChanged,
      'fromTier': previous.tier.name,
      'toTier': current.tier.name,
      'fromConfidence': previous.confidence.name,
      'toConfidence': current.confidence.name,
      'fromRuntimeStatus': previous.runtimeObservation.status.wireName,
      'toRuntimeStatus': current.runtimeObservation.status.wireName,
    };
  }

  void _logEvent(
    String event, [
    Map<String, Object?> payload = const <String, Object?>{},
  ]) {
    _logger.log(
      PerformanceTierLogRecord(
        event: event,
        timestamp: DateTime.now(),
        sessionId: _sessionId,
        payload: payload,
      ),
    );
  }

  static String _buildSessionId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'perf-tier-$micros';
  }
}

enum _RecomputeTrigger {
  initialize,
  manualRefresh,
  runtimePolling;

  String get wireName {
    return switch (this) {
      _RecomputeTrigger.initialize => 'initialize',
      _RecomputeTrigger.manualRefresh => 'manualRefresh',
      _RecomputeTrigger.runtimePolling => 'runtimePolling',
    };
  }
}
