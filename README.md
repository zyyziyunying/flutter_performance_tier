# Flutter Performance Tier

一个可复用的 Flutter 性能分级能力（Android / iOS），用于：

- 启动阶段快速给出设备分级（Tier）
- 将 Tier 映射为业务策略（动画、媒体、缓存等）
- 基于运行期信号做动态降级（热状态、低电量、内存压力、掉帧信号）

## 开发命令

- `flutter pub get`
- `flutter analyze`
- `dart format lib test`
- `flutter test`
- `flutter run`

## 结构化日志优先（已移除面板）

最新 Demo 已改为“结构化日志输出优先”，不再展示复杂决策面板。  
核心输出为 `PERF_TIER_LOG` 前缀的 JSON Line，便于直接复制给 AI 排查。

- 运行 `flutter run` 后，在控制台筛选 `PERF_TIER_LOG`
- App 内可一键复制 `AI Diagnostics JSON`
- `flutter test` 会输出 `PERF_TIER_TEST_RESULT` JSON 结果

## 快速接入：开启掉帧信号（可选）

默认情况下，掉帧信号关闭。  
若要开启，创建服务时传入 `enableFrameDropSignal: true`：

```dart
final service = DefaultPerformanceTierService(
  enableFrameDropSignal: true,
);

await service.initialize();
final decision = await service.getCurrentDecision();

final runtimeState = decision.runtimeObservation.status.wireName;
final frameDropState = decision.deviceSignals.frameDropState; // normal/moderate/critical
final frameDropRate = decision.deviceSignals.frameDropRate; // 0.0 ~ 1.0
```

## 掉帧阈值联调模板（M3 收尾）

建议从以下模板起步，再按业务场景微调：

- `Balanced（默认）`：`window=30s`、`budget=16.667ms`、`rate=0.12/0.25`、`count=8/20`
- `Feed/Scroll`：`window=20s`、`budget=16.667ms`、`rate=0.10/0.20`、`count=18/45`
- `High Refresh（90/120Hz）`：`window=20s`、`budget=11.111ms/8.333ms`、`rate=0.08/0.18`、`count=24/60`

`Feed/Scroll` 参考接入示例：

```dart
final service = DefaultPerformanceTierService(
  enableFrameDropSignal: true,
  runtimeSignalRefreshInterval: const Duration(seconds: 10),
  frameDropSignalSampler: SchedulerFrameDropSignalSampler(
    sampleWindow: const Duration(seconds: 20),
    targetFrameBudget: const Duration(microseconds: 16667),
    minSampledFrameCount: 90,
    moderateDropRate: 0.10,
    criticalDropRate: 0.20,
    moderateDroppedFrameCount: 18,
    criticalDroppedFrameCount: 45,
  ),
  runtimeTierController: RuntimeTierController(
    config: const RuntimeTierControllerConfig(
      enableFrameDropSignal: true,
      downgradeDebounce: Duration(seconds: 3),
      recoveryCooldown: Duration(seconds: 35),
      upgradeDebounce: Duration(seconds: 12),
      moderateFrameDropLevel: 1,
      criticalFrameDropLevel: 2,
    ),
  ),
);
```

## 更多文档

- 运行期动态降级：`docs/runtime_dynamic_tiering.md`
- 规则说明：`docs/rulebook.md`
- 场景策略映射：`docs/scene_policy_mapping.md`
- 业务接入示例：`docs/business_integration_sample.md`
