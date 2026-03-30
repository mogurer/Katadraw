# =============================================================================
# InputHandler - プレイ中の入力処理モジュール
# =============================================================================
# マウス、ゲームパッド、ドラッグ、矩形選択、バウンディングボックスを担当。
# game の状態（point_positions, selected_indices 等）を直接更新する。

class_name InputHandler
extends RefCounted

# --- Constants ---
const HOVER_DISTANCE := 30.0
const CLICK_HIT_DISTANCE := 30.0  # クリック時: ポイント上のみヒット
const BB_ANCHOR_SIZE := 10.0
const BB_ANCHOR_HIT := 16.0
const BB_CENTER_SIZE := 9.0
const PAD_CURSOR_SPEED := 600.0
const PAD_RIGHT_STICK_SPEED := 400.0  # A+左スティックのポイント移動速度
const PAD_A_DPAD_SPEED := 266.67  # A+十字キー連続移動速度（スティック全倒しの約2/3）
const PAD_RIGHT_STICK_DEADZONE := 0.5  # 右スティック: 揺り戻し・誤検知防止のデッドゾーン
const RIGHT_STICK_REDETECT_ANGLE_DEG := 5.0  # 右スティック: 固定時の方向からこの角度以上変化で再検出（ゆっくり操作でも反応）
## レイ方向を固定したままにする許容角（これ以上スティックが動くとレイ更新）。KATA / L-R 後のピン解除にも使う
const RIGHT_STICK_RAY_PIN_BREAK_ANGLE_DEG := 15.0
## 同一レイ上に並ぶとみなす垂直距離（最良点の perp からの追加許容 px）
const RIGHT_STICK_RAY_COLLINEAR_PERP_EPS_PX := 4.0
const PAD_LEFT_STICK_NEUTRAL_DEADZONE := 0.15  # 左スティック: ニュートラル判定（これ未満で次のポイント移動を受け付ける）

# --- Callback (game が設定) ---
var on_points_changed: Callable
var on_selection_changed: Callable  # 左スティック・十字キー・LB/RBで選択ポイントが変更された時

# --- 操作中の一時状態 ---
var drag_offsets: Array[Vector2] = []
var bb_dragging: bool = false
var bb_anchor_idx: int = -1
var bb_origin: Vector2 = Vector2.ZERO
var bb_start_mouse: Vector2 = Vector2.ZERO
var bb_start_positions: Array[Vector2] = []
var bb_start_rect: Rect2 = Rect2()
var pad_cursor: Vector2 = Vector2.ZERO
var pad_cursor_initialized: bool = false
var pad_grabbing: bool = false
var _grabbing_from_right_stick: bool = false  # 右スティックでつかんでいる場合のみ、離すとリリース
var _right_stick_was_active: bool = false  # 前フレームで右スティックがデッドゾーン超えていたか
var _right_stick_release_frames: int = 0  # 右スティックがデッドゾーン以下になった連続フレーム数（誤リリース防止）
var _right_stick_dir_when_fixed: Vector2 = Vector2.ZERO  # 選択固定時の右スティック方向（累積角度で再検出判定）
var _left_stick_used_while_right_held: bool = false  # 左スティック操作で選択固定。右スティック方向変化でクリア→再検出
var _left_stick_was_neutral: bool = true  # 前フレーム終了時に左スティックがニュートラルだったか（ポイント移動は中立→傾きの1回だけ）
var _right_stick_ray_pinned: bool = false  # KATA / L-R 後はレイ方向を固定（15°以上で解除）
var _right_stick_locked_ray_dir: Vector2 = Vector2.ZERO  # 正規化。ピン中はこの方向でレイを張る
var _right_stick_last_effective_ray_dir: Vector2 = Vector2.ZERO  # process_pad 直近で使ったレイ方向（ピン時のロック値）
var _right_stick_ray_bundle: Array[int] = []  # 同一レイ上の候補（沿距離昇順）。L-R で巡回
## KATA 後: 左・十字がニュートラルかつ右スティックが ref から15°以上動くまで、自動レイ選択で掴みを変えない
var _rs_kata_grab_lock: bool = false
var _rs_kata_grab_lock_ref_dir: Vector2 = Vector2.ZERO
## L-R 後: 右15°以上動くか次のL-Rまで、自動レイ選択で選択を変えない
var _rs_lr_selection_lock: bool = false
var _rs_lr_lock_ref_dir: Vector2 = Vector2.ZERO

