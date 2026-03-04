# 开发推进与下一步（基于 `DEVELOPMENT_PLAN.md`）

> 评估时间：2026-03-04  
> 本次更新：已明确当前交付目标为“结构化 JSON + 经业务服务上传 OSS”，日志平台与报表闭环后置。  
> 对齐范围：`DEVELOPMENT_PLAN.md` 第 1-159 行

## 1）已完成

- **M0 基础设施**：Flutter 项目骨架（Android/iOS）与 `flutter_lints` 已落地。
- **M1 静态分级核心**：`PerformanceTierService`、`RuleBasedTierEngine`、`TierDecision`、`TierLevel`、`TierConfidence` 已落地。
- **规则工程化（V1）**：`TierConfig` + `TierConfigOverride` + `ModelTierCapRule` 已落地并可维护。
- **规则链路增强**：SDK 阈值降档、机型封顶与 RAM/低内存/MPC 主规则已接入。
- **平台字段补齐**：Android/iOS 均已回传 `deviceModel`，并覆盖字段完整性测试。
- **M2 场景策略落地**：`home_hero_animation`、`feed_video_list` 已接入 `DefaultPolicyResolver`。
- **M2 测试验收闭环**：服务编排、平台字段完整性、初始化耗时基线已补齐。
- **M3 动态降级主链路**：热状态 / 低电量 / 内存压力 / 掉帧信号均已接入，含降级防抖、冷却恢复、升级防抖。
- **M3 运行期可观测**：
  - 新增 `RuntimeTierObservation`（`status` + `triggerReason`）结构化输出；
  - 补充 `statusDurationMs` / `downgradeTriggerCount` / `recoveryTriggerCount`；
  - `RuntimeTierController` 输出 `pending/active/cooldown/recovery-pending/recovered`；
  - demo 改为结构化日志诊断页（`PERF_TIER_LOG` + AI Diagnostics JSON）。
- **M3 收尾（本次）**：
  - `docs/runtime_dynamic_tiering.md` 补齐掉帧阈值联调流程、参数模板、接入示例；
  - `README.md` 补齐 M3 联调模板速查（Balanced / Feed-Scroll / High Refresh）；
  - 文档测试描述已对齐“结构化日志优先”现状。

## 2）当前正在做

- **阶段定位**：**M3 收尾后的初步真机验收阶段**（按验收清单验证功能闭环）。
- **关键缺口 A（执行清单）**：**已清零**。
- **关键缺口 B（规则工程化）**：**已清零**。
- **关键缺口 C（测试验收）**：**已清零**。
- **关键缺口 D（运行期信号）**：**已清零**。
- **当前不纳入**：业务日志平台接入、阈值回归报表/看板建设。
- **当前不强制**：OSS 上传链路固化（命名规范/重试策略等）可按后续实际需要再优化。

## 3）下一步准备做（按优先级）

1. **初步真机验收**：按 `docs/real_device_acceptance_checklist.md` 完成 Android/iOS 双端功能验收。
2. **问题收敛**：记录验收中发现的问题与结论，保证“功能基本可用”。
3. **后置项（M4）**：远程配置抽象 + 灰度与回滚策略文档（平台报表能力继续后置，链路固化按需进行）。

## 4）会话交接（下次可直接继续）

- **本次关键改动文件**：
  - `README.md`（新增“当前目标（2026-03）”口径）
  - `DEVELOPMENT_PLAN.md`（新增当前交付口径、非目标与验收标准）
  - `NEXT_STEPS.md`（阶段定位与优先级调整为真机初步验收）
  - `docs/runtime_dynamic_tiering.md`（后续建议改为“JSON + OSS 优先”）
  - `docs/real_device_acceptance_checklist.md`（新增真机初步验收 checklist）
- **已验证命令**：本次仅文档更新，未重复执行 `flutter analyze` / `flutter test`。
- **下次会话建议起手任务**：进入“**按 checklist 进行真机初步验收**”任务。
