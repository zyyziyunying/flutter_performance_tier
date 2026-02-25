import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultPolicyResolver', () {
    const resolver = DefaultPolicyResolver();

    test('returns two high-load scenario mappings for each tier', () {
      for (final tier in TierLevel.values) {
        final policy = resolver.resolve(tier);
        expect(policy.scenarioPolicies, hasLength(2));
        expect(
          policy.scenarioPolicies.map((ScenarioPolicy it) => it.id),
          containsAll(<String>['home_hero_animation', 'feed_video_list']),
        );
      }
    });

    test('uses tighter animation budget for high tiers', () {
      final lowPolicy = resolver.resolve(TierLevel.t0Low);
      final ultraPolicy = resolver.resolve(TierLevel.t3Ultra);

      final lowHome = lowPolicy.scenarioPolicies.firstWhere(
        (ScenarioPolicy it) => it.id == 'home_hero_animation',
      );
      final ultraHome = ultraPolicy.scenarioPolicies.firstWhere(
        (ScenarioPolicy it) => it.id == 'home_hero_animation',
      );

      expect(lowHome.knobs['animationPreset'], 'minimal');
      expect(ultraHome.knobs['animationPreset'], 'full');
      expect(ultraHome.acceptanceTargets['firstFrameBudgetMs'], 280);
    });

    test('increases video preload capacity by tier', () {
      final midPolicy = resolver.resolve(TierLevel.t1Mid);
      final highPolicy = resolver.resolve(TierLevel.t2High);

      final midVideo = midPolicy.scenarioPolicies.firstWhere(
        (ScenarioPolicy it) => it.id == 'feed_video_list',
      );
      final highVideo = highPolicy.scenarioPolicies.firstWhere(
        (ScenarioPolicy it) => it.id == 'feed_video_list',
      );

      expect(midVideo.knobs['mediaPreloadCount'], 2);
      expect(highVideo.knobs['mediaPreloadCount'], 3);
      expect(highVideo.acceptanceTargets['maxColdStartToFirstVideoMs'], 850);
    });
  });
}
