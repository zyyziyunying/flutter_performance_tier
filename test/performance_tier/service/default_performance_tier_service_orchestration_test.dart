import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/default_performance_tier_service_test_support.dart';

void main() {
  group('DefaultPerformanceTierService orchestration', () {
    test('initializes once and appends resolved policy output', () async {
      final collector = SequenceSignalCollector(<DeviceSignals>[
        androidSignals(
          ramBytes: 8 * bytesPerGb,
          mediaPerformanceClass: 13,
          sdkInt: 35,
        ),
      ]);
      final configProvider = RecordingConfigProvider(const TierConfig());
      final engine = RecordingTierEngine(
        decisionFactory: (
            {required DeviceSignals signals, required TierConfig config}) {
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
      final resolver = RecordingPolicyResolver(policy);
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

    test(
      'refresh before initialize performs exactly one recomputation',
      () async {
        final collector = SequenceSignalCollector(<DeviceSignals>[
          androidSignals(
            ramBytes: 4 * bytesPerGb,
            mediaPerformanceClass: 11,
            sdkInt: 34,
          ),
          androidSignals(
            ramBytes: 12 * bytesPerGb,
            mediaPerformanceClass: 13,
            sdkInt: 34,
          ),
        ]);
        final configProvider = RecordingConfigProvider(const TierConfig());
        final engine = RecordingTierEngine(
          decisionFactory: (
              {required DeviceSignals signals, required TierConfig config}) {
            final tier = signals.totalRamBytes == 12 * bytesPerGb
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
        final resolver = RecordingPolicyResolver(
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
        final collector = SequenceSignalCollector(<DeviceSignals>[
          androidSignals(
            ramBytes: 4 * bytesPerGb,
            mediaPerformanceClass: 11,
            sdkInt: 34,
          ),
          androidSignals(
            ramBytes: 12 * bytesPerGb,
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

    test('returns fallback decision when signal collection fails', () async {
      final collector = ThrowingSignalCollector(
        StateError('collector offline'),
      );
      final engine = RecordingTierEngine(
        decisionFactory: (
            {required DeviceSignals signals, required TierConfig config}) {
          return TierDecision(
            tier: TierLevel.t3Ultra,
            confidence: TierConfidence.high,
            deviceSignals: signals,
          );
        },
      );
      final resolver = RecordingPolicyResolver(
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

    test(
      'config load failure falls back and later refresh can recover',
      () async {
        final collector = SequenceSignalCollector(<DeviceSignals>[
          androidSignals(
            ramBytes: 12 * bytesPerGb,
            mediaPerformanceClass: 13,
            sdkInt: 35,
          ),
        ]);
        final configProvider = SequenceConfigProvider(<Object>[
          StateError('config unavailable'),
          const TierConfig(),
        ]);
        final engine = RecordingTierEngine(
          decisionFactory: (
              {required DeviceSignals signals, required TierConfig config}) {
            return TierDecision(
              tier: TierLevel.t3Ultra,
              confidence: TierConfidence.high,
              deviceSignals: signals,
              reasons: const <String>['from fake engine'],
            );
          },
        );
        final resolver = RecordingPolicyResolver(
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
          runtimeSignalRefreshInterval: Duration.zero,
        );
        addTearDown(service.dispose);

        await service.initialize();
        final fallbackDecision = await service.getCurrentDecision();

        expect(configProvider.loadCallCount, 1);
        expect(collector.collectCallCount, 0);
        expect(engine.evaluateCallCount, 0);
        expect(fallbackDecision.tier, TierLevel.t1Mid);
        expect(fallbackDecision.confidence, TierConfidence.low);
        expect(fallbackDecision.deviceSignals.platform, 'unknown');
        expect(
          fallbackDecision.reasons.single,
          contains('Failed to load performance tier config:'),
        );
        expect(resolver.resolveCalls, <TierLevel>[TierLevel.t1Mid]);

        await service.refresh();
        final recoveredDecision = await service.getCurrentDecision();

        expect(configProvider.loadCallCount, 2);
        expect(collector.collectCallCount, 1);
        expect(engine.evaluateCallCount, 1);
        expect(recoveredDecision.tier, TierLevel.t3Ultra);
        expect(recoveredDecision.confidence, TierConfidence.high);
        expect(recoveredDecision.deviceSignals.platform, 'android');
        expect(resolver.resolveCalls, <TierLevel>[
          TierLevel.t1Mid,
          TierLevel.t3Ultra,
        ]);
      },
    );
  });
}
