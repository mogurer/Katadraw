# =============================================================================
# InputHandler - input handling module
# =============================================================================
# Handles mouse, gamepad, dragging, rectangle selection, and bounding boxes.
# Updates game state such as point_positions and selected_indices directly.

class_name InputHandler
extends RefCounted

# --- Constants ---
const HOVER_DISTANCE := 30.0
const CLICK_HIT_DISTANCE := 30.0  # Click only hits points directly.
const BB_ANCHOR_SIZE := 10.0
const BB_ANCHOR_HIT := 16.0
const BB_CENTER_SIZE := 9.0
const PAD_CURSOR_SPEED := 600.0
const PAD_RIGHT_STICK_SPEED := 400.0
const PAD_A_DPAD_SPEED := 200.00
const PAD_LEFT_STICK_SPEED_EXPONENT := 4.0
const PAD_RIGHT_STICK_DEADZONE := 0.5
const RIGHT_STICK_REDETECT_ANGLE_DEG := 5.0
const RIGHT_STICK_RAY_PIN_BREAK_ANGLE_DEG := 15.0
const RIGHT_STICK_RAY_SHOULDER_CONE_HALF_ANGLE_DEG := 22.0
const RIGHT_STICK_RAY_SHOULDER_MIN_PERP_PX := 4.0
const PAD_LEFT_STICK_NEUTRAL_DEADZONE := 0.15
const DEBUG_PAD_RAY_LR := false
const DRAG_CURSOR_SPRING := 52.0
const DRAG_CURSOR_DAMPING := 14.0
const DRAG_FOLLOW_SPRING := 20.0
const DRAG_FOLLOW_DAMPING := 9.0
const DRAG_FOLLOW_SPEED_MIN := 1.0
const DRAG_FOLLOW_SPEED_MAX := 30.0
const DRAG_FOLLOW_MIN_FACTOR := 0.05
const DRAG_ANGLE_SPRING := 34.0
const DRAG_ANGLE_DAMPING := 8.0
const DRAG_VELOCITY_DAMPING := 4.6
const DRAG_MAX_INFLUENCE_RATIO := 0.35
const DRAG_STOP_SPEED := 8.0
const DRAG_STEP_MAX := 1.0 / 120.0
const DRAG_POSITION_EPSILON := 0.01
const GUIDE_EDGE_SNAP_RADIUS := 26.0
const GUIDE_VERTEX_SNAP_RADIUS := 16.0
const GUIDE_EDGE_SPRING := 9.0
const GUIDE_VERTEX_SPRING := 22.0
const GUIDE_SNAP_DAMPING := 4.8
const GUIDE_VERTEX_LOCK_RADIUS := 7.0
const GUIDE_VERTEX_LOCK_SPRING := 220.0
const GUIDE_VERTEX_LOCK_DAMPING := 30.0
const GUIDE_VERTEX_CONTACT_RELEASE_MUL := 0.35
const PLAYER_RADIUS := 16.0
const PLAYER_FORCE_RADIUS := 128.0
const PLAYER_MOVE_SPEED := 320.0
const PLAYER_DPAD_SPEED := 220.0
const PLAYER_SPEED_BOOST_PER_BUTTON := 0.35
const PLAYER_REPEL_STRENGTH := 6400.0
const PLAYER_ATTRACT_STRENGTH := 5600.0
const PLAYER_CONTACT_FORCE := 9000.0
const PLAYER_MIN_FORCE_DISTANCE := 8.0
const POINT_PAIR_REPULSE_DISTANCE := 32.0
const POINT_PAIR_REPULSE_STRENGTH := 2600.0
const POINT_PAIR_REPULSE_MIN_DISTANCE := 2.0

# --- Callbacks set by game ---
var on_points_changed: Callable
var on_selection_changed: Callable

# --- Temporary interaction state ---
var drag_offsets: Array[Vector2] = []
var point_velocities: Array[Vector2] = []
var drag_target_active: bool = false
var drag_target_position: Vector2 = Vector2.ZERO
var drag_target_offset: Vector2 = Vector2.ZERO
var drag_point_idx: int = -1
var drag_start_positions: Array[Vector2] = []
var drag_influence_weights: Array[float] = []
var drag_angle_prev_idx: int = -1
var drag_angle_next_idx: int = -1
var drag_angle_reference: float = 0.0
var point_stop_frames: Array[int] = []
var bb_dragging: bool = false
var bb_anchor_idx: int = -1
var bb_origin: Vector2 = Vector2.ZERO
var bb_start_mouse: Vector2 = Vector2.ZERO
var bb_start_positions: Array[Vector2] = []
var bb_start_rect: Rect2 = Rect2()
var pad_cursor: Vector2 = Vector2.ZERO
var pad_cursor_initialized: bool = false
var pad_grabbing: bool = false
var _grabbing_from_right_stick: bool = false
var _right_stick_was_active: bool = false
var _right_stick_release_frames: int = 0
var _right_stick_dir_when_fixed: Vector2 = Vector2.ZERO
var _left_stick_used_while_right_held: bool = false
var _left_stick_was_neutral: bool = true
var _right_stick_ray_pinned: bool = false
var _right_stick_locked_ray_dir: Vector2 = Vector2.ZERO
var _right_stick_last_effective_ray_dir: Vector2 = Vector2.ZERO
var _right_stick_ray_bundle: Array[int] = []
var _rs_kata_grab_lock: bool = false
var _rs_kata_grab_lock_ref_dir: Vector2 = Vector2.ZERO
var _rs_lr_selection_lock: bool = false
var _rs_lr_lock_ref_dir: Vector2 = Vector2.ZERO
var _prev_shoulder_l_pressed: bool = false
var _prev_shoulder_r_pressed: bool = false
var _right_stick_ray_auto_select_done: bool = false
var _last_rs_phys_dir_at_auto_select: Vector2 = Vector2.ZERO

# Whether grab-capable input is currently active.
var grab_input_active: bool = false

# Right stick debug rendering.
var debug_right_stick_active: bool = false
var debug_right_stick_center: Vector2 = Vector2.ZERO
var debug_right_stick_direction: Vector2 = Vector2.ZERO
var _last_input_method: String = ""
var player_position: Vector2 = Vector2.ZERO
var player_position_initialized: bool = false
var player_force_attracting: bool = false
var player_force_repelling: bool = false
var player_has_motion_input: bool = false
var player_force_active: bool = false
var player_influenced_point_count: int = 0
var mouse_force_pressed: bool = false

# --- game reference ---
var _game: Node2D


func _init(game: Node2D) -> void:
	_game = game


func _log_pad_ray_lr(msg: String) -> void:
	if DEBUG_PAD_RAY_LR:
		print("[PadRayLR] ", Time.get_ticks_msec(), " ", msg)


func is_bb_dragging() -> bool:
	return bb_dragging


func is_pad_grabbing_modifier_now() -> bool:
	if _game.game_state != "playing" and _game.game_state != "rules":
		return false
	return player_force_attracting or player_force_repelling or player_force_active


func update_grab_state_for_mouse() -> void:
	"""Update interaction state for mouse-driven player control."""
	grab_input_active = mouse_force_pressed or player_force_active


func release_mouse_grab() -> void:
	"""Force-release the mouse-driven attract state."""
	_game.is_dragging = false
	_game.selected_indices.clear()
	_game.hovered_index = -1
	drag_offsets.clear()
	_end_active_drag(true)
	mouse_force_pressed = false
	player_force_attracting = false
	player_force_repelling = false
	pad_grabbing = false
	_grabbing_from_right_stick = false
	_clear_right_stick_ray_state()
	_game.queue_redraw()


