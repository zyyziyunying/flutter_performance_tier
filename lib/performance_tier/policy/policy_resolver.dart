import '../model/tier_level.dart';
import 'performance_policy.dart';
import 'scenario_policy.dart';

abstract interface class PolicyResolver {
  PerformancePolicy resolve(TierLevel tier);
}

class DefaultPolicyResolver implements PolicyResolver {
  const DefaultPolicyResolver();

  @override
  PerformancePolicy resolve(TierLevel tier) {
    return switch (tier) {
      TierLevel.t0Low => const PerformancePolicy(
        animationLevel: 0,
        mediaPreloadCount: 1,
        decodeConcurrency: 1,
        imageMaxSidePx: 720,
        scenarioPolicies: <ScenarioPolicy>[
          ScenarioPolicy(
            id: 'home_hero_animation',
            displayName: 'Home hero animation',
            knobs: <String, Object>{
              'animationPreset': 'minimal',
              'particleEffectsEnabled': false,
              'firstFramePreloadCount': 0,
            },
            acceptanceTargets: <String, Object>{
              'firstResultBudgetMs': 300,
              'firstFrameBudgetMs': 450,
              'maxJankRatePct': 8,
            },
          ),
          ScenarioPolicy(
            id: 'feed_video_list',
            displayName: 'Feed/video list',
            knobs: <String, Object>{
              'autoplayEnabled': false,
              'mediaPreloadCount': 1,
              'decodeConcurrency': 1,
              'thumbnailMaxSidePx': 720,
            },
            acceptanceTargets: <String, Object>{
              'maxColdStartToFirstVideoMs': 1200,
              'maxJankRatePct': 10,
              'maxResidentMemoryMb': 380,
            },
          ),
        ],
      ),
      TierLevel.t1Mid => const PerformancePolicy(
        animationLevel: 1,
        mediaPreloadCount: 2,
        decodeConcurrency: 1,
        imageMaxSidePx: 1080,
        scenarioPolicies: <ScenarioPolicy>[
          ScenarioPolicy(
            id: 'home_hero_animation',
            displayName: 'Home hero animation',
            knobs: <String, Object>{
              'animationPreset': 'basic',
              'particleEffectsEnabled': false,
              'firstFramePreloadCount': 1,
            },
            acceptanceTargets: <String, Object>{
              'firstResultBudgetMs': 300,
              'firstFrameBudgetMs': 380,
              'maxJankRatePct': 6,
            },
          ),
          ScenarioPolicy(
            id: 'feed_video_list',
            displayName: 'Feed/video list',
            knobs: <String, Object>{
              'autoplayEnabled': true,
              'mediaPreloadCount': 2,
              'decodeConcurrency': 1,
              'thumbnailMaxSidePx': 1080,
            },
            acceptanceTargets: <String, Object>{
              'maxColdStartToFirstVideoMs': 1000,
              'maxJankRatePct': 7,
              'maxResidentMemoryMb': 460,
            },
          ),
        ],
      ),
      TierLevel.t2High => const PerformancePolicy(
        animationLevel: 2,
        mediaPreloadCount: 3,
        decodeConcurrency: 2,
        imageMaxSidePx: 1440,
        scenarioPolicies: <ScenarioPolicy>[
          ScenarioPolicy(
            id: 'home_hero_animation',
            displayName: 'Home hero animation',
            knobs: <String, Object>{
              'animationPreset': 'enhanced',
              'particleEffectsEnabled': true,
              'firstFramePreloadCount': 2,
            },
            acceptanceTargets: <String, Object>{
              'firstResultBudgetMs': 300,
              'firstFrameBudgetMs': 320,
              'maxJankRatePct': 4,
            },
          ),
          ScenarioPolicy(
            id: 'feed_video_list',
            displayName: 'Feed/video list',
            knobs: <String, Object>{
              'autoplayEnabled': true,
              'mediaPreloadCount': 3,
              'decodeConcurrency': 2,
              'thumbnailMaxSidePx': 1440,
            },
            acceptanceTargets: <String, Object>{
              'maxColdStartToFirstVideoMs': 850,
              'maxJankRatePct': 5,
              'maxResidentMemoryMb': 560,
            },
          ),
        ],
      ),
      TierLevel.t3Ultra => const PerformancePolicy(
        animationLevel: 3,
        mediaPreloadCount: 4,
        decodeConcurrency: 3,
        imageMaxSidePx: 2160,
        scenarioPolicies: <ScenarioPolicy>[
          ScenarioPolicy(
            id: 'home_hero_animation',
            displayName: 'Home hero animation',
            knobs: <String, Object>{
              'animationPreset': 'full',
              'particleEffectsEnabled': true,
              'firstFramePreloadCount': 3,
            },
            acceptanceTargets: <String, Object>{
              'firstResultBudgetMs': 300,
              'firstFrameBudgetMs': 280,
              'maxJankRatePct': 3,
            },
          ),
          ScenarioPolicy(
            id: 'feed_video_list',
            displayName: 'Feed/video list',
            knobs: <String, Object>{
              'autoplayEnabled': true,
              'mediaPreloadCount': 4,
              'decodeConcurrency': 3,
              'thumbnailMaxSidePx': 2160,
            },
            acceptanceTargets: <String, Object>{
              'maxColdStartToFirstVideoMs': 700,
              'maxJankRatePct': 4,
              'maxResidentMemoryMb': 700,
            },
          ),
        ],
      ),
    };
  }
}
