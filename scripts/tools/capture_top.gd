# Tool: top-down orthographic screenshot of the whole track (GUI mode).
# Usage:
#   /Applications/Godot.app/Contents/MacOS/Godot --script scripts/tools/capture_top.gd
extends SceneTree


func _init() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1400, 1000)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 110.0
	cam.position = Vector3(3.0, 60.0, 13.0)
	cam.rotate_x(-PI / 2.0)  # look straight down
	root.add_child(cam)
	cam.current = true

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	root.add_child(light)

	# Ground so the track reads against something.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.2, 0.14)
	mat.roughness = 1.0
	plane.material = mat
	ground.mesh = plane
	root.add_child(ground)

	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)

	for _i in 40:
		await process_frame

	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png("res://docs/track_top.png")
	print("TOP_SAVED size=", img.get_size(), " err=", err)
	world.queue_free()
	await process_frame
	quit()