func reset_for_stage() -> void:

	drag_offsets.clear()
	_end_active_drag(true)
	_ensure_drag_state_arrays()
	bb_dragging = false
	bb_anchor_idx = -1
	bb_start_positions.clear()
	pad_grabbing = false
	pad_cursor_initialized = false
	_grabbing_from_right_stick = false
	_right_stick_was_active = false
	_right_stick_release_frames = 0
	_right_stick_dir_when_fixed = Vector2.ZERO
	_left_stick_used_while_right_held = false
	_left_stick_was_neutral = true
	_clear_right_stick_ray_state()
	debug_right_stick_active = false
	grab_input_active = false
	_last_input_method = ""
	_prev_shoulder_l_pressed = false
	_prev_shoulder_r_pressed = false
	player_position_initialized = false
	player_force_attracting = false
	player_force_repelling = false
	player_has_motion_input = false
	player_force_active = false
	player_influenced_point_count = 0
	mouse_force_pressed = false
	_reset_player_position()


func _reset_player_position() -> void:
	player_position = _default_player_position()
	player_position_initialized = true


func _default_player_position() -> Vector2:
	if _game.point_positions.is_empty():
		return _game.shape_center
	var spawn_offset_y: float = maxf(_game.guide_radius_val, 96.0) + PLAYER_FORCE_RADIUS + 24.0
	var spawn_pos: Vector2 = _game.shape_center + Vector2(0.0, spawn_offset_y)
	var vp: Vector2 = _game.get_viewport_rect().size
	var margin: float = PLAYER_RADIUS
	return spawn_pos.clamp(Vector2(margin, margin), Vector2(vp.x - margin, vp.y - margin))


func _refresh_hovered_point() -> void:
	_game.hovered_index = get_player_focus_index(HOVER_DISTANCE)


func handle_mouse_motion(mouse: Vector2) -> void:
	if bb_dragging:
		_handle_bb_motion(mouse)
		return
	player_position = mouse
	player_position_initialized = true
	player_has_motion_input = false
	_last_input_method = "mouse"
	_refresh_hovered_point()
	_game.queue_redraw()


func handle_mouse_press(mouse: Vector2) -> void:
	_last_input_method = "mouse"
	player_position = mouse
	player_position_initialized = true
	mouse_force_pressed = true
	player_force_attracting = true
	player_force_repelling = false
	grab_input_active = true
	_game.is_dragging = false
	_game.queue_redraw()


func _begin_drag(mouse: Vector2) -> void:
	_game.is_dragging = true
	drag_offsets.clear()
	for idx in _game.selected_indices:
		drag_offsets.append(_game.point_positions[idx] - mouse)
	if _game.selected_indices.size() == 1 and drag_offsets.size() == 1:
		_begin_point_drag(_game.selected_indices[0], mouse + drag_offsets[0], "mouse")


func handle_mouse_release(_mouse: Vector2) -> void:
	_last_input_method = "mouse"
	if bb_dragging:
		_end_bb_drag()
		return

	mouse_force_pressed = false
	player_force_attracting = false
	player_force_repelling = false
	grab_input_active = player_force_active
	_game.is_dragging = false
	_game.queue_redraw()


func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.001:
		return a
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t


# =============================================================================
# Bounding Box
# =============================================================================

func get_bb_rect() -> Rect2:
	if _game.selected_indices.size() < 2:
		return Rect2()
	var min_p: Vector2 = _game.point_positions[_game.selected_indices[0]]
	var max_p: Vector2 = min_p
	for i in range(1, _game.selected_indices.size()):
		var pt: Vector2 = _game.point_positions[_game.selected_indices[i]]
		min_p.x = minf(min_p.x, pt.x)
		min_p.y = minf(min_p.y, pt.y)
		max_p.x = maxf(max_p.x, pt.x)
		max_p.y = maxf(max_p.y, pt.y)
	return Rect2(min_p, max_p - min_p)


func get_bb_anchors(r: Rect2) -> Array[Vector2]:
	var tl: Vector2 = r.position
	var br: Vector2 = r.position + r.size
	var tc: Vector2 = Vector2((tl.x + br.x) * 0.5, tl.y)
	var bc: Vector2 = Vector2((tl.x + br.x) * 0.5, br.y)
	var ml: Vector2 = Vector2(tl.x, (tl.y + br.y) * 0.5)
	var mr: Vector2 = Vector2(br.x, (tl.y + br.y) * 0.5)
	var tr: Vector2 = Vector2(br.x, tl.y)
	var bl: Vector2 = Vector2(tl.x, br.y)
	return [tl, tc, tr, ml, mr, bl, bc, br]


func _get_bb_opposite(idx: int) -> int:
	match idx:
		0: return 7
		1: return 6
		2: return 5
		3: return 4
		4: return 3
		5: return 2
		6: return 1
		7: return 0
	return -1


func _hit_bb_anchor(mouse: Vector2) -> int:
	if _game.selected_indices.size() < 2:
		return -1
	var r: Rect2 = get_bb_rect()
	if r.size.x < 1.0 and r.size.y < 1.0:
		return -1
	var center: Vector2 = r.position + r.size * 0.5
	if mouse.distance_to(center) <= BB_ANCHOR_HIT:
		return 8
	var anchors: Array[Vector2] = get_bb_anchors(r)
	for i in range(anchors.size()):
		if mouse.distance_to(anchors[i]) <= BB_ANCHOR_HIT:
			return i
	return -1


func _begin_bb_drag(anchor_idx: int, mouse: Vector2) -> void:
	_end_active_drag(true)
	bb_dragging = true
	bb_anchor_idx = anchor_idx
	bb_start_mouse = mouse
	bb_start_rect = get_bb_rect()
	if anchor_idx < 8:
		var anchors: Array[Vector2] = get_bb_anchors(bb_start_rect)
		bb_origin = anchors[_get_bb_opposite(anchor_idx)]
	bb_start_positions.clear()
	for idx in _game.selected_indices:
		bb_start_positions.append(_game.point_positions[idx])


func _handle_bb_motion(mouse: Vector2) -> void:
	if not bb_dragging:
		return

	if bb_anchor_idx == 8:
		var delta: Vector2 = mouse - bb_start_mouse
		if Input.is_key_pressed(KEY_SHIFT):
			delta = delta / 3.0
		for i in range(_game.selected_indices.size()):
			var idx: int = _game.selected_indices[i]
			_game.point_positions[idx] = bb_start_positions[i] + delta
		_clamp_points_to_viewport()
		_notify_points_changed()
		_game.queue_redraw()
		return

	var r: Rect2 = bb_start_rect
	var sx: float = 1.0
	var sy: float = 1.0
	var affects_x: bool = bb_anchor_idx != 1 and bb_anchor_idx != 6
	var affects_y: bool = bb_anchor_idx != 3 and bb_anchor_idx != 4

	if affects_x and r.size.x > 1.0:
		var orig_dist_x: float = bb_start_mouse.x - bb_origin.x
		var new_dist_x: float = mouse.x - bb_origin.x
		if absf(orig_dist_x) > 1.0:
			sx = new_dist_x / orig_dist_x

	if affects_y and r.size.y > 1.0:
		var orig_dist_y: float = bb_start_mouse.y - bb_origin.y
		var new_dist_y: float = mouse.y - bb_origin.y
		if absf(orig_dist_y) > 1.0:
			sy = new_dist_y / orig_dist_y

	for i in range(_game.selected_indices.size()):
		var idx: int = _game.selected_indices[i]
		var orig: Vector2 = bb_start_positions[i]
		var offset: Vector2 = orig - bb_origin
		_game.point_positions[idx] = bb_origin + Vector2(offset.x * sx, offset.y * sy)

	_clamp_points_to_viewport()
	_notify_points_changed()
	_game.queue_redraw()


