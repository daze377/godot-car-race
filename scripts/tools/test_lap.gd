# Tool: lap-counting test (headless). Simulates start -> leave -> cross line.
# Usage:
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/tools/test_lap.gd
extends SceneTree

const WORLD_PATH := "res://scenes/world/world.tscn"
const PLAYER_PATH := "res://scenes/player/player_car.tscn"
const LAP_SCRIPT: GDScript = preload("res://scripts/race/lap_system.gd")


func _init() -> void:
	_run()


func _run() -> void:
	var ground := StaticBody3D.new()
	var gc := CollisionShape3D.new()
	gc.shape = WorldBoundaryShape3D.new()
	ground.add_child(gc)
	root.add_child(ground)

	var world: Node3D = load(WORLD_PATH).instantiate()
	root.add_child(world)
	var player: PlayerCar = load(PLAYER_PATH).instantiate()
	root.add_child(player)
	var lap: LapSystem = LAP_SCRIPT.new() as LapSystem
	root.add_child(lap)

	# Let the lap system connect to the finish Area3D (it awaits one frame).
	for _i in 5:
		await process_frame

	# Place the car on the start/finish line -> should START the race.
	player.reset_to(world.start_origin, world.start_yaw)
	for _i in 5:
		await physics_frame
	var started: bool = lap._started

	# Drive away from the line -> should mark "left start".
	player.position = Vector3(10.0, world.start_origin.y, world.start_origin.z)
	for _i in 5:
		await physics_frame
	var left: bool = lap._left_start

	# Cross the line again -> should complete lap 1.
	player.position = Vector3(0.0, world.start_origin.y, world.start_origin.z)
	for _i in 5:
		await physics_frame
	var lap1: int = lap.current_lap

	print("LAP TEST: started=%s  left=%s  current_lap=%d" % [started, left, lap1])
	var ok: bool = started and left and lap1 == 1
	print("RESULT lap:", "PASS" if ok else "FAIL")

	lap.queue_free()
	player.queue_free()
	world.queue_free()
	ground.queue_free()
	print("=== %d FAILURE(S) ===" % (0 if ok else 1))
	quit(0 if ok else 1)
