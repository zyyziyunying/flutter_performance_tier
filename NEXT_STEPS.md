# 开发推进与下一步（基于 `DEVELOPMENT_PLAN.md`）

> 评估时间：2026-02-25  
> 本次更新：已完成“3）下一步准备做”第 2 项（iOS 运行期采集字段扩展：热状态/低电量模式），并延续此前已完成的第 1 项测试验收与场景映射工作。  
> 对齐范围：`DEVELOPMENT_PLAN.md` 第 1-157 行

## 1）已完成

- **M0 基础设施**：Flutter 项目骨架已建立（Android/iOS），并启用 `flutter_lints` 与分析配置。
- **M1 静态分级核心**：已实现 `PerformanceTierService`、`RuleBasedTierEngine`、`TierDecision`、`TierLevel`、`TierConfidence` 等核心模型与接口。
- **规则工程化（V1）已落地**：`TierConfig` 已支持 RAM/系统版本/机型规则，新增 `TierConfigOverride` 覆盖 patch 与 `ModelTierCapRule`（rulebook 可维护）。
- **规则链路增强**：`RuleBasedTierEngine` 已新增 SDK 阈值降档与机型封顶规则，并保留 RAM + `isLowRamDevice` + Media Performance Class 主规则。
- **平台字段补齐**：Android/iOS 采集链路已新增 `deviceModel` 回传（用于机型规则匹配）；demo 面板可展示机型。
- **iOS 运行期字段扩展**：新增 `thermalState`、`thermalStateLevel`、`isLowPowerModeEnabled` 采集与 Dart 解析，demo 面板可展示。
- **首批业务场景映射已落地**：已定义 `home_hero_animation` 与 `feed_video_list` 的分 Tier 策略与验收指标，并接入 `DefaultPolicyResolver`。
- **文档与测试补齐**：新增场景映射文档与 resolver 单测；`flutter analyze`、`flutter test` 均通过。
- **测试验收补齐（M2）**：新增服务编排测试、平台字段完整性测试，初始化首结果耗时基线 `p95≈0.33ms`（目标 `<=300ms`，测试环境内存内采样）。

## 2）当前正在做

- **阶段定位**：进入 **M2 主线推进后半段**（规则配置化 + 首批场景映射已完成，开始补齐验收与运行期信号）。
- **关键缺口 A（执行清单）**：首批 2 个高负载场景已明确，但尚缺“场景接入 demo 交互开关”与业务侧接入样例。
- **关键缺口 B（规则工程化）**：**已清零**（rulebook + override 机制已完成并有测试覆盖）。
- **关键缺口 C（测试验收）**：**已清零**（服务编排/平台字段完整性测试已补齐，初始化耗时基线已记录）。

## 3）下一步准备做（按优先级）

1. **（已完成）补测试与验收项**：服务编排/平台字段完整性测试已补齐，初始化耗时基线已记录（目标 300ms 首结果）。
2. **（已完成）扩展 iOS 采集字段**：已补充热状态等运行期信号，为 M3 动态降级做准备。
3. **补文档对齐**：新增/更新 `docs/rulebook.md`，说明默认阈值与覆盖优先级。
4. **补业务接入示例**：在 demo 中增加“按场景展示策略命中”的可视化入口，便于验收。

## 4）会话交接（下次可直接继续）

- **本次关键改动文件**：
  - `lib/performance_tier/config/tier_config.dart`（rulebook + override + 机型封顶规则）
  - `lib/performance_tier/config/config_provider.dart`（基础配置与覆盖合并）
  - `lib/performance_tier/engine/rule_based_tier_engine.dart`（SDK/机型规则落地）
  - `lib/performance_tier/model/device_signals.dart`（新增 `deviceModel` + 运行期信号字段）
  - `lib/main.dart`（demo 展示运行期信号字段）
  - `lib/performance_tier/policy/scenario_policy.dart`（场景策略与验收指标模型）
  - `lib/performance_tier/policy/performance_policy.dart`（挂载场景策略输出）
  - `lib/performance_tier/policy/policy_resolver.dart`（首批 2 个高负载场景策略映射）
  - `android/app/src/main/kotlin/com/example/flutter_performance_tier/DeviceSignalChannelHandler.kt`（Android 回传机型）
  - `ios/Runner/AppDelegate.swift`（iOS 回传机型 + 热状态/低电量模式）
  - `test/performance_tier/rule_based_tier_engine_test.dart`
  - `test/performance_tier/tier_config_test.dart`
  - `test/performance_tier/policy_resolver_test.dart`
  - `test/performance_tier/service/default_performance_tier_service_test.dart`
  - `test/performance_tier/service/platform_field_integrity_test.dart`
  - `docs/scene_policy_mapping.md`
  - `docs/initialization_baseline.md`
- **已验证命令**：
  - `flutter analyze`
  - `flutter test`
- **下次会话建议起手任务**：按“3）下一步准备做”第 3 项，补 `docs/rulebook.md`（默认阈值与覆盖优先级）。