func _end_bb_drag() -> void:
	bb_dragging = false
	bb_anchor_idx = -1
	bb_start_positions.clear()
	_notify_points_changed()
	_game.queue_redraw()


# =============================================================================
# Transform operations
# =============================================================================

func _get_selection_center() -> Vector2:
	var center := Vector2.ZERO
	for idx in _game.selected_indices:
		center += _game.point_positions[idx]
	return center / _game.selected_indices.size()


func rotate_selected(angle: float) -> void:
	_end_active_drag(true)
	var center: Vector2 = _get_selection_center()
	for idx in _game.selected_indices:
		var offset: Vector2 = _game.point_positions[idx] - center
		_game.point_positions[idx] = center + offset.rotated(angle)
	_clamp_points_to_viewport()
	_notify_points_changed()
	_game.queue_redraw()


func scale_selected(factor: float) -> void:
	_end_active_drag(true)
	var center: Vector2 = _get_selection_center()
	for idx in _game.selected_indices:
		var offset: Vector2 = _game.point_positions[idx] - center
		_game.point_positions[idx] = center + offset * factor
	_clamp_points_to_viewport()
	_notify_points_changed()
	_game.queue_redraw()


# =============================================================================
# Gamepad
# =============================================================================

func handle_pad_button(btn: int, pressed: bool) -> void:
	if _game.game_state != "playing" and _game.game_state != "rules":
		return
	if _game.point_positions.is_empty():
		return
	_last_input_method = "pad"
	if btn == JOY_BUTTON_A:
		player_force_attracting = pressed
	elif btn == JOY_BUTTON_B:
		player_force_repelling = pressed
	grab_input_active = _get_player_force_mode() != 0 or player_force_active


func _ensure_pad_selection() -> void:
	"""Ensure there is always one pad-selected point."""
	if _game.selected_indices.size() >= 1:
		return
	var best: int = _find_point_at(pad_cursor)
	if best < 0:
		best = _find_closest_point(pad_cursor)
	if best >= 0:
		_game.selected_indices.clear()
		_game.selected_indices.append(best)
		_game.hovered_index = best
		pad_cursor = _game.point_positions[best]
		pad_grabbing = true
		_grabbing_from_right_stick = false
		_game.is_dragging = true
		_game.queue_redraw()


func get_connected_indices(idx: int) -> Array[int]:
	"""Return connected prev/next indices."""
	return [_get_polygon_prev(idx), _get_polygon_next(idx)]


func _get_polygon_prev(idx: int) -> int:
	"""Get previous index on the polygon loop."""
	var n: int = _game.point_positions.size()
	if _game.stage_manager.stage_type == "two_circles":
		var split: int = _game.stage_manager.group_split
		if idx < split:
			return (idx - 1 + split) % split
		else:
			var g2: int = n - split
			return split + (idx - split - 1 + g2) % g2
	return (idx - 1 + n) % n


func _get_polygon_next(idx: int) -> int:
	"""Get next index on the polygon loop."""
	var n: int = _game.point_positions.size()
	if _game.stage_manager.stage_type == "two_circles":
		var split: int = _game.stage_manager.group_split
		if idx < split:
			return (idx + 1) % split
		else:
			var g2: int = n - split
			return split + (idx - split + 1) % g2
	return (idx + 1) % n


func _apply_lr_grab_lock_after_shoulder_cycle() -> void:
	_right_stick_ray_pinned = true
	if _right_stick_last_effective_ray_dir.length_squared() > 0.0001:
		_right_stick_locked_ray_dir = _right_stick_last_effective_ray_dir
	_rs_lr_selection_lock = true
	if _right_stick_last_effective_ray_dir.length_squared() > 0.0001:
		_rs_lr_lock_ref_dir = _right_stick_last_effective_ray_dir.normalized()
	else:
		var rsx: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var rsy: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		var rsv: Vector2 = Vector2(rsx, rsy)
		if rsv.length() >= PAD_RIGHT_STICK_DEADZONE:
			_rs_lr_lock_ref_dir = rsv.normalized()
		else:
			_rs_lr_lock_ref_dir = Vector2.RIGHT


# LB/RB polygon ring traversal.
func _cycle_polygon_ring_adjacent(cw: bool, right_stick_style: bool) -> bool:
	if _game.selected_indices.is_empty():
		return false
	var cur: int = _game.selected_indices[0]
	var nxt: int = _get_polygon_next(cur) if cw else _get_polygon_prev(cur)
	var n_pts: int = _game.point_positions.size()
	var guard: int = 0
	while _is_locked(nxt) and guard < n_pts:
		nxt = _get_polygon_next(nxt) if cw else _get_polygon_prev(nxt)
		guard += 1
		if nxt == cur:
			return false
	if _is_locked(nxt) or nxt == cur:
		return false
	if right_stick_style:
		_apply_ray_selection(nxt)
		_apply_lr_grab_lock_after_shoulder_cycle()
		if DEBUG_PAD_RAY_LR:
			_log_pad_ray_lr("cycle_poly_ring cw=" + str(cw) + " -> sel=" + str(_game.selected_indices[0]) + " ref_eff=" + str(_rs_lr_lock_ref_dir))
	else:
		_game.selected_indices.clear()
		_game.selected_indices.append(nxt)
		_game.hovered_index = nxt
		pad_cursor = _game.point_positions[nxt]
		pad_grabbing = true
		_grabbing_from_right_stick = false
		_game.is_dragging = true
		_game.queue_redraw()
		_notify_selection_changed()
	return true


func _cycle_pad_point_direction(direction: Vector2) -> void:
	"""Move selection toward the closest connected point in the input direction."""
	if _game.selected_indices.is_empty():
		return
	var idx: int = _game.selected_indices[0]
	var pos: Vector2 = _game.point_positions[idx]
	var prev_idx: int = _get_polygon_prev(idx)
	var next_idx: int = _get_polygon_next(idx)

	var candidates: Array[Dictionary] = []
	if not _is_locked(prev_idx):
		candidates.append({"idx": prev_idx, "pos": _game.point_positions[prev_idx]})
	if not _is_locked(next_idx) and next_idx != prev_idx:
		candidates.append({"idx": next_idx, "pos": _game.point_positions[next_idx]})
	if candidates.is_empty():
		return

	# Choose the connected edge closest to the input direction.
	var input_angle: float = direction.angle()
	var best: Dictionary = candidates[0]
	var best_diff: float = INF
	for c in candidates:
		var to_p: Vector2 = (c["pos"] as Vector2) - pos
		if to_p.length_squared() < 0.0001:
			continue
		var line_angle: float = to_p.angle()
		var diff: float = abs(wrapf(line_angle - input_angle, -PI, PI))
		if diff < best_diff:
			best_diff = diff
			best = c
	_game.selected_indices.clear()
	_game.selected_indices.append(best["idx"])
	_game.hovered_index = best["idx"]
	pad_cursor = best["pos"]
	pad_grabbing = true
	_grabbing_from_right_stick = false
	_game.is_dragging = true
	_game.queue_redraw()
	_notify_selection_changed()