# つかみ状態の判定用（右スティック・A・マウスでポイントを動かせる状態か）
var grab_input_active: bool = false

# 右スティックデバッグ可視化用（process_pad で更新）
var debug_right_stick_active: bool = false
var debug_right_stick_center: Vector2 = Vector2.ZERO
var debug_right_stick_direction: Vector2 = Vector2.ZERO
var _last_input_method: String = ""  # "mouse" or "pad" - 入力切り替え検出用

# --- game 参照 ---
var _game: Node2D


func _init(game: Node2D) -> void:
	_game = game


func update_grab_state_for_mouse() -> void:
	"""マウス利用時: process_pad がスキップされるため、grab_input_active をここで更新（実現率表示用）"""
	grab_input_active = _game.is_dragging and _last_input_method == "mouse"


func release_mouse_grab() -> void:
	"""マウスクリック・ドラッグ状態を強制的に解除（two_circles で1つ目の円確定時など）"""
	_game.is_dragging = false
	_game.selected_indices.clear()
	_game.hovered_index = -1
	drag_offsets.clear()
	# パッドのつかみ状態も解除（クリア後も右スティック入力が残ると grab が再点灯するのを防ぐ）
	pad_grabbing = false
	_grabbing_from_right_stick = false
	_clear_right_stick_ray_state()
	_game.queue_redraw()


func reset_for_stage() -> void:
	"""ステージ開始時に呼び、操作中の一時状態をクリアする"""
	drag_offsets.clear()
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


func handle_mouse_motion(mouse: Vector2) -> void:
	if bb_dragging:
		_handle_bb_motion(mouse)
		_last_input_method = "mouse"
		return

	if _game.is_dragging:
		# マウス入力を検知した瞬間に、コントローラで掴んでいた状態をリリース
		if _last_input_method == "pad" or drag_offsets.size() != _game.selected_indices.size():
			_game.is_dragging = false
			pad_grabbing = false
			_last_input_method = "mouse"
			# ホバー更新へフォールスルー（下の else で処理）
		else:
			for i in range(_game.selected_indices.size()):
				var idx: int = _game.selected_indices[i]
				_game.point_positions[idx] = mouse + drag_offsets[i]
			_clamp_points_to_viewport()
			drag_offsets.clear()
			for idx in _game.selected_indices:
				drag_offsets.append(_game.point_positions[idx] - mouse)
			_notify_points_changed()
			_game.queue_redraw()
			_last_input_method = "mouse"

	else:
		var best: int = _find_point_at(mouse)
		var hover_changed: bool = (best != _game.hovered_index)
		if hover_changed:
			_game.hovered_index = best
		# マウスオーバーで選択ポイントをそこへ移動（ホバー＝選択）
		var need_select: bool = best >= 0 and (_game.selected_indices.is_empty() or _game.selected_indices[0] != best)
		if need_select:
			_game.selected_indices.clear()
			_game.selected_indices.append(best)
			_game.hovered_index = best
			_notify_selection_changed()
		if hover_changed or need_select:
			_game.queue_redraw()
		_last_input_method = "mouse"


func handle_mouse_press(mouse: Vector2) -> void:
	_last_input_method = "mouse"
	var clicked: int = _find_point_at(mouse, CLICK_HIT_DISTANCE)

	# クリックした位置にポイントがあればつかむ。なければ何もしない
	if clicked < 0:
		return
	_game.selected_indices.clear()
	_game.selected_indices.append(clicked)
	_game.hovered_index = clicked
	_notify_selection_changed()
	_begin_drag(mouse)


func _begin_drag(mouse: Vector2) -> void:
	_game.is_dragging = true
	drag_offsets.clear()
	for idx in _game.selected_indices:
		drag_offsets.append(_game.point_positions[idx] - mouse)


func handle_mouse_release(_mouse: Vector2) -> void:
	_last_input_method = "mouse"
	if bb_dragging:
		_end_bb_drag()
		return

	if _game.is_dragging:
		_game.is_dragging = false
		_notify_points_changed()
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
	var center: Vector2 = _get_selection_center()
	for idx in _game.selected_indices:
		var offset: Vector2 = _game.point_positions[idx] - center
		_game.point_positions[idx] = center + offset.rotated(angle)
	_clamp_points_to_viewport()
	_notify_points_changed()
	_game.queue_redraw()


