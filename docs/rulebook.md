# V1 Rulebook（默认阈值与覆盖优先级）

更新时间：2026-02-25

## 1. 配置项与默认阈值

默认 `TierConfig` 定义在 `lib/performance_tier/config/tier_config.dart`。

| 配置项 | 默认值 | 含义 |
| --- | --- | --- |
| `lowRamMaxBytes` | `3 * 1024 * 1024 * 1024`（3GB） | `totalRamBytes <= 3GB` 时落到 `t0Low` |
| `midRamMaxBytes` | `6 * 1024 * 1024 * 1024`（6GB） | `3GB < totalRamBytes <= 6GB` 时为 `t1Mid` |
| `highRamMaxBytes` | `10 * 1024 * 1024 * 1024`（10GB） | `6GB < totalRamBytes <= 10GB` 时为 `t2High`，更高为 `t3Ultra` |
| `highMediaPerformanceClass` | `12` | `mediaPerformanceClass >= 12` 时至少提升到 `t2High` |
| `ultraMediaPerformanceClass` | `13` | `mediaPerformanceClass >= 13` 时至少提升到 `t3Ultra` |
| `minSdkForHighTier` | `0` | 高档位系统版本下限（`0` 表示不启用） |
| `minSdkForUltraTier` | `0` | 超高档位系统版本下限（`0` 表示不启用） |
| `modelTierCaps` | `[]` | 机型封顶规则列表（默认空） |

约束关系（构造时断言）：
- `lowRamMaxBytes <= midRamMaxBytes <= highRamMaxBytes`
- `highMediaPerformanceClass <= ultraMediaPerformanceClass`
- `minSdkForHighTier <= minSdkForUltraTier`

## 2. 判级链路（命中顺序）

引擎实现位于 `lib/performance_tier/engine/rule_based_tier_engine.dart`，规则按以下顺序执行：

1. **RAM 基线分级**：先根据 `totalRamBytes` 得到基础 Tier。`totalRamBytes` 缺失时回退到 `t1Mid`。
2. **低内存设备强制降档**：若 `isLowRamDevice == true`，直接强制 `t0Low`，并禁止后续 MPC 升档。
3. **MPC 升档**：仅在未被低内存强制降档时生效，按 `highMediaPerformanceClass/ultraMediaPerformanceClass` 抬升档位。
4. **SDK 封顶**：若配置了 `minSdkForUltraTier/minSdkForHighTier`（>0），系统版本不达标时分别封顶为 `t2High/t1Mid`。
5. **机型封顶**：按 `modelTierCaps` 顺序匹配 `deviceModel`，命中第一条后按 `maxTier` 封顶并停止继续匹配。

说明：
- 封顶规则本质上是“取更低档位”（`min`），升档规则是“取更高档位”（`max`）。
- SDK 封顶与机型封顶叠加时，最终结果等价于“更严格者优先”。

## 3. 覆盖策略（Override Patch）

合并入口位于 `lib/performance_tier/config/config_provider.dart`：
- `DefaultConfigProvider.load()` 返回 `config.applyOverride(configOverride)`。
- 即：**基础 rulebook + 覆盖 patch**。

`TierConfig.applyOverride` 的优先级规则：
- 标量字段（RAM/MPC/SDK）：`override` 字段非空即覆盖基础值；为空则沿用基础值。
- `modelTierCaps`：整体替换，不做 append merge。
  - `null`：沿用基础列表。
  - `[]`：显式清空基础列表。
- SDK 下限冲突自动修正：若合并后出现 `minSdkForUltraTier < minSdkForHighTier`，会自动对齐，确保 `high <= ultra`。

### 3.1 SDK 冲突对齐细则

当 `minSdkForUltraTier < minSdkForHighTier` 时：
- 仅设置了 `minSdkForHighTier`：自动把 `minSdkForUltraTier` 提升到同值。
- 仅设置了 `minSdkForUltraTier`：自动把 `minSdkForHighTier` 对齐到同值。
- 两者都设置但冲突：以 `minSdkForHighTier` 为准，将 `minSdkForUltraTier` 提升到 `minSdkForHighTier`。

## 4. 覆盖示例

```dart
const base = TierConfig();
const override = TierConfigOverride(
  lowRamMaxBytes: 2 * 1024 * 1024 * 1024,
  minSdkForHighTier: 29,
  minSdkForUltraTier: 33,
  modelTierCaps: <ModelTierCapRule>[
    ModelTierCapRule(pattern: 'SM-A0', maxTier: TierLevel.t1Mid),
  ],
);

final merged = base.applyOverride(override);
```

等价结论：
- RAM 低档阈值改为 2GB。
- 高/超高 SDK 封顶阈值分别改为 29/33。
- 机型封顶规则替换为仅一条 `SM-A0 -> t1Mid`。

## 5. 配套测试

- 配置覆盖与解析：`test/performance_tier/tier_config_test.dart`
- 规则链路（低内存、MPC、SDK、机型封顶）：`test/performance_tier/rule_based_tier_engine_test.dart`
