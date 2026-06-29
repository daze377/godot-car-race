# Tool: top-down view of the starting grid (player + AI cars), early frames so
# cars are still near their grid slots. Verifies AI model facing direction.
# Usage:
#   /Applications/Godot.app/Contents/MacOS/Godot --script scripts/tools/capture_grid.gd
extends SceneTree


func _init() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1500, 950)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 26.0
	cam.position = Vector3(4.0, 28.0, 35.0)
	cam.rotate_x(-PI / 2.0)
	root.add_child(cam)
	cam.current = true

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	root.add_child(light)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.2, 0.14)
	mat.roughness = 1.0
	plane.material = mat
	ground.mesh = plane
	root.add_child(ground)

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	# Disable the player's chase camera so our top-down camera renders.
	for c in main.find_children("*", "Camera3D", true, false):
		c.current = false
	cam.current = true

	# Early frames: cars are still on the grid.
	for _i in 8:
		await process_frame

	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png("res://docs/grid_top.png")
	print("GRID_SAVED size=", img.get_size(), " err=", err)

	main.queue_free()
	await process_frame
	quit()