func scale_selected(factor: float) -> void:
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
	_ensure_pad_selection()
	if not pressed:
		return
	var a_held: bool = Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	var rx: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var right_stick_held: bool = Vector2(rx, ry).length() >= PAD_RIGHT_STICK_DEADZONE
	var pad_grabbing_modifier: bool = a_held or right_stick_held
	# L/R 押下の瞬間だけ右スティックがデッドゾーン内と読まれることがある。レイ束巡回には
	# 「今スティックが倒れている」だけに依存せず、直前まで右レイ選択していた文脈も見る。
	var cur_sel: int = _game.selected_indices[0] if _game.selected_indices.size() > 0 else -1
	var sel_on_ray_bundle: bool = cur_sel >= 0 and _right_stick_ray_bundle.find(cur_sel) >= 0
	var use_ray_bundle_for_shoulder: bool = _right_stick_ray_bundle.size() >= 2 and (
		right_stick_held
		or _right_stick_was_active
		or _grabbing_from_right_stick
		or sel_on_ray_bundle
	)
	_last_input_method = "pad"
	match btn:
		JOY_BUTTON_LEFT_SHOULDER:
			if use_ray_bundle_for_shoulder:
				_cycle_ray_bundle(-1)
			else:
				_cycle_pad_point(-1)
		JOY_BUTTON_RIGHT_SHOULDER:
			if use_ray_bundle_for_shoulder:
				_cycle_ray_bundle(1)
			else:
				_cycle_pad_point(1)
		JOY_BUTTON_DPAD_UP:
			if not pad_grabbing_modifier:
				_cycle_pad_point_direction(Vector2.UP)
		JOY_BUTTON_DPAD_DOWN:
			if not pad_grabbing_modifier:
				_cycle_pad_point_direction(Vector2.DOWN)
		JOY_BUTTON_DPAD_LEFT:
			if not pad_grabbing_modifier:
				_cycle_pad_point_direction(Vector2.LEFT)
		JOY_BUTTON_DPAD_RIGHT:
			if not pad_grabbing_modifier:
				_cycle_pad_point_direction(Vector2.RIGHT)


func _ensure_pad_selection() -> void:
	"""コントローラ操作時は常に1点選択。未選択なら最寄りポイントを選択"""
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
	"""接続されている prev, next のインデックスを返す"""
	return [_get_polygon_prev(idx), _get_polygon_next(idx)]


func _get_polygon_prev(idx: int) -> int:
	"""多角形上の前のインデックス（two_circles はグループ内でループ）"""
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
	"""多角形上の次のインデックス"""
	var n: int = _game.point_positions.size()
	if _game.stage_manager.stage_type == "two_circles":
		var split: int = _game.stage_manager.group_split
		if idx < split:
			return (idx + 1) % split
		else:
			var g2: int = n - split
			return split + (idx - split + 1) % g2
	return (idx + 1) % n


func _cycle_pad_point(dir: int) -> void:
	var unlocked: Array[int] = []
	for i in range(_game.point_positions.size()):
		if not _is_locked(i):
			unlocked.append(i)
	if unlocked.is_empty():
		return
	var current_idx: int = -1
	if _game.selected_indices.size() > 0:
		current_idx = unlocked.find(_game.selected_indices[0])
	var next: int = (current_idx + dir + unlocked.size()) % unlocked.size()
	_game.selected_indices.clear()
	_game.selected_indices.append(unlocked[next])
	_game.hovered_index = unlocked[next]
	pad_cursor = _game.point_positions[unlocked[next]]
	pad_grabbing = true
	_grabbing_from_right_stick = false
	_game.is_dragging = true
	_game.queue_redraw()
	_notify_selection_changed()


func _cycle_pad_point_direction(direction: Vector2) -> void:
	"""十字キー: 入力方向から円形・両方向に走査し、最初にヒットする線の先へ切り替え
	ルール: 位置+方向→移動先。接続（prev/next）のみ対象。入力方向の角度から走査開始し、
	最も角度差が小さい接続先を選択（＝最初にヒットする線）。"""
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

	# 入力方向の角度（円形走査の開始位置）
	var input_angle: float = direction.angle()
	# 各接続先への線の角度との差が最小のものを選択（＝最初にヒット）
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


