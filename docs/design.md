# BuildScene 赛车游戏 — 设计文档

> Spec-driven（superpowers 方法论）：先规格，后实现。本文档是实现的唯一依据。

## 1. 游戏概念
一款街机风格的第三人称赛车游戏。玩家驾驶赛车在矩形闭环赛道上竞速，目标是用最短时间完成若干圈。

## 2. 范围 (MVP)
**纳入**
- 玩家赛车：街机物理（加速 / 刹车 / 倒车 / 转向 / 轻微漂移）
- 第三人称跟随相机（平滑跟随 + 朝向插值）
- 矩形闭环赛道：直道铺设路面块，弯道平地 + 护栏引导
- 起终点线 + 计圈（Area3D 触发，需按顺序穿过 checkpoint）
- 速度表 + 圈数 + 单圈/总计时 HUD
- 环境装饰：护栏、起终点旗、看台、树、锥桶障碍
- 灯光（DirectionalLight3D + WorldEnvironment 天空）

**不纳入（后续迭代）**
- AI 对手、多人、回放、车辆损坏、音效、菜单系统

## 3. 技术选型
| 项 | 选择 | 理由 |
|---|---|---|
| 物理 | **CharacterBody3D**（运动学街机） | RigidBody3D 翻车难调；运动学可控、稳定、不翻 |
| 渲染 | Forward Plus（已配） | 3D 默认，质量好 |
| 物理 engine | Jolt Physics（已配） | 已启用 |
| 赛道构建 | **程序化生成**（world.gd） | 参数化、可调、比手写几百节点可靠 |
| 单位 | 米（Godot 默认） | 素材已是真实米制 |

## 4. 素材使用清单
来自 `assets/kenney_racing-kit/Models/GLTF format/`：
- `raceCarRed`（玩家车视觉；尺寸 0.729×0.397×1.346m，几何中心偏移 `(0.35, 0, 0.663)`）
- `roadStraightLong`（直道路面，2m/块）+ `roadStartPositions`（起点）
- `barrierWall` / `barrierRed`（护栏边界）
- `flagCheckers`（起终点旗）、`flagGreen`/`flagRed`
- `grandStand`（看台）、`treeSmall`/`treeLarge`（树）、`cone`（来自 car-kit，障碍）
- `pylon`、`billboard`（装饰）

## 5. 拼接数据（实测）
网格基准：标准块 `x∈[-0.35,0.65]`（宽1m）、`z∈[-1.65,-0.65]`（长1m）。
- 直道沿 -Z 每 2m（roadStraightLong）铺一块，接缝在 -0.65、-2.65、-4.65…
- `raceCar` 原点在车体角，视觉节点偏移 `(+0.35, 0, +0.663)` 居中。

## 6. 架构与文件结构
```
project.godot                  (改: 主场景=main.tscn + input map)
scenes/
  main.tscn                    主场景：组合 World + Player + Camera + HUD + Light
  player/player_car.tscn       玩家车：CharacterBody3D + raceCar 视觉 + 碰撞
  world/world.tscn             世界根：world.gd 程序化生成赛道
  ui/hud.tscn                  HUD：CanvasLayer + Label
scripts/
  player/player_car.gd         赛车控制（街机物理）
  player/follow_camera.gd      跟随相机
  world/world.gd               程序化赛道/护栏/装饰生成
  race/lap_system.gd           计圈 + checkpoint
  ui/hud.gd                    HUD 更新
  game/race_signals.gd         全局信号（autoload，圈数/计时广播）
scripts/tools/measure_dimensions.gd   (已建，工具)
docs/design.md                 本文档
```

## 7. 控制方案 (input map)
| 动作 | 键 | 用途 |
|---|---|---|
| `accelerate` | W / ↑ / 手柄 A | 加速 |
| `brake` | S / ↓ / 手柄 B | 刹车 / 倒车 |
| `steer_left` | A / ← | 左转 |
| `steer_right` | D / → | 右转 |
| `reset_car` | R | 复位到最近 checkpoint |

## 8. 赛车物理参数（初值，待调）
- 最大速度 28 m/s (~100 km/h)
- 加速度 12 m/s²，刹车 20 m/s²
- 转向角速度 2.2 rad/s（随速度反比，低速更灵活）
- 重力 19.6（街机略重）
- 漂移：高速转向时降低侧向摩擦 → 滑动

## 9. 计圈规则
- 起点线 = Area3D，玩家从静止出发；首次穿过起点开始计时。
- 4 个 checkpoint（赛道四角）需按顺序触发，防止抄近路。
- 穿过所有 checkpoint 后再次穿过起点线 → 圈数 +1，记录单圈时间。
- 目标 3 圈，完成后显示总成绩。

## 10. 验证
- Godot headless `--import` 通过、无脚本错误
- `--check-only` 场景加载无报错
- 提供编辑器运行 + CLI 运行两种方式（README）

---

# V2 — 真实弯道赛道 + AI 对手（重构）

> V1 的矩形+草地弯道被判定"太糟糕"。V2 用 racing-kit 路面件沿样条铺设真实弯道赛道，并加入 car-kit 车辆做 AI 对手。

## V2.1 赛道：Catmull-Rom 样条中心线
- 一组控制点（俯视 X-Z）定义**闭合**赛道，含长直道、S 弯、发夹弯。
- Catmull-Rom 插值生成密集中心线（~0.7m/点），暴露给 AI 作 waypoints。
- 沿中心线按弧长每 ~1.8m 放一块 `roadStraightLong`（块长 2m，略重叠防缝），旋转对齐切线 → 弯道处自然扇形铺设成真实弯道。
- 护栏 `barrierWall` 沿中心线两侧偏移 `road_half` 铺设（长边对齐赛道方向）。
- 起终点线 Area3D 在起点，朝向切线。

## V2.2 AI 对手车（car-kit 车辆）
- `ai_car.gd`：CharacterBody3D + car-kit 模型（police / taxi / firetruck / sedan-sports）。
  - car-kit 车辆原点居中（x=0, z≈0），居中偏移≈0，比 raceCar 简单。
  - 控制：朝下一 waypoint 转向（限角速度）+ 油门；弯道（转向偏差大）自动减速。
  - 简化物理（velocity = forward·speed，无漂移），避免 AI 翻车。
- 多辆 AI，不同发车位（起终点后间隔 + 横向车道偏移）、不同极速。
- 玩家 raceCarRed 与 AI 同场竞速。

## V2.3 计圈适配
- 起终点 Area3D 仅对 group "player" 计圈（AI 不触发玩家计圈）。
- AI 自带简单圈数计数（穿过起终点线计数，仅展示用）。

## V2.4 验证
- 回归：物理 / 赛道(中心线闭合+路面数) / AI(沿 waypoints 前进不脱轨) / 计圈。
- 截图：确认弯道路面连续、AI 车在赛道上、起终点正常。
