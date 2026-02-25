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

## 可调参数示例（掉帧阈值）

可以通过自定义采样器与运行期控制器参数调优：

```dart
final service = DefaultPerformanceTierService(
  enableFrameDropSignal: true,
  frameDropSignalSampler: SchedulerFrameDropSignalSampler(
    sampleWindow: const Duration(seconds: 30),
    targetFrameBudget: const Duration(microseconds: 16667),
    moderateDropRate: 0.12,
    criticalDropRate: 0.25,
    moderateDroppedFrameCount: 8,
    criticalDroppedFrameCount: 20,
    minSampledFrameCount: 60,
  ),
  runtimeTierController: RuntimeTierController(
    config: const RuntimeTierControllerConfig(
      enableFrameDropSignal: true,
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