func _dpad_any_pressed() -> bool:
	return Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT)


## レイ方向に対して垂直距離が近い点を「同一レイ上」とみなし、沿距離で昇順ソートしたインデックス列
func _build_ray_collinear_bundle(origin: Vector2, dir_n: Vector2) -> Array[int]:
	var items: Array[Array] = []
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		var p: Vector2 = _game.point_positions[i]
		var delta: Vector2 = p - origin
		var along: float = delta.dot(dir_n)
		if along < 0.0:
			continue
		var perp: Vector2 = delta - along * dir_n
		var perp_dist: float = perp.length()
		items.append([i, along, perp_dist])
	if items.is_empty():
		return []
	items.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[2] as float) < (b[2] as float)
	)
	var min_p: float = items[0][2] as float
	var bundle: Array[int] = []
	for it in items:
		if (it[2] as float) <= min_p + RIGHT_STICK_RAY_COLLINEAR_PERP_EPS_PX:
			bundle.append(it[0] as int)
	bundle.sort_custom(func(a: int, b: int) -> bool:
		var a_along: float = (_game.point_positions[a] - origin).dot(dir_n)
		var b_along: float = (_game.point_positions[b] - origin).dot(dir_n)
		return a_along < b_along
	)
	return bundle


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


## レイ束（沿距離順）のインデックスで、指定ポイントに幾何的に最も近いスロットを返す（束外のとき pos=0 相当のズレを防ぐ）
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


func _cycle_ray_bundle(dir: int) -> void:
	if _right_stick_ray_bundle.size() < 2:
		return
	var cur: int = _game.selected_indices[0]
	var pos: int = _right_stick_ray_bundle.find(cur)
	if pos < 0:
		pos = _nearest_ray_bundle_slot_for_point(cur, _right_stick_ray_bundle)
	pos = (pos + dir + _right_stick_ray_bundle.size()) % _right_stick_ray_bundle.size()
	_apply_ray_selection(_right_stick_ray_bundle[pos])
	_right_stick_ray_pinned = true
	if _right_stick_last_effective_ray_dir.length_squared() > 0.0001:
		_right_stick_locked_ray_dir = _right_stick_last_effective_ray_dir
	_rs_lr_selection_lock = true
	var rsx: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var rsy: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var rsv: Vector2 = Vector2(rsx, rsy)
	if rsv.length() >= PAD_RIGHT_STICK_DEADZONE:
		_rs_lr_lock_ref_dir = rsv.normalized()
	elif _right_stick_last_effective_ray_dir.length_squared() > 0.0001:
		_rs_lr_lock_ref_dir = _right_stick_last_effective_ray_dir.normalized()
	else:
		_rs_lr_lock_ref_dir = Vector2.RIGHT


func _sync_pinned_selection_only() -> void:
	if _rs_kata_grab_lock or _rs_lr_selection_lock:
		return
	var bundle: Array[int] = _right_stick_ray_bundle
	if bundle.is_empty() or _game.selected_indices.is_empty():
		return
	var cur: int = _game.selected_indices[0]
	if bundle.find(cur) >= 0:
		return
	# 束の再計算で外れた場合は「沿距離の先頭」ではなく、直前の選択位置に最も近い束内点へ（自動レイの最良点と bundle[0] が一致しないことがある）
	var slot: int = _nearest_ray_bundle_slot_for_point(cur, bundle)
	_apply_ray_selection(bundle[slot])


func _stick_to_cardinal_direction(stick_vec: Vector2) -> Vector2:
	"""アナログスティックを上下左右のいずれかに変換。傾きが弱い場合は ZERO"""
	if stick_vec.length() < 0.15:
		return Vector2.ZERO
	if absf(stick_vec.x) > absf(stick_vec.y):
		return Vector2(signf(stick_vec.x), 0)
	else:
		return Vector2(0, signf(stick_vec.y))


func _select_point_by_direction_line(origin: Vector2, direction: Vector2) -> void:
	"""右スティック: 倒した方角に半直線を引き、その方向側で直線に最も近いポイントを選択（逆側は対象外）"""
	if direction.length_squared() < 0.0001:
		return
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
			continue  # スティックの逆側のポイントは対象外
		var perp: Vector2 = delta - along * dir_n
		var perp_dist: float = perp.length()
		if best < 0 or perp_dist < best_perp_dist or (absf(perp_dist - best_perp_dist) < 0.001 and along > best_along):
			best_perp_dist = perp_dist
			best_along = along
			best = i
	if best < 0:
		return
	_apply_ray_selection(best)
	_right_stick_ray_bundle = _build_ray_collinear_bundle(origin, dir_n)


