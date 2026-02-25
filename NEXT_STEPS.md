# 开发推进与下一步（基于 `DEVELOPMENT_PLAN.md`）

> 评估时间：2026-02-25  
> 本次更新：已完成“3）下一步准备做”第 1 项（rulebook 配置化阈值 + 覆盖机制 + 对应测试）  
> 对齐范围：`DEVELOPMENT_PLAN.md` 第 1-157 行

## 1）已完成

- **M0 基础设施**：Flutter 项目骨架已建立（Android/iOS），并启用 `flutter_lints` 与分析配置。
- **M1 静态分级核心**：已实现 `PerformanceTierService`、`RuleBasedTierEngine`、`TierDecision`、`TierLevel`、`TierConfidence` 等核心模型与接口。
- **规则工程化（V1）已落地**：`TierConfig` 已支持 RAM/系统版本/机型规则，新增 `TierConfigOverride` 覆盖 patch 与 `ModelTierCapRule`（rulebook 可维护）。
- **规则链路增强**：`RuleBasedTierEngine` 已新增 SDK 阈值降档与机型封顶规则，并保留 RAM + `isLowRamDevice` + Media Performance Class 主规则。
- **平台字段补齐**：Android/iOS 采集链路已新增 `deviceModel` 回传（用于机型规则匹配）；demo 面板可展示机型。
- **基础质量验证**：新增配置覆盖与规则降档测试；`flutter analyze`、`flutter test` 均通过。

## 2）当前正在做

- **阶段定位**：进入 **M2 主线推进**（规则配置化已完成，开始聚焦业务映射与验收）。
- **关键缺口 A（执行清单）**：尚未明确“首批 2 个高负载业务场景”及对应策略映射表。
- **关键缺口 B（规则工程化）**：**已清零**（rulebook + override 机制已完成并有测试覆盖）。
- **关键缺口 C（测试验收）**：平台字段完整性清单、配置覆盖优先级验收口径、初始化耗时基线仍需固化。

## 3）下一步准备做（按优先级）

1. **明确首批业务接入场景**：至少选 2 个高负载页面（如首屏动画、列表/视频页），给出策略映射与验收指标。
2. **补测试与验收项**：完善服务编排/平台字段完整性测试，并记录初始化耗时基线（目标 300ms 首结果）。
3. **扩展 iOS 采集字段**：补充热状态等运行期信号，为 M3 动态降级做准备。
4. **补文档对齐**：新增/更新 `docs/rulebook.md`，说明默认阈值与覆盖优先级。

## 4）会话交接（下次可直接继续）

- **本次关键改动文件**：
  - `lib/performance_tier/config/tier_config.dart`（rulebook + override + 机型封顶规则）
  - `lib/performance_tier/config/config_provider.dart`（基础配置与覆盖合并）
  - `lib/performance_tier/engine/rule_based_tier_engine.dart`（SDK/机型规则落地）
  - `lib/performance_tier/model/device_signals.dart`（新增 `deviceModel`）
  - `android/app/src/main/kotlin/com/example/flutter_performance_tier/DeviceSignalChannelHandler.kt`（Android 回传机型）
  - `ios/Runner/AppDelegate.swift`（iOS 回传机型）
  - `test/performance_tier/rule_based_tier_engine_test.dart`
  - `test/performance_tier/tier_config_test.dart`
- **已验证命令**：
  - `flutter analyze`
  - `flutter test`
- **下次会话建议起手任务**：按“3）下一步准备做”第 1 项，先敲定 2 个业务场景和策略映射表，再补验收用例。
