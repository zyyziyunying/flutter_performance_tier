import 'package:flutter/foundation.dart';
import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultPerformanceTierService orchestration', () {
    test('initializes once and appends resolved policy output', () async {
      final collector = _SequenceSignalCollector(<DeviceSignals>[
        _androidSignals(
          ramBytes: 8 * _bytesPerGb,
          mediaPerformanceClass: 13,
          sdkInt: 35,
        ),
      ]);
      final configProvider = _RecordingConfigProvider(const TierConfig());
      final engine = _RecordingTierEngine(
        decisionFactory:
            ({required DeviceSignals signals, required TierConfig config}) {
              return TierDecision(
                tier: TierLevel.t2High,
                confidence: TierConfidence.medium,
                deviceSignals: signals,
                reasons: const <String>['tier selected by fake engine'],
              );
            },
      );
      const policy = PerformancePolicy(
        animationLevel: 2,
        mediaPreloadCount: 3,
        decodeConcurrency: 2,
        imageMaxSidePx: 1440,
      );
      final resolver = _RecordingPolicyResolver(policy);
      final service = DefaultPerformanceTierService(
        signalCollector: collector,
        configProvider: configProvider,
        engine: engine,
        policyResolver: resolver,
      );
      addTearDown(service.dispose);

      await service.initialize();
      final decision = await service.getCurrentDecision();

      expect(configProvider.loadCallCount, 1);
      expect(collector.collectCallCount, 1);
      expect(engine.evaluateCallCount, 1);
      expect(resolver.resolveCalls, <TierLevel>[TierLevel.t2High]);
      expect(
        decision.reasons,
        contains('Resolved policy for tier=${TierLevel.t2High.name}.'),
      );
      expect(decision.appliedPolicies['animationLevel'], 2);
      expect(decision.appliedPolicies['decodeConcurrency'], 2);
    });

    test('applies runtime downgrade before resolving tier policy', () async {
      final collector = _SequenceSignalCollector(<DeviceSignals>[
        _androidSignals(
          ramBytes: 12 * _bytesPerGb,
          mediaPerformanceClass: 13,
          sdkInt: 35,
          thermalStateLevel: 2,
          isLowPowerModeEnabled: true,
        ),
      ]);
      final configProvider = _RecordingConfigProvider(const TierConfig());
      final engine = _RecordingTierEngine(
        decisionFactory:
            ({required DeviceSignals signals, required TierConfig config}) {
              return TierDecision(
                tier: TierLevel.t3Ultra,
                confidence: TierConfidence.high,
                deviceSignals: signals,
                reasons: const <String>['base tier selected by fake engine'],
              );
            },
      );
      const policy = PerformancePolicy(
        animationLevel: 1,
        mediaPreloadCount: 2,
        decodeConcurrency: 1,
        imageMaxSidePx: 1080,
      );
      final resolver = _RecordingPolicyResolver(policy);
      final service = DefaultPerformanceTierService(
        signalCollector: collector,
        configProvider: configProvider,
        engine: engine,
        policyResolver: resolver,
        runtimeSignalRefreshInterval: Duration.zero,
        runtimeTierController: RuntimeTierController(
          config: const RuntimeTierControllerConfig(
            downgradeDebounce: Duration.zero,
            recoveryCooldown: Duration(seconds: 30),
          ),
        ),
      );
      addTearDown(service.dispose);

      await service.initialize();
      final decision = await service.getCurrentDecision();

      expect(decision.tier, TierLevel.t1Mid);
      expect(
        decision.reasons.any(
          (reason) => reason.contains('Runtime downgrade active'),
        ),
        isTrue,
      );
      expect(decision.runtimeObservation.status, RuntimeTierStatus.active);
      expect(
        decision.runtimeObservation.triggerReason,
        contains('thermalState=serious(level=2)'),
      );
      expect(resolver.resolveCalls, <TierLevel>[TierLevel.t1Mid]);
    });

    test(
      'applies runtime downgrade when memory pressure signal is critical',
      () async {
        final collector = _SequenceSignalCollector(<DeviceSignals>[
          _androidSignals(
            ramBytes: 12 * _bytesPerGb,
            mediaPerformanceClass: 13,
            sdkInt: 35,
            thermalStateLevel: 0,
            isLowPowerModeEnabled: false,
            memoryPressureState: 'critical',
            memoryPressureLevel: 2,
          ),
        ]);
        final configProvider = _RecordingConfigProvider(const TierConfig());
        final engine = _RecordingTierEngine(
          decisionFactory:
              ({required DeviceSignals signals, required TierConfig config}) {
                return TierDecision(
                  tier: TierLevel.t3Ultra,
                  confidence: TierConfidence.high,
                  deviceSignals: signals,
                  reasons: const <String>['base tier selected by fake engine'],
                );
              },
        );
        const policy = PerformancePolicy(
          animationLevel: 1,
          mediaPreloadCount: 2,
          decodeConcurrency: 1,
          imageMaxSidePx: 1080,
        );
        final resolver = _RecordingPolicyResolver(policy);
        final service = DefaultPerformanceTierService(
          signalCollector: collector,
          configProvider: configProvider,
          engine: engine,
          policyResolver: resolver,
          runtimeSignalRefreshInterval: Duration.zero,
          runtimeTierController: RuntimeTierController(
            config: const RuntimeTierControllerConfig(
              downgradeDebounce: Duration.zero,
              recoveryCooldown: Duration(seconds: 30),
            ),
          ),
        );
        addTearDown(service.dispose);

        await service.initialize();
        final decision = await service.getCurrentDecision();

        expect(decision.tier, TierLevel.t1Mid);
        expect(
          decision.reasons.any(
            (reason) => reason.contains('memoryPressure=critical'),
          ),
          isTrue,
        );
        expect(decision.runtimeObservation.status, RuntimeTierStatus.active);
        expect(
          decision.runtimeObservation.triggerReason,
          contains('memoryPressure=critical'),
        );
        expect(resolver.resolveCalls, <TierLevel>[TierLevel.t1Mid]);
      },
    );

    test(
      'refresh before initialize performs exactly one recomputation',
      () async {
        final collector = _SequenceSignalCollector(<DeviceSignals>[
          _androidSignals(
            ramBytes: 4 * _bytesPerGb,
            mediaPerformanceClass: 11,
            sdkInt: 34,
          ),
          _androidSignals(
            ramBytes: 12 * _bytesPerGb,
            mediaPerformanceClass: 13,
            sdkInt: 34,
          ),
        ]);
        final configProvider = _RecordingConfigProvider(const TierConfig());
        final engine = _RecordingTierEngine(
          decisionFactory:
              ({required DeviceSignals signals, required TierConfig config}) {
                final tier = signals.totalRamBytes == 12 * _bytesPerGb
                    ? TierLevel.t3Ultra
                    : TierLevel.t1Mid;
                return TierDecision(
                  tier: tier,
                  confidence: TierConfidence.medium,
                  deviceSignals: signals,
                  reasons: const <String>['from fake engine'],
                );
              },
        );
        final resolver = _RecordingPolicyResolver(
          const PerformancePolicy(
            animationLevel: 1,
            mediaPreloadCount: 2,
            decodeConcurrency: 1,
            imageMaxSidePx: 1080,
          ),
        );
        final service = DefaultPerformanceTierService(
          signalCollector: collector,
          configProvider: configProvider,
          engine: engine,
          policyResolver: resolver,
        );
        addTearDown(service.dispose);

        await service.refresh();

        expect(configProvider.loadCallCount, 1);
        expect(collector.collectCallCount, 1);
        expect(engine.evaluateCallCount, 1);
        expect(resolver.resolveCalls, <TierLevel>[TierLevel.t1Mid]);

        await service.refresh();
        final latest = await service.getCurrentDecision();

        expect(configProvider.loadCallCount, 2);
        expect(collector.collectCallCount, 2);
        expect(engine.evaluateCallCount, 2);
        expect(resolver.resolveCalls, <TierLevel>[
          TierLevel.t1Mid,
          TierLevel.t3Ultra,
        ]);
        expect(latest.tier, TierLevel.t3Ultra);
      },
    );

    test(
      'watchDecision emits current decision first and then refreshed one',
      () async {
        final collector = _SequenceSignalCollector(<DeviceSignals>[
          _androidSignals(
            ramBytes: 4 * _bytesPerGb,
            mediaPerformanceClass: 11,
            sdkInt: 34,
          ),
          _androidSignals(
            ramBytes: 12 * _bytesPerGb,
            mediaPerformanceClass: 13,
            sdkInt: 34,
          ),
        ]);
        final service = DefaultPerformanceTierService(
          signalCollector: collector,
          configProvider: const DefaultConfigProvider(),
          engine: const RuleBasedTierEngine(),
          policyResolver: const DefaultPolicyResolver(),
        );
        addTearDown(service.dispose);

        await service.initialize();
        final streamFuture = service.watchDecision().take(2).toList();

        await service.refresh();
        final decisions = await streamFuture;

        expect(decisions, hasLength(2));
        expect(decisions.first.tier, TierLevel.t1Mid);
        expect(decisions.last.tier, TierLevel.t3Ultra);
        expect(collector.collectCallCount, 2);
      },
    );

    test(
      'periodic runtime polling updates decision without manual refresh',
      () async {
        final collector = _SequenceSignalCollector(<DeviceSignals>[
          _androidSignals(
            ramBytes: 12 * _bytesPerGb,
            mediaPerformanceClass: 13,
            sdkInt: 35,
            thermalStateLevel: 0,
            isLowPowerModeEnabled: false,
          ),
          _androidSignals(
            ramBytes: 12 * _bytesPerGb,
            mediaPerformanceClass: 13,
            sdkInt: 35,
            thermalStateLevel: 0,
            isLowPowerModeEnabled: true,
          ),
        ]);
        final engine = _RecordingTierEngine(
          decisionFactory:
              ({required DeviceSignals signals, required TierConfig config}) {
                return TierDecision(
                  tier: TierLevel.t3Ultra,
                  confidence: TierConfidence.high,
                  deviceSignals: signals,
                );
              },
        );
        final service = DefaultPerformanceTierService(
          signalCollector: collector,
          configProvider: const DefaultConfigProvider(),
          engine: engine,
          policyResolver: const DefaultPolicyResolver(),
          runtimeSignalRefreshInterval: const Duration(milliseconds: 10),
          runtimeTierController: RuntimeTierController(
            config: const RuntimeTierControllerConfig(
              downgradeDebounce: Duration.zero,
              recoveryCooldown: Duration(seconds: 30),
            ),
          ),
        );
        addTearDown(service.dispose);

        await service.initialize();
        final decisions = await service
            .watchDecision()
            .take(2)
            .toList()
            .timeout(const Duration(seconds: 1));

        expect(decisions.first.tier, TierLevel.t3Ultra);
        expect(decisions.last.tier, TierLevel.t2High);
        expect(collector.collectCallCount, greaterThanOrEqualTo(2));
      },
    );

    test('returns fallback decision when signal collection fails', () async {
      final collector = _ThrowingSignalCollector(
        StateError('collector offline'),
      );
      final engine = _RecordingTierEngine(
        decisionFactory:
            ({required DeviceSignals signals, required TierConfig config}) {
              return TierDecision(
                tier: TierLevel.t3Ultra,
                confidence: TierConfidence.high,
                deviceSignals: signals,
              );
            },
      );
      final resolver = _RecordingPolicyResolver(
        const PerformancePolicy(
          animationLevel: 1,
          mediaPreloadCount: 2,
          decodeConcurrency: 1,
          imageMaxSidePx: 1080,
        ),
      );
      final service = DefaultPerformanceTierService(
        signalCollector: collector,
        configProvider: const DefaultConfigProvider(),
        engine: engine,
        policyResolver: resolver,
      );
      addTearDown(service.dispose);

      await service.initialize();
      final decision = await service.getCurrentDecision();

      expect(decision.tier, TierLevel.t1Mid);
      expect(decision.confidence, TierConfidence.low);
      expect(decision.deviceSignals.platform, 'unknown');
      expect(
        decision.reasons.single,
        contains('Failed to collect platform signals:'),
      );
      expect(engine.evaluateCallCount, 0);
      expect(resolver.resolveCalls, <TierLevel>[TierLevel.t1Mid]);
    });
  });

  group('DefaultPerformanceTierService initialization baseline', () {
    test('returns first decision within 300ms budget', () async {
      const warmupRuns = 5;
      const measuredRuns = 40;
      final latenciesUs = <int>[];

      for (var i = 0; i < warmupRuns + measuredRuns; i++) {
        final service = DefaultPerformanceTierService(
          signalCollector: _SequenceSignalCollector(<DeviceSignals>[
            _androidSignals(
              ramBytes: 8 * _bytesPerGb,
              mediaPerformanceClass: 13,
              sdkInt: 35,
            ),
          ]),
          configProvider: const DefaultConfigProvider(),
          engine: const RuleBasedTierEngine(),
          policyResolver: const DefaultPolicyResolver(),
        );

        final stopwatch = Stopwatch()..start();
        await service.initialize();
        await service.getCurrentDecision();
        stopwatch.stop();
        await service.dispose();

        if (i >= warmupRuns) {
          latenciesUs.add(stopwatch.elapsedMicroseconds);
        }
      }

      latenciesUs.sort();
      final p50Us = _percentile(latenciesUs, percentile: 0.50);
      final p95Us = _percentile(latenciesUs, percentile: 0.95);
      final maxUs = latenciesUs.last;
      debugPrint(
        'DefaultPerformanceTierService initialize baseline: '
        'p50=${_toMilliseconds(p50Us)}ms, '
        'p95=${_toMilliseconds(p95Us)}ms, '
        'max=${_toMilliseconds(maxUs)}ms',
      );

      expect(
        p95Us,
        lessThanOrEqualTo(300000),
        reason:
            'Expected p95<=300ms but got p95=${_toMilliseconds(p95Us)}ms, '
            'max=${_toMilliseconds(maxUs)}ms.',
      );
    });
  });
}

