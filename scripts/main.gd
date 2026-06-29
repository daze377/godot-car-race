# Main — the entry scene. Composes the world, player, camera, and HUD.
# Builds environment/lighting/ground here; world.tscn and hud.tscn are loaded
# only if present, so the scene is runnable at every stage of development.
extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player_car.tscn")
const WORLD_SCENE_PATH := "res://scenes/world/world.tscn"
const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"
const LAP_SYSTEM_SCRIPT: GDScript = preload("res://scripts/race/lap_system.gd")
const AI_CAR_SCENE: PackedScene = preload("res://scenes/race/ai_car.tscn")
const AI_POLICE: PackedScene = preload("res://assets/kenney_car-kit/Models/GLB format/police.glb")
const AI_TAXI: PackedScene = preload("res://assets/kenney_car-kit/Models/GLB format/taxi.glb")
const AI_FIRETRUCK: PackedScene = preload("res://assets/kenney_car-kit/Models/GLB format/firetruck.glb")
const AI_SEDAN: PackedScene = preload("res://assets/kenney_car-kit/Models/GLB format/sedan-sports.glb")

const START_POS := Vector3(0.0, 0.6, 0.0)
const START_YAW := 0.0

# Dev tool: pass "screenshot" on the command line to capture docs/preview.png.
var _cap_delay := -1


func _ready() -> void:
	_setup_environment()
	_build_ground()

	var world: Node = null
	if ResourceLoader.exists(WORLD_SCENE_PATH):
		world = load(WORLD_SCENE_PATH).instantiate()
		add_child(world)

	var player := PLAYER_SCENE.instantiate() as PlayerCar
	add_child(player)
	var start_pos: Vector3 = START_POS
	var start_yaw: float = START_YAW
	if world != null and "start_origin" in world:
		start_pos = world.start_origin
		start_yaw = world.start_yaw
	player.reset_to(start_pos, start_yaw)

	if world != null and "centerline" in world:
		_spawn_ai(world)

	var cam := FollowCamera.new()
	add_child(cam)
	cam.current = true

	var lap_system := LAP_SYSTEM_SCRIPT.new() as Node
	add_child(lap_system)

	if ResourceLoader.exists(HUD_SCENE_PATH):
		add_child(load(HUD_SCENE_PATH).instantiate())

	if "screenshot" in OS.get_cmdline_args():
		_cap_delay = 60


func _process(_delta: float) -> void:
	if _cap_delay > 0:
		_cap_delay -= 1
		if _cap_delay == 0:
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png("res://docs/preview.png")
			print("SHOT_SAVED")
			get_tree().quit()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.82, 0.92)
	env.fog_light_energy = 0.25
	env.fog_density = 0.001

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"

	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.17, 0.2, 0.15)
	mat.roughness = 1.0
	plane.material = mat
	mi.mesh = plane
	ground.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := WorldBoundaryShape3D.new()
	col.shape = shape
	ground.add_child(col)

	add_child(ground)


# Spawn AI opponents on the grid behind/ahead of the player, in different lanes.
func _spawn_ai(world: Node) -> void:
	var cl_v: Variant = world.get("centerline")
	if cl_v == null:
		return
	var cl: PackedVector3Array = cl_v
	if cl.size() < 8:
		return

	var t0: Vector3 = cl[1] - cl[0]
	t0.y = 0.0
	t0 = t0.normalized()
	var normal: Vector3 = Vector3(t0.z, 0.0, -t0.x)
	var yaw: float = atan2(-t0.x, -t0.z)
	var grid_origin: Vector3 = world.start_origin

	# model / top speed / forward offset / lateral lane / starting waypoint
	var configs := [
		{"model": AI_POLICE, "speed": 19.0, "fwd": 2.0, "lane": -1.0, "wp": 3},
		{"model": AI_TAXI, "speed": 20.0, "fwd": 7.0, "lane": 1.0, "wp": 6},
		{"model": AI_SEDAN, "speed": 21.0, "fwd": 12.0, "lane": -0.35, "wp": 9},
		{"model": AI_FIRETRUCK, "speed": 18.0, "fwd": 17.0, "lane": 0.35, "wp": 12},
	]

	for cfg in configs:
		var ai := AI_CAR_SCENE.instantiate() as AICar
		add_child(ai)
		var fwd_off: float = cfg["fwd"]
		var lane: float = cfg["lane"]
		var spawn: Vector3 = grid_origin + t0 * fwd_off + normal * lane
		ai.centerline = cl
		ai.lane_offset = lane
		ai._wp = cfg["wp"]
		ai.max_speed = cfg["speed"]
		ai.reset_to(spawn, yaw)
		var model_scene: PackedScene = cfg["model"]
		var model: Node3D = model_scene.instantiate()
		ai.add_child(model)
