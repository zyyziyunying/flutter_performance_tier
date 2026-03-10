# Flutter Performance Tier

一个可复用的 Flutter 性能分级能力（Android / iOS），用于：

- 启动阶段快速给出设备分级（Tier）
- 将 Tier 映射为业务策略（动画、媒体、缓存等）
- 基于运行期信号做动态降级（热状态、低电量、内存压力、掉帧信号）

## 当前目标（2026-03）

- 库侧稳定输出结构化决策 JSON（`TierDecision`、`runtimeObservation`、`PERF_TIER_LOG`）。
- 业务侧通过自有上传服务将诊断 JSON 归档到 OSS，形成可追溯最小闭环。
- 当前阶段不以“统一日志平台接入 / 阈值回归报表看板”作为交付前置条件。

## 开发命令

- `flutter pub get`
- `flutter analyze`
- `dart format lib test`
- `flutter test`
- `flutter run`
- `flutter run -t lib/internal_upload_probe_main.dart`
- `flutter pub run build_runner build --delete-conflicting-outputs --define flutter_secure_dotenv_generator:flutter_secure_dotenv=OUTPUT_FILE=encryption_key.json`

## 结构化日志优先（已移除面板）

最新 Demo 已改为“结构化日志输出优先”，不再展示复杂决策面板。  
核心输出为 `PERF_TIER_LOG` 前缀的 JSON Line，便于直接复制给 AI 排查。

- 运行 `flutter run` 后，在控制台筛选 `PERF_TIER_LOG`
- App 内可一键复制 `AI Diagnostics JSON`
- `flutter test` 会输出 `PERF_TIER_TEST_RESULT` JSON 结果

默认 `main.dart` 只保留最小诊断示例。  
内部上传探针已拆到独立入口：`flutter run -t lib/internal_upload_probe_main.dart`。

## 内部上传探针配置

`internal_upload_probe_main.dart` 现在按以下优先级读取配置：

1. `--dart-define`
2. `lib/internal_upload_probe/internal_upload_probe_env.dart` 对应的 secure env

支持的键：

- `UPLOAD_PROBE_URL`
- `UPLOAD_PROBE_LOGIN_URL`
- `UPLOAD_PROBE_TOKEN`
- `UPLOAD_PROBE_USERNAME`
- `UPLOAD_PROBE_PASSWORD`
- `UPLOAD_PROBE_SOURCE`
- `UPLOAD_PROBE_AUTH_SESSION_KEY`

如需本地 secure env，可从 `.env.internal_upload_probe.example` 复制出 `.env.internal_upload_probe`。

当前仓库已经固定了 `internal_upload_probe_env.dart` 里的 `_encryptionKey` / `_iv`，所以你在修改 `.env.internal_upload_probe` 后，应沿用这两个值重新生成：

```bash
flutter pub run build_runner build \
  --delete-conflicting-outputs \
  --define flutter_secure_dotenv_generator:flutter_secure_dotenv=ENCRYPTION_KEY=JxdHpbfQMpnFdghEeyDHKO0zHJz3IkBlE7n5hodXzAo= \
  --define flutter_secure_dotenv_generator:flutter_secure_dotenv=IV=I9nqIzp5hTpEIr/LRcS4dg== \
  --define flutter_secure_dotenv_generator:flutter_secure_dotenv=OUTPUT_FILE=encryption_key.json
```

## 生命周期

`PerformanceTierService` 现在显式暴露 `dispose()`。  
业务侧在页面或应用生命周期结束时应主动释放服务，避免遗留 `Timer`、`StreamController` 和掉帧采样器。

```dart
final PerformanceTierService service = DefaultPerformanceTierService();

await service.initialize();
final decision = await service.getCurrentDecision();

// 页面或容器销毁时释放资源
await service.dispose();
```

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
final runtimeStatusDurationMs =
    decision.runtimeObservation.statusDuration.inMilliseconds;
final downgradeTriggerCount =
    decision.runtimeObservation.downgradeTriggerCount;
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

## 文档

- 文档导航：`docs/README.md`
