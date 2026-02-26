# 开发推进与下一步（基于 `DEVELOPMENT_PLAN.md`）

> 评估时间：2026-02-26  
> 本次更新：已完成“掉帧阈值联调建议 + M3 文档参数建议”收尾，并对齐结构化日志模式。  
> 对齐范围：`DEVELOPMENT_PLAN.md` 第 1-157 行

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
  - `RuntimeTierController` 输出 `pending/active/cooldown/recovery-pending/recovered`；
  - demo 改为结构化日志诊断页（`PERF_TIER_LOG` + AI Diagnostics JSON）。
- **M3 收尾（本次）**：
  - `docs/runtime_dynamic_tiering.md` 补齐掉帧阈值联调流程、参数模板、接入示例；
  - `README.md` 补齐 M3 联调模板速查（Balanced / Feed-Scroll / High Refresh）；
  - 文档测试描述已对齐“结构化日志优先”现状。

## 2）当前正在做

- **阶段定位**：**M3 已收尾，进入 M4 准备阶段**（远程配置与灰度发布能力）。
- **关键缺口 A（执行清单）**：**已清零**。
- **关键缺口 B（规则工程化）**：**已清零**。
- **关键缺口 C（测试验收）**：**已清零**。
- **关键缺口 D（运行期信号）**：**已清零**。

## 3）下一步准备做（按优先级）

1. **M4 远程配置抽象**：落地配置拉取接口与本地默认配置 merge 规则。
2. **可观测性增强**：补充运行期状态停留时长 / 触发次数埋点，支持阈值回归。
3. **灰度与回滚策略**：补齐开关矩阵、灰度范围与紧急回滚流程文档。

## 4）会话交接（下次可直接继续）

- **本次关键改动文件**：
  - `docs/runtime_dynamic_tiering.md`（新增掉帧联调流程 + 参数模板 + 接入示例）
  - `README.md`（新增 M3 掉帧阈值联调模板速查）
  - `NEXT_STEPS.md`（阶段状态更新至 M3 收尾完成）
- **已验证命令**：
  - `flutter analyze`
  - `flutter test`
- **下次会话建议起手任务**：进入“**M4 远程配置抽象 + 灰度回滚策略**”任务。