const int _bytesPerGb = 1024 * 1024 * 1024;

class _SequenceSignalCollector implements DeviceSignalCollector {
  _SequenceSignalCollector(List<DeviceSignals> signals)
    : _signals = List<DeviceSignals>.from(signals);

  final List<DeviceSignals> _signals;
  int collectCallCount = 0;

  @override
  Future<DeviceSignals> collect() async {
    collectCallCount += 1;
    if (_signals.isEmpty) {
      throw StateError('No more fake signals.');
    }
    if (_signals.length == 1) {
      return _signals.first;
    }
    return _signals.removeAt(0);
  }
}

class _ThrowingSignalCollector implements DeviceSignalCollector {
  _ThrowingSignalCollector(this._error);

  final Object _error;
  int collectCallCount = 0;

  @override
  Future<DeviceSignals> collect() async {
    collectCallCount += 1;
    throw _error;
  }
}

class _RecordingConfigProvider implements ConfigProvider {
  _RecordingConfigProvider(this._config);

  final TierConfig _config;
  int loadCallCount = 0;

  @override
  Future<TierConfig> load() async {
    loadCallCount += 1;
    return _config;
  }
}

class _RecordingTierEngine implements TierEngine {
  _RecordingTierEngine({required this.decisionFactory});

  final TierDecision Function({
    required DeviceSignals signals,
    required TierConfig config,
  })
  decisionFactory;
  int evaluateCallCount = 0;

