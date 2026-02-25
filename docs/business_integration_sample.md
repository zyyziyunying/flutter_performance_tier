# 业务接入样例：按场景命中策略

更新时间：2026-02-25

## 场景

以下示例展示业务页面如何从 `TierDecision.appliedPolicies` 中提取场景策略，并命中 `home_hero_animation` / `feed_video_list`。

## 示例代码

```dart
import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';

class SceneStrategyAdapter {
  const SceneStrategyAdapter();

  ScenarioPolicy? resolveScenario(
    TierDecision decision,
    String scenarioId,
  ) {
    final rawPolicy = Map<String, Object?>.from(decision.appliedPolicies);
    final policy = PerformancePolicy.fromMap(rawPolicy);
    return policy.scenarioById(scenarioId);
  }
}

void applyFeedVideoPolicy(TierDecision decision) {
  const adapter = SceneStrategyAdapter();
  final scenario = adapter.resolveScenario(decision, 'feed_video_list');
  if (scenario == null) {
    return;
  }

  final knobs = scenario.knobs;
  final autoplayEnabled = knobs['autoplayEnabled'] as bool? ?? false;
  final preloadCount = knobs['mediaPreloadCount'] as int? ?? 1;
  final decodeConcurrency = knobs['decodeConcurrency'] as int? ?? 1;

  // 将策略参数映射到业务组件。
  configureFeedPlayer(
    autoplayEnabled: autoplayEnabled,
    preloadCount: preloadCount,
    decodeConcurrency: decodeConcurrency,
  );
}

void configureFeedPlayer({
  required bool autoplayEnabled,
  required int preloadCount,
  required int decodeConcurrency,
}) {
  // 业务侧实现。
}
```

## 建议

- 先按 `scenarioId` 取策略，再读取 `knobs`，避免直接依赖 Tier 常量分支。
- 对每个字段提供业务兜底值，保证策略缺失时可回退。
- 结合 `acceptanceTargets` 做验收监控（如卡顿率、首结果耗时）。
