# PlayerCar — arcade-style racing vehicle using a kinematic CharacterBody3D.
# Rationale (see docs/design.md §3): CharacterBody3D avoids the tip-over and
# tuning headaches of RigidBody3D while giving precise, predictable control.
extends CharacterBody3D
class_name PlayerCar

# ---- Engine tuning ----
@export_group("Engine")
@export var max_speed: float = 28.0          # m/s (~100 km/h)
@export var accel: float = 14.0              # m/s^2
@export var brake_force: float = 22.0        # m/s^2
@export var reverse_speed: float = 9.0       # m/s
@export var coast_drag: float = 0.75         # natural slow-down (m/s per s)

# ---- Steering tuning ----
@export_group("Steering")
@export var max_steer_rate: float = 2.4      # rad/s at full lock
@export var steer_speed_scale: float = 11.0  # speed (m/s) at which steering reaches full rate
@export var min_steer_factor: float = 0.42   # steering authority when barely moving
@export var invert_steer: bool = false       # flip if model faces the "wrong" way
@export var mouse_steer: bool = true         # steer toward mouse cursor on the track
@export var mouse_steer_angle: float = 50.0  # degrees off-heading for full lock
@export var mouse_steer_smooth: float = 9.0  # filter mouse target (higher = snappier)
@export var steer_input_smooth: float = 14.0 # filter combined steer input

# ---- Physics tuning ----
@export_group("Physics")
@export var gravity: float = 26.0
@export var lateral_grip: float = 3.8        # higher = less drift (grippy)

# ---- Read-only state (consumed by HUD) ----
var speed_kmh: float = 0.0

var _steer: float = 0.0   # smoothed -1..1
var _throttle: float = 0.0  # smoothed -1..1
var _spawn_pos: Vector3 = Vector3.ZERO
var _spawn_yaw: float = 0.0
var _has_spawn: bool = false
var _mouse_yaw_target: float = 0.0
var _mouse_yaw_init: bool = false


func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	_read_input(delta)
	# Steer before engine so velocity aligns with the new heading (less snap).
	_apply_steering(delta)
	_apply_engine(delta)
	_apply_gravity()
	move_and_slide()
	speed_kmh = abs(_forward_speed()) * 3.6


func forward_dir() -> Vector3:
	return -global_transform.basis.z.normalized()


func _forward_speed() -> float:
	return velocity.dot(forward_dir())


func _read_input(delta: float) -> void:
	var target_throttle := 0.0
	if Input.is_action_pressed("accelerate"):
		target_throttle += 1.0
	if Input.is_action_pressed("brake"):
		target_throttle -= 1.0
	_throttle = lerpf(_throttle, target_throttle, _exp_t(9.0, delta))

	var kb_steer := 0.0
	if Input.is_action_pressed("steer_left"):
		kb_steer += 1.0
	if Input.is_action_pressed("steer_right"):
		kb_steer -= 1.0

	var target_steer := kb_steer
	if mouse_steer:
		target_steer = clampf(_mouse_steer_value(delta) + kb_steer, -1.0, 1.0)
	_steer = lerpf(_steer, target_steer, _exp_t(steer_input_smooth, delta))

	if Input.is_action_just_pressed("reset_car"):
		_mouse_yaw_init = false
		if _has_spawn:
			reset_to(_spawn_pos, _spawn_yaw)
		else:
			reset_to(global_position + Vector3.UP, global_rotation.y)


# Raycast mouse → ground, then heavily smooth the target yaw to avoid chase-cam jitter.
func _mouse_steer_value(delta: float) -> float:
	var raw_yaw: float = _mouse_yaw_from_ray()
	if raw_yaw == INF:
		return _steer

	if not _mouse_yaw_init:
		_mouse_yaw_target = raw_yaw
		_mouse_yaw_init = true
	else:
		var yaw_step: float = angle_difference(_mouse_yaw_target, raw_yaw)
		_mouse_yaw_target += yaw_step * _exp_t(mouse_steer_smooth, delta)

	var diff: float = angle_difference(global_rotation.y, _mouse_yaw_target)
	var full_lock: float = deg_to_rad(maxf(mouse_steer_angle, 8.0))
	if absf(diff) < deg_to_rad(2.5):
		return 0.0
	return clampf(diff / full_lock, -1.0, 1.0)


func _mouse_yaw_from_ray() -> float:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return INF
	var cam: Camera3D = viewport.get_camera_3d()
	if cam == null:
		return INF

	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var ray_origin: Vector3 = cam.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = cam.project_ray_normal(mouse_pos)
	if absf(ray_dir.y) < 0.0001:
		return INF

	var plane_y: float = global_position.y
	var t: float = (plane_y - ray_origin.y) / ray_dir.y
	if t < 0.0:
		return INF

	var hit: Vector3 = ray_origin + ray_dir * t
	var to_hit: Vector3 = hit - global_position
	to_hit.y = 0.0
	if to_hit.length_squared() < 1.0:
		return INF

	return atan2(-to_hit.x, -to_hit.z)


func _apply_engine(delta: float) -> void:
	var fwd := forward_dir()
	var speed := _forward_speed()

	if _throttle > 0.01:
		speed += accel * _throttle * delta
		speed = clampf(speed, -reverse_speed, max_speed)
	elif _throttle < -0.01:
		if speed > 0.5:
			speed += brake_force * _throttle * delta
		else:
			speed += accel * _throttle * delta
			speed = maxf(speed, -reverse_speed)
	else:
		speed -= sign(speed) * coast_drag * delta
		if absf(speed) < 0.2:
			speed = 0.0

	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	var lateral := hvel - fwd * hvel.dot(fwd)
	var grip_factor: float = maxf(0.0, 1.0 - lateral_grip * delta)
	lateral *= grip_factor

	var new_h := fwd * speed + lateral
	velocity.x = new_h.x
	velocity.z = new_h.z


func _apply_steering(delta: float) -> void:
	var speed := _forward_speed()
	var speed_abs: float = absf(speed)
	var speed_factor: float = lerpf(min_steer_factor, 1.0, clampf(speed_abs / steer_speed_scale, 0.0, 1.0))
	var move_sign: float = sign(speed) if speed_abs > 0.3 else 1.0
	var dir: float = -1.0 if invert_steer else 1.0
	rotate_y(_steer * max_steer_rate * speed_factor * move_sign * dir * delta)


func _apply_gravity() -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * get_physics_process_delta_time()


func reset_to(pos: Vector3, yaw: float) -> void:
	_spawn_pos = pos
	_spawn_yaw = yaw
	_has_spawn = true
	position = pos
	rotation = Vector3.ZERO
	rotate_y(yaw)
	velocity = Vector3.ZERO
	_steer = 0.0
	_throttle = 0.0
	_mouse_yaw_init = false


func _exp_t(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)