func _clear_right_stick_ray_state() -> void:
	_right_stick_ray_pinned = false
	_right_stick_locked_ray_dir = Vector2.ZERO
	_right_stick_last_effective_ray_dir = Vector2.ZERO
	_right_stick_ray_bundle.clear()
	_rs_kata_grab_lock = false
	_rs_kata_grab_lock_ref_dir = Vector2.ZERO
	_rs_lr_selection_lock = false
	_rs_lr_lock_ref_dir = Vector2.ZERO
	_right_stick_ray_auto_select_done = false
	_last_rs_phys_dir_at_auto_select = Vector2.ZERO


func _dpad_any_pressed() -> bool:
	return Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT)


# Corridor width along the shoulder ray.
func ray_shoulder_corridor_max_perp_px(along: float) -> float:
	return maxf(
		RIGHT_STICK_RAY_SHOULDER_MIN_PERP_PX,
		along * tan(deg_to_rad(RIGHT_STICK_RAY_SHOULDER_CONE_HALF_ANGLE_DEG))
	)


# Check whether a point is inside the shoulder ray corridor.
func _point_is_in_ray_shoulder_corridor(origin: Vector2, dir_n: Vector2, idx: int) -> bool:
	if _is_locked(idx):
		return false
	var dir_nn: Vector2 = dir_n.normalized() if dir_n.length_squared() > 0.0001 else Vector2.RIGHT
	var delta: Vector2 = _game.point_positions[idx] - origin
	var along: float = delta.dot(dir_nn)
	if along < 0.0:
		return false
	var perp_dist: float = (delta - along * dir_nn).length()
	if perp_dist > ray_shoulder_corridor_max_perp_px(along):
		return false
	return true


# Collect all points in the shoulder ray corridor.
func _collect_all_indices_in_ray_shoulder_corridor(origin: Vector2, dir_n: Vector2) -> Array[int]:
	var out: Array[int] = []
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		if _point_is_in_ray_shoulder_corridor(origin, dir_n, i):
			out.append(i)
	return out


func _finalize_shoulder_ray_bundle(origin: Vector2, dir_n: Vector2) -> Array[int]:
	var all_in: Array[int] = _collect_all_indices_in_ray_shoulder_corridor(origin, dir_n)
	if all_in.is_empty():
		return []
	return _sort_indices_by_ray_along(origin, dir_n, all_in)


func _sort_indices_by_ray_along(origin: Vector2, dir_n: Vector2, indices: Array[int]) -> Array[int]:
	var arr: Array[int] = indices.duplicate()
	arr.sort_custom(func(a: int, b: int) -> bool:
		var a_along: float = (_game.point_positions[a] - origin).dot(dir_n)
		var b_along: float = (_game.point_positions[b] - origin).dot(dir_n)
		return a_along < b_along
	)
	return arr


func _apply_ray_selection(idx: int) -> void:
	_game.selected_indices.clear()
	_game.selected_indices.append(idx)
	_game.hovered_index = idx
	pad_cursor = _game.point_positions[idx]
	pad_grabbing = true
	_grabbing_from_right_stick = true
	_game.is_dragging = true
	_game.queue_redraw()
	_notify_selection_changed()


# Find the nearest slot in the ray bundle.
func _nearest_ray_bundle_slot_for_point(cur_point_idx: int, bundle: Array[int]) -> int:
	if bundle.is_empty():
		return 0
	var cur_pos: Vector2 = _game.point_positions[cur_point_idx]
	var best_slot: int = 0
	var best_d2: float = INF
	for i in range(bundle.size()):
		var d2: float = cur_pos.distance_squared_to(_game.point_positions[bundle[i]])
		if d2 < best_d2:
			best_d2 = d2
			best_slot = i
	return best_slot


# Core cycling logic inside a ray bundle.
func _cycle_ray_bundle_core(bundle: Array[int], dir: int, right_stick_style: bool) -> bool:
	if bundle.size() < 2 or _game.selected_indices.is_empty():
		return false
	var cur: int = _game.selected_indices[0]
	var pos: int = bundle.find(cur)
	if pos < 0:
		pos = _nearest_ray_bundle_slot_for_point(cur, bundle)
	var nxt_pos: int = (pos + dir + bundle.size()) % bundle.size()
	var nxt: int = bundle[nxt_pos]
	if right_stick_style:
		_apply_ray_selection(nxt)
		_apply_lr_grab_lock_after_shoulder_cycle()
		if DEBUG_PAD_RAY_LR:
			_log_pad_ray_lr("cycle_ray_bundle dir=" + str(dir) + " -> sel=" + str(nxt) + " ref_eff=" + str(_rs_lr_lock_ref_dir))
	else:
		_game.selected_indices.clear()
		_game.selected_indices.append(nxt)
		_game.hovered_index = nxt
		pad_cursor = _game.point_positions[nxt]
		pad_grabbing = true
		_grabbing_from_right_stick = false
		_game.is_dragging = true
		_game.queue_redraw()
		_notify_selection_changed()
	return true


# Cycle only within the current ray bundle.
func _cycle_ray_bundle(dir: int) -> void:
	_cycle_ray_bundle_core(_right_stick_ray_bundle, dir, true)


# Rebuild a ray bundle from the saved ray if possible.
func _try_shoulder_cycle_ray_bundle_from_saved_ray(dir: int) -> bool:
	if _right_stick_last_effective_ray_dir.length_squared() < 0.0001:
		return false
	var centroid := Vector2.ZERO
	var count: int = 0
	for i in range(_game.point_positions.size()):
		if not _is_locked(i):
			centroid += _game.point_positions[i]
			count += 1
	if count == 0:
		return false
	centroid /= float(count)
	var dir_n: Vector2 = _right_stick_last_effective_ray_dir.normalized()
	var bundle: Array[int] = _finalize_shoulder_ray_bundle(centroid, dir_n)
	if bundle.size() < 2:
		return true
	return _cycle_ray_bundle_core(bundle, dir, false)


func _sync_pinned_selection_only() -> void:
	if _rs_kata_grab_lock or _rs_lr_selection_lock:
		return
	var bundle: Array[int] = _right_stick_ray_bundle
	if bundle.is_empty() or _game.selected_indices.is_empty():
		return
	var cur: int = _game.selected_indices[0]
	if bundle.find(cur) >= 0:
		return
	# If the current point fell out of the bundle, snap to the nearest slot.
	var slot: int = _nearest_ray_bundle_slot_for_point(cur, bundle)
	_apply_ray_selection(bundle[slot])


func _stick_to_cardinal_direction(stick_vec: Vector2) -> Vector2:
	"""Convert an analog stick vector into a cardinal direction."""
	if stick_vec.length() < 0.15:
		return Vector2.ZERO
	if absf(stick_vec.x) > absf(stick_vec.y):
		return Vector2(signf(stick_vec.x), 0)
	else:
		return Vector2(0, signf(stick_vec.y))


