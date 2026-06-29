# FollowCamera — smooth third-person chase camera.
# Lazily finds the player via the "player" group so the scene does not need a
# hard NodePath binding (order of _ready is not guaranteed).
extends Camera3D
class_name FollowCamera

@export_group("Framing")
@export var distance: float = 7.5       # behind the car
@export var height: float = 3.8         # above the car
@export var look_height: float = 1.2    # aim point height on the car
@export var look_ahead: float = 2.5     # aim point shifted along velocity

@export_group("Smoothing")
@export var position_smooth: float = 5.5
@export var rotation_smooth: float = 7.0

var _target: Node3D = null


func _ready() -> void:
	# Visual update between physics ticks for smoother motion.
	set_process(true)
	set_physics_process(false)


func _process(delta: float) -> void:
	if _target == null:
		var node: Node = get_tree().get_first_node_in_group("player")
		if node != null:
			_target = node as Node3D
	if _target == null:
		return

	var car_basis: Basis = _target.global_transform.basis
	var back: Vector3 = car_basis.z
	var up: Vector3 = car_basis.y

	var desired: Vector3 = _target.global_position + back * distance + up * height
	var pt: float = _exp_t(position_smooth, delta)
	global_position = global_position.lerp(desired, pt)

	var aim_fwd: Vector3 = -car_basis.z
	if _target is CharacterBody3D:
		var vel: Vector3 = (_target as CharacterBody3D).velocity
		vel.y = 0.0
		if vel.length_squared() > 1.0:
			aim_fwd = vel.normalized()
	var aim: Vector3 = _target.global_position + Vector3.UP * look_height + aim_fwd * look_ahead
	var look_tf: Transform3D = global_transform.looking_at(aim, Vector3.UP)
	var rt: float = _exp_t(rotation_smooth, delta)
	global_basis = global_basis.slerp(look_tf.basis, rt)


func _exp_t(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)
