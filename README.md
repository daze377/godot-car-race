# BuildScene Racing

An arcade-style third-person racing game **with AI opponents**. Built with Kenney **Car Kit** + **Racing Kit** (CC0) assets on **Godot 4.7** + **Jolt Physics**.

## Features

- **Curved race track** — Catmull-Rom spline centerline with long straights, hairpins, and S-curves (`roadStraightLong` tiles along the curve, barriers + collision walls on both sides)
- **4 AI opponents** — police, taxi, firetruck, and sedan-sports from Car Kit; follow waypoints with corner braking and lane separation
- **Player car** — raceCarRed with arcade physics (accelerate / brake / reverse / steer / light drift)
- **Mouse steering** — point the cursor at the track to steer; keyboard A/D can be combined
- **Third-person chase camera** — smooth follow with velocity look-ahead
- **Lap system** — 3 laps, best-lap timing, HUD (speed / lap count / timer)

## Running the Game

### Option 1: Godot Editor

1. Open Godot 4.7
2. Import `project.godot`
3. Press **F5**

### Option 2: Command Line

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /path/to/godot-car-race
```

### Option 3: Windows Executable (.exe)

Cross-exported from macOS; build artifacts are in `export/`:

| File | Description |
|---|---|
| `export/BuildScene.exe` | Windows 64-bit launcher (~104 MB, Git LFS) |
| `export/BuildScene.pck` | Game data pack (must sit next to the `.exe`) |

**On Windows:** place `BuildScene.exe` and `BuildScene.pck` in the same folder, then double-click `BuildScene.exe`.

**Re-export** (requires Godot 4.7 export templates):

```bash
./scripts/tools/export_windows.sh
```

Or in the Godot editor: **Project → Export → Windows Desktop → Export Project**.

## Controls

| Input | Action |
|---|---|
| W / ↑ | Accelerate |
| S / ↓ | Brake / reverse |
| **Mouse** | Steer (aim at a point on the track) |
| A / ← | Steer left (stacks with mouse) |
| D / → | Steer right (stacks with mouse) |
| R | Reset to start grid |

**Goal:** finish 3 laps ahead of 4 AI opponents and set a new best lap time.

## Project Layout

```
scenes/
  main.tscn               Entry scene (world + player + 4 AI + camera + HUD + light)
  player/player_car.tscn  Player car (raceCarRed)
  race/ai_car.tscn        AI car (collision + script; model injected by main)
  world/world.tscn        Track root (procedural spline in world.gd)
  ui/hud.tscn             HUD overlay
scripts/
  main.gd                 Scene assembly + AI grid spawn
  player/player_car.gd    Arcade car physics + mouse steer
  player/follow_camera.gd Chase camera
  race/ai_car.gd          AI waypoint follower
  race/lap_system.gd      Lap counting (player only)
  world/world.gd          Catmull-Rom track / barriers / collision / decor
  ui/hud.gd               HUD updates
  tools/                  Headless tests + screenshot scripts
docs/                     Design notes + screenshots
export/                   Windows release build (.exe + .pck)
```

## Automated Tests (headless, expect 0 failures)

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --script scripts/tools/test_player_physics.gd --path .   # physics
$GODOT --headless --script scripts/tools/test_world.gd        --path .     # track + collision
$GODOT --headless --script scripts/tools/test_ai.gd           --path .     # AI movement
$GODOT --headless --script scripts/tools/test_lap.gd          --path .     # lap logic
```

## Screenshots

```bash
$GODOT --script scripts/tools/capture_top.gd          --path .   # track top-down
$GODOT --script scripts/tools/capture_grid.gd        --path .   # starting grid (with AI)
$GODOT --script scripts/tools/capture_race.gd        --path .   # race overview
$GODOT --script scripts/tools/capture_screenshot.gd --path .   # player view
```

## Tuning

- Track shape: `WAYPOINTS` in `scripts/world/world.gd`
- AI speed / steering: `@export` vars in `scripts/race/ai_car.gd`
- Player feel: `@export` vars in `scripts/player/player_car.gd` (`mouse_steer_smooth`, `lateral_grip`, etc.)

## Design Docs

See `docs/design.md` for the V2 notes (spline track + AI system).
