# LapSystem — counts laps via the finish-line Area3D (group "lap_finish").
# State machine handles the start (player spawns on the line) and each crossing.
extends Node
class_name LapSystem

signal lap_completed(lap: int, lap_time: float)
signal race_finished(total_time: float, best_lap: float)

@export var target_laps: int = 3

var current_lap: int = 0
var race_time: float = 0.0
var last_lap_time: float = 0.0
var best_lap_time: float = INF
var finished: bool = false

var _started: bool = false
var _left_start: bool = false
var _lap_start_time: float = 0.0

var race_started: bool:
	get:
		return _started


func _ready() -> void:
	add_to_group("lap_system")
	# The world builds its finish Area3D in _ready; connect one frame later.
	await get_tree().process_frame
	for node in get_tree().get_nodes_in_group("lap_finish"):
		var area := node as Area3D
		if area != null:
			area.body_entered.connect(_on_finish_entered)
			area.body_exited.connect(_on_finish_exited)


func _process(delta: float) -> void:
	if _started and not finished:
		race_time += delta


func _on_finish_exited(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		_left_start = true


func _on_finish_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return

	# First contact while still sitting on the line = race start.
	if not _left_start:
		if not _started:
			_started = true
			race_time = 0.0
			_lap_start_time = 0.0
		return

	if finished:
		return

	# Crossed the line after having left -> a lap is complete.
	last_lap_time = race_time - _lap_start_time
	if last_lap_time < best_lap_time:
		best_lap_time = last_lap_time
	_lap_start_time = race_time
	current_lap += 1
	lap_completed.emit(current_lap, last_lap_time)

	if current_lap >= target_laps:
		finished = true
		race_finished.emit(race_time, best_lap_time)
