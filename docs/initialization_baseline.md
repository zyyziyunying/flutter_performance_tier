# 初始化耗时基线（M2）

> 记录时间：2026-02-25  
> 目标：首个可用结果 `<=300ms`

## 测量方式

- 用例：`test/performance_tier/service/default_performance_tier_service_test.dart`
- 关注测试：`DefaultPerformanceTierService initialization baseline returns first decision within 300ms budget`
- 执行命令：
  - `flutter test test/performance_tier/service/default_performance_tier_service_test.dart --plain-name "returns first decision within 300ms budget"`
- 统计口径：
  - 预热 5 次 + 采样 40 次
  - 指标为 `initialize() + getCurrentDecision()` 的端到端耗时
  - 使用 `Stopwatch.elapsedMicroseconds` 统计后转换为毫秒

## 基线结果（本地）

- `p50 ≈ 0.20ms`
- `p95 ≈ 0.33ms`
- `max ≈ 0.84ms`

## 结论

- 当前 Dart 侧服务编排链路远低于 `300ms` 目标，满足“首结果预算”。
- 该基线基于测试环境的内存内假数据采集，不包含真实 MethodChannel 与真机系统调用耗时。
- 下一步建议在 Android/iOS 真机补充同口径采样，形成平台实测基线。
