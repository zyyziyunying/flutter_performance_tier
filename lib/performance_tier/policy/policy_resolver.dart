import '../model/tier_level.dart';
import 'performance_policy.dart';

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
      ),
      TierLevel.t1Mid => const PerformancePolicy(
        animationLevel: 1,
        mediaPreloadCount: 2,
        decodeConcurrency: 1,
        imageMaxSidePx: 1080,
      ),
      TierLevel.t2High => const PerformancePolicy(
        animationLevel: 2,
        mediaPreloadCount: 3,
        decodeConcurrency: 2,
        imageMaxSidePx: 1440,
      ),
      TierLevel.t3Ultra => const PerformancePolicy(
        animationLevel: 3,
        mediaPreloadCount: 4,
        decodeConcurrency: 3,
        imageMaxSidePx: 2160,
      ),
    };
  }
}