func process_pad(delta: float) -> void:
	grab_input_active = false
	if _game.game_state != "playing" and _game.game_state != "rules":
		return
	if _game.game_state == "rules" and _game.rules_focus_button:
		return
	if _game.point_positions.is_empty():
		return
	if not pad_cursor_initialized:
		pad_cursor = _game.shape_center
		pad_cursor_initialized = true
	_ensure_pad_selection()

	var left_x: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var left_y: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var left_raw: Vector2 = Vector2(left_x, left_y)
	var left_neutral: bool = left_raw.length() < PAD_LEFT_STICK_NEUTRAL_DEADZONE
	var left_vec: Vector2 = left_raw if not left_neutral else Vector2.ZERO

	var right_x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var right_y: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var right_vec := Vector2(right_x, right_y)
	var right_active: bool = right_vec.length() >= PAD_RIGHT_STICK_DEADZONE

	var a_held: bool = Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	var pad_grabbing_modifier: bool = a_held or right_active

	# 右スティック: 重心＋レイ。ピン中はレイ方向固定（15°以上で解除）。KATA/L-R ロック中は自動選択しない。
	if right_active:
		_last_input_method = "pad"
		var current_dir: Vector2 = right_vec.normalized()
		var cos_pin_break: float = cos(deg_to_rad(RIGHT_STICK_RAY_PIN_BREAK_ANGLE_DEG))

		if _rs_kata_grab_lock and left_neutral and not _dpad_any_pressed() \
				and current_dir.dot(_rs_kata_grab_lock_ref_dir) < cos_pin_break:
			_rs_kata_grab_lock = false

		if _rs_lr_selection_lock and current_dir.dot(_rs_lr_lock_ref_dir) < cos_pin_break:
			_rs_lr_selection_lock = false

		var dir_for_ray: Vector2
		if _right_stick_ray_pinned:
			if current_dir.dot(_right_stick_locked_ray_dir) >= cos_pin_break:
				dir_for_ray = _right_stick_locked_ray_dir
			else:
				dir_for_ray = current_dir
				_right_stick_locked_ray_dir = current_dir
				_right_stick_ray_pinned = false
				_left_stick_used_while_right_held = false
		else:
			dir_for_ray = current_dir
			_right_stick_locked_ray_dir = current_dir

		_right_stick_last_effective_ray_dir = dir_for_ray

		var direction_changed: bool = true  # 初回は再検出
		if _left_stick_used_while_right_held and _right_stick_dir_when_fixed.length_squared() > 0.01:
			var dot_ls: float = current_dir.dot(_right_stick_dir_when_fixed)
			var cos5: float = cos(deg_to_rad(RIGHT_STICK_REDETECT_ANGLE_DEG))
			direction_changed = (dot_ls < cos5)
			if direction_changed:
				_left_stick_used_while_right_held = false

		var centroid := Vector2.ZERO
		var count: int = 0
		for i in range(_game.point_positions.size()):
			if not _is_locked(i):
				centroid += _game.point_positions[i]
				count += 1
		if count > 0:
			centroid /= float(count)
			debug_right_stick_active = true
			debug_right_stick_center = centroid
			debug_right_stick_direction = dir_for_ray
			_right_stick_ray_bundle = _build_ray_collinear_bundle(centroid, dir_for_ray)
			var block_auto: bool = _rs_kata_grab_lock or _rs_lr_selection_lock
			if block_auto:
				pass
			elif _right_stick_ray_pinned:
				_sync_pinned_selection_only()
			elif direction_changed or not _left_stick_used_while_right_held:
				_select_point_by_direction_line(centroid, dir_for_ray)
		else:
			debug_right_stick_active = false
		_right_stick_was_active = true
		_right_stick_release_frames = 0
		_grabbing_from_right_stick = true
	elif _right_stick_was_active:
		# L/R ショルダー押下で右スティックが一瞬デッドゾーン内に入ると、ここが連続し
		# _clear_right_stick_ray_state が走り L-R で選んだ点がレイ自動選択に戻る。ロック中はリリース判定を進めない。
		if not right_active and (_rs_lr_selection_lock or _rs_kata_grab_lock):
			_right_stick_release_frames = 0
		else:
			_right_stick_release_frames += 1
			if _right_stick_release_frames >= 2:
				_right_stick_was_active = false
				_right_stick_release_frames = 0
				_right_stick_dir_when_fixed = Vector2.ZERO
				_left_stick_used_while_right_held = false
				_clear_right_stick_ray_state()
				debug_right_stick_active = false
				if not a_held and pad_grabbing and _grabbing_from_right_stick:
					pad_grabbing = false
					_grabbing_from_right_stick = false
					_game.is_dragging = false
					_game.queue_redraw()

	# 左スティック: A/右スティック中は KATA 変形（連続移動）、それ以外はポイント移動（中立→傾きの1回だけ）
	if left_vec != Vector2.ZERO:
		_last_input_method = "pad"
		if pad_grabbing_modifier and _game.selected_indices.size() >= 1:
			var speed: float = left_vec.length() * PAD_RIGHT_STICK_SPEED * delta
			var move: Vector2 = left_vec.normalized() * speed
			for idx in _game.selected_indices:
				_game.point_positions[idx] += move
			pad_cursor = _game.point_positions[_game.selected_indices[0]]
			_clamp_points_to_viewport()
			_notify_points_changed()
			_game.queue_redraw()
			if _game.game_state != "playing" and _game.game_state != "rules":
				return
			if _grabbing_from_right_stick:
				if not _left_stick_used_while_right_held:
					_right_stick_dir_when_fixed = right_vec.normalized()
				_left_stick_used_while_right_held = true
			if right_active and _grabbing_from_right_stick and _right_stick_last_effective_ray_dir.length_squared() > 0.0001:
				_right_stick_ray_pinned = true
				_right_stick_locked_ray_dir = _right_stick_last_effective_ray_dir
				if not _rs_kata_grab_lock:
					_rs_kata_grab_lock = true
					_rs_kata_grab_lock_ref_dir = _right_stick_last_effective_ray_dir.normalized()
		else:
			if not _grabbing_from_right_stick:
				var left_cardinal: Vector2 = _stick_to_cardinal_direction(left_raw)
				if left_cardinal != Vector2.ZERO and _left_stick_was_neutral:
					_cycle_pad_point_direction(left_cardinal)

	_left_stick_was_neutral = left_neutral

	# A/右スティック選択 + 十字キー → ポイント連続移動
	if pad_grabbing_modifier and _game.selected_indices.size() >= 1:
		var dpad: Vector2 = Vector2.ZERO
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
			dpad.y -= 1
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
			dpad.y += 1
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
			dpad.x -= 1
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
			dpad.x += 1
		if dpad != Vector2.ZERO:
			_last_input_method = "pad"
			var move: Vector2 = dpad.normalized() * PAD_A_DPAD_SPEED * delta
			for idx in _game.selected_indices:
				_game.point_positions[idx] += move
			pad_cursor = _game.point_positions[_game.selected_indices[0]]
			_clamp_points_to_viewport()
			_notify_points_changed()
			_game.queue_redraw()
			if right_active and _right_stick_last_effective_ray_dir.length_squared() > 0.0001:
				_right_stick_ray_pinned = true
				_right_stick_locked_ray_dir = _right_stick_last_effective_ray_dir
			if _grabbing_from_right_stick and right_active and _right_stick_last_effective_ray_dir.length_squared() > 0.0001:
				if not _rs_kata_grab_lock:
					_rs_kata_grab_lock = true
					_rs_kata_grab_lock_ref_dir = _right_stick_last_effective_ray_dir.normalized()
			if _game.game_state != "playing" and _game.game_state != "rules":
				return

	# つかみ状態: 右スティック・A・マウスでポイントを動かせる状態か
	if _game.game_state != "playing" and _game.game_state != "rules":
		grab_input_active = false
		return
	grab_input_active = pad_grabbing_modifier or (_game.is_dragging and _last_input_method == "mouse")


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
	"""距離制限なしで最寄りのアンロックポイントを返す"""
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
	"""from_pos から direction の方向にある最寄りのポイントを返す。該当がなければ -1"""
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
