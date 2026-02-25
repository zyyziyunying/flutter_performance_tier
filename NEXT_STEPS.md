# 开发推进与下一步（基于 `DEVELOPMENT_PLAN.md`）

> 评估时间：2026-02-25  
> 本次更新：M3 已补齐“掉帧信号链路（可选开关）”并完成运行期降级联动 + demo 透出。  
> 对齐范围：`DEVELOPMENT_PLAN.md` 第 1-157 行

## 1）已完成

- **M0 基础设施**：Flutter 项目骨架（Android/iOS）与 `flutter_lints` 已落地。
- **M1 静态分级核心**：`PerformanceTierService`、`RuleBasedTierEngine`、`TierDecision`、`TierLevel`、`TierConfidence` 已落地。
- **规则工程化（V1）**：`TierConfig` + `TierConfigOverride` + `ModelTierCapRule` 已落地并可维护。
- **规则链路增强**：SDK 阈值降档、机型封顶与 RAM/低内存/MPC 主规则已接入。
- **平台字段补齐**：Android/iOS 均已回传 `deviceModel`，demo 可展示。
- **M2 场景策略落地**：`home_hero_animation`、`feed_video_list` 已接入 `DefaultPolicyResolver`。
- **M2 测试验收闭环**：服务编排、平台字段完整性、初始化耗时基线已补齐。
- **M3 动态降级主链路**：热状态 / 低电量 / 内存压力均已接入，含降级防抖、冷却恢复、升级防抖。
- **M3 运行期可观测（本次）**：
  - 新增 `RuntimeTierObservation`（`status` + `triggerReason`）结构化输出；
  - `RuntimeTierController` 已输出 `pending/active/cooldown/recovery-pending/recovered`；
  - demo 面板已展示 `Runtime State`、`Runtime Trigger` 与内存压力字段；
  - 相关单测 / 组件测试已更新并通过。
- **M3 掉帧信号链路（本次）**：
  - 新增 `SchedulerFrameDropSignalSampler`，基于 `FrameTiming` 采集窗口掉帧率；
  - 新增可选开关 `enableFrameDropSignal`（默认关闭）；
  - `DeviceSignals` 已补齐 `frameDropState/Level/Rate` 与计数字段；
  - 运行期降级规则已支持 `frameDrop` 信号参与降档决策；
  - demo 面板已展示 `Frame Drop` 相关字段，测试覆盖已补齐。

## 2）当前正在做

- **阶段定位**：进入 **M3 收尾阶段**（核心链路完成，转向剩余信号补齐与参数调优）。
- **关键缺口 A（执行清单）**：**已清零**。
- **关键缺口 B（规则工程化）**：**已清零**。
- **关键缺口 C（测试验收）**：**已清零**（含运行期可观测新增断言）。
- **关键缺口 D（运行期信号）**：**已清零**（热状态 / 低电量 / 内存压力 / 掉帧信号均已接入）。

## 3）下一步准备做（按优先级）

1. **M3 文档持续对齐**：补充掉帧信号参数说明、开关接入方式与建议阈值。
2. **可观测性增强（可选）**：补充运行期状态停留时长/触发次数埋点口径，支持后续阈值回归。
3. **阈值联调回归**：结合真实业务场景，校准掉帧窗口长度与 critical 判定阈值。

## 4）会话交接（下次可直接继续）

- **本次关键改动文件**：
  - `lib/performance_tier/service/frame_drop_signal_sampler.dart`（新增掉帧窗口采样器）
  - `lib/performance_tier/model/device_signals.dart`（新增 frameDrop 字段与解析）
  - `lib/performance_tier/service/default_performance_tier_service.dart`（掉帧采样注入决策链路）
  - `lib/performance_tier/service/runtime_tier_controller.dart`（新增 frameDrop 运行期降级规则）
  - `lib/main.dart`（demo 展示 Frame Drop 字段）
  - `test/performance_tier/service/runtime_tier_controller_test.dart`（frameDrop 开关与降级断言）
  - `test/performance_tier/service/default_performance_tier_service_test.dart`（服务编排 frameDrop 断言）
  - `test/performance_tier/service/platform_field_integrity_test.dart`（frameDrop 解析契约断言）
  - `test/widget_test.dart`（demo 字段可见性断言）
- **已验证命令**：
  - `flutter analyze`
  - `flutter test`（35 tests passed；初始化基线最新观测 `p95≈0.40ms`，满足 `<=300ms` 目标）
- **下次会话建议起手任务**：进入“掉帧阈值联调 + M3 文档参数建议”收尾任务。
