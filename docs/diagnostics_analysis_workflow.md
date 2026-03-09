# 诊断数据分析流程

## 1. 输入前提

这个分析脚本直接面向当前 Demo 已经产出的两类数据：

- `AI Diagnostics JSON`
- `PERF_TIER_LOG` 结构化日志

对应项目里的核心字段包括：

- `TierDecision`
- `DeviceSignals`
- `RuntimeTierObservation`
- `recentStructuredLogs`

## 2. 运行脚本

分析一批从 OSS 拉下来的 JSON：

```powershell
python tool\analyze_diagnostics.py D:\path\to\pulled\data
```

同时分析多个目录：

```powershell
python tool\analyze_diagnostics.py D:\path\to\android D:\path\to\ios
```

自定义输出目录：

```powershell
python tool\analyze_diagnostics.py D:\path\to\pulled\data --output build\diagnostics_analysis_run_01
```

## 3. 产出文件

默认输出到 `build/diagnostics_analysis/`：

- `session_summary.csv`：每条诊断样本一行，适合看字段完整性、tier、runtime 状态
- `event_timeline.csv`：把结构化日志拍平成事件时间线
- `device_model_summary.csv`：按 `platform + deviceModel` 聚合
- `flagged_sessions.csv`：优先人工排查的异常样本
- `parse_issues.csv`：格式错误或不支持的输入
- `summary.md`：第一眼摘要

## 4. 推荐分析顺序

1. 先看 `summary.md`，确认样本量、字段完整率、热点问题。
2. 再看 `parse_issues.csv`，先把坏数据和混合格式清掉。
3. 再看 `session_summary.csv`：
   - `device_model` 是否缺失
   - `total_ram_bytes` 是否缺失
   - `runtime_status` 是否异常
   - 是否出现 fallback 样本
4. 再看 `device_model_summary.csv`：
   - 同机型是否映射到多个 tier
   - 哪些机型 `active` / `cooldown` 比例高
   - 哪些机型 fallback 多
5. 再看 `event_timeline.csv`：
   - 触发重算的是哪个 trigger
   - runtime 状态有没有真正变化
   - tier 变化是否符合预期
6. 最后用 `flagged_sessions.csv` 作为人工深挖 shortlist。

## 5. 重点关注什么

### 静态分级

- 同一个 `deviceModel` 通常应该趋于稳定 tier。
- 低 RAM 设备不应该大量落在高 tier。
- 高 RAM + 高 `mediaPerformanceClass` 设备如果长期在低 tier，需要结合 `reasons` 解释。

### 运行期降级

- `runtime_status=active/cooldown` 应该能对应清晰的 `triggerReason`。
- `downgrade_trigger_count` 很高但恢复很少的样本要重点看。
- `frame_drop_rate` 很高但没有运行期降级，说明阈值可能过松。

### 数据质量

- `deviceModel`、`totalRamBytes` 缺失会直接削弱后续分析价值。
- fallback 多通常说明平台采集或上传封装不稳定。

## 6. 冒烟验证

仓库里带了一个样本：

```powershell
python tool\analyze_diagnostics.py tool\testdata\sample_ai_report.json --output build\diagnostics_analysis_sample
```

这个命令能跑通，就可以直接切换到真实拉取数据。
