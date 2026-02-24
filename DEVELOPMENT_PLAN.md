# Flutter Performance Tier 项目开发计划

## 1. 项目目标

- 建立一个可复用的 Flutter 性能分级能力，面向 Android 与 iOS 双端。
- 在应用启动阶段快速给出设备性能等级（Tier），并输出可直接用于业务降级的策略集。
- 提供运行期信号监听（内存压力、温度/功耗信号、帧率波动）能力，支持动态降级。
- 支持本地默认策略 + 远程配置覆盖，做到可运营、可灰度、可回滚。

## 2. 范围与非目标

### 2.1 本期范围（MVP + V1）

- 平台：Android、iOS（Flutter 插件 + Dart API）。
- 能力：设备画像采集、静态分级、运行期状态更新、策略下发。
- 输出：统一 `PerformanceProfile` 与 `TierDecision`。
- 集成：提供 demo 页面展示分级结果与策略命中。

### 2.2 非目标（本期不做）

- Web、Windows、macOS、Linux 端支持。
- 自动机器学习分级模型训练。
- 大规模云端数据平台（仅预留埋点接口）。

## 3. 关键场景

- 首屏极限场景：根据机型能力决定首屏动画复杂度、首帧后预加载数量。
- 列表/视频场景：按 Tier 调整解码策略、缓存大小、并发预取数。
- 长时运行场景：收到内存压力或热状态升高后，自动降级渲染质量。

## 4. 总体架构

- Dart 层：
  - `PerformanceTierService`：统一入口，提供初始化、订阅、刷新。
  - `TierEngine`：分级计算核心（规则引擎）。
  - `PolicyResolver`：把 Tier 映射为业务可用策略（开关/阈值）。
  - `ConfigProvider`：本地默认配置 + 远程配置合并。
- 平台层（Plugin）：
  - Android：采集 CPU/内存、`isLowRamDevice`、Media Performance Class 等信号。
  - iOS：采集机型标识、可用内存、热状态等信号。
- 观测层：
  - 埋点接口：初始化耗时、分级结果、降级触发次数、恢复次数。

## 5. 分级设计

### 5.1 数据输入

- 静态信号：RAM 总量、SoC/机型档位、系统版本、存储与 ABI 信息。
- 动态信号：内存压力、热状态、掉帧率（可选）、崩溃前告警信号（可选）。

### 5.2 分级结果

- Tier 建议：`T0_LOW` / `T1_MID` / `T2_HIGH` / `T3_ULTRA`。
- 置信度：`low` / `medium` / `high`（用于灰度策略与兜底）。
- 理由集合：记录命中的关键规则，便于排查。

### 5.3 策略输出（示例）

- UI：动画等级、阴影/模糊开关、图片默认分辨率。
- 媒体：预加载数量、解码并发、缓存阈值。
- 算法：模型大小选择（small/base/large）。

## 6. 里程碑计划

### M0（第 1 周）：项目与基础设施

- 新建 Flutter 项目（Android/iOS）。
- 目录规范、代码规范、lint 与 CI 基础流水线。
- 产出：可运行空壳 + 基础文档。

### M1（第 2-3 周）：静态分级 MVP

- 完成 Android/iOS 设备信号采集插件。
- 实现 `TierEngine` 首版规则（基于 RAM + 机型档位）。
- 提供同步/异步 API：`getCurrentTier()`、`getProfile()`。
- 产出：可稳定返回分级结果。

### M2（第 4 周）：策略映射与业务接入

- 实现 `PolicyResolver` 与默认策略模板。
- 提供示例接入（动画、列表预加载、图片质量）。
- 产出：分级结果能真实驱动性能降级。

### M3（第 5 周）：运行期动态降级

- 监听内存压力与热状态；支持动态降级/恢复。
- 加入防抖与冷却时间，避免频繁抖动。
- 产出：长时运行稳定，降级行为可观察。

### M4（第 6 周）：远程配置、灰度与发布

- 对接远程配置（可先抽象接口，后接 Firebase Remote Config 或自研）。
- 增加灰度开关与回滚策略。
- 完成文档、示例、发布检查清单。
- 产出：可用于生产环境的小版本上线。

## 7. 代码结构建议

```text
flutter_performance_tier/
  lib/
    performance_tier/
      performance_tier_service.dart
      model/
      engine/
      policy/
      config/
      telemetry/
    main.dart
  android/
  ios/
  docs/
    architecture.md
    rulebook.md
```

## 8. API 草案

```dart
abstract class PerformanceTierService {
  Future<void> initialize();
  Future<TierDecision> getCurrentDecision();
  Stream<TierDecision> watchDecision();
  Future<void> refresh();
}
```

- `TierDecision`：tier、confidence、reasons、appliedPolicies。
- 初始化要求：应用启动后 300ms 内返回首个可用结果（先粗分，后精化）。

## 9. 测试计划

- 单元测试：规则命中、边界值、配置覆盖优先级。
- 平台测试：Android/iOS 真实设备采集字段完整性。
- 性能测试：初始化耗时、分级计算耗时、运行期监听开销。
- 回归测试：策略切换对关键页面帧率与内存占用的影响。

## 10. 验收标准（首版）

- Android/iOS 设备均可输出稳定 Tier。
- Tier 与策略映射可在 demo 中可视化验证。
- 运行期降级触发可观测，且无明显抖动。
- 关键 API 文档齐全，具备被业务方集成条件。

## 11. 风险与应对

- 机型碎片化导致规则误判：增加置信度与远程覆盖。
- 平台字段受系统版本限制：提供字段缺失兜底路径。
- 过度降级影响体验：分场景策略拆分 + A/B 验证。

## 12. 下一步执行清单（立刻开始）

1. 明确首批接入业务场景（至少 2 个高负载页面）。
2. 定义 V1 规则表（RAM/机型/系统版本阈值）。
3. 完成 `TierDecision` 与 `Policy` 数据模型。
4. 先打通 Android 采集链路，再补齐 iOS 对齐字段。
5. 完成 demo 页面与日志面板，便于联调验收。
