# Tool: automated physics test for the player car (headless, no keyboard needed).
# Usage:
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/tools/test_player_physics.gd
# Uses the SceneTree `physics_frame` signal to step exactly one physics tick per
# await, giving deterministic physics time regardless of how fast idle frames run.
extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/player/player_car.tscn"


func _init() -> void:
	# Start the async test coroutine; _init returns immediately.
	_run_tests()


func _run_tests() -> void:
	var player: PlayerCar = load(PLAYER_SCENE_PATH).instantiate()
	var ground := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	ground.add_child(col)
	root.add_child(ground)
	root.add_child(player)

	# Let the tree initialize, then place the car.
	await physics_frame
	player.reset_to(Vector3(0.0, 0.6, 0.0), 0.0)
	for _i in 10:
		await physics_frame

	var failures: int = 0
	failures += await _test_acceleration(player)
	failures += await _test_steering(player)

	player.queue_free()
	ground.queue_free()
	print("=== %d FAILURE(S) ===" % failures)
	quit(failures)


func _test_acceleration(player: PlayerCar) -> int:
	Input.action_press("accelerate")
	for _i in 150:
		await physics_frame
	Input.action_release("accelerate")
	var speed: float = player.speed_kmh
	var pos: Vector3 = player.global_position
	# Car faces -Z, so it should have moved to negative Z and gained speed.
	var passed: bool = speed > 50.0 and pos.z < -3.0
	print("TEST accel   : speed_kmh=%6.1f  pos.z=%7.2f  => %s" % [speed, pos.z, "PASS" if passed else "FAIL"])
	return 0 if passed else 1


func _test_steering(player: PlayerCar) -> int:
	# Carry residual speed, then hold left for 1 second.
	var yaw_before: float = player.global_rotation.y
	Input.action_press("steer_left")
	for _i in 60:
		await physics_frame
	Input.action_release("steer_left")
	var delta: float = absf(player.global_rotation.y - yaw_before)
	var passed: bool = delta > 0.3
	print("TEST steer   : yaw_delta=%6.3f rad                 => %s" % [delta, "PASS" if passed else "FAIL"])
	return 0 if passed else 1
