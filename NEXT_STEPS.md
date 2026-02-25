# 开发推进与下一步（基于 `DEVELOPMENT_PLAN.md`）

> 评估时间：2026-02-25  
> 本次更新：已从 M3 起手，完成“运行期热状态/低电量触发的动态降级策略 + 防抖/冷却 + 最小可测闭环”。  
> 对齐范围：`DEVELOPMENT_PLAN.md` 第 1-157 行

## 1）已完成

- **M0 基础设施**：Flutter 项目骨架已建立（Android/iOS），并启用 `flutter_lints` 与分析配置。
- **M1 静态分级核心**：已实现 `PerformanceTierService`、`RuleBasedTierEngine`、`TierDecision`、`TierLevel`、`TierConfidence` 等核心模型与接口。
- **规则工程化（V1）已落地**：`TierConfig` 已支持 RAM/系统版本/机型规则，新增 `TierConfigOverride` 覆盖 patch 与 `ModelTierCapRule`（rulebook 可维护）。
- **规则链路增强**：`RuleBasedTierEngine` 已新增 SDK 阈值降档与机型封顶规则，并保留 RAM + `isLowRamDevice` + Media Performance Class 主规则。
- **平台字段补齐**：Android/iOS 采集链路已新增 `deviceModel` 回传（用于机型规则匹配）；demo 面板可展示机型。
- **iOS 运行期字段扩展**：新增 `thermalState`、`thermalStateLevel`、`isLowPowerModeEnabled` 采集与 Dart 解析，demo 面板可展示。
- **首批业务场景映射已落地**：已定义 `home_hero_animation` 与 `feed_video_list` 的分 Tier 策略与验收指标，并接入 `DefaultPolicyResolver`。
- **文档与测试补齐**：新增场景映射文档、rulebook 文档、业务接入样例文档与策略解析单测；`flutter analyze`、`flutter test` 均通过。
- **测试验收补齐（M2）**：新增服务编排测试、平台字段完整性测试，初始化首结果耗时基线 `p95≈0.33ms`（目标 `<=300ms`，测试环境内存内采样）。
- **M3 起手闭环完成**：新增 `RuntimeTierController`，基于热状态/低电量实现运行期动态降级，支持防抖与冷却恢复；服务层已接入并支持周期性轮询刷新。

## 2）当前正在做

- **阶段定位**：进入 **M3 主线推进前半段**（运行期热状态/低电量动态降级已落地，开始补齐更完整运行期信号与恢复策略）。
- **关键缺口 A（执行清单）**：**已清零**（demo 已支持按场景查看策略命中，业务接入样例文档已补齐）。
- **关键缺口 B（规则工程化）**：**已清零**（rulebook + override 机制已完成并有测试覆盖）。
- **关键缺口 C（测试验收）**：**已清零**（服务编排/平台字段完整性测试已补齐，初始化耗时基线已记录）。
- **关键缺口 D（运行期信号）**：**部分收敛**（热状态/低电量已接入；内存压力与掉帧信号仍待补齐）。

## 3）下一步准备做（按优先级）

1. **补内存压力信号链路**：补齐 Android/iOS 内存压力采集与 Dart 侧解析，并接入运行期降级决策。
2. **细化动态恢复策略**：增加“升级恢复”分级节流（上调防抖），避免热状态边缘抖动导致体验波动。
3. **补 Demo 运行期观测**：展示“动态降级状态（pending/active/cooldown/recovered）”与触发原因，便于联调。
4. **补文档对齐（M3）**：新增运行期动态降级策略文档（阈值、时序、防抖/冷却配置建议）。

## 4）会话交接（下次可直接继续）

- **本次关键改动文件**：
  - `lib/performance_tier/config/tier_config.dart`（rulebook + override + 机型封顶规则）
  - `lib/performance_tier/config/config_provider.dart`（基础配置与覆盖合并）
  - `lib/performance_tier/engine/rule_based_tier_engine.dart`（SDK/机型规则落地）
  - `lib/performance_tier/model/device_signals.dart`（新增 `deviceModel` + 运行期信号字段）
  - `lib/performance_tier/service/runtime_tier_controller.dart`（运行期热状态/低电量动态降级状态机，含防抖与冷却）
  - `lib/performance_tier/service/default_performance_tier_service.dart`（接入运行期动态降级与周期刷新）
  - `lib/main.dart`（demo 展示运行期信号字段 + 场景策略命中可视化）
  - `lib/performance_tier/policy/scenario_policy.dart`（场景策略与验收指标模型）
  - `lib/performance_tier/policy/performance_policy.dart`（挂载场景策略输出）
  - `lib/performance_tier/policy/policy_resolver.dart`（首批 2 个高负载场景策略映射）
  - `android/app/src/main/kotlin/com/example/flutter_performance_tier/DeviceSignalChannelHandler.kt`（Android 回传机型）
  - `ios/Runner/AppDelegate.swift`（iOS 回传机型 + 热状态/低电量模式）
  - `test/performance_tier/rule_based_tier_engine_test.dart`
  - `test/performance_tier/tier_config_test.dart`
  - `test/performance_tier/policy_resolver_test.dart`
  - `test/performance_tier/performance_policy_test.dart`
  - `test/performance_tier/service/default_performance_tier_service_test.dart`
  - `test/performance_tier/service/runtime_tier_controller_test.dart`
  - `test/performance_tier/service/platform_field_integrity_test.dart`
  - `docs/scene_policy_mapping.md`
  - `docs/initialization_baseline.md`
  - `docs/rulebook.md`
  - `docs/business_integration_sample.md`
- **已验证命令**：
  - `flutter analyze`
  - `flutter test`（30 tests passed；初始化基线测试最新观测 `p95≈0.44ms`，仍满足 `<=300ms` 目标）
- **下次会话建议起手任务**：继续 M3，优先补内存压力信号接入，并把动态降级状态在 demo 面板中可视化。
