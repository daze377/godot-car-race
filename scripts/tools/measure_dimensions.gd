# Tool: measure all GLB model dimensions for scene assembly.
# Headless usage:
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --script scripts/tools/measure_dimensions.gd
# Prints CSV: name,size_x,size_y,size_z,min_x,min_z,max_x,max_z  (meters)
extends SceneTree

const KIT_DIRS := [
	"res://assets/kenney_racing-kit/Models/GLTF format/",
	"res://assets/kenney_car-kit/Models/GLB format/",
]


func _init() -> void:
	print("=== GLB DIMENSIONS (Godot units / meters) ===")
	for kit_dir in KIT_DIRS:
		_measure_dir(kit_dir)
	quit()


func _measure_dir(kit_dir: String) -> void:
	var dir := DirAccess.open(kit_dir)
	if dir == null:
		print("# (could not open %s)" % kit_dir)
		return
	var files := PackedStringArray()
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if fn.ends_with(".glb"):
			files.append(fn.get_basename())
		fn = dir.get_next()
	dir.list_dir_end()
	files.sort()
	print("# --- %s (%d models) ---" % [kit_dir, files.size()])
	print("name,size_x,size_y,size_z,min_x,min_z,max_x,max_z")
	for f in files:
		var res := load(kit_dir + f + ".glb")
		if res == null:
			print("%s,LOAD_FAILED,0,0,0,0,0,0,0" % f)
			continue
		var total := _measure(res)
		var s := total.size
		print("%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f" % [
			f, s.x, s.y, s.z,
			total.position.x, total.position.z,
			total.end.x, total.end.z,
		])


func _measure(packed: PackedScene) -> AABB:
	var aabbs: Array[AABB] = []
	_gather(packed.instantiate(), Transform3D(), aabbs)
	if aabbs.is_empty():
		return AABB()
	var total: AABB = aabbs[0]
	for i in range(1, aabbs.size()):
		total = total.merge(aabbs[i])
	return total


# Recursively collect each MeshInstance3D's local AABB, transformed by the
# accumulated relative transform. Does NOT require the node to be in the tree.
func _gather(node: Node3D, xform: Transform3D, out: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		out.append(xform * mi.get_aabb())
	for c in node.get_children():
		if c is Node3D:
			_gather(c as Node3D, xform * (c as Node3D).transform, out)
