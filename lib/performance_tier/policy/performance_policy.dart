import 'package:flutter/foundation.dart';

import 'scenario_policy.dart';

@immutable
class PerformancePolicy {
  const PerformancePolicy({
    required this.animationLevel,
    required this.mediaPreloadCount,
    required this.decodeConcurrency,
    required this.imageMaxSidePx,
    this.scenarioPolicies = const <ScenarioPolicy>[],
  });

  final int animationLevel;
  final int mediaPreloadCount;
  final int decodeConcurrency;
  final int imageMaxSidePx;
  final List<ScenarioPolicy> scenarioPolicies;

  Map<String, Object> toMap() {
    return <String, Object>{
      'animationLevel': animationLevel,
      'mediaPreloadCount': mediaPreloadCount,
      'decodeConcurrency': decodeConcurrency,
      'imageMaxSidePx': imageMaxSidePx,
      'scenarioPolicies': scenarioPolicies
          .map((ScenarioPolicy policy) => policy.toMap())
          .toList(),
    };
  }
}
