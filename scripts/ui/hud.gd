# HUD — speedometer, lap counter, timers. Reads the player and lap system via
# their groups so no hard NodePath wiring is needed.
extends CanvasLayer

var _player: PlayerCar = null
var _lap: LapSystem = null

var _speed_label: Label
var _lap_label: Label
var _time_label: Label
var _best_label: Label
var _msg_label: Label


func _ready() -> void:
	_speed_label = _make_label(Vector2(24.0, 20.0), 30)
	_lap_label = _make_label(Vector2(24.0, 60.0), 24)
	_time_label = _make_label(Vector2(24.0, 92.0), 22)
	_best_label = _make_label(Vector2(24.0, 120.0), 20)
	_msg_label = _make_label(Vector2(380.0, 30.0), 36)


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerCar
	if _lap == null:
		_lap = get_tree().get_first_node_in_group("lap_system") as LapSystem

	if _player != null:
		_speed_label.text = "%d km/h" % int(round(_player.speed_kmh))

	if _lap != null:
		_lap_label.text = "LAP %d / %d" % [_lap.current_lap, _lap.target_laps]
		_time_label.text = "TIME  %.1f s" % _lap.race_time
		if is_inf(_lap.best_lap_time):
			_best_label.text = "BEST  --"
		else:
			_best_label.text = "BEST  %.1f s" % _lap.best_lap_time
		if _lap.finished:
			_msg_label.text = "FINISH!  %.1f s" % _lap.race_time
		elif not _lap.race_started:
			_msg_label.text = "GO!"


func _make_label(pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label
