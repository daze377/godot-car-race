# Tool: structural + collision test for the V2 curved track (headless).
# Usage:
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/tools/test_world.gd
extends SceneTree

const WORLD_PATH := "res://scenes/world/world.tscn"
const PLAYER_PATH := "res://scenes/player/player_car.tscn"


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
	await physics_frame

	# --- structural checks ---
	var walls: int = world.find_children("*", "StaticBody3D", true, false).size()
	var areas: int = world.find_children("*", "Area3D", true, false).size()
	var roads: int = world.find_children("*", "MeshInstance3D", true, false).size()
	var cl_v: Variant = world.get("centerline")
	var cl: PackedVector3Array = cl_v if cl_v != null else PackedVector3Array()
	print("STRUCT: walls=%d areas=%d mesh=%d centerline=%d" % [walls, areas, roads, cl.size()])
	var struct_ok: bool = walls > 40 and areas == 1 and roads > 20 and cl.size() > 100
	print("RESULT struct:", "PASS" if struct_ok else "FAIL")

	# --- collision check: a car driving flat out must stay bounded ---
	var player: PlayerCar = load(PLAYER_PATH).instantiate()
	root.add_child(player)
	await physics_frame
	player.reset_to(world.start_origin, world.start_yaw)
	Input.action_press("accelerate")
	for _i in 200:
		await physics_frame
	Input.action_release("accelerate")
	var dist: float = player.global_position.distance_to(world.start_origin)
	print("COLLIDE: distance from start after 200 frames = %.2f" % dist)
	# Bounded movement (not flying off to infinity) => walls work.
	var collide_ok: bool = dist > 5.0 and dist < 80.0
	print("RESULT collide:", "PASS" if collide_ok else "FAIL")

	player.queue_free()
	world.queue_free()
	ground.queue_free()
	var fail: int = 0 if (struct_ok and collide_ok) else 1
	print("=== %d FAILURE(S) ===" % fail)
	quit(fail)
