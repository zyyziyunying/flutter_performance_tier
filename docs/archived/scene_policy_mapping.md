# 首批高负载场景策略映射（M2）

更新时间：2026-02-25

## 场景 A：首屏动画（`home_hero_animation`）

| Tier | 动画预设 | 粒子特效 | 首帧后预加载数 | 首结果预算 | 首帧预算 | 最大卡顿率 |
| --- | --- | --- | --- | --- | --- | --- |
| `t0Low` | `minimal` | `false` | `0` | `<=300ms` | `<=450ms` | `<=8%` |
| `t1Mid` | `basic` | `false` | `1` | `<=300ms` | `<=380ms` | `<=6%` |
| `t2High` | `enhanced` | `true` | `2` | `<=300ms` | `<=320ms` | `<=4%` |
| `t3Ultra` | `full` | `true` | `3` | `<=300ms` | `<=280ms` | `<=3%` |

## 场景 B：列表/视频页（`feed_video_list`）

| Tier | 自动播放 | 预加载数 | 解码并发 | 缩略图边长 | 首视频冷启预算 | 最大卡顿率 | 常驻内存上限 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `t0Low` | `false` | `1` | `1` | `720` | `<=1200ms` | `<=10%` | `<=380MB` |
| `t1Mid` | `true` | `2` | `1` | `1080` | `<=1000ms` | `<=7%` | `<=460MB` |
| `t2High` | `true` | `3` | `2` | `1440` | `<=850ms` | `<=5%` | `<=560MB` |
| `t3Ultra` | `true` | `4` | `3` | `2160` | `<=700ms` | `<=4%` | `<=700MB` |

## 落地位置

- 规则输出：`lib/performance_tier/policy/policy_resolver.dart`
- 数据模型：`lib/performance_tier/policy/scenario_policy.dart`
- 统一输出入口：`lib/performance_tier/policy/performance_policy.dart`
