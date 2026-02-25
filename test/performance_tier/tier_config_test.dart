import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TierConfig', () {
    const gb = 1024 * 1024 * 1024;

    test('applies override patch on top of base rulebook', () {
      const base = TierConfig(
        lowRamMaxBytes: 3 * gb,
        midRamMaxBytes: 6 * gb,
        highRamMaxBytes: 10 * gb,
      );

      const override = TierConfigOverride(
        lowRamMaxBytes: 2 * gb,
        minSdkForHighTier: 29,
        minSdkForUltraTier: 33,
        modelTierCaps: <ModelTierCapRule>[
          ModelTierCapRule(pattern: 'SM-A0', maxTier: TierLevel.t1Mid),
        ],
      );

      final merged = base.applyOverride(override);

      expect(merged.lowRamMaxBytes, 2 * gb);
      expect(merged.midRamMaxBytes, 6 * gb);
      expect(merged.minSdkForHighTier, 29);
      expect(merged.minSdkForUltraTier, 33);
      expect(merged.modelTierCaps, hasLength(1));
      expect(merged.modelTierCaps.first.maxTier, TierLevel.t1Mid);
    });

    test('parses override payload map', () {
      final override = TierConfigOverride.fromMap(<String, Object?>{
        'highMediaPerformanceClass': 11,
        'ultraMediaPerformanceClass': 12,
        'modelTierCaps': <Map<String, Object?>>[
          <String, Object?>{
            'pattern': 'iPhone10',
            'maxTier': 't1_mid',
            'caseSensitive': false,
          },
        ],
      });

      expect(override.highMediaPerformanceClass, 11);
      expect(override.ultraMediaPerformanceClass, 12);
      expect(override.modelTierCaps, hasLength(1));
      expect(override.modelTierCaps!.first.maxTier, TierLevel.t1Mid);
      expect(override.modelTierCaps!.first.matches('iPhone10,3'), isTrue);
    });
  });

  group('DefaultConfigProvider', () {
    test('returns merged config with override patch', () async {
      const provider = DefaultConfigProvider(
        config: TierConfig(minSdkForHighTier: 0),
        configOverride: TierConfigOverride(minSdkForHighTier: 28),
      );

      final loaded = await provider.load();
      expect(loaded.minSdkForHighTier, 28);
    });
  });
}
