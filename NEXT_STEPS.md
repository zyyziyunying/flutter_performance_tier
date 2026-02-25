# 开发推进与下一步（基于 `DEVELOPMENT_PLAN.md`）

> 评估时间：2026-02-25  
> 本次更新：M3 已完成“内存压力信号链路 + 动态恢复节流（升级防抖）+ 最小测试闭环”。  
> 对齐范围：`DEVELOPMENT_PLAN.md` 第 1-157 行

## 1）已完成

- **M0 基础设施**：Flutter 项目骨架已建立（Android/iOS），并启用 `flutter_lints` 与分析配置。
- **M1 静态分级核心**：已实现 `PerformanceTierService`、`RuleBasedTierEngine`、`TierDecision`、`TierLevel`、`TierConfidence` 等核心模型与接口。
- **规则工程化（V1）已落地**：`TierConfig` 已支持 RAM/系统版本/机型规则，新增 `TierConfigOverride` 覆盖 patch 与 `ModelTierCapRule`（rulebook 可维护）。
- **规则链路增强**：`RuleBasedTierEngine` 已新增 SDK 阈值降档与机型封顶规则，并保留 RAM + `isLowRamDevice` + Media Performance Class 主规则。
- **平台字段补齐**：Android/iOS 采集链路已新增 `deviceModel` 回传（用于机型规则匹配）；demo 面板可展示机型。
- **M2 场景策略落地**：已定义 `home_hero_animation` 与 `feed_video_list` 的分 Tier 策略与验收指标，并接入 `DefaultPolicyResolver`。
- **M2 测试验收闭环**：服务编排测试、平台字段完整性测试与初始化耗时基线已补齐。
- **M3 动态降级起手闭环**：`RuntimeTierController` 已支持热状态/低电量触发降级，含降级防抖与冷却恢复。
- **M3 内存压力链路完成**：Android/iOS 原生均已回传 `memoryPressureState`/`memoryPressureLevel`，Dart 解析与运行期降级决策已接入。
- **M3 恢复策略细化完成**：已增加 `upgradeDebounce`，恢复过程改为“冷却后逐级上调”，降低边缘状态抖动。

## 2）当前正在做

- **阶段定位**：进入 **M3 主线后半段**（运行期信号与恢复策略核心闭环已完成，转向可观测性与剩余信号补齐）。
- **关键缺口 A（执行清单）**：**已清零**（demo 场景策略命中可视化 + 业务样例文档已具备）。
- **关键缺口 B（规则工程化）**：**已清零**（rulebook + override 机制稳定）。
- **关键缺口 C（测试验收）**：**已清零**（运行期链路已扩展到内存压力，相关测试已补齐）。
- **关键缺口 D（运行期信号）**：**部分收敛**（热状态/低电量/内存压力已接入；掉帧信号仍待补齐）。

## 3）下一步准备做（按优先级）

1. **补 Demo 运行期观测**：展示动态状态（`pending/active/cooldown/recovery-pending/recovered`）与触发原因，便于联调排障。
2. **补掉帧信号链路**：补齐帧率波动采集、Dart 侧解析与运行期降级联动（先做可选开关）。
3. **M3 文档持续对齐**：结合联调反馈微调阈值建议，补充“不同业务场景推荐参数”。

## 4）会话交接（下次可直接继续）

- **本次关键改动文件**：
  - `lib/performance_tier/model/device_signals.dart`（新增 `memoryPressureState`/`memoryPressureLevel` 字段与解析）
  - `lib/performance_tier/service/runtime_tier_controller.dart`（接入内存压力信号；新增升级防抖与逐级恢复）
  - `android/app/src/main/kotlin/com/example/flutter_performance_tier/DeviceSignalChannelHandler.kt`（Android 内存压力等级计算与回传）
  - `ios/Runner/AppDelegate.swift`（iOS 内存告警监听与时间窗等级映射回传）
  - `test/performance_tier/service/runtime_tier_controller_test.dart`（新增恢复节流路径与内存压力降级测试）
  - `test/performance_tier/service/default_performance_tier_service_test.dart`（新增内存压力驱动降级编排测试）
  - `test/performance_tier/service/platform_field_integrity_test.dart`（新增内存压力字段契约与解析校验）
  - `docs/runtime_dynamic_tiering.md`（新增 M3 运行期动态降级策略文档）
- **已验证命令**：
  - `flutter analyze`
  - `flutter test`（32 tests passed；初始化基线最新观测 `p95≈0.54ms`，满足 `<=300ms` 目标）
- **下次会话建议起手任务**：优先完成 demo 的运行期状态可视化，再接掉帧信号链路。
