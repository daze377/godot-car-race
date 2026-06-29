# World V2 — real curved race track built from a Catmull-Rom centerline.
# Control points define a closed loop with straights, S-curves and a hairpin.
# Road surface (roadStraightLong) is laid along the baked centerline, fanning
# around corners to form a real track (not a rectangle). Barriers line both
# sides. The baked centerline is exposed for AI cars to follow.
extends Node3D
class_name World

@export_group("Track")
@export var road_half: float = 2.3       # corridor half-width
@export var surface_step: float = 1.7    # road block spacing (block is 2m, slight overlap)
@export var samples_per_seg: int = 16    # Catmull-Rom samples per control segment

# Control points (top-down X-Z, Y=0) — a closed loop with varied corners.
var WAYPOINTS := PackedVector3Array([
	Vector3(0.0, 0.0, 35.0),    # 0 start/finish straight
	Vector3(28.0, 0.0, 35.0),   # 1 long straight
	Vector3(38.0, 0.0, 25.0),   # 2 right hander
	Vector3(38.0, 0.0, 8.0),    # 3 straight down
	Vector3(30.0, 0.0, -2.0),   # 4 corner
	Vector3(16.0, 0.0, -4.0),   # 5
	Vector3(10.0, 0.0, 4.0),    # 6 S-curve
	Vector3(4.0, 0.0, -4.0),    # 7
	Vector3(-6.0, 0.0, -8.0),   # 8 hairpin
	Vector3(-18.0, 0.0, -6.0),  # 9
	Vector3(-30.0, 0.0, 2.0),   # 10 corner
	Vector3(-32.0, 0.0, 18.0),  # 11 straight up
	Vector3(-22.0, 0.0, 30.0),  # 12 corner
	Vector3(-10.0, 0.0, 35.0),  # 13 back to start straight
])

# models
const ROAD := preload("res://assets/kenney_racing-kit/Models/GLTF format/roadStraightLong.glb")
const BARRIER := preload("res://assets/kenney_racing-kit/Models/GLTF format/barrierWall.glb")
const FLAG := preload("res://assets/kenney_racing-kit/Models/GLTF format/flagCheckers.glb")
const STAND := preload("res://assets/kenney_racing-kit/Models/GLTF format/grandStand.glb")
const TREE := preload("res://assets/kenney_racing-kit/Models/GLTF format/treeLarge.glb")

# roadStraightLong geometric center at local (0.15, ~0, -1.65); barrierWall at (0.5, ~0, -0.06).
const OFFSET_ROAD := Vector3(-0.15, 0.0, 1.65)
const OFFSET_BARRIER := Vector3(-0.5, 0.0, 0.06)

# Exposed to main.gd (player spawn) and AI cars (waypoints).
var start_origin: Vector3
var start_yaw: float
var centerline: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	centerline = _bake_centerline(WAYPOINTS, samples_per_seg)
	var tangent := _tangent_at(0)
	start_origin = centerline[0] + Vector3(0.0, 0.6, 0.0)
	start_yaw = atan2(-tangent.x, -tangent.z)
	_build_surface()
	_build_collisions()
	_build_barriers()
	_build_start_finish()
	_build_decor()