func _select_point_by_direction_line(origin: Vector2, direction: Vector2) -> bool:
	"""Select the best point along a direction line and return success."""
	if direction.length_squared() < 0.0001:
		return false
	var dir_n: Vector2 = direction.normalized()
	var best: int = -1
	var best_perp_dist: float = INF
	var best_along: float = -INF
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		var p: Vector2 = _game.point_positions[i]
		var delta: Vector2 = p - origin
		var along: float = delta.dot(dir_n)
		if along < 0:
			continue
		var perp: Vector2 = delta - along * dir_n
		var perp_dist: float = perp.length()
		if best < 0 or perp_dist < best_perp_dist or (absf(perp_dist - best_perp_dist) < 0.001 and along > best_along):
			best_perp_dist = perp_dist
			best_along = along
			best = i
	if best < 0:
		return false
	_apply_ray_selection(best)
	if DEBUG_PAD_RAY_LR:
		_log_pad_ray_lr("select_line -> idx=" + str(best))
	_right_stick_ray_bundle = _finalize_shoulder_ray_bundle(origin, dir_n)
	return true


func process_pad(delta: float) -> void:
	if _game.game_state != "playing" and _game.game_state != "rules":
		player_has_motion_input = false
		player_force_attracting = false
		player_force_repelling = false
		grab_input_active = false
		return
	if _game.game_state == "rules" and _game.rules_focus_button:
		player_has_motion_input = false
		player_force_attracting = false
		player_force_repelling = false
		grab_input_active = false
		return
	if _game.point_positions.is_empty():
		player_has_motion_input = false
		player_force_attracting = false
		player_force_repelling = false
		grab_input_active = false
		return
	if not player_position_initialized:
		_reset_player_position()

	var left_x: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var left_y: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var left_raw: Vector2 = Vector2(left_x, left_y)
	var left_neutral: bool = left_raw.length() < PAD_LEFT_STICK_NEUTRAL_DEADZONE
	var move_vec: Vector2 = left_raw if not left_neutral else Vector2.ZERO
	var dpad: Vector2 = Vector2.ZERO
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		dpad.y -= 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		dpad.y += 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		dpad.x -= 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		dpad.x += 1.0

	player_force_attracting = Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	player_force_repelling = Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	var speed_mul: float = _get_player_speed_multiplier()
	var moved: bool = false
	if move_vec != Vector2.ZERO:
		var speed: float = pow(clampf(move_vec.length(), 0.0, 1.0), PAD_LEFT_STICK_SPEED_EXPONENT) * PLAYER_MOVE_SPEED * speed_mul
		player_position += move_vec.normalized() * speed * delta
		moved = true
	if dpad != Vector2.ZERO:
		player_position += dpad.normalized() * PLAYER_DPAD_SPEED * speed_mul * delta
		moved = true

	player_has_motion_input = moved
	if not _game.selected_indices.is_empty():
		_game.selected_indices.clear()
	if moved:
		_clamp_player_to_viewport()
		_last_input_method = "pad"
		_game.queue_redraw()
	_refresh_hovered_point()
	grab_input_active = _get_player_force_mode() != 0 or player_force_active
	_game.is_dragging = false


# =============================================================================
# Drag Physics
# =============================================================================

func update_drag_physics(delta: float) -> void:
	_ensure_drag_state_arrays()
	if not player_position_initialized:
		_reset_player_position()
	if not player_force_active and not _has_points_within_player_force() and not _has_active_point_velocity():
		return

	var steps: int = maxi(1, int(ceil(delta / DRAG_STEP_MAX)))
	var step_delta: float = delta / float(steps)
	var moved: bool = false
	for _i in range(steps):
		moved = _step_drag_physics(step_delta) or moved

	if moved:
		_notify_points_changed()
		_game.queue_redraw()


func _step_drag_physics(delta: float) -> bool:
	if _game.point_positions.is_empty():
		player_force_active = false
		player_influenced_point_count = 0
		return false

	var before: Array[Vector2] = _game.point_positions.duplicate()
	var guide_loops: Array = _build_fixed_guide_snap_loops()
	var nearest_features: Array = _compute_nearest_guide_features(guide_loops)
	var vertex_locks: Dictionary = _compute_vertex_locks(nearest_features)
	var forces: Array[Vector2] = []
	forces.resize(_game.point_positions.size())
	for i in range(forces.size()):
		forces[i] = Vector2.ZERO

	player_influenced_point_count = 0
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			point_velocities[i] = Vector2.ZERO
			continue
		var player_force: Vector2 = _compute_player_force(i)
		if player_force.length_squared() > 0.0001:
			forces[i] += player_force
			player_influenced_point_count += 1
	_apply_point_pair_repulsion(forces)
	_apply_guide_snap_and_repulsion(forces, nearest_features, vertex_locks)
	player_force_active = player_influenced_point_count > 0
	grab_input_active = player_force_active or _get_player_force_mode() != 0 or mouse_force_pressed

	var damping: float = exp(-DRAG_VELOCITY_DAMPING * delta)
	var vp: Vector2 = _game.get_viewport_rect().size
	var margin: float = _game.ui_renderer.POINT_RADIUS
	var lo := Vector2(margin, margin)
	var hi := Vector2(vp.x - margin, vp.y - margin)

	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			point_velocities[i] = Vector2.ZERO
			continue
		point_velocities[i] += forces[i] * delta
		point_velocities[i] *= damping
		_game.point_positions[i] += point_velocities[i] * delta
		_clamp_point_to_viewport(i, lo, hi)

	if not player_force_active and not _has_active_point_velocity():
		_zero_all_point_velocities()

	for i in range(_game.point_positions.size()):
		if before[i].distance_squared_to(_game.point_positions[i]) > DRAG_POSITION_EPSILON * DRAG_POSITION_EPSILON:
			return true
	return false


func _compute_player_force(point_idx: int) -> Vector2:
	var force_mode: int = _get_player_force_mode()
	if force_mode == 0 and not mouse_force_pressed:
		return Vector2.ZERO
	var point_pos: Vector2 = _game.point_positions[point_idx]
	var from_player: Vector2 = point_pos - player_position
	var dist: float = maxf(from_player.length(), PLAYER_MIN_FORCE_DISTANCE)
	var influence_limit: float = PLAYER_FORCE_RADIUS + _game.ui_renderer.POINT_RADIUS
	if dist > influence_limit:
		return Vector2.ZERO
	var falloff: float = 1.0 - dist / influence_limit
	var direction: Vector2 = from_player / dist
	if force_mode > 0 or mouse_force_pressed:
		direction = -direction
	var base_strength: float = PLAYER_ATTRACT_STRENGTH if (force_mode > 0 or mouse_force_pressed) else PLAYER_REPEL_STRENGTH
	var force: Vector2 = direction * (base_strength * falloff * falloff)
	if _is_player_touching_point(point_idx):
		force += direction * PLAYER_CONTACT_FORCE
	return force


func _is_player_touching_point(point_idx: int) -> bool:
	if point_idx < 0 or point_idx >= _game.point_positions.size():
		return false
	var contact_radius: float = PLAYER_RADIUS + _game.ui_renderer.POINT_RADIUS
	return player_position.distance_to(_game.point_positions[point_idx]) <= contact_radius


func _apply_point_pair_repulsion(forces: Array[Vector2]) -> void:
	var threshold_sq: float = POINT_PAIR_REPULSE_DISTANCE * POINT_PAIR_REPULSE_DISTANCE
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		for j in range(i + 1, _game.point_positions.size()):
			if _is_locked(j):
				continue
			var delta: Vector2 = _game.point_positions[j] - _game.point_positions[i]
			var dist_sq: float = delta.length_squared()
			if dist_sq > threshold_sq:
				continue
			var dist: float = maxf(sqrt(dist_sq), POINT_PAIR_REPULSE_MIN_DISTANCE)
			var falloff: float = 1.0 - dist / POINT_PAIR_REPULSE_DISTANCE
			var dir: Vector2 = delta / dist
			var force: Vector2 = dir * (POINT_PAIR_REPULSE_STRENGTH * falloff * falloff)
			forces[i] -= force
			forces[j] += force


