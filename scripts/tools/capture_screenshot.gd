# Tool: render main scene and save a screenshot (GUI mode required, NOT headless).
# Usage:
#   /Applications/Godot.app/Contents/MacOS/Godot --script scripts/tools/capture_screenshot.gd
extends SceneTree


func _init() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

	# Let the scene build and the camera settle.
	for _i in 90:
		await process_frame

	var tex: ViewportTexture = root.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		print("SHOT_FAILED: null image (need GUI mode, not --headless)")
		quit(1)
		return
	var err: int = img.save_png("res://docs/preview.png")
	print("SHOT_SAVED size=", img.get_size(), " save_err=", err)

	main.queue_free()
	await process_frame
	quit()
