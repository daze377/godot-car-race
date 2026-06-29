# Tool: AI car behavior test (headless). Loads the full main scene (with AI),
# steps physics, and asserts every AI car advances along the track.
# Usage:
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/tools/test_ai.gd
extends SceneTree


func _init() -> void:
	_run()


func _run() -> void:
	var ground := StaticBody3D.new()
	var gc := CollisionShape3D.new()
	gc.shape = WorldBoundaryShape3D.new()
	ground.add_child(gc)
	root.add_child(ground)

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await physics_frame

	var ais: Array = get_nodes_in_group("ai_car")
	print("AI count = ", ais.size())
	if ais.is_empty():
		print("RESULT ai: FAIL (no AI cars spawned)")
		quit(1)
		return

	var start_positions: Array = []
	for a in ais:
		start_positions.append(a.global_position)

	# ~5 seconds of physics.
	for _i in 300:
		await physics_frame

	var moved: int = 0
	var n: int = ais.size()
	for i in n:
		var a: Node3D = ais[i]
		var d: float = a.global_position.distance_to(start_positions[i])
		if d > 10.0:
			moved += 1
	print("AI moved >10m: %d / %d" % [moved, n])

	var ok: bool = moved == n
	print("RESULT ai:", "PASS" if ok else "FAIL")

	main.queue_free()
	ground.queue_free()
	print("=== %d FAILURE(S) ===" % (0 if ok else 1))
	quit(0 if ok else 1)
