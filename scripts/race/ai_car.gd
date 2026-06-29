# AICar — opponent vehicle that follows the track centerline (waypoints).
# Simplified kinematic physics (no drift) so AI stays stable and on-track.
# Steers toward the next waypoint and eases off in corners.
extends CharacterBody3D
class_name AICar

@export var max_speed: float = 20.0      # m/s on straights
@export var corner_speed: float = 11.0   # m/s when steering hard
@export var turn_rate: float = 2.8       # max yaw rate (rad/s)
@export var accel_rate: float = 3.0      # throttle response
@export var gravity: float = 26.0
@export var wp_reach: float = 5.0        # distance to consider a waypoint reached
@export var lane_offset: float = 0.0     # lateral shift from centerline (m), set by main
@export var look_ahead_wp: int = 3       # steer toward waypoint this far ahead

# Set by main.gd before the first physics frame.
var centerline: PackedVector3Array = PackedVector3Array()
var speed_kmh: float = 0.0
var laps: int = 0

var _wp: int = 0
var _crossed_half: bool = false
var _stuck_frames: int = 0

const _AVOID_RANGE := 14.0
const _STUCK_SPEED := 1.5
const _STUCK_SKIP_FRAMES := 30


func _physics_process(delta: float) -> void:
	if centerline.is_empty():
		move_and_slide()
		return

	_advance_wp()
	var n := centerline.size()
	var target: Vector3 = _lane_target((_wp + look_ahead_wp) % n)
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0

	# Steer toward the target waypoint (rate-limited).
	var desired_yaw: float = atan2(-to_target.x, -to_target.z)
	var diff: float = angle_difference(global_rotation.y, desired_yaw)
	var max_turn: float = turn_rate * delta
	rotate_y(clampf(diff, -max_turn, max_turn))

	# Ease off the throttle when the car still needs to turn a lot.
	var fwd: Vector3 = forward_dir()
	var target_speed: float = corner_speed if absf(diff) > 0.35 else max_speed
	target_speed = minf(target_speed, _traffic_speed_cap())
	var speed: float = velocity.dot(fwd)
	speed = lerpf(speed, target_speed, accel_rate * delta)
	velocity = fwd * speed

	if absf(speed) < _STUCK_SPEED:
		_stuck_frames += 1
	else:
		_stuck_frames = 0
	if _stuck_frames >= _STUCK_SKIP_FRAMES:
		_wp += 2
		_stuck_frames = 0
		var unstick: Vector3 = _lane_target(_wp % n) - global_position
		unstick.y = 0.0
		if unstick.length_squared() > 0.01:
			position += unstick.normalized() * 0.8

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()
	speed_kmh = absf(speed) * 3.6


func _ready() -> void:
	add_to_group("ai_car")
	# AI pass through each other; lane logic + avoidance handle spacing.
	collision_layer = 2
	collision_mask = 1


func forward_dir() -> Vector3:
	return -global_transform.basis.z.normalized()


# World position for a centerline sample shifted into this car's racing lane.
func _lane_target(wp_index: int) -> Vector3:
	var n := centerline.size()
	var p: Vector3 = centerline[wp_index % n]
	if absf(lane_offset) < 0.01:
		return p
	var pn: Vector3 = centerline[(wp_index + 1) % n]
	var tangent: Vector3 = pn - p
	tangent.y = 0.0
	if tangent.length_squared() < 0.0001:
		return p
	tangent = tangent.normalized()
	var normal: Vector3 = Vector3(tangent.z, 0.0, -tangent.x)
	return p + normal * lane_offset


# Slow down when another car is directly ahead in our lane cone.
func _traffic_speed_cap() -> float:
	var cap: float = max_speed
	var fwd: Vector3 = forward_dir()
	for node in get_tree().get_nodes_in_group("ai_car"):
		if node == self:
			continue
		cap = minf(cap, _approach_cap(node as Node3D, fwd))
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		cap = minf(cap, _approach_cap(player as Node3D, fwd))
	return cap


func _approach_cap(other: Node3D, fwd: Vector3) -> float:
	if other == null:
		return max_speed
	var to_other: Vector3 = other.global_position - global_position
	to_other.y = 0.0
	var dist: float = to_other.length()
	if dist < 0.1 or dist > _AVOID_RANGE:
		return max_speed
	var to_norm: Vector3 = to_other / dist
	if fwd.dot(to_norm) < 0.55:
		return max_speed
	# Only brake for cars sharing our corridor (ignore parallel lanes).
	var right: Vector3 = Vector3(fwd.z, 0.0, -fwd.x)
	var lateral: float = absf(right.dot(to_other))
	var lane_other: float = 0.0
	if other is AICar:
		lane_other = (other as AICar).lane_offset
	var lane_gap: float = absf(lane_offset - lane_other)
	if lateral > 1.2 and lane_gap > 0.6:
		return max_speed
	# Match speed to gap — tighter gap, slower cap (down to ~corner_speed).
	var t: float = clampf(dist / (_AVOID_RANGE * 0.65), 0.25, 1.0)
	return lerpf(corner_speed * 0.35, max_speed, t)


# Advance through waypoints that have been passed/reached.
func _advance_wp() -> void:
	var n := centerline.size()
	for _k in 12:
		var wp: Vector3 = _lane_target(_wp % n)
		var d: float = global_position.distance_to(Vector3(wp.x, global_position.y, wp.z))
		if d < wp_reach:
			_wp += 1
		else:
			break
	# Crude lap counter: passed the halfway point then wrapped back to start.
	var idx := _wp % n
	if idx > int(n / 2.0):
		_crossed_half = true
	elif idx < 3 and _crossed_half:
		laps += 1
		_crossed_half = false


func reset_to(pos: Vector3, yaw: float) -> void:
	position = pos
	rotation = Vector3.ZERO
	rotate_y(yaw)
	velocity = Vector3.ZERO
	_stuck_frames = 0