func _get_player_force_mode() -> int:
	if mouse_force_pressed:
		return 1
	if player_force_attracting == player_force_repelling:
		return 0
	return 1 if player_force_attracting else -1


func _get_player_speed_multiplier() -> float:
	var boost_count: int = 0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		boost_count += 1
	if Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		boost_count += 1
	if absf(Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)) > 0.35:
		boost_count += 1
	if absf(Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)) > 0.35:
		boost_count += 1
	return 1.0 + float(boost_count) * PLAYER_SPEED_BOOST_PER_BUTTON


func _has_points_within_player_force() -> bool:
	if _get_player_force_mode() == 0 and not mouse_force_pressed:
		return false
	var influence_limit: float = PLAYER_FORCE_RADIUS + _game.ui_renderer.POINT_RADIUS
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		if player_position.distance_to(_game.point_positions[i]) <= influence_limit:
			return true
	return false


func _begin_point_drag(idx: int, target_position: Vector2, input_method: String) -> void:
	if idx < 0 or idx >= _game.point_positions.size():
		return
	_ensure_drag_state_arrays()
	drag_target_active = true
	drag_point_idx = idx
	drag_target_position = target_position
	drag_target_offset = target_position - _game.point_positions[idx]
	drag_start_positions = _game.point_positions.duplicate()
	_prepare_drag_influence_weights(idx)
	_capture_drag_angle_reference(idx)
	_last_input_method = input_method


func _ensure_pad_drag_context() -> void:
	if _game.selected_indices.size() != 1:
		return
	var idx: int = _game.selected_indices[0]
	if drag_target_active and drag_point_idx == idx and _last_input_method == "pad":
		return
	_begin_point_drag(idx, _game.point_positions[idx], "pad")


func _end_active_drag(clear_velocity: bool) -> void:
	drag_target_active = false
	drag_point_idx = -1
	drag_target_offset = Vector2.ZERO
	drag_start_positions.clear()
	drag_influence_weights.clear()
	drag_angle_prev_idx = -1
	drag_angle_next_idx = -1
	drag_angle_reference = 0.0
	player_force_active = false
	player_influenced_point_count = 0
	if clear_velocity:
		_zero_all_point_velocities()


func _ensure_drag_state_arrays() -> void:
	while point_velocities.size() < _game.point_positions.size():
		point_velocities.append(Vector2.ZERO)
	while point_velocities.size() > _game.point_positions.size():
		point_velocities.pop_back()
	while point_stop_frames.size() < _game.point_positions.size():
		point_stop_frames.append(0)
	while point_stop_frames.size() > _game.point_positions.size():
		point_stop_frames.pop_back()


func _zero_all_point_velocities() -> void:
	for i in range(point_velocities.size()):
		point_velocities[i] = Vector2.ZERO
	for i in range(point_stop_frames.size()):
		point_stop_frames[i] = 0


func _has_active_point_velocity() -> bool:
	for velocity in point_velocities:
		if velocity.length() > DRAG_STOP_SPEED:
			return true
	for i in range(point_velocities.size()):
		if point_velocities[i].length_squared() > 0.01:
			return true
	return false


func _is_drag_point_valid() -> bool:
	return (
		drag_point_idx >= 0
		and drag_point_idx < _game.point_positions.size()
		and drag_start_positions.size() == _game.point_positions.size()
	)


func _prepare_drag_influence_weights(grab_idx: int) -> void:
	drag_influence_weights.clear()
	var loop_bounds: Vector2i = _get_loop_bounds_for_index(grab_idx)
	var perimeter: float = _get_loop_perimeter(loop_bounds.x, loop_bounds.y)
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			drag_influence_weights.append(0.0)
		elif i == grab_idx:
			drag_influence_weights.append(1.0)
		elif i < loop_bounds.x or i >= loop_bounds.y or perimeter <= 0.001:
			drag_influence_weights.append(0.0)
		else:
			var ratio: float = _get_contour_distance(grab_idx, i, loop_bounds.x, loop_bounds.y) / perimeter
			drag_influence_weights.append(_falloff_weight_from_ratio(ratio))


func _capture_drag_angle_reference(grab_idx: int) -> void:
	drag_angle_prev_idx = _get_polygon_prev(grab_idx)
	drag_angle_next_idx = _get_polygon_next(grab_idx)
	if drag_angle_prev_idx == drag_angle_next_idx:
		drag_angle_reference = 0.0
		return
	drag_angle_reference = _local_signed_angle(drag_angle_prev_idx, grab_idx, drag_angle_next_idx)


func _apply_local_angle_spring(forces: Array[Vector2]) -> void:
	if not _is_drag_point_valid():
		return
	if drag_angle_prev_idx < 0 or drag_angle_next_idx < 0:
		return
	if drag_angle_prev_idx >= _game.point_positions.size() or drag_angle_next_idx >= _game.point_positions.size():
		return
	if _is_locked(drag_angle_prev_idx) or _is_locked(drag_angle_next_idx) or _is_locked(drag_point_idx):
		return

	var center: Vector2 = _game.point_positions[drag_point_idx]
	var prev_vec: Vector2 = _game.point_positions[drag_angle_prev_idx] - center
	var next_vec: Vector2 = _game.point_positions[drag_angle_next_idx] - center
	if prev_vec.length_squared() < 0.001 or next_vec.length_squared() < 0.001:
		return

	var angle_error: float = wrapf(_local_signed_angle(drag_angle_prev_idx, drag_point_idx, drag_angle_next_idx) - drag_angle_reference, -PI, PI)
	if absf(angle_error) < 0.0001:
		return

	var correction: float = angle_error * 0.5
	var desired_prev_pos: Vector2 = center + prev_vec.rotated(correction)
	var desired_next_pos: Vector2 = center + next_vec.rotated(-correction)
	var prev_delta: Vector2 = desired_prev_pos - _game.point_positions[drag_angle_prev_idx]
	var next_delta: Vector2 = desired_next_pos - _game.point_positions[drag_angle_next_idx]
	var angle_center_force: Vector2 = -(prev_delta + next_delta) * 0.5

	forces[drag_angle_prev_idx] += prev_delta * DRAG_ANGLE_SPRING - point_velocities[drag_angle_prev_idx] * DRAG_ANGLE_DAMPING
	forces[drag_angle_next_idx] += next_delta * DRAG_ANGLE_SPRING - point_velocities[drag_angle_next_idx] * DRAG_ANGLE_DAMPING
	forces[drag_point_idx] += angle_center_force * DRAG_ANGLE_SPRING - point_velocities[drag_point_idx] * DRAG_ANGLE_DAMPING * 0.5


