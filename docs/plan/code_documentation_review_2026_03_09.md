# 代码与文档审查问题记录（2026-03-09）

## 1. 背景

- 审查范围：`flutter_performance_tier` 当前代码与文档现状。
- 审查方式：基于仓库静态阅读 + 本地命令验证。
- 已执行验证：
  - `flutter analyze`
  - `flutter test`
  - `python tool\analyze_diagnostics.py tool\testdata\sample_ai_report.json --output build\diagnostics_analysis_sample_review`
- 当前结论：仓库可以跑通，但存在若干生命周期、抽象边界、工程定位和文档维护问题，后续如果继续扩展到真机联调或远程配置阶段，容易放大成真实缺陷。

## 2. 结论摘要

核心库的分层整体是清楚的，`engine / policy / service` 的职责划分也基本成立，测试覆盖对当前主链路有一定保护。

真正需要优先处理的问题，不是“代码完全不能用”，而是下面几类“现在还能忍，后面会变雷”的问题：

1. 初始化异常路径没有收口，服务对象可能进入坏状态。
2. Service 抽象缺少释放能力，资源生命周期设计不完整。
3. Demo、内部联调逻辑和可复用库边界混在一起，仓库定位不够干净。
4. 文档开始与实际文件漂移，已经出现可直接误导维护者的错误引用。

## 3. 问题清单

### 3.1 高优先级：初始化失败后可能进入坏状态

**涉及文件**

- `lib/performance_tier/service/default_performance_tier_service.dart`

**问题描述**

`DefaultPerformanceTierService.initialize()` 在首个有效 `TierDecision` 产出前，就先把 `_initialized` 置为 `true`，并启动了 frame sampler 与 runtime polling。

当前 `collect()` 的异常有 fallback 兜底，但 `_configProvider.load()` 不在 fallback 保护范围内。也就是说，只要后续把 `ConfigProvider` 做成可能失败的远端配置、灰度配置或文件配置，初始化失败后就可能出现以下状态：

- 服务对象看起来已经初始化；
- 定时轮询已经启动；
- `_currentDecision` 仍然为空；
- 后续 `getCurrentDecision()` 直接命中 `_currentDecision!` 空值断言；
- 业务层很难区分这是“未初始化”还是“初始化失败后残留坏状态”。

**影响**

- 这是明显的生命周期一致性问题。
- 现在之所以没有暴露，主要是因为默认 `ConfigProvider` 恒成功。
- 一旦进入 M4 远程配置阶段，这个问题很容易从“潜在设计缺陷”变成真实线上故障。

**建议动作**

- 将 `_initialized = true` 延后到首次成功产出 decision 之后，或引入独立的 `initializing / initialized / failed / disposed` 状态。
- 至少把 `_configProvider.load()` 纳入统一异常处理路径。
- 为“配置加载失败”补一个明确测试，避免以后改造时回归。

### 3.2 中优先级：Service 抽象没有暴露释放能力

**涉及文件**

- `lib/performance_tier/performance_tier_service.dart`
- `lib/performance_tier/service/default_performance_tier_service.dart`

**问题描述**

`PerformanceTierService` interface 只暴露了：

- `initialize()`
- `getCurrentDecision()`
- `watchDecision()`
- `refresh()`

但具体实现 `DefaultPerformanceTierService` 内部实际持有：

- `StreamController`
- `Timer`
- `FrameDropSignalSampler`

这些资源都需要显式释放，然而 interface 没有 `dispose()`。这意味着：

- 如果业务代码按 interface 编程，就拿不到释放入口；
- 如果业务要正确释放资源，就只能依赖具体实现类；
- 抽象层的价值被削弱，后续替换实现也会变得 awkward。

**影响**

- 容易出现页面退出后仍有 timer 存活、监听未清理的风险。
- 让“推荐按接口依赖”这件事在实践里站不住脚。

**建议动作**

- 让 `PerformanceTierService` 直接暴露 `dispose()`，或继承统一的可释放接口。
- 在 README / 接入示例里明确生命周期要求。
- 增加一个“通过 interface 持有并释放”的测试或示例，确保抽象与实现一致。

