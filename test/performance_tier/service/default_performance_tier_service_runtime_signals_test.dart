import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/default_performance_tier_service_test_support.dart';

void main() {
  group('DefaultPerformanceTierService runtime signals', () {
    test('applies runtime downgrade before resolving tier policy', () async {
      final collector = SequenceSignalCollector(<DeviceSignals>[
        androidSignals(
          ramBytes: 12 * bytesPerGb,
          mediaPerformanceClass: 13,
          sdkInt: 35,
          thermalStateLevel: 2,
          isLowPowerModeEnabled: true,
        ),
      ]);
      final configProvider = RecordingConfigProvider(const TierConfig());
      final engine = RecordingTierEngine(
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
      final resolver = RecordingPolicyResolver(policy);
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
      expect(decision.runtimeObservation.downgradeTriggerCount, 1);
      expect(decision.runtimeObservation.recoveryTriggerCount, 0);
      expect(decision.runtimeObservation.statusDuration, Duration.zero);
      expect(resolver.resolveCalls, <TierLevel>[TierLevel.t1Mid]);
    });

    test(
      'applies runtime downgrade when memory pressure signal is critical',
      () async {
        final collector = SequenceSignalCollector(<DeviceSignals>[
          androidSignals(
            ramBytes: 12 * bytesPerGb,
            mediaPerformanceClass: 13,
            sdkInt: 35,
            thermalStateLevel: 0,
            isLowPowerModeEnabled: false,
            memoryPressureState: 'critical',
            memoryPressureLevel: 2,
          ),
        ]);
        final configProvider = RecordingConfigProvider(const TierConfig());
        final engine = RecordingTierEngine(
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
        final resolver = RecordingPolicyResolver(policy);
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
        expect(decision.runtimeObservation.downgradeTriggerCount, 1);
        expect(decision.runtimeObservation.recoveryTriggerCount, 0);
        expect(resolver.resolveCalls, <TierLevel>[TierLevel.t1Mid]);
      },
    );

    test(
      'applies runtime downgrade when frame-drop signal is critical',
      () async {
        final collector = SequenceSignalCollector(<DeviceSignals>[
          androidSignals(
            ramBytes: 12 * bytesPerGb,
            mediaPerformanceClass: 13,
            sdkInt: 35,
            thermalStateLevel: 0,
            isLowPowerModeEnabled: false,
          ),
        ]);
        final frameDropSampler =
            SequenceFrameDropSignalSampler(<FrameDropSignalSnapshot>[
              const FrameDropSignalSnapshot(
                state: 'critical',
                level: 2,
                dropRate: 0.35,
                droppedFrameCount: 22,
                sampledFrameCount: 60,
              ),
            ]);
        final configProvider = RecordingConfigProvider(const TierConfig());
        final engine = RecordingTierEngine(
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
        final resolver = RecordingPolicyResolver(policy);
        final service = DefaultPerformanceTierService(
          signalCollector: collector,
          frameDropSignalSampler: frameDropSampler,
          enableFrameDropSignal: true,
          configProvider: configProvider,
          engine: engine,
          policyResolver: resolver,
          runtimeSignalRefreshInterval: Duration.zero,
          runtimeTierController: RuntimeTierController(
            config: const RuntimeTierControllerConfig(
              downgradeDebounce: Duration.zero,
              recoveryCooldown: Duration(seconds: 30),
              enableFrameDropSignal: true,
            ),
          ),
        );
        addTearDown(service.dispose);

        await service.initialize();
        final decision = await service.getCurrentDecision();

        expect(decision.tier, TierLevel.t1Mid);
        expect(decision.deviceSignals.frameDropState, 'critical');
        expect(decision.deviceSignals.frameDropLevel, 2);
        expect(decision.deviceSignals.frameDropRate, 0.35);
        expect(
          decision.reasons.any(
            (reason) => reason.contains('frameDrop=critical'),
          ),
          isTrue,
        );
        expect(frameDropSampler.startCallCount, 1);
        expect(resolver.resolveCalls, <TierLevel>[TierLevel.t1Mid]);
      },
    );

    test(
      'periodic runtime polling updates decision without manual refresh',
      () async {
        final collector = SequenceSignalCollector(<DeviceSignals>[
          androidSignals(
            ramBytes: 12 * bytesPerGb,
            mediaPerformanceClass: 13,
            sdkInt: 35,
            thermalStateLevel: 0,
            isLowPowerModeEnabled: false,
          ),
          androidSignals(
            ramBytes: 12 * bytesPerGb,
            mediaPerformanceClass: 13,
            sdkInt: 35,
            thermalStateLevel: 0,
            isLowPowerModeEnabled: true,
          ),
        ]);
        final engine = RecordingTierEngine(
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
  });
}
