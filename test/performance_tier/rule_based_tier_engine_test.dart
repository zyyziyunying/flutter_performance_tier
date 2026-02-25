import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleBasedTierEngine', () {
    const engine = RuleBasedTierEngine();
    const config = TierConfig();
    const gb = 1024 * 1024 * 1024;

    test('returns low tier when low-ram device is reported', () {
      final decision = engine.evaluate(
        signals: DeviceSignals(
          platform: 'android',
          collectedAt: DateTime(2026),
          totalRamBytes: 8 * 1024 * 1024 * 1024,
          isLowRamDevice: true,
          mediaPerformanceClass: 13,
          sdkInt: 35,
        ),
        config: config,
      );

      expect(decision.tier, TierLevel.t0Low);
      expect(decision.confidence, TierConfidence.high);
    });

    test('raises tier by media performance class signal', () {
      final decision = engine.evaluate(
        signals: DeviceSignals(
          platform: 'android',
          collectedAt: DateTime(2026),
          totalRamBytes: 4 * 1024 * 1024 * 1024,
          isLowRamDevice: false,
          mediaPerformanceClass: 12,
          sdkInt: 35,
        ),
        config: config,
      );

      expect(decision.tier, TierLevel.t2High);
      expect(decision.confidence, TierConfidence.high);
    });

    test('caps tier when sdk version is below configured thresholds', () {
      final decision = engine.evaluate(
        signals: DeviceSignals(
          platform: 'android',
          collectedAt: DateTime(2026),
          totalRamBytes: 12 * gb,
          isLowRamDevice: false,
          mediaPerformanceClass: 13,
          sdkInt: 28,
        ),
        config: const TierConfig(minSdkForHighTier: 29, minSdkForUltraTier: 33),
      );

      expect(decision.tier, TierLevel.t1Mid);
      expect(
        decision.reasons.any((reason) => reason.contains('minSdkForHighTier')),
        isTrue,
      );
    });

    test('caps tier when model rule is matched', () {
      final decision = engine.evaluate(
        signals: DeviceSignals(
          platform: 'android',
          deviceModel: 'Moto E(7)',
          collectedAt: DateTime(2026),
          totalRamBytes: 8 * gb,
          isLowRamDevice: false,
          mediaPerformanceClass: 13,
          sdkInt: 34,
        ),
        config: const TierConfig(
          modelTierCaps: <ModelTierCapRule>[
            ModelTierCapRule(pattern: 'moto e', maxTier: TierLevel.t1Mid),
          ],
        ),
      );

      expect(decision.tier, TierLevel.t1Mid);
      expect(
        decision.reasons.any((reason) => reason.contains('matched "moto e"')),
        isTrue,
      );
    });
  });
}
