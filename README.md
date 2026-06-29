# BuildScene Racing

街机风格的第三人称赛车游戏，**带 AI 对手**。使用 Kenney **Car Kit** + **Racing Kit**（CC0）素材，基于 **Godot 4.7** + **Jolt Physics**。

## 特性
- 🏁 **真实弯道赛道**：Catmull-Rom 样条中心线，含长直道、发夹弯、S 弯（路面用 `roadStraightLong` 沿曲线铺设，护栏 + 碰撞边界双侧）
- 🤖 **4 辆 AI 对手**：car-kit 的 police / taxi / firetruck / sedan-sports，沿赛道 waypoints 自动跟随、弯道减速
- 🚗 玩家 raceCarRed，街机物理（加速/刹车/倒车/转向/漂移）
- 🎥 第三人称平滑跟随相机
- ⏱️ 计圈系统（3 圈，最佳单圈）+ HUD（速度/圈数/计时）

## 运行

### 方式一：Godot 编辑器
1. 打开 Godot 4.7
2. 导入 `project.godot`
3. 按 **F5**

### 方式二：命令行
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/dazelu/Godot/build-scene
```

### 方式三：Windows 可执行文件 (.exe)
已在 macOS 上交叉导出，产物在 `export/`：

| 文件 | 说明 |
|---|---|
| `export/BuildScene.exe` | Windows 64 位主程序（~104 MB） |
| `export/BuildScene.pck` | 游戏资源包（需与 .exe 同目录） |

**在 Windows 上运行**：将 `BuildScene.exe` 和 `BuildScene.pck` 放在同一文件夹，双击 `BuildScene.exe`。

**重新导出**（需已安装 Godot 4.7 导出模板）：
```bash
./scripts/tools/export_windows.sh
```

或在 Godot 编辑器：**项目 → 导出 → Windows Desktop → 导出项目**。

## 操作
| 按键 | 动作 |
|---|---|
| W / ↑ | 加速 |
| S / ↓ | 刹车 / 倒车 |
| **鼠标** | **转向（指向地面目标点）** |
| A / ← | 左转（可与鼠标叠加） |
| D / → | 右转（可与鼠标叠加） |
| R | 复位 |

**目标**：在 4 辆 AI 对手中完成 3 圈，刷新最佳单圈。

## 项目结构
```
scenes/
  main.tscn               主场景（world + player + 4 AI + camera + hud + light）
  player/player_car.tscn  玩家车（raceCar）
  race/ai_car.tscn        AI 车（碰撞+脚本，模型由 main 注入）
  world/world.tscn        赛道（world.gd 程序化样条赛道）
  ui/hud.tscn             HUD
scripts/
  main.gd                 场景组装 + AI 发车
  player/player_car.gd    赛车物理
  player/follow_camera.gd 跟随相机
  race/ai_car.gd          AI 跟随逻辑
  race/lap_system.gd      计圈（仅计玩家）
  world/world.gd          Catmull-Rom 赛道 / 护栏 / 碰撞边界 / 装饰
  ui/hud.gd               HUD
  tools/                  测试 + 截图脚本
docs/                     设计文档 + 截图
```

## 自动化测试（headless，全部 0 FAILURE）
```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --script scripts/tools/test_player_physics.gd --path .   # 物理
$GODOT --headless --script scripts/tools/test_world.gd        --path .     # 赛道结构+碰撞
$GODOT --headless --script scripts/tools/test_ai.gd           --path .     # AI 跟随
$GODOT --headless --script scripts/tools/test_lap.gd          --path .     # 计圈
```

## 截图
```bash
$GODOT --script scripts/tools/capture_top.gd   --path .    # 赛道俯视
$GODOT --script scripts/tools/capture_grid.gd  --path .    # 发车区（含 AI）
$GODOT --script scripts/tools/capture_race.gd  --path .    # 比赛全局
$GODOT --script scripts/tools/capture_screenshot.gd --path .  # 玩家视角
```

## 调参
- 赛道形状：`scripts/world/world.gd` 的 `WAYPOINTS` 控制点
- AI 速度/转角：`scripts/race/ai_car.gd` 的 `@export`
- 玩家手感：`scripts/player/player_car.gd` 的 `@export`

## 设计文档
`docs/design.md`（含 V2 重构说明：样条赛道 + AI 系统）