func _apply_guide_snap_and_repulsion(forces: Array[Vector2], nearest_features: Array, vertex_locks: Dictionary) -> void:
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		var feature: Dictionary = nearest_features[i] as Dictionary
		var pos: Vector2 = _game.point_positions[i]
		var edge_dist: float = feature.get("edge_dist", INF) as float
		if edge_dist < GUIDE_EDGE_SNAP_RADIUS:
			var edge_strength: float = 1.0 - edge_dist / GUIDE_EDGE_SNAP_RADIUS
			var edge_target: Vector2 = feature.get("edge_point", pos) as Vector2
			forces[i] += (edge_target - pos) * (GUIDE_EDGE_SPRING * edge_strength)
			forces[i] -= point_velocities[i] * (GUIDE_SNAP_DAMPING * edge_strength)
		var vertex_dist: float = feature.get("vertex_dist", INF) as float
		if vertex_dist < GUIDE_VERTEX_SNAP_RADIUS:
			var vertex_strength: float = 1.0 - vertex_dist / GUIDE_VERTEX_SNAP_RADIUS
			var vertex_target: Vector2 = feature.get("vertex_pos", pos) as Vector2
			forces[i] += (vertex_target - pos) * (GUIDE_VERTEX_SPRING * vertex_strength)
			forces[i] -= point_velocities[i] * (GUIDE_SNAP_DAMPING * vertex_strength)
		var lock_data: Dictionary = vertex_locks.get(i, {}) as Dictionary
		if lock_data.is_empty():
			continue
		var lock_pos: Vector2 = lock_data.get("vertex_pos", pos) as Vector2
		var player_touching: bool = _is_player_touching_point(i)
		var lock_mul: float = GUIDE_VERTEX_CONTACT_RELEASE_MUL if player_touching else 1.0
		forces[i] += (lock_pos - pos) * (GUIDE_VERTEX_LOCK_SPRING * lock_mul)
		forces[i] -= point_velocities[i] * (GUIDE_VERTEX_LOCK_DAMPING * lock_mul)


func _build_fixed_guide_snap_loops() -> Array:
	var loops: Array = _game.stage_manager.get_active_guide_loops_world()
	var filtered: Array = []
	for loop in loops:
		var points: Array = loop as Array
		if points.size() >= 2:
			filtered.append(points)
	return filtered


func get_debug_snap_vertices_world() -> Array:
	var vertices: Array = []
	for loop in _build_fixed_guide_snap_loops():
		for point in loop:
			vertices.append(point)
	return vertices


func _transform_fixed_guide_points(points: Array) -> Array:
	var verts: Array = []
	var center: Vector2 = _game.guide_center_1
	var scale: float = _game.guide_radius_val
	var rotation: float = _game.correspondence_rotation
	var cos_r: float = cos(rotation)
	var sin_r: float = sin(rotation)
	for pt in points:
		var p: Vector2 = pt as Vector2
		var tx: float = (p.x * cos_r - p.y * sin_r) * scale
		var ty: float = (p.x * sin_r + p.y * cos_r) * scale
		verts.append(center + Vector2(tx, ty))
	return verts


func _build_regular_polygon_loop(center: Vector2, radius: float, n_sides: int, rotation: float) -> Array:
	var verts: Array = []
	for k in range(n_sides):
		var angle: float = rotation + TAU * float(k) / float(maxi(n_sides, 1))
		verts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return verts


func _build_circle_loop(center: Vector2, radius: float) -> Array:
	var verts: Array = []
	for i in range(_game.CIRCLE_SEGMENTS):
		var angle: float = TAU * float(i) / float(maxi(_game.CIRCLE_SEGMENTS, 1))
		verts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return verts


func _compute_nearest_guide_features(guide_loops: Array) -> Array:
	var features: Array = []
	for i in range(_game.point_positions.size()):
		var pos: Vector2 = _game.point_positions[i]
		var best: Dictionary = {
			"vertex_dist": INF,
			"vertex_pos": pos,
			"vertex_idx": -1,
			"vertex_loop": -1,
			"edge_dist": INF,
			"edge_point": pos,
			"edge_start_idx": -1,
			"edge_loop": -1,
			"loop_size": 0,
		}
		for loop_idx in range(guide_loops.size()):
			var loop: Array = guide_loops[loop_idx] as Array
			var loop_size: int = loop.size()
			for vertex_idx in range(loop_size):
				var vertex_pos: Vector2 = loop[vertex_idx] as Vector2
				var vertex_dist: float = pos.distance_to(vertex_pos)
				if vertex_dist < (best.get("vertex_dist", INF) as float):
					best["vertex_dist"] = vertex_dist
					best["vertex_pos"] = vertex_pos
					best["vertex_idx"] = vertex_idx
					best["vertex_loop"] = loop_idx
				var next_idx: int = (vertex_idx + 1) % loop_size
				var edge_point: Vector2 = _closest_point_on_segment(pos, vertex_pos, loop[next_idx] as Vector2)
				var edge_dist: float = pos.distance_to(edge_point)
				if edge_dist < (best.get("edge_dist", INF) as float):
					best["edge_dist"] = edge_dist
					best["edge_point"] = edge_point
					best["edge_start_idx"] = vertex_idx
					best["edge_loop"] = loop_idx
					best["loop_size"] = loop_size
		features.append(best)
	return features


func _compute_vertex_locks(nearest_features: Array) -> Dictionary:
	var vertex_locks: Dictionary = {}
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		var feature: Dictionary = nearest_features[i] as Dictionary
		var vertex_idx: int = feature.get("vertex_idx", -1) as int
		var vertex_loop: int = feature.get("vertex_loop", -1) as int
		var vertex_dist: float = feature.get("vertex_dist", INF) as float
		if vertex_idx < 0 or vertex_loop < 0 or vertex_dist > GUIDE_VERTEX_LOCK_RADIUS:
			continue
		vertex_locks[i] = {
			"vertex_loop": vertex_loop,
			"vertex_idx": vertex_idx,
			"vertex_pos": feature.get("vertex_pos", _game.point_positions[i]),
			"vertex_dist": vertex_dist,
		}
	return vertex_locks


func _feature_is_on_same_vertex_or_edge(feature: Dictionary, occupied_data: Dictionary) -> bool:
	var occupied_loop: int = occupied_data.get("vertex_loop", -1) as int
	var occupied_vertex: int = occupied_data.get("vertex_idx", -1) as int
	if feature.get("vertex_loop", -1) as int == occupied_loop and feature.get("vertex_idx", -1) as int == occupied_vertex:
		return true
	if feature.get("edge_loop", -1) as int != occupied_loop:
		return false
	var loop_size: int = maxi(1, occupied_data.get("loop_size", feature.get("loop_size", 0)) as int)
	var edge_start: int = feature.get("edge_start_idx", -1) as int
	var prev_edge: int = (occupied_vertex - 1 + loop_size) % loop_size
	return edge_start == occupied_vertex or edge_start == prev_edge


func _guide_vertex_feature_id(loop_idx: int, vertex_idx: int) -> String:
	return str(loop_idx) + ":" + str(vertex_idx)


func _get_occupied_anchor_for_point(point_idx: int, occupied_vertices: Dictionary) -> Dictionary:
	for occupied in occupied_vertices.values():
		var occupied_data: Dictionary = occupied as Dictionary
		if int(occupied_data.get("point_idx", -1)) == point_idx:
			return occupied_data
	return {}


func _local_signed_angle(prev_idx: int, center_idx: int, next_idx: int) -> float:
	var from_prev: Vector2 = _game.point_positions[prev_idx] - _game.point_positions[center_idx]
	var to_next: Vector2 = _game.point_positions[next_idx] - _game.point_positions[center_idx]
	return atan2(from_prev.cross(to_next), from_prev.dot(to_next))


func _get_loop_bounds_for_index(idx: int) -> Vector2i:
	if _game.stage_manager.stage_type != "two_circles":
		return Vector2i(0, _game.point_positions.size())
	var split: int = _game.stage_manager.group_split
	if idx < split:
		return Vector2i(0, split)
	return Vector2i(split, _game.point_positions.size())