func _bake_centerline(cps: PackedVector3Array, per: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := cps.size()
	for i in n:
		var p0: Vector3 = cps[(i - 1 + n) % n]
		var p1: Vector3 = cps[i]
		var p2: Vector3 = cps[(i + 1) % n]
		var p3: Vector3 = cps[(i + 2) % n]
		for s in per:
			var t: float = float(s) / float(per)
			out.append(_catmull_rom(p0, p1, p2, p3, t))
	return out


func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _tangent_at(index: int) -> Vector3:
	var n := centerline.size()
	var a: Vector3 = centerline[index % n]
	var b: Vector3 = centerline[(index + 1) % n]
	return (b - a).normalized()


# Lay road blocks by accumulated arc length so spacing is even through corners.
func _build_surface() -> void:
	var n := centerline.size()
	var acc: float = 0.0
	var next_at: float = 0.0
	for i in n:
		var p: Vector3 = centerline[i]
		var pn: Vector3 = centerline[(i + 1) % n]
		if acc >= next_at:
			var tangent: Vector3 = (pn - p).normalized()
			_place(ROAD, Vector3(p.x, 0.0, p.z), tangent, OFFSET_ROAD, false)
			next_at = acc + surface_step
		acc += p.distance_to(pn)


func _build_barriers() -> void:
	var n := centerline.size()
	# Every few samples to keep barrier count reasonable.
	var stride: int = max(1, int(n / 90.0))
	for i in range(0, n, stride):
		var p: Vector3 = centerline[i]
		var pn: Vector3 = centerline[(i + 1) % n]
		var tangent: Vector3 = (pn - p).normalized()
		var normal: Vector3 = Vector3(tangent.z, 0.0, -tangent.x)
		_place(BARRIER, p + normal * road_half, tangent, OFFSET_BARRIER, true)
		_place(BARRIER, p - normal * road_half, tangent, OFFSET_BARRIER, true)


# Invisible collision walls along both sides of the track (GLB barriers have no
# collision). Keeps cars inside the corridor through every corner.
func _build_collisions() -> void:
	var n := centerline.size()
	var stride: int = max(1, int(n / 60.0))
	for i in range(0, n, stride):
		var p: Vector3 = centerline[i]
		var pn: Vector3 = centerline[(i + 1) % n]
		var tangent: Vector3 = (pn - p).normalized()
		var normal: Vector3 = Vector3(tangent.z, 0.0, -tangent.x)
		_wall(p + normal * road_half, tangent)
		_wall(p - normal * road_half, tangent)


func _wall(pos: Vector3, tangent: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 1.2, 3.0)  # thin, low, long-along-Z
	col.shape = shape
	col.position = Vector3(0.0, 0.6, 0.0)
	body.add_child(col)
	body.position = pos
	body.basis = Basis.looking_at(tangent, Vector3.UP)
	add_child(body)


func _build_start_finish() -> void:
	# Finish-line trigger (group "lap_finish"); only the player is counted.
	var area := Area3D.new()
	area.add_to_group("lap_finish")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(road_half * 2.0, 3.0, 1.2)
	col.shape = shape
	col.position = Vector3(0.0, 1.5, 0.0)
	area.add_child(col)
	area.position = start_origin
	area.rotate_y(start_yaw)
	add_child(area)

	# Checker flags flanking the line.
	var tangent := _tangent_at(0)
	var normal := Vector3(tangent.z, 0.0, -tangent.x)
	_place(FLAG, start_origin + normal * (road_half + 0.5), tangent, Vector3.ZERO, false)
	_place(FLAG, start_origin - normal * (road_half + 0.5), tangent, Vector3.ZERO, false)


func _build_decor() -> void:
	# Grandstands beside the main straight, facing the track.
	_place(STAND, Vector3(10.0, 0.0, 42.0), Vector3(0.0, 0.0, -1.0), Vector3.ZERO, false)
	_place(STAND, Vector3(-10.0, 0.0, 42.0), Vector3(0.0, 0.0, -1.0), Vector3.ZERO, false)
	# Trees scattered in the infield / runoff.
	for tp in [Vector3(0.0, 0.0, 15.0), Vector3(18.0, 0.0, 18.0), Vector3(-15.0, 0.0, 12.0), Vector3(20.0, 0.0, -20.0), Vector3(-25.0, 0.0, -20.0)]:
		_place(TREE, tp, Vector3(1.0, 0.0, 0.0), Vector3.ZERO, false)


# Place a GLB at world_pos. align_x=false: -Z faces forward (road blocks).
# align_x=true: +X faces forward (barrierWall, whose long edge is along X).
func _place(scene: PackedScene, world_pos: Vector3, forward: Vector3, center_offset: Vector3, align_x: bool) -> Node3D:
	var node := Node3D.new()
	var model: Node3D = scene.instantiate()
	model.position = center_offset
	node.add_child(model)
	node.position = world_pos
	if align_x:
		node.rotate_y(atan2(-forward.z, forward.x))
	else:
		node.basis = Basis.looking_at(forward, Vector3.UP)
	add_child(node)
	return node
