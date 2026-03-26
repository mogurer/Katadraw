# =============================================================================
# DebugInputRecorder - テスト実行時の操作ログ（user:// に保存）
# =============================================================================

class_name DebugInputRecorder
extends RefCounted

var _lines: PackedStringArray = PackedStringArray()
var _last_move_sample: Vector2 = Vector2(-1e12, -1e12)
var _pad_last_over: bool = false
var _rng_seed: int = 0


func start_recording(seed_val: int, point_positions: Array[Vector2]) -> void:
	_rng_seed = seed_val
	_lines.clear()
	_lines.append("kata_draw_debug_log v1")
	_lines.append("rng_seed=" + str(seed_val))
	_lines.append("--- initial_points ---")
	for i in range(point_positions.size()):
		var p: Vector2 = point_positions[i]
		_lines.append("p%d %f %f" % [i, p.x, p.y])
	_lines.append("--- events ---")


func record_event(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_lines.append("mouse_down %f %f" % [event.position.x, event.position.y])
		else:
			_lines.append("mouse_up %f %f" % [event.position.x, event.position.y])
	elif event is InputEventMouseMotion:
		var d: float = _last_move_sample.distance_to(event.position)
		if d > 8.0 or _last_move_sample.x < -1e11:
			_last_move_sample = event.position
			_lines.append("mm %f %f" % [event.position.x, event.position.y])


func record_pad_stick_if_needed() -> void:
	var lx: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var ly: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var v: Vector2 = Vector2(lx, ly)
	var over: bool = v.length() > 0.25
	if over != _pad_last_over:
		_pad_last_over = over
		if over:
			_lines.append("pad_ls %f %f" % [lx, ly])
	elif over and Engine.get_process_frames() % 6 == 0:
		_lines.append("pad_ls %f %f" % [lx, ly])


func save_to_user_file() -> String:
	DirAccess.make_dir_recursive_absolute("user://debug_input_logs")
	var fn: String = "session_%d.txt" % Time.get_ticks_msec()
	var path: String = "user://debug_input_logs/%s" % fn
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string("\n".join(_lines))
	return path
