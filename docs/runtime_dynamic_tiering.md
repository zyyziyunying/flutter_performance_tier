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

## 3. 降级规则（当前版本）

默认阈值：

- `fairThermalStateLevel=1`
- `seriousThermalStateLevel=2`
- `criticalThermalStateLevel=3`
- `moderateMemoryPressureLevel=1`
- `criticalMemoryPressureLevel=2`

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

Tier 变化采用“按步数降档”，最低不低于 `t0Low`。

## 4. 时序控制（防抖/冷却/恢复节流）

默认时间参数：

- `downgradeDebounce = 5s`
- `recoveryCooldown = 30s`
- `upgradeDebounce = 10s`

状态语义：

- **pending**：有降级信号但仍在降级防抖窗口。
- **active**：降级已生效。
- **cooldown**：信号消失后，仍在冷却窗口，保持降级。
- **recovery-pending / upgrade-pending**：允许恢复后，仍在升级防抖窗口，保持当前档位。
- **recovered**：恢复到基线 tier。

恢复策略（当前版本）：

- 冷却结束后，不直接恢复到基线；
- 每次仅上调 1 档；
- 每次上调之间需满足 `upgradeDebounce`；
- 直到恢复基线档位。

## 5. Service 集成

- `DefaultPerformanceTierService` 在每次重算时：
  1. 先用静态规则得到 `baseTier`
  2. 再调用 `RuntimeTierController.adjust` 得到运行期修正结果
  3. 用修正后的 tier 解析策略并产出 `TierDecision`

## 6. 可观测性与测试

当前可观测输出：

- `TierDecision.reasons` 内含运行期状态信息，例如：
  - `Runtime downgrade pending...`
  - `Runtime downgrade active...`
  - `Runtime cooldown active...`
  - `Runtime recovery pending...`
  - `Runtime upgrade step applied...`
  - `Runtime downgrade recovered...`

已覆盖测试：

- `test/performance_tier/service/runtime_tier_controller_test.dart`
  - 降级防抖
  - 冷却保持
  - 逐级恢复与升级防抖
  - 热状态/内存压力降级映射
- `test/performance_tier/service/default_performance_tier_service_test.dart`
  - 运行期降级在策略解析前生效
  - 内存压力触发服务编排降级
- `test/performance_tier/service/platform_field_integrity_test.dart`
  - Android/iOS 内存压力字段契约与 Dart 解析完整性

## 7. 后续建议

- 在 demo 面板显式展示运行期状态机状态（不仅依赖 reasons 文本）。
- 增加掉帧信号作为可选降级输入，并支持场景级开关。
- 累计运行期触发次数与停留时长埋点，为阈值调优提供数据依据。