func _get_loop_perimeter(start_idx: int, end_idx: int) -> float:
	var perimeter: float = 0.0
	for i in range(start_idx, end_idx):
		var next_idx: int = i + 1
		if next_idx >= end_idx:
			next_idx = start_idx
		perimeter += _game.point_positions[i].distance_to(_game.point_positions[next_idx])
	return perimeter


func _get_contour_distance(from_idx: int, to_idx: int, start_idx: int, end_idx: int) -> float:
	if from_idx == to_idx:
		return 0.0
	var forward: float = 0.0
	var cur: int = from_idx
	while cur != to_idx:
		var next_idx: int = cur + 1
		if next_idx >= end_idx:
			next_idx = start_idx
		forward += _game.point_positions[cur].distance_to(_game.point_positions[next_idx])
		cur = next_idx
	var backward: float = 0.0
	cur = from_idx
	while cur != to_idx:
		var prev_idx: int = cur - 1
		if prev_idx < start_idx:
			prev_idx = end_idx - 1
		backward += _game.point_positions[cur].distance_to(_game.point_positions[prev_idx])
		cur = prev_idx
	return minf(forward, backward)


func _advance_loop_index(idx: int, direction: int, start_idx: int, end_idx: int) -> int:
	if direction >= 0:
		var next_idx: int = idx + 1
		return start_idx if next_idx >= end_idx else next_idx
	var prev_idx: int = idx - 1
	return end_idx - 1 if prev_idx < start_idx else prev_idx


func _get_contour_distance_in_direction(from_idx: int, to_idx: int, start_idx: int, end_idx: int, direction: int) -> float:
	if from_idx == to_idx:
		return 0.0
	var distance: float = 0.0
	var cur: int = from_idx
	while cur != to_idx:
		var next_idx: int = _advance_loop_index(cur, direction, start_idx, end_idx)
		distance += _game.point_positions[cur].distance_to(_game.point_positions[next_idx])
		cur = next_idx
	return distance


func _path_has_blocking_occupied_point(
	from_idx: int,
	to_idx: int,
	start_idx: int,
	end_idx: int,
	direction: int,
	occupied_vertices: Dictionary
) -> bool:
	if occupied_vertices.is_empty() or from_idx == to_idx:
		return false
	var cur: int = from_idx
	while cur != to_idx:
		var next_idx: int = _advance_loop_index(cur, direction, start_idx, end_idx)
		if next_idx == to_idx:
			return false
		for occupied in occupied_vertices.values():
			var occupied_data: Dictionary = occupied as Dictionary
			var occupied_idx: int = int(occupied_data.get("point_idx", -1))
			if occupied_idx == next_idx and occupied_idx != from_idx:
				return true
		cur = next_idx
	return false


func _is_drag_link_blocked(
	from_idx: int,
	to_idx: int,
	start_idx: int,
	end_idx: int,
	occupied_vertices: Dictionary
) -> bool:
	if from_idx == to_idx:
		return false
	var forward_len: float = _get_contour_distance_in_direction(from_idx, to_idx, start_idx, end_idx, 1)
	var backward_len: float = _get_contour_distance_in_direction(from_idx, to_idx, start_idx, end_idx, -1)
	if forward_len <= backward_len:
		return _path_has_blocking_occupied_point(from_idx, to_idx, start_idx, end_idx, 1, occupied_vertices)
	return _path_has_blocking_occupied_point(from_idx, to_idx, start_idx, end_idx, -1, occupied_vertices)


func _get_drag_follow_speed_factor() -> float:
	if not _is_drag_point_valid():
		return 1.0
	var speed: float = point_velocities[drag_point_idx].length()
	if speed <= DRAG_FOLLOW_SPEED_MIN:
		return DRAG_FOLLOW_MIN_FACTOR
	if speed >= DRAG_FOLLOW_SPEED_MAX:
		return 1.0
	var t: float = (speed - DRAG_FOLLOW_SPEED_MIN) / (DRAG_FOLLOW_SPEED_MAX - DRAG_FOLLOW_SPEED_MIN)
	return lerpf(DRAG_FOLLOW_MIN_FACTOR, 1.0, clampf(t, 0.0, 1.0))


func _falloff_weight_from_ratio(ratio: float) -> float:
	if ratio <= 0.0:
		return 1.0
	if ratio >= DRAG_MAX_INFLUENCE_RATIO:
		return 0.0
	var normalized: float = ratio / DRAG_MAX_INFLUENCE_RATIO
	return pow(1.0 - normalized, 2.0)


func _clamp_point_to_viewport(idx: int, lo: Vector2, hi: Vector2) -> void:
	var pos: Vector2 = _game.point_positions[idx]
	var clamped: Vector2 = pos.clamp(lo, hi)
	if not is_equal_approx(pos.x, clamped.x):
		point_velocities[idx].x = 0.0
	if not is_equal_approx(pos.y, clamped.y):
		point_velocities[idx].y = 0.0
	_game.point_positions[idx] = clamped


# =============================================================================
# Utilities
# =============================================================================

func _clamp_points_to_viewport() -> void:
	var vp: Vector2 = _game.get_viewport_rect().size
	var margin: float = _game.ui_renderer.POINT_RADIUS
	var lo := Vector2(margin, margin)
	var hi := Vector2(vp.x - margin, vp.y - margin)
	for i in range(_game.point_positions.size()):
		_game.point_positions[i] = _game.point_positions[i].clamp(lo, hi)


func _clamp_player_to_viewport() -> void:
	var vp: Vector2 = _game.get_viewport_rect().size
	var margin: float = PLAYER_RADIUS
	player_position = player_position.clamp(Vector2(margin, margin), Vector2(vp.x - margin, vp.y - margin))


func has_player_avatar() -> bool:
	return player_position_initialized


func get_player_position() -> Vector2:
	return player_position


func is_player_attracting() -> bool:
	return _get_player_force_mode() > 0


func is_player_force_active() -> bool:
	return player_force_active


func is_player_repelling() -> bool:
	return _get_player_force_mode() < 0


func get_player_focus_index(max_dist: float = PLAYER_FORCE_RADIUS) -> int:
	if not player_position_initialized:
		return -1
	return _find_point_at(player_position, max_dist)


func _find_point_at(pos: Vector2, max_dist: float = HOVER_DISTANCE) -> int:
	var best: int = -1
	var best_d: float = max_dist
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		var d: float = pos.distance_to(_game.point_positions[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func _find_closest_point(pos: Vector2) -> int:
	"""Return the closest unlocked point without a distance limit."""
	var best: int = -1
	var best_d: float = INF
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		var d: float = pos.distance_to(_game.point_positions[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func _find_point_in_direction(from_pos: Vector2, direction: Vector2) -> int:
	"""Return the closest unlocked point in the given direction."""
	var dir_n: Vector2 = direction.normalized()
	var best: int = -1
	var best_d: float = INF
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		var p: Vector2 = _game.point_positions[i]
		var delta: Vector2 = p - from_pos
		if delta.length_squared() < 1.0:
			continue
		if delta.normalized().dot(dir_n) < 0.3:
			continue
		var d: float = from_pos.distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func _is_selected(idx: int) -> bool:
	return idx in _game.selected_indices


func _is_locked(idx: int) -> bool:
	return _game.stage_manager.is_locked(idx)


func _notify_points_changed() -> void:
	if on_points_changed.is_valid():
		on_points_changed.call()


func _notify_selection_changed() -> void:
	if on_selection_changed.is_valid():
		on_selection_changed.call()


