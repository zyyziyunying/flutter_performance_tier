import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/default_performance_tier_service_test_support.dart';

void main() {
  group('DefaultPerformanceTierService logging', () {
    test('emits structured decision logs for initialize and refresh', () async {
      final collector = SequenceSignalCollector(<DeviceSignals>[
        androidSignals(
          ramBytes: 4 * bytesPerGb,
          mediaPerformanceClass: 11,
          sdkInt: 34,
        ),
        androidSignals(
          ramBytes: 12 * bytesPerGb,
          mediaPerformanceClass: 13,
          sdkInt: 35,
        ),
      ]);
      final logger = RecordingLogger();
      final service = DefaultPerformanceTierService(
        signalCollector: collector,
        configProvider: const DefaultConfigProvider(),
        engine: const RuleBasedTierEngine(),
        policyResolver: const DefaultPolicyResolver(),
        runtimeSignalRefreshInterval: Duration.zero,
        logger: logger,
      );
      addTearDown(service.dispose);

      await service.initialize();
      await service.refresh();

      final completedEvents = logger.records
          .where((record) => record.event == 'decision.recompute.completed')
          .toList();

      expect(completedEvents, hasLength(2));
      expect(completedEvents.first.payload['trigger'], 'initialize');
      expect(
        completedEvents.first.payload['transition'],
        containsPair('type', 'initial'),
      );
      expect(completedEvents.last.payload['trigger'], 'manualRefresh');
      expect(
        completedEvents.last.payload['transition'],
        containsPair('fromTier', TierLevel.t1Mid.name),
      );
      expect(
        completedEvents.last.payload['transition'],
        containsPair('toTier', TierLevel.t3Ultra.name),
      );
    });
  });
}
