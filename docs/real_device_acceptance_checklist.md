# 真机验收 Checklist（JSON + OSS 目标）

更新时间：2026-03-04

适用范围：`flutter_performance_tier` 当前阶段交付目标（结构化 JSON 产出 + 经业务服务上传 OSS）。

## 1. 准备

- [ ] 使用真机（非模拟器）各 1 台：Android / iOS。
- [ ] `flutter run` 启动成功，Demo 页面可见。
- [ ] 上传鉴权参数可用（`UPLOAD_PROBE_TOKEN` 或 `UPLOAD_PROBE_USERNAME` + `UPLOAD_PROBE_PASSWORD`）。

## 2. 核心功能（两端都做）

- [ ] 首次进入后能拿到 `TierDecision`（页面 headline 不再是 initializing）。
- [ ] 控制台能看到 `PERF_TIER_LOG` JSON Line。
- [ ] `AI Diagnostics JSON` 可复制，且 JSON 结构完整可解析。
- [ ] JSON 内包含 `runtimeObservation.status`。
- [ ] JSON 内包含 `runtimeObservation.statusDurationMs`。
- [ ] JSON 内包含 `runtimeObservation.downgradeTriggerCount` / `runtimeObservation.recoveryTriggerCount`。

## 3. 运行期变化验证（两端都做）

- [ ] 触发一次高负载后，`runtimeObservation.status` 有变化（如 `pending/active/...`）。
- [ ] 恢复到轻负载后，状态可进入恢复链路（如 `cooldown/recovered`）。
- [ ] 点击刷新按钮后，日志出现 `decision.recompute.completed`。

## 4. 上传链路（重点）

- [ ] 点击 `Run Dio /upload probe` 后上传成功。
- [ ] 服务端返回成功信息可见。
- [ ] OSS 上可查到对应 JSON 对象（文件名/时间匹配）。
- [ ] 上传失败时（断网或鉴权错误）有清晰错误信息，恢复后可再次成功上传。

## 5. 通过标准

- [ ] Android 全部通过。
- [ ] iOS 全部通过。
- [ ] 两端至少各完成 1 次“生成 JSON -> 上传 -> OSS 可查”的闭环。

## 6. 验收记录模板（可复制）

```markdown
# 真机验收记录

- 验收日期：
- 验收人：
- 分支/版本：

## 设备信息

- Android：
  - 品牌/型号：
  - 系统版本：
  - App 版本：
- iOS：
  - 机型：
  - 系统版本：
  - App 版本：

## 结果

- Android：通过 / 未通过
- iOS：通过 / 未通过

## 失败项与原因

- （如无可写“无”）

## OSS 归档样本

- Android 对象路径：
- iOS 对象路径：

## 结论

- 是否满足当前阶段交付标准：是 / 否
```
