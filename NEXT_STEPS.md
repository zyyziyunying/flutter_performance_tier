# 开发推进与下一步（基于 `DEVELOPMENT_PLAN.md`）

> 评估时间：2026-02-25  
> 本次更新：M3 已补齐“运行期可观测（状态 + 触发原因）”并完成 demo 面板透出。  
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

## 2）当前正在做

- **阶段定位**：进入 **M3 收尾阶段**（核心链路完成，转向剩余信号补齐与参数调优）。
- **关键缺口 A（执行清单）**：**已清零**。
- **关键缺口 B（规则工程化）**：**已清零**。
- **关键缺口 C（测试验收）**：**已清零**（含运行期可观测新增断言）。
- **关键缺口 D（运行期信号）**：**部分收敛**（热状态 / 低电量 / 内存压力已接入；掉帧信号待补齐）。

## 3）下一步准备做（按优先级）

1. **补掉帧信号链路**：补齐帧率波动采集、Dart 侧解析与运行期降级联动（先做可选开关）。
2. **M3 文档持续对齐**：结合联调反馈微调阈值建议，补充“不同业务场景推荐参数”。
3. **可观测性增强（可选）**：补充运行期状态停留时长/触发次数埋点口径，支持后续阈值回归。

## 4）会话交接（下次可直接继续）

- **本次关键改动文件**：
  - `lib/performance_tier/model/runtime_tier_observation.dart`（新增运行期状态模型）
  - `lib/performance_tier/model/tier_decision.dart`（新增 `runtimeObservation`）
  - `lib/performance_tier/service/runtime_tier_controller.dart`（结构化状态与触发原因输出）
  - `lib/performance_tier/service/default_performance_tier_service.dart`（透传运行期观测）
  - `lib/main.dart`（demo 展示 Runtime State / Runtime Trigger + 内存压力字段）
  - `test/performance_tier/service/runtime_tier_controller_test.dart`（状态机断言补齐）
  - `test/performance_tier/service/default_performance_tier_service_test.dart`（服务侧透传断言补齐）
  - `test/widget_test.dart`（demo 可视化字段断言补齐）
- **已验证命令**：
  - `flutter analyze`
  - `flutter test`（32 tests passed；初始化基线最新观测 `p95≈0.41ms`，满足 `<=300ms` 目标）
- **下次会话建议起手任务**：直接从“掉帧信号链路（可选开关）”开始实现。
