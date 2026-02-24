import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleBasedTierEngine', () {
    const engine = RuleBasedTierEngine();
    const config = TierConfig();

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
  });
}
