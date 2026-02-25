# 运行期动态降级策略（M3）

> 更新时间：2026-02-25  
> 适用实现：`RuntimeTierController` + `DefaultPerformanceTierService` 当前主干实现

## 1. 目标

- 在长时运行中，根据实时压力信号动态降级，优先保证稳定性与流畅性。
- 通过降级防抖、恢复冷却、升级防抖，降低边缘状态抖动带来的策略频繁切换。

## 2. 信号输入

当前已接入信号：

- **热状态**：`thermalState` / `thermalStateLevel`
- **低电量模式**：`isLowPowerModeEnabled`
- **内存压力**：`memoryPressureState` / `memoryPressureLevel`
- **掉帧波动（可选开关）**：`frameDropState` / `frameDropLevel` / `frameDropRate`

平台采集说明：

- **Android**：
  - 基于 `ActivityManager.MemoryInfo.lowMemory` 与 `availMem/threshold` 推导内存压力。
  - 输出 `memoryPressureState`（`normal/moderate/critical`）与 `memoryPressureLevel`（`0/1/2`）。
- **iOS**：
  - 监听 `UIApplication.didReceiveMemoryWarningNotification`。
  - 以内存告警发生时间窗口推导压力等级：
    - `<=30s`：critical（2）
    - `<=120s`：moderate（1）
    - 其他：normal（0）
- **Dart（Flutter 引擎侧）**：
  - `SchedulerFrameDropSignalSampler` 监听 `FrameTiming`，按窗口统计超预算帧。
  - 默认窗口与阈值：
    - `sampleWindow=30s`
    - `targetFrameBudget=16.667ms`
    - `minSampledFrameCount=60`
    - `moderateDropRate=0.12` / `criticalDropRate=0.25`
    - `moderateDroppedFrameCount=8` / `criticalDroppedFrameCount=20`
  - 通过 `DefaultPerformanceTierService(enableFrameDropSignal: true)` 启用。

## 3. 降级规则（当前版本）

默认阈值：

- `fairThermalStateLevel=1`
- `seriousThermalStateLevel=2`
- `criticalThermalStateLevel=3`
- `moderateMemoryPressureLevel=1`
- `criticalMemoryPressureLevel=2`
- `moderateFrameDropLevel=1`（开关开启时生效）
- `criticalFrameDropLevel=2`（开关开启时生效）

规则映射（取“更严格”的降级步数）：

- 热状态：
  - `fair` -> 降 1 档
  - `serious` -> 降 2 档
  - `critical` -> 降 3 档
- 低电量模式：
  - `true` -> 至少降 1 档
- 内存压力：
  - `moderate` -> 至少降 1 档
  - `critical` -> 至少降 2 档
- 掉帧波动（可选）：
  - `moderate` -> 至少降 1 档
  - `critical` -> 至少降 2 档

Tier 变化采用“按步数降档”，最低不低于 `t0Low`。

## 4. 时序控制（防抖 / 冷却 / 恢复节流）

默认时间参数：

- `downgradeDebounce = 5s`
- `recoveryCooldown = 30s`
- `upgradeDebounce = 10s`

状态语义：

- **pending**：有降级信号但仍在降级防抖窗口。
- **active**：降级已生效。
- **cooldown**：信号消失后，仍在冷却窗口，保持降级。
- **recovery-pending**：允许恢复后，仍在升级防抖窗口，保持当前档位。
- **recovered**：恢复到基线 tier。

恢复策略（当前版本）：

- 冷却结束后，不直接恢复到基线；
- 每次仅上调 1 档；
- 每次上调之间需满足 `upgradeDebounce`；
- 直到恢复基线档位。

## 5. Service 集成

- `DefaultPerformanceTierService` 在每次重算时：
  1. 先用静态规则得到 `baseTier`
  2. 合并 `FrameDropSignalSampler` 的快照到 `DeviceSignals`（若启用）
  3. 再调用 `RuntimeTierController.adjust` 得到运行期修正结果
  4. 用修正后的 tier 解析策略并产出 `TierDecision`
- 开关语义：
  - `enableFrameDropSignal=false`（默认）：不采样，不参与降级。
  - `enableFrameDropSignal=true`：启动采样器，且默认 `RuntimeTierController` 打开 frameDrop 规则。

## 6. 可观测性与测试

当前可观测输出：

- `TierDecision.runtimeObservation`（结构化）：
  - `status`：`inactive/pending/active/cooldown/recovery-pending/recovered`
  - `triggerReason`：触发信号摘要（如 `thermalState=serious(level=2)`）
- `TierDecision.deviceSignals`（新增可观测字段）：
  - `frameDropState` / `frameDropLevel` / `frameDropRate`
  - `frameDroppedCount` / `frameSampledCount`
- `TierDecision.reasons`（文本）仍保留详细链路信息，便于排障。
- demo 面板已展示 `Runtime State`、`Runtime Trigger`、内存压力与 `Frame Drop` 字段。

已覆盖测试：

- `test/performance_tier/service/runtime_tier_controller_test.dart`
  - 降级防抖
  - 冷却保持
  - 逐级恢复与升级防抖
  - 热状态 / 内存压力 / 掉帧降级映射
  - 掉帧开关关闭时不触发降级
  - 结构化状态字段断言
- `test/performance_tier/service/default_performance_tier_service_test.dart`
  - 运行期降级在策略解析前生效
  - 内存压力与掉帧信号触发服务编排降级
  - `runtimeObservation` 透传断言
- `test/performance_tier/service/platform_field_integrity_test.dart`
  - Android / iOS 内存压力字段契约与 Dart 解析完整性
  - `frameDrop*` 字段解析完整性
- `test/widget_test.dart`
  - demo 运行期可观测字段可见性（含 Frame Drop）

## 7. 后续建议

- 累计运行期触发次数与停留时长埋点，为阈值调优提供数据依据。
- 结合真实业务场景回放，校准 `sampleWindow` 与 drop rate 阈值，降低误判率。