  @override
  TierDecision evaluate({
    required DeviceSignals signals,
    required TierConfig config,
  }) {
    evaluateCallCount += 1;
    return decisionFactory(signals: signals, config: config);
  }
}

class _RecordingPolicyResolver implements PolicyResolver {
  _RecordingPolicyResolver(this._policy);

  final PerformancePolicy _policy;
  final List<TierLevel> resolveCalls = <TierLevel>[];

  @override
  PerformancePolicy resolve(TierLevel tier) {
    resolveCalls.add(tier);
    return _policy;
  }
}

DeviceSignals _androidSignals({
  required int ramBytes,
  required int sdkInt,
  required int mediaPerformanceClass,
  bool isLowRamDevice = false,
  String deviceModel = 'Pixel 8 Pro',
  int? thermalStateLevel,
  bool? isLowPowerModeEnabled,
  String? memoryPressureState,
  int? memoryPressureLevel,
}) {
  return DeviceSignals(
    platform: 'android',
    deviceModel: deviceModel,
    totalRamBytes: ramBytes,
    isLowRamDevice: isLowRamDevice,
    mediaPerformanceClass: mediaPerformanceClass,
    sdkInt: sdkInt,
    thermalStateLevel: thermalStateLevel,
    isLowPowerModeEnabled: isLowPowerModeEnabled,
    memoryPressureState: memoryPressureState,
    memoryPressureLevel: memoryPressureLevel,
    collectedAt: DateTime(2026),
  );
}

int _percentile(List<int> sortedValues, {required double percentile}) {
  if (sortedValues.isEmpty) {
    throw ArgumentError('sortedValues must not be empty.');
  }
  var index = (sortedValues.length * percentile).ceil() - 1;
  if (index < 0) {
    index = 0;
  }
  if (index >= sortedValues.length) {
    index = sortedValues.length - 1;
  }
  return sortedValues[index];
}

String _toMilliseconds(int microseconds) {
  return (microseconds / 1000).toStringAsFixed(2);
}
