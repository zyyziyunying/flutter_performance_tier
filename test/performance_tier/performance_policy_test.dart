import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PerformancePolicy parsing', () {
    test('parses resolver output and finds scenario by id', () {
      final rawPolicy = const DefaultPolicyResolver().resolve(TierLevel.t2High);
      final parsed = PerformancePolicy.fromMap(
        Map<String, Object?>.from(rawPolicy.toMap()),
      );

      expect(parsed.animationLevel, 2);
      expect(parsed.mediaPreloadCount, 3);
      expect(parsed.scenarioPolicies, hasLength(2));
      expect(
        parsed.scenarioById('home_hero_animation')?.knobs['animationPreset'],
        'enhanced',
      );
      expect(
        parsed
            .scenarioById('feed_video_list')
            ?.acceptanceTargets['maxJankRatePct'],
        5,
      );
    });

    test('throws FormatException when required fields are missing', () {
      expect(
        () => PerformancePolicy.fromMap(<String, Object?>{'animationLevel': 1}),
        throwsFormatException,
      );
    });
  });

  group('ScenarioPolicy parsing', () {
    test('parses valid payload map', () {
      final scenario = ScenarioPolicy.fromMap(<String, Object?>{
        'id': 'home_hero_animation',
        'displayName': 'Home hero animation',
        'knobs': <String, Object>{
          'animationPreset': 'minimal',
          'firstFramePreloadCount': 0,
        },
        'acceptanceTargets': <String, Object>{
          'firstResultBudgetMs': 300,
          'maxJankRatePct': 8,
        },
      });

      expect(scenario.id, 'home_hero_animation');
      expect(scenario.knobs['animationPreset'], 'minimal');
      expect(scenario.acceptanceTargets['firstResultBudgetMs'], 300);
    });

    test('throws FormatException when payload is invalid', () {
      expect(
        () => ScenarioPolicy.fromMap(<String, Object?>{
          'id': 'home_hero_animation',
          'displayName': 'Home hero animation',
        }),
        throwsFormatException,
      );
    });
  });
}