### 3.3 中优先级：Demo 与可复用库边界混杂，仓库定位不够干净

**涉及文件**

- `lib/main.dart`
- `pubspec.yaml`
- `README.md`

**问题描述**

仓库对外口径写的是“可复用的 Flutter 性能分级能力”，但 demo 层仍然带有明显的内部联调痕迹：

- `lib/main.dart` 直接内置上传探针逻辑；
- 存在硬编码 HTTP 登录与上传地址；
- 依赖 workspace 内部包 `common`；
- Demo 页职责不只是展示 tier，而是顺带承担内部诊断上传能力；
- `pubspec.yaml` 的 description 仍是 `A new Flutter project.`，和当前项目定位不匹配。

这会让仓库呈现出一种比较别扭的状态：库本身想做成可复用能力，但 sample 和打包方式又像强绑定内部环境的联调壳子。

**影响**

- 新接手的人很难快速判断哪些代码是库主干，哪些只是内部临时验证逻辑。
- 外部复用或后续抽离 package 时，`main.dart` 和依赖关系会成为阻力。
- README 所描述的“可复用”定位，会被当前 demo 结构稀释。

**建议动作**

- 将上传 probe 逻辑下沉到独立 example/internal demo，避免污染主示例。
- 对外保留最小接入 demo，对内联调工具单独隔离。
- 更新 `pubspec.yaml` 描述，明确这是内部 package 还是可复用模块。
- README 增加“库主干”和“内部联调 Demo”边界说明。

### 3.4 低优先级：文档已出现漂移，存在误导性引用

**涉及文件**

- `docs/runtime_dynamic_tiering.md`
- `docs/progress/initialization_baseline.md`
- `test/performance_tier/service/default_performance_tier_service_baseline_perf_test.dart`
- `test/performance_tier/service/default_performance_tier_service_runtime_signals_test.dart`

**问题描述**

文档中多处仍引用 `test/performance_tier/service/default_performance_tier_service_test.dart`，但该文件在仓库中并不存在，相关测试已经拆分为多个文件。

这类问题看起来不大，但会直接影响：

- 新维护者按文档执行命令；
- 回溯某个测试覆盖点时的定位效率；
- 文档可信度。

**影响**

- 维护者会先怀疑环境问题，而不是意识到文档本身已经过期。
- 文档一旦开始漂移，后续更容易持续失真。

**建议动作**

- 把文档引用改为当前真实文件名。
- 文档里尽量少写“单文件固定路径”，必要时直接写测试名和推荐命令。
- 以后文档更新时，把“引用是否还能跑通”作为最基本检查项。

## 4. 额外观察

### 4.1 当前测试结论是“能跑”，不是“边界已经设计稳”

本次 `flutter analyze` 与 `flutter test` 都通过，说明当前主链路在既有假设下是成立的。

但需要明确：

- 现在测试覆盖更多是在保护当前实现；
- 真正的风险点集中在未来扩展场景；
- 尤其是远程配置、灰度参数、独立对外接入这几类需求，一旦推进，会直接碰到上面的问题。

### 4.2 核心代码质量整体好于 Demo 与文档层

从结构上看，当前仓库最稳的是：

- `RuleBasedTierEngine`
- `RuntimeTierController`
- `PolicyResolver`
- 现有 service orchestration tests

相对更弱的是：

- demo 的工程边界
- 文档一致性
- 生命周期异常路径

这意味着后续优化优先级应当是：

1. 先补生命周期与抽象边界。
2. 再清理 demo / internal tooling 边界。
3. 最后统一修正文档引用和仓库定位描述。

## 5. 建议的后续动作顺序

1. 修正 `DefaultPerformanceTierService` 初始化异常路径，补失败态测试。
2. 给 `PerformanceTierService` 增加可释放能力，并同步更新示例。
3. 拆分 demo 与内部上传 probe，减少主仓库“内部联调工具味”。
4. 统一修正文档中的测试路径、项目定位与当前阶段说明。

## 6. 备注

本文件记录的是当前仓库状态下的审查结论，重点是帮助后续开发排优先级，不代表必须一次性全部处理完成。
