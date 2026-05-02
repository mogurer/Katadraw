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
const GUIDE_EDGE_GLIDE_RADIUS := 10.0
const GUIDE_EDGE_GLIDE_DAMPING := 22.0
const GUIDE_EDGE_SUCTION_RADIUS := 5.0
const GUIDE_EDGE_SUCTION_SPRING := 26.0
const GUIDE_EDGE_PASS_THROUGH_SPEED := 240.0
const GUIDE_EDGE_PASS_THROUGH_RATIO := 1.3
const GUIDE_EDGE_SLIDE_TRACK_SPRING := 18.0
const GUIDE_VERTEX_LOCK_RADIUS := 7.0
const GUIDE_VERTEX_LOCK_SPRING := 220.0
const GUIDE_VERTEX_LOCK_DAMPING := 30.0
const GUIDE_VERTEX_CONTACT_RELEASE_MUL := 0.35
## 「強制力」(CCW・点-辺斥力): ガイドへの最短距離がこの値より内側ほど弱く（0 で無効に近い）
const GUIDE_CONSTRAINT_SUPPRESS_DIST := GUIDE_EDGE_SNAP_RADIUS
const GUIDE_CONSTRAINT_SUPPRESS_EXP := 2.2
## ガイド上の留まり: スナップ・ロック・スライドの上乗せ（strength 1 付近での最大ブースト）
const GUIDE_STICK_VERTEX_SPRING_EXTRA := 0.62
const GUIDE_STICK_EDGE_SPRING_EXTRA := 0.48
const GUIDE_STICK_SNAP_DAMP_EXTRA := 0.58
const GUIDE_STICK_VERTEX_LOCK_SPRING_EXTRA := 0.42
const GUIDE_STICK_EDGE_GLIDE_DAMP_EXTRA := 0.45
const GUIDE_STICK_EDGE_SLIDE_TRACK_EXTRA := 0.58
## 積分後のガイド寄せ lerp を少し強める（0〜1 にクランプ）
const GUIDE_STICK_POST_LOCK_LERP_ADD := 0.10
const GUIDE_STICK_POST_EDGE_LERP_ADD := 0.12
const PLAYER_RADIUS := 16.0
const PLAYER_FORCE_RADIUS := 128.0
const PLAYER_SPEED_BOOST_PER_BUTTON := 0.35
const PLAYER_REPEL_STRENGTH := 6400.0
const PLAYER_ATTRACT_STRENGTH := 5600.0
const PLAYER_CONTACT_FORCE := 9000.0
const PLAYER_MIN_FORCE_DISTANCE := 8.0
## 辺が交差しているときの強制解消: 未ロック頂点をこの半径の円周に等間隔配置
const PLAYER_CROSS_RESOLVE_RADIUS := 64.0
const POINT_PAIR_REPULSE_DISTANCE := 64.0
const POINT_PAIR_REPULSE_STRENGTH := 2600.0
const POINT_PAIR_REPULSE_MIN_DISTANCE := 2.0
## A+X 同時長押し: 頂点同士を押し広げて周上の等間隔に近づける追加斥力（長押しで増幅、上限あり）
## 長押しは最大 3 秒で頭打ち。最大強さは旧実装（飽和時）比 2 倍。
const AX_SPACING_HOLD_CAP_MS := 3000.0
## A+X 「長押し」として均等化領域のチャージ・追加斥力などを許可するまでの最短時間（ms）。旧 0.5 は単位ズレ（0.5ms）だった。
const AX_SPACING_MIN_HOLD_BEFORE_EFFECT_MS := 500.0
## A+X 追加斥力は「多角形の辺で隣り合う頂点ペア」のみ（全ペアだと n² で描画・物理とも重い）。
## 周上の等間隔化は主に隣接間隔の調整で足りる想定。
## この距離より遠いペアには追加斥力は乗らない（大きい輪郭でも隣同士に効くよう余裕を持たせる）
const AX_SPACING_REPULSE_DISTANCE := 400.0
const AX_SPACING_REPULSE_STRENGTH := 10240.0
const AX_SPACING_REPULSE_MIN_DISTANCE := 2.0
const AX_SPACING_MAX_STRENGTH_MUL := 2.0
## 均等化半径内での滞在累積（ms）から強さ係数 0〜1 に飽和させる時間
const AX_SPACING_DWELL_RAMP_FULL_MS := 2500.0
const AX_SPACING_DWELL_ACCUM_CAP_MS := 4000.0
## 頂点と非隣接辺が近づいたときの斥力（線の交差を抑える）
const POINT_EDGE_REPULSE_DISTANCE := 56.0
const POINT_EDGE_REPULSE_STRENGTH := 3400.0
const POINT_EDGE_REPULSE_MIN_DISTANCE := 3.0
## 多角形の中心周り角順（CCW）を保ち、隣接インデックス間で cross<0 にならないよう補正（線の交差抑止）
const POLYGON_CCW_ORDER_STRENGTH := 3200.0
## 画面端（viewport）からこの距離（px）以内では、速度・モードに関係なく即座に内向き斥力
const VIEWPORT_EDGE_REPULSE_ZONE := 50.0
const PLAYFIELD_EDGE_RETURN_STRENGTH := 1500.0
const PLAYFIELD_EDGE_RETURN_REPULSE_MUL := 1.65
const PLAYFIELD_EDGE_RETURN_VEL_BOOST := 0.006
## ガイド上・斥力が法線方向に強いとき接線へ逃がして滑らせる
const GUIDE_REPEL_SLIDE_ASSIST := 0.42
## この距離以内ならプレイヤー引力・斥力でガイド拘束を弱め、剥がしやすくする（px）
const GUIDE_PEEL_DISTANCE_PX := 32.0
## peel_mul の下限（小さいほどガイドに吸い付く力が弱く剥がれやすい）。旧 0.18 から約 3 倍外れやすく
const GUIDE_PEEL_SNAP_FLOOR := 0.06
## 自キャラ中心に近いほど引力・斥力を強める（端での倍率 1、重なりに近いほど上乗せ）
const PLAYER_FORCE_PROXIMITY_BOOST := 1.55

const PLAYER_ACCEL := 2560.0
const PLAYER_VEL_FRICTION := 9.0
const PLAYER_SPEED_SOFT_CAP := 500.0
const PLAYER_SPEED_HARD_CAP := 5120.0
## 現在速度が大きいほど上限を少し上げる（移動量に応じて最高速が上がる）
const PLAYER_SPEED_CAP_VEL_BLEND := 0.42
## 左スティック／十字の連続移動: 入力を維持している間、加速度が滑らかに立ち上がる（この時間で頭打ち）
const PLAYER_MOVE_RAMP_TIME_MS := 960.0
## 立ち上がり終端での PLAYER_ACCEL 倍率（先頭は 1.0）
const PLAYER_MOVE_RAMP_ACCEL_MAX_MUL := 1.82

## この速度以下なら「静止」とみなし、引力・斥力の影響半径チャージを進める（px/秒）
const PLAYER_FORCE_CHARGE_STATIONARY_EPS := 14.0
## このフレームのマウス相対移動(px)がこれ以上ならパッドの速度に相当し「移動」とみなしチャージを止める
const PLAYER_FORCE_CHARGE_MOUSE_MOVE_PX_EPS := 2.0
## 静止中、A/X 長押しで影響半径を幾何級数的に拡張（移動中は成長停止し、既に拡がった分は維持）
const EMPTY_FORCE_RADIUS_TICK_MS := 200
const EMPTY_FORCE_RADIUS_TICK_CAP := 22
## 自キャラ〜頂点がこの距離以内かつガイド上のとき、引力・斥力でガイド吸着を無視（edge_dist が EDGE 以下＝ガイド上）
const GUIDE_ATTRACT_FREE_PROXIMITY_PX := 64.0
const GUIDE_ATTRACT_FREE_EDGE_DIST_PX := 10.0
## 自キャラが上記より遠く、かつガイド辺に乗っているときの引力・斥力: 法線を弱め接線を強めて剥がれにくく滑らせる
const PLAYER_DISTANT_ON_GUIDE_NORMAL_SCALE := 0.28
const PLAYER_DISTANT_ON_GUIDE_TANGENT_SCALE := 1.18

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

## パッド移動の速度（マウス操作時は毎フレームゼロに戻す）
var player_velocity: Vector2 = Vector2.ZERO
## 同一フレーム内の InputEventMouseMotion.relative ノルム累積（チャージ静止判定用）
var _mouse_rel_motion_for_charge: float = 0.0
## 左スティック／十字の移動入力が続いている累積時間（ms）。ニュートラルでリセット
var _pad_move_ramp_ms: float = 0.0
## 斥力ホールド中、静止していた累積時間（ms）。移動中は増えず、再静止で続きから成長
var _empty_repulse_stationary_ms: float = 0.0
## 引力ホールド中の静止累積（ms）
var _empty_attract_stationary_ms: float = 0.0
var _empty_repulse_radius_bonus: float = 0.0
var _empty_attract_radius_bonus: float = 0.0
## A+X（またはマウス左右同時）長押しで等間隔用斥力を有効にしているフレーム
var _ax_spacing_active: bool = false
var _ax_spacing_hold_ms: float = 0.0
## A+X中の静止のみで増える均等化半径（引力・斥力と同じ幾何ボーナス）
var _ax_spacing_region_stationary_ms: float = 0.0
var _ax_spacing_region_radius_bonus: float = 0.0
## A+X 中の stationary_charge が直前フレームから false→true になったとき用（移動後の再ウェイトだけに使う）
var _ax_spacing_prev_stationary_for_region: bool = true
## 上記のとき、領域チャージが再び進むまでの絶対時刻（msec）。0 のとき無効
var _ax_spacing_region_charge_suppress_until_msec: int = 0
## 均等化半径内での頂点別滞在累積（ms）。半径外へ出たフレームで 0 に戻す
var _ax_spacing_vertex_dwell_ms: Array[float] = []

# --- 空間グリッド用: 点-辺斥力の visited 世代管理 ---
## _apply_point_edge_repulsion 内での重複チェックを Dictionary 割り当てなしで行うための世代カウンタ
var _edge_repulse_gen: int = 0
## 各点インデックスが最後に処理された世代番号。_edge_repulse_gen と一致すれば処理済み
var _edge_repulse_visited: PackedInt32Array = PackedInt32Array()

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
	return player_force_attracting or player_force_repelling or player_force_active or _ax_spacing_active


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
	player_velocity = Vector2.ZERO
	_empty_repulse_stationary_ms = 0.0
	_empty_attract_stationary_ms = 0.0
	_empty_repulse_radius_bonus = 0.0
	_empty_attract_radius_bonus = 0.0
	_ax_spacing_active = false
	_ax_spacing_hold_ms = 0.0
	_ax_spacing_region_stationary_ms = 0.0
	_ax_spacing_region_radius_bonus = 0.0
	_ax_spacing_prev_stationary_for_region = true
	_ax_spacing_region_charge_suppress_until_msec = 0
	_ax_spacing_vertex_dwell_ms.clear()
	_mouse_rel_motion_for_charge = 0.0
	_pad_move_ramp_ms = 0.0
	_reset_player_position()


func _reset_player_position() -> void:
	player_position = _default_player_position()
	player_position_initialized = true


func _default_player_position() -> Vector2:
	var vp: Vector2 = _game.get_viewport_rect().size
	var margin: float = PLAYER_RADIUS
	var hi := Vector2(vp.x - margin, vp.y - margin)
	var lo := Vector2(margin, margin)
	if GameConfig.USE_SCREEN_HUD_GUIDE:
		return _game.stage_manager.hud_guide_spawn_centroid.clamp(lo, hi)
	if _game.point_positions.is_empty():
		return _game.shape_center.clamp(lo, hi)
	var c := Vector2.ZERO
	for p in _game.point_positions:
		c += p
	c /= float(_game.point_positions.size())
	return c.clamp(lo, hi)


func _refresh_hovered_point() -> void:
	_game.hovered_index = get_player_focus_index(HOVER_DISTANCE)


func handle_mouse_motion(mouse: Vector2, motion_relative: Vector2 = Vector2.ZERO) -> void:
	if bb_dragging:
		_mouse_rel_motion_for_charge += motion_relative.length()
		_handle_bb_motion(mouse)
		return
	_mouse_rel_motion_for_charge += motion_relative.length()
	player_position = mouse
	player_position_initialized = true
	player_velocity = Vector2.ZERO
	player_has_motion_input = false
	_last_input_method = "mouse"
	_refresh_hovered_point()
	_game.queue_redraw()


func handle_mouse_press(mouse: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	_last_input_method = "mouse"
	player_position = mouse
	player_position_initialized = true
	player_velocity = Vector2.ZERO
	if button == MOUSE_BUTTON_LEFT:
		player_force_repelling = true
		player_force_attracting = false
	elif button == MOUSE_BUTTON_RIGHT:
		player_force_attracting = true
		player_force_repelling = false
	else:
		return
	mouse_force_pressed = true
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


func handle_mouse_release(_mouse: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	_last_input_method = "mouse"
	if bb_dragging:
		_end_bb_drag()
		return

	if button == MOUSE_BUTTON_LEFT:
		player_force_repelling = false
	elif button == MOUSE_BUTTON_RIGHT:
		player_force_attracting = false
	mouse_force_pressed = player_force_attracting or player_force_repelling
	grab_input_active = mouse_force_pressed or player_force_active
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
		player_force_repelling = pressed
	elif btn == JOY_BUTTON_X:
		player_force_attracting = pressed
	elif btn == JOY_BUTTON_B and pressed:
		player_force_repelling = false
		player_force_attracting = false
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
	return _game.get_polygon_prev_vertex_index(idx)


func _get_polygon_next(idx: int) -> int:
	"""Get next index on the polygon loop."""
	return _game.get_polygon_next_vertex_index(idx)


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
		_empty_repulse_stationary_ms = 0.0
		_empty_attract_stationary_ms = 0.0
		_ax_spacing_active = false
		_ax_spacing_hold_ms = 0.0
		_ax_spacing_region_stationary_ms = 0.0
		_ax_spacing_region_radius_bonus = 0.0
		_ax_spacing_prev_stationary_for_region = true
		_ax_spacing_region_charge_suppress_until_msec = 0
		_pad_move_ramp_ms = 0.0
		return
	if _game.game_state == "rules" and _game.rules_focus_button:
		player_has_motion_input = false
		player_force_attracting = false
		player_force_repelling = false
		grab_input_active = false
		_empty_repulse_stationary_ms = 0.0
		_empty_attract_stationary_ms = 0.0
		_ax_spacing_active = false
		_ax_spacing_hold_ms = 0.0
		_ax_spacing_region_stationary_ms = 0.0
		_ax_spacing_region_radius_bonus = 0.0
		_ax_spacing_prev_stationary_for_region = true
		_ax_spacing_region_charge_suppress_until_msec = 0
		_pad_move_ramp_ms = 0.0
		return
	if _game.point_positions.is_empty():
		player_has_motion_input = false
		player_force_attracting = false
		player_force_repelling = false
		grab_input_active = false
		_empty_repulse_stationary_ms = 0.0
		_empty_attract_stationary_ms = 0.0
		_ax_spacing_active = false
		_ax_spacing_hold_ms = 0.0
		_ax_spacing_region_stationary_ms = 0.0
		_ax_spacing_region_radius_bonus = 0.0
		_ax_spacing_prev_stationary_for_region = true
		_ax_spacing_region_charge_suppress_until_msec = 0
		_pad_move_ramp_ms = 0.0
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

	var pad_a: bool = Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	var pad_x: bool = Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	var pad_lb: bool = Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER)
	var pad_rb: bool = Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)
	var pad_b: bool = Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	var mouse_left: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mouse_right: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	_ax_spacing_active = false

	if pad_b:
		player_force_repelling = false
		player_force_attracting = false
	elif (
		_game.game_state == "rules"
		and _game.get_rules_next_button_rect().has_point(player_position)
		and pad_a
	):
		# [つぎへ] 上では A は遷移用 — 斥力にしない
		player_force_repelling = false
		player_force_attracting = false
	elif (
		_game.game_state == "playing"
		and not pad_b
		and ((pad_a and pad_x) or (mouse_left and mouse_right))
	):
		# A+X 同時（またはマウス左右同時）: 自キャラ引力・斥力はオフにし、頂点間斥力のみ
		_ax_spacing_active = true
		player_force_repelling = false
		player_force_attracting = false
	else:
		player_force_repelling = pad_a
		player_force_attracting = pad_x
		# マウス左右は毎フレームここでも維持する。上の代入は「パッドの A/X が押されていない」とき 0 になり、
		# handle_mouse_press だけでは次の _process で力が消える（コントローラ操作後にマウスが効かない原因）。
		if mouse_left and not mouse_right:
			player_force_repelling = true
			player_force_attracting = false
		elif mouse_right and not mouse_left:
			player_force_attracting = true
			player_force_repelling = false

	if pad_b:
		player_force_repelling = false
		player_force_attracting = false
		_ax_spacing_active = false

	if _ax_spacing_active:
		_ax_spacing_hold_ms = minf(_ax_spacing_hold_ms + delta * 1000.0, AX_SPACING_HOLD_CAP_MS)
	else:
		_ax_spacing_hold_ms = 0.0

	mouse_force_pressed = mouse_left or mouse_right

	var in_play_ef: bool = _game.game_state == "playing" or _game.game_state == "rules"
	var max_charge_ms: float = float(EMPTY_FORCE_RADIUS_TICK_CAP - 1) * float(EMPTY_FORCE_RADIUS_TICK_MS)

	var speed_mul: float = _get_player_speed_multiplier()
	var moved: bool = false
	var wish: Vector2 = Vector2.ZERO
	if move_vec.length_squared() > 0.0001:
		wish = move_vec.normalized() * pow(clampf(move_vec.length(), 0.0, 1.0), PAD_LEFT_STICK_SPEED_EXPONENT)
	if dpad != Vector2.ZERO:
		var ddn: Vector2 = dpad.normalized()
		wish = ddn if wish.length_squared() < 0.0001 else (wish + ddn).normalized()
	if wish.length_squared() > 0.0001:
		_pad_move_ramp_ms = minf(_pad_move_ramp_ms + delta * 1000.0, PLAYER_MOVE_RAMP_TIME_MS)
		var u: float = clampf(_pad_move_ramp_ms / maxf(PLAYER_MOVE_RAMP_TIME_MS, 1.0), 0.0, 1.0)
		var su: float = u * u * (3.0 - 2.0 * u)
		var ramp_mul: float = lerpf(1.0, PLAYER_MOVE_RAMP_ACCEL_MAX_MUL, su)
		player_velocity += wish * (PLAYER_ACCEL * delta * speed_mul * ramp_mul)
		var sp: float = player_velocity.length()
		var cap: float = lerpf(
			PLAYER_SPEED_SOFT_CAP,
			PLAYER_SPEED_HARD_CAP,
			clampf(sp * PLAYER_SPEED_CAP_VEL_BLEND / maxf(PLAYER_SPEED_HARD_CAP, 1.0), 0.0, 1.0)
		)
		cap = minf(cap, PLAYER_SPEED_HARD_CAP)
		if sp > cap:
			player_velocity *= cap / sp
		moved = true
	else:
		_pad_move_ramp_ms = 0.0
		player_velocity *= exp(-PLAYER_VEL_FRICTION * delta)

	# 静止判定: パッド速度に加え、このフレームのマウス相対移動が大きいときも「移動」（マウスは毎フレーム velocity が 0 に戻るため）
	var mouse_moved_for_charge: bool = _mouse_rel_motion_for_charge >= PLAYER_FORCE_CHARGE_MOUSE_MOVE_PX_EPS
	_mouse_rel_motion_for_charge = 0.0
	var stationary_charge: bool = (
		player_velocity.length() <= PLAYER_FORCE_CHARGE_STATIONARY_EPS
		and not mouse_moved_for_charge
	)

	# 静止中のみ引力・斥力の影響半径が成長。移動中は成長停止し、既に拡がった分は維持（速度更新後と同一基準）
	_empty_repulse_radius_bonus = 0.0
	_empty_attract_radius_bonus = 0.0
	if in_play_ef:
		if player_force_repelling:
			if stationary_charge:
				_empty_repulse_stationary_ms = minf(
					_empty_repulse_stationary_ms + delta * 1000.0,
					max_charge_ms
				)
			var tr_f: float = 1.0 + _empty_repulse_stationary_ms / float(EMPTY_FORCE_RADIUS_TICK_MS)
			tr_f = minf(tr_f, float(EMPTY_FORCE_RADIUS_TICK_CAP))
			_empty_repulse_radius_bonus = _force_radius_bonus_smooth(tr_f)
		else:
			_empty_repulse_stationary_ms = 0.0
		if player_force_attracting:
			if stationary_charge:
				_empty_attract_stationary_ms = minf(
					_empty_attract_stationary_ms + delta * 1000.0,
					max_charge_ms
				)
			var ta_f: float = 1.0 + _empty_attract_stationary_ms / float(EMPTY_FORCE_RADIUS_TICK_MS)
			ta_f = minf(ta_f, float(EMPTY_FORCE_RADIUS_TICK_CAP))
			_empty_attract_radius_bonus = _force_radius_bonus_smooth(ta_f)
		else:
			_empty_attract_stationary_ms = 0.0
	else:
		_empty_repulse_stationary_ms = 0.0
		_empty_attract_stationary_ms = 0.0

	# A+X 均等化領域: 上記と同じ stationary_charge。ホールド閾値・移動→再静止での再ウェイトは A 初回長押しと同程度に揃える。
	if in_play_ef and _ax_spacing_active:
		if stationary_charge and not _ax_spacing_prev_stationary_for_region:
			if _ax_spacing_hold_ms >= AX_SPACING_MIN_HOLD_BEFORE_EFFECT_MS:
				_ax_spacing_region_charge_suppress_until_msec = (
					Time.get_ticks_msec()
					+ int(AX_SPACING_MIN_HOLD_BEFORE_EFFECT_MS)
				)
		_ax_spacing_prev_stationary_for_region = stationary_charge

		var hold_ok_region: bool = _ax_spacing_hold_ms >= AX_SPACING_MIN_HOLD_BEFORE_EFFECT_MS
		var region_suppressed: bool = (
			stationary_charge
			and Time.get_ticks_msec() < _ax_spacing_region_charge_suppress_until_msec
		)
		var can_charge_ax_region: bool = stationary_charge and hold_ok_region and not region_suppressed
		if can_charge_ax_region:
			_ax_spacing_region_stationary_ms = minf(
				_ax_spacing_region_stationary_ms + delta * 1000.0,
				max_charge_ms
			)
		var tr_ax: float = 1.0 + _ax_spacing_region_stationary_ms / float(EMPTY_FORCE_RADIUS_TICK_MS)
		tr_ax = minf(tr_ax, float(EMPTY_FORCE_RADIUS_TICK_CAP))
		_ax_spacing_region_radius_bonus = _force_radius_bonus_smooth(tr_ax)
	else:
		_ax_spacing_region_stationary_ms = 0.0
		_ax_spacing_region_radius_bonus = 0.0
		_ax_spacing_prev_stationary_for_region = stationary_charge
		_ax_spacing_region_charge_suppress_until_msec = 0

	player_position += player_velocity * delta
	if wish.length_squared() > 0.0001 or player_velocity.length_squared() > 3600.0:
		moved = true

	player_has_motion_input = moved
	if not _game.selected_indices.is_empty():
		_game.selected_indices.clear()
	if moved:
		_clamp_player_to_viewport()
		_last_input_method = "pad"
		_game.queue_redraw()
	_refresh_hovered_point()
	grab_input_active = (
		_get_player_force_mode() != 0
		or player_force_active
		or _ax_spacing_active
	)
	_game.is_dragging = false


# =============================================================================
# Drag Physics
# =============================================================================

func _sync_point_indices_to_centroid_polygon_order() -> void:
	_game.rebuild_polygon_walk_order_centroid_angular()
	if not _game.is_polygon_walk_order_active():
		return
	var ord_perm: PackedInt32Array = _game.polygon_walk_order.duplicate()
	_game.apply_vertex_permutation_reorder_positions_from_walk_order()
	_permute_input_state_after_vertex_reorder(ord_perm)


func update_drag_physics(delta: float) -> void:
	_ensure_drag_state_arrays()
	if not player_position_initialized:
		_reset_player_position()
	if (
		not player_force_active
		and not _has_points_within_player_force()
		and not _has_active_point_velocity()
		and not _ax_spacing_active
	):
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

	var vp: Vector2 = _game.get_viewport_rect().size
	var margin: float = _game.ui_renderer.POINT_RADIUS
	var lo := Vector2(margin, margin)
	var hi := Vector2(vp.x - margin, vp.y - margin)

	var before: Array[Vector2] = _game.point_positions.duplicate()

	_ensure_drag_state_arrays()
	_update_ax_spacing_vertex_dwell(delta)

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
			player_force = _remap_player_force_when_distant_on_guide(i, nearest_features[i], player_force)
			forces[i] += player_force
			player_influenced_point_count += 1
	# 空間グリッドを1回だけ構築して pair/edge 両方の斥力計算で使い回す
	var _pos_grid: Dictionary = _build_position_grid(POINT_PAIR_REPULSE_DISTANCE)
	_apply_point_pair_repulsion(forces, _pos_grid)
	if _ax_spacing_active and _ax_spacing_hold_ms >= AX_SPACING_MIN_HOLD_BEFORE_EFFECT_MS:
		_apply_ax_spacing_equal_spacing_repulsion(forces)
	var guide_constraint_mul: PackedFloat32Array = _build_guide_constraint_mul_array(nearest_features)
	_apply_point_edge_repulsion(forces, _pos_grid, guide_constraint_mul)
	_apply_polygon_ccw_order_constraint(forces, guide_constraint_mul)
	_apply_guide_snap_and_repulsion(forces, nearest_features, vertex_locks)
	_constrain_forces_for_edge_slide(forces, nearest_features, vertex_locks)
	_apply_playfield_edge_return_forces(forces, lo, hi)
	player_force_active = player_influenced_point_count > 0
	grab_input_active = (
		player_force_active
		or _get_player_force_mode() != 0
		or _ax_spacing_active
	)

	var damping: float = exp(-DRAG_VELOCITY_DAMPING * delta)

	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			point_velocities[i] = Vector2.ZERO
			continue
		point_velocities[i] += forces[i] * delta
		point_velocities[i] *= damping
		_game.point_positions[i] += point_velocities[i] * delta
		_clamp_point_to_viewport(i, lo, hi)

	if not guide_loops.is_empty():
		var post_features: Array = _compute_nearest_guide_features(guide_loops)
		_apply_post_move_guide_constraints(post_features, vertex_locks)

	var topology_changed: bool = false
	if _polygon_edges_have_interior_intersection() and _has_any_unlocked_polygon_vertex():
		topology_changed = true
		_resolve_intersections_2opt(lo, hi)

	if not player_force_active and not _has_active_point_velocity():
		_zero_all_point_velocities()

	for i in range(_game.point_positions.size()):
		if before[i].distance_squared_to(_game.point_positions[i]) > DRAG_POSITION_EPSILON * DRAG_POSITION_EPSILON:
			return true
	if topology_changed:
		return true
	return false


## rebuild で得た walk 順を point_positions に焼いたあと、速度・選択・ガイド距離など index 連動状態を同じ置換で追従する
func _permute_input_state_after_vertex_reorder(ord: PackedInt32Array) -> void:
	var n: int = ord.size()
	if n == 0:
		return
	var inv: PackedInt32Array = PackedInt32Array()
	inv.resize(n)
	for new_i in range(n):
		inv[ord[new_i]] = new_i
	_ensure_drag_state_arrays()
	var new_vel: Array[Vector2] = []
	new_vel.resize(n)
	for i in range(n):
		new_vel[i] = point_velocities[ord[i]]
	for i in range(n):
		point_velocities[i] = new_vel[i]
	if point_stop_frames.size() == n:
		var new_sf: Array[int] = []
		new_sf.resize(n)
		for i in range(n):
			new_sf[i] = point_stop_frames[ord[i]]
		for i in range(n):
			point_stop_frames[i] = new_sf[i]
	if drag_point_idx >= 0 and drag_point_idx < n:
		drag_point_idx = inv[drag_point_idx]
	if drag_angle_prev_idx >= 0 and drag_angle_prev_idx < n:
		drag_angle_prev_idx = inv[drag_angle_prev_idx]
	if drag_angle_next_idx >= 0 and drag_angle_next_idx < n:
		drag_angle_next_idx = inv[drag_angle_next_idx]
	if _game.hovered_index >= 0 and _game.hovered_index < n:
		_game.hovered_index = inv[_game.hovered_index]
	for si in range(_game.selected_indices.size()):
		var oi: int = _game.selected_indices[si]
		if oi >= 0 and oi < n:
			_game.selected_indices[si] = inv[oi]
	for bi in range(_right_stick_ray_bundle.size()):
		var oi2: int = _right_stick_ray_bundle[bi]
		if oi2 >= 0 and oi2 < n:
			_right_stick_ray_bundle[bi] = inv[oi2]
	if drag_start_positions.size() == n:
		var new_ds: Array[Vector2] = []
		new_ds.resize(n)
		for i in range(n):
			new_ds[i] = drag_start_positions[ord[i]]
		drag_start_positions.clear()
		for i in range(n):
			drag_start_positions.append(new_ds[i])
	if drag_influence_weights.size() == n:
		var new_w: Array[float] = []
		new_w.resize(n)
		for i in range(n):
			new_w[i] = drag_influence_weights[ord[i]]
		drag_influence_weights.clear()
		for i in range(n):
			drag_influence_weights.append(new_w[i])
	_game.ui_renderer.permute_guide_point_distances_for_vertex_reorder(ord)


func _get_effective_player_force_limit() -> float:
	var bonus: float = 0.0
	var fm: int = _get_player_force_mode()
	if fm > 0:
		bonus = _empty_attract_radius_bonus
	elif fm < 0:
		bonus = _empty_repulse_radius_bonus
	return PLAYER_FORCE_RADIUS + _game.ui_renderer.POINT_RADIUS + bonus


func _is_guide_snap_bypassed_by_player_force(point_idx: int, feature: Dictionary) -> bool:
	if _get_player_force_mode() == 0:
		return false
	if point_idx < 0 or point_idx >= _game.point_positions.size():
		return false
	if player_position.distance_to(_game.point_positions[point_idx]) > GUIDE_ATTRACT_FREE_PROXIMITY_PX:
		return false
	var ed: float = feature.get("edge_dist", INF) as float
	return ed <= GUIDE_ATTRACT_FREE_EDGE_DIST_PX


func _remap_player_force_when_distant_on_guide(point_idx: int, feature: Dictionary, pf: Vector2) -> Vector2:
	if pf.length_squared() < 0.0001:
		return pf
	if player_position.distance_to(_game.point_positions[point_idx]) <= GUIDE_ATTRACT_FREE_PROXIMITY_PX:
		return pf
	var edge_dist: float = feature.get("edge_dist", INF) as float
	if edge_dist >= GUIDE_EDGE_GLIDE_RADIUS:
		return pf
	var pos: Vector2 = _game.point_positions[point_idx]
	var tangent: Vector2 = _feature_edge_tangent(feature)
	var normal: Vector2 = _feature_edge_normal(feature, pos)
	var fn: float = pf.dot(normal)
	var ft: float = pf.dot(tangent)
	return tangent * (ft * PLAYER_DISTANT_ON_GUIDE_TANGENT_SCALE) + normal * (fn * PLAYER_DISTANT_ON_GUIDE_NORMAL_SCALE)


func _compute_player_force(point_idx: int) -> Vector2:
	var force_mode: int = _get_player_force_mode()
	if force_mode == 0:
		return Vector2.ZERO
	var point_pos: Vector2 = _game.point_positions[point_idx]
	var from_player: Vector2 = point_pos - player_position
	var dist: float = maxf(from_player.length(), PLAYER_MIN_FORCE_DISTANCE)
	var influence_limit: float = _get_effective_player_force_limit()
	if dist > influence_limit:
		return Vector2.ZERO
	var falloff: float = 1.0 - dist / influence_limit
	var direction: Vector2 = from_player / dist
	if force_mode > 0:
		direction = -direction
	var base_strength: float = PLAYER_ATTRACT_STRENGTH if force_mode > 0 else PLAYER_REPEL_STRENGTH
	var force: Vector2 = direction * (base_strength * falloff * falloff)
	# 自キャラに近いほど強い（中心付近で最大約 (1+PROXIMITY_BOOST) 倍）
	var prox_t: float = clampf(1.0 - dist / influence_limit, 0.0, 1.0)
	force *= 1.0 + PLAYER_FORCE_PROXIMITY_BOOST * prox_t * prox_t
	if _is_player_touching_point(point_idx):
		force += direction * PLAYER_CONTACT_FORCE
	return force


func _is_player_touching_point(point_idx: int) -> bool:
	if point_idx < 0 or point_idx >= _game.point_positions.size():
		return false
	var contact_radius: float = PLAYER_RADIUS + _game.ui_renderer.POINT_RADIUS
	return player_position.distance_to(_game.point_positions[point_idx]) <= contact_radius


func _force_radius_geometric_step_sum(ticks: int) -> float:
	# ティックごとの加算が +2,+4,+8,… のとき、ticks 回分の累計 = sum_{i=1}^{ticks} 2^i = 2^(ticks+1) - 2
	if ticks <= 0:
		return 0.0
	var t: int = mini(ticks, EMPTY_FORCE_RADIUS_TICK_CAP)
	return pow(2.0, float(t + 1)) - 2.0


## 0.2s 相当の段を連続化（隣接段の累計値を線形補間）
func _force_radius_bonus_smooth(tr_float: float) -> float:
	if tr_float <= 0.0:
		return 0.0
	var tf: float = minf(tr_float, float(EMPTY_FORCE_RADIUS_TICK_CAP))
	var lo: int = int(floor(tf))
	var hi: int = int(ceil(tf))
	var alpha: float = tf - float(lo)
	return lerpf(
		_force_radius_geometric_step_sum(lo),
		_force_radius_geometric_step_sum(hi),
		alpha
	)


func _build_position_grid(cell_size: float) -> Dictionary:
	"""現在の point_positions を cell_size のグリッドに登録して返す。
	各セルは Vector2i キーに対して点インデックスの Array を持つ。
	pair/edge 斥力の O(n²) → O(n) 化に使う。"""
	var grid: Dictionary = {}
	var inv: float = 1.0 / cell_size
	for i in range(_game.point_positions.size()):
		var p: Vector2 = _game.point_positions[i]
		var key: Vector2i = Vector2i(int(floor(p.x * inv)), int(floor(p.y * inv)))
		if not grid.has(key):
			grid[key] = []
		(grid[key] as Array).append(i)
	return grid


func _apply_point_pair_repulsion(forces: Array[Vector2], grid: Dictionary) -> void:
	"""グリッドで近傍セル（3×3）のみ確認して点間斥力を適用。O(n²) → O(n)。"""
	var n_vert: int = _game.point_positions.size()
	var thr: float = POINT_PAIR_REPULSE_DISTANCE
	var threshold_sq: float = thr * thr
	var inv: float = 1.0 / thr  # cell_size == thr なので 1セル分が閾値半径に対応
	for i in range(n_vert):
		if _is_locked(i):
			continue
		var pi: Vector2 = _game.point_positions[i]
		var cx: int = int(floor(pi.x * inv))
		var cy: int = int(floor(pi.y * inv))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var key: Vector2i = Vector2i(cx + dx, cy + dy)
				if not grid.has(key):
					continue
				for j in (grid[key] as Array):
					if j <= i:
						continue  # 対称ペアの重複を回避
					if _is_locked(j):
						continue
					var delta: Vector2 = _game.point_positions[j] - pi
					var dist_sq: float = delta.length_squared()
					if dist_sq > threshold_sq:
						continue
					var dist: float = maxf(sqrt(dist_sq), POINT_PAIR_REPULSE_MIN_DISTANCE)
					var falloff: float = 1.0 - dist / thr
					var dir: Vector2 = delta / dist
					var force: Vector2 = dir * (POINT_PAIR_REPULSE_STRENGTH * falloff * falloff)
					forces[i] -= force
					forces[j] += force


## ワールド座標の2頂点間。戻りは i→j 方向の斥力ベクトル（i に -v、j に +v を足す用）
func _ax_spacing_pair_repulsion_force(pi: Vector2, pj: Vector2, strength_mul: float) -> Vector2:
	var delta_v: Vector2 = pj - pi
	var thr: float = AX_SPACING_REPULSE_DISTANCE
	var dist_sq: float = delta_v.length_squared()
	if dist_sq > thr * thr:
		return Vector2.ZERO
	var dist: float = maxf(sqrt(dist_sq), AX_SPACING_REPULSE_MIN_DISTANCE)
	var falloff: float = 1.0 - dist / thr
	var dir: Vector2 = delta_v / dist
	return dir * (AX_SPACING_REPULSE_STRENGTH * strength_mul * falloff * falloff)


## A+X 均等化が効く半径（`_get_effective_player_force_limit` と同形: 基準＋引力・斥力と同じ静止チャージボーナス）
func get_ax_spacing_equalization_radius() -> float:
	return PLAYER_FORCE_RADIUS + _game.ui_renderer.POINT_RADIUS + _ax_spacing_region_radius_bonus


func _ax_spacing_dwell_weight(ms: float) -> float:
	if ms <= 0.001:
		return 0.0
	var t: float = clampf(ms / maxf(AX_SPACING_DWELL_RAMP_FULL_MS, 1.0), 0.0, 1.0)
	return t * t


func _ax_spacing_edge_dwell_multiplier(i: int, j: int, i_in: bool, j_in: bool) -> float:
	if not i_in and not j_in:
		return 0.0
	var wi: float = _ax_spacing_dwell_weight(_ax_spacing_vertex_dwell_ms[i]) if i_in else 0.0
	var wj: float = _ax_spacing_dwell_weight(_ax_spacing_vertex_dwell_ms[j]) if j_in else 0.0
	var m: float
	if wi > 0.001 and wj > 0.001:
		m = sqrt(wi * wj)
	elif wi > 0.001:
		m = wi
	elif wj > 0.001:
		m = wj
	else:
		return 0.0
	return m * AX_SPACING_MAX_STRENGTH_MUL


func _update_ax_spacing_vertex_dwell(delta_sec: float) -> void:
	_ensure_drag_state_arrays()
	if not _ax_spacing_active:
		for k in range(_ax_spacing_vertex_dwell_ms.size()):
			_ax_spacing_vertex_dwell_ms[k] = 0.0
		return
	var R: float = get_ax_spacing_equalization_radius()
	var rsq: float = R * R
	var pp: Vector2 = player_position
	var dm: float = delta_sec * 1000.0
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			_ax_spacing_vertex_dwell_ms[i] = 0.0
			continue
		var inside: bool = pp.distance_squared_to(_game.point_positions[i]) <= rsq
		if inside:
			_ax_spacing_vertex_dwell_ms[i] = minf(_ax_spacing_vertex_dwell_ms[i] + dm, AX_SPACING_DWELL_ACCUM_CAP_MS)
		else:
			_ax_spacing_vertex_dwell_ms[i] = 0.0


func is_ax_spacing_mode_active() -> bool:
	return _ax_spacing_active


func get_ax_spacing_hold_ms() -> float:
	return _ax_spacing_hold_ms


## 多角形の辺（walk 順またはインデックス順）のワールド座標端点。可視化フォールバック用
func get_polygon_loop_edge_endpoints_world() -> Array:
	var out: Array = []
	var edges: Array[Vector2i] = _get_polygon_edges_for_repulsion()
	for e: Vector2i in edges:
		var ia: int = e.x
		var ib: int = e.y
		if ia < 0 or ib < 0 or ia >= _game.point_positions.size() or ib >= _game.point_positions.size():
			continue
		out.append({"from": _game.point_positions[ia], "to": _game.point_positions[ib]})
	return out


func get_ax_spacing_repulsion_debug_segments() -> Array:
	"""描画用: A+X 等間隔斥力が作用する辺ごとに { from, to, magnitude }（ワールド座標）"""
	var out: Array = []
	if not _ax_spacing_active or _ax_spacing_hold_ms < AX_SPACING_MIN_HOLD_BEFORE_EFFECT_MS:
		return out
	var R: float = get_ax_spacing_equalization_radius()
	var rsq: float = R * R
	var pp: Vector2 = player_position
	var edges: Array[Vector2i] = _get_polygon_edges_for_repulsion()
	for e in edges:
		var i: int = e.x
		var j: int = e.y
		if _is_locked(i) or _is_locked(j):
			continue
		var pi: Vector2 = _game.point_positions[i]
		var pj: Vector2 = _game.point_positions[j]
		var i_in: bool = pp.distance_squared_to(pi) <= rsq
		var j_in: bool = pp.distance_squared_to(pj) <= rsq
		if not i_in and not j_in:
			continue
		var em: float = _ax_spacing_edge_dwell_multiplier(i, j, i_in, j_in)
		if em < 0.001:
			continue
		var fvec: Vector2 = _ax_spacing_pair_repulsion_force(pi, pj, em)
		var mag: float = fvec.length()
		if mag < 0.05:
			continue
		out.append({"from": pi, "to": pj, "magnitude": mag})
	return out


func _apply_ax_spacing_equal_spacing_repulsion(forces: Array[Vector2]) -> void:
	"""自キャラ中心半径内／滞在時間でゲートされた辺隣接ペアのみ、既存のアルゴで斥力追加。"""
	var R: float = get_ax_spacing_equalization_radius()
	var rsq: float = R * R
	var pp: Vector2 = player_position
	_ensure_drag_state_arrays()
	var edges: Array[Vector2i] = _get_polygon_edges_for_repulsion()
	for e in edges:
		var i: int = e.x
		var j: int = e.y
		if _is_locked(i) or _is_locked(j):
			continue
		var pi: Vector2 = _game.point_positions[i]
		var pj: Vector2 = _game.point_positions[j]
		var i_in: bool = pp.distance_squared_to(pi) <= rsq
		var j_in: bool = pp.distance_squared_to(pj) <= rsq
		if not i_in and not j_in:
			continue
		var strength_mul: float = _ax_spacing_edge_dwell_multiplier(i, j, i_in, j_in)
		if strength_mul < 0.001:
			continue
		var fvec: Vector2 = _ax_spacing_pair_repulsion_force(pi, pj, strength_mul)
		if fvec.length_squared() < 1e-12:
			continue
		forces[i] -= fvec
		forces[j] += fvec


## ガイド（辺・頂点の近傍）にいるほど CCW・点-辺斥力を弱める。1=そのまま、0=ほぼ無効
func _guide_constraint_force_mul(feature: Dictionary) -> float:
	var edge_dist: float = feature.get("edge_dist", INF) as float
	var vertex_dist: float = feature.get("vertex_dist", INF) as float
	var d: float = minf(edge_dist, vertex_dist)
	if d >= GUIDE_CONSTRAINT_SUPPRESS_DIST:
		return 1.0
	var t: float = clampf(d / maxf(GUIDE_CONSTRAINT_SUPPRESS_DIST, 0.001), 0.0, 1.0)
	return pow(t, GUIDE_CONSTRAINT_SUPPRESS_EXP)


func _build_guide_constraint_mul_array(nearest_features: Array) -> PackedFloat32Array:
	var n: int = nearest_features.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		out[i] = _guide_constraint_force_mul(nearest_features[i] as Dictionary)
	return out


## UIRenderer 等から多角形の辺（均等化 UI 用）を参照する場合
func get_polygon_edges_for_repulsion() -> Array[Vector2i]:
	return _get_polygon_edges_for_repulsion()


func _get_polygon_edges_for_repulsion() -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	var n: int = _game.point_positions.size()
	if n < 3:
		return edges
	if _game.is_polygon_walk_order_active():
		var ord: PackedInt32Array = _game.polygon_walk_order
		for k in range(n):
			edges.append(Vector2i(ord[k], ord[(k + 1) % n]))
		return edges
	for i in range(n):
		edges.append(Vector2i(i, (i + 1) % n))
	return edges


func _polygon_edges_share_vertex(e1: Vector2i, e2: Vector2i) -> bool:
	return e1.x == e2.x or e1.x == e2.y or e1.y == e2.x or e1.y == e2.y


func _segment_intersect_strict_interior(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	var r: Vector2 = a2 - a1
	var s: Vector2 = b2 - b1
	var rxs: float = r.x * s.y - r.y * s.x
	var qp: Vector2 = b1 - a1
	if absf(rxs) < 1e-12:
		return false
	var t: float = (qp.x * s.y - qp.y * s.x) / rxs
	var u: float = (qp.x * r.y - qp.y * r.x) / rxs
	const eps: float = 1e-4
	return t > eps and t < 1.0 - eps and u > eps and u < 1.0 - eps


func _polygon_edges_have_interior_intersection() -> bool:
	var edges: Array[Vector2i] = _get_polygon_edges_for_repulsion()
	var n_edges: int = edges.size()
	if n_edges < 4:
		return false
	for ii in range(n_edges):
		var e1: Vector2i = edges[ii]
		var p1: Vector2 = _game.point_positions[e1.x]
		var p2: Vector2 = _game.point_positions[e1.y]
		for jj in range(ii + 1, n_edges):
			var e2: Vector2i = edges[jj]
			if _polygon_edges_share_vertex(e1, e2):
				continue
			var p3: Vector2 = _game.point_positions[e2.x]
			var p4: Vector2 = _game.point_positions[e2.y]
			if _segment_intersect_strict_interior(p1, p2, p3, p4):
				return true
	return false


func _has_any_unlocked_polygon_vertex() -> bool:
	for i in range(_game.point_positions.size()):
		if not _is_locked(i):
			return true
	return false


func _resolve_polygon_edge_intersection_circle_around_player(lo: Vector2, hi: Vector2) -> void:
	var n: int = _game.point_positions.size()
	if n < 3:
		return
	var R: float = PLAYER_CROSS_RESOLVE_RADIUS
	for i in range(n):
		if _is_locked(i):
			continue
		var ang: float = TAU * float(i) / float(n)
		var pos: Vector2 = player_position + Vector2(cos(ang), sin(ang)) * R
		_game.point_positions[i] = pos.clamp(lo, hi)
		point_velocities[i] = Vector2.ZERO


## 最初に見つかった内部交差辺ペアの辺インデックス (i, j) を返す。
## 辺 i は point_positions[i]→point_positions[(i+1)%n]。なければ Vector2i(-1, -1)。
func _find_first_crossing_edge_indices() -> Vector2i:
	var n: int = _game.point_positions.size()
	if n < 4:
		return Vector2i(-1, -1)
	for i in range(n - 1):
		var i1: int = i + 1
		var p1: Vector2 = _game.point_positions[i]
		var p2: Vector2 = _game.point_positions[i1]
		for j in range(i + 2, n):
			var j1: int = (j + 1) % n
			if j1 == i:
				continue
			var p3: Vector2 = _game.point_positions[j]
			var p4: Vector2 = _game.point_positions[j1]
			if _segment_intersect_strict_interior(p1, p2, p3, p4):
				return Vector2i(i, j)
	return Vector2i(-1, -1)


## 2-opt swap: 辺 (ei→ei+1) と (ej→ej+1) の交差を解消するため、
## point_positions[ei+1 .. ej] の区間を逆順にする置換を全ステートに適用する。
func _2opt_swap_and_permute_state(ei: int, ej: int) -> void:
	var n: int = _game.point_positions.size()
	var ord := PackedInt32Array()
	ord.resize(n)
	for k in range(n):
		ord[k] = k
	var left: int = ei + 1
	var right: int = ej
	while left < right:
		var tmp: int = ord[left]
		ord[left] = ord[right]
		ord[right] = tmp
		left += 1
		right -= 1
	_game.polygon_walk_order = ord
	var ord_perm: PackedInt32Array = ord.duplicate()
	_game.apply_vertex_permutation_reorder_positions_from_walk_order()
	_permute_input_state_after_vertex_reorder(ord_perm)


## 2-opt uncrossing: 交差がなくなるまで逐次的に辺を swap する。
## 収束しない場合に備え最大 n² 回で打ち切り、残れば円配置フォールバックを使う。
func _resolve_intersections_2opt(lo: Vector2, hi: Vector2) -> void:
	var n: int = _game.point_positions.size()
	var max_iter: int = n * n
	for _iter in range(max_iter):
		var pair: Vector2i = _find_first_crossing_edge_indices()
		if pair.x < 0:
			return
		_2opt_swap_and_permute_state(pair.x, pair.y)
	if _polygon_edges_have_interior_intersection() and _has_any_unlocked_polygon_vertex():
		if _game.stage_type != "circle":
			_resolve_polygon_edge_intersection_circle_around_player(lo, hi)


func _apply_point_edge_repulsion(forces: Array[Vector2], grid: Dictionary, guide_constraint_mul: PackedFloat32Array) -> void:
	"""グリッドでエッジ両端点の近傍セル（3×3）内の点のみ確認して点-辺斥力を適用。O(n²) → O(n)。
	各エッジを外ループにし、近傍で見つかった点 k を世代カウンタで重複除去することで
	Dictionary を毎エッジ割り当てずに済む。"""
	var n: int = _game.point_positions.size()
	if n < 3:
		return
	var edges: Array[Vector2i] = _get_polygon_edges_for_repulsion()
	var thr: float = POINT_EDGE_REPULSE_DISTANCE
	var thr_sq: float = thr * thr
	var inv: float = 1.0 / POINT_PAIR_REPULSE_DISTANCE  # グリッドと同じ cell_size
	# 世代カウンタを進めて "未訪問" 状態にリセット（配列クリア不要）
	_edge_repulse_gen += 1
	var gen: int = _edge_repulse_gen
	if _edge_repulse_visited.size() < n:
		_edge_repulse_visited.resize(n)
	for e in edges:
		var a: int = e.x
		var b: int = e.y
		var pa: Vector2 = _game.point_positions[a]
		var pb: Vector2 = _game.point_positions[b]
		var ab: Vector2 = pb - pa
		var ab_len_sq: float = ab.length_squared()
		if ab_len_sq < 1e-10:
			continue
		# 両端点の近傍セルを探索（エッジが短い限り完全に網羅できる）
		for ep in [pa, pb]:
			var cx: int = int(floor(ep.x * inv))
			var cy: int = int(floor(ep.y * inv))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var key: Vector2i = Vector2i(cx + dx, cy + dy)
					if not grid.has(key):
						continue
					for k in (grid[key] as Array):
						if _edge_repulse_visited[k] == gen:
							continue  # このエッジに対して既に確認済み
						_edge_repulse_visited[k] = gen
						if k == a or k == b:
							continue
						if _is_locked(k):
							continue
						var p: Vector2 = _game.point_positions[k]
						var t_proj: float = clampf((p - pa).dot(ab) / ab_len_sq, 0.0, 1.0)
						var closest: Vector2 = pa + ab * t_proj
						var delta: Vector2 = p - closest
						var dist_sq: float = delta.length_squared()
						if dist_sq > thr_sq:
							continue
						var dist: float = maxf(sqrt(dist_sq), POINT_EDGE_REPULSE_MIN_DISTANCE)
						var falloff: float = 1.0 - dist / thr
						var dir: Vector2 = delta / dist
						var gmul: float = 1.0
						if k < guide_constraint_mul.size():
							gmul = guide_constraint_mul[k]
						if gmul < 0.001:
							continue
						forces[k] += dir * (POINT_EDGE_REPULSE_STRENGTH * falloff * falloff * gmul)


func _centroid_positions_range(start_idx: int, end_exclusive: int) -> Vector2:
	var s := Vector2.ZERO
	var c: int = 0
	for i in range(start_idx, end_exclusive):
		s += _game.point_positions[i]
		c += 1
	return s / float(maxi(c, 1))


func _apply_polygon_ccw_order_constraint(forces: Array[Vector2], guide_constraint_mul: PackedFloat32Array) -> void:
	var n: int = _game.point_positions.size()
	if n < 3:
		return
	if _game.is_polygon_walk_order_active():
		var c: Vector2 = _centroid_positions_range(0, n)
		_apply_ccw_order_for_walk_segment(forces, 0, n, c, guide_constraint_mul)
		return
	var c0: Vector2 = _centroid_positions_range(0, n)
	_apply_ccw_order_for_loop(forces, 0, n, c0, guide_constraint_mul)


func _apply_ccw_order_for_loop(forces: Array[Vector2], idx_start: int, idx_count: int, center: Vector2, guide_constraint_mul: PackedFloat32Array) -> void:
	if idx_count < 3:
		return
	for offset in range(idx_count):
		var i: int = idx_start + offset
		var nxt: int = idx_start + ((offset + 1) % idx_count)
		if _is_locked(i) and _is_locked(nxt):
			continue
		var a: Vector2 = _game.point_positions[i] - center
		var b: Vector2 = _game.point_positions[nxt] - center
		var al: float = a.length()
		var bl: float = b.length()
		if al < 3.0 or bl < 3.0:
			continue
		var cr: float = a.x * b.y - a.y * b.x
		if cr >= 0.0:
			continue
		var gmul: float = 1.0
		if i < guide_constraint_mul.size() and nxt < guide_constraint_mul.size():
			gmul = minf(guide_constraint_mul[i], guide_constraint_mul[nxt])
		if gmul < 0.001:
			continue
		var perp: Vector2 = Vector2(-a.y, a.x)
		var pl: float = perp.length()
		if pl < 1e-5:
			continue
		perp /= pl
		var mag: float = POLYGON_CCW_ORDER_STRENGTH * clampf((-cr) / (al * bl + 80.0), 0.04, 3.0) * gmul
		if not _is_locked(nxt):
			forces[nxt] += perp * mag
		if not _is_locked(i):
			forces[i] -= perp * mag * 0.42


func _apply_ccw_order_for_walk_segment(forces: Array[Vector2], seg_start_in_order: int, seg_len: int, center: Vector2, guide_constraint_mul: PackedFloat32Array) -> void:
	if seg_len < 3:
		return
	var order: PackedInt32Array = _game.polygon_walk_order
	for t in range(seg_len):
		var i: int = order[seg_start_in_order + t]
		var nxt: int = order[seg_start_in_order + ((t + 1) % seg_len)]
		if _is_locked(i) and _is_locked(nxt):
			continue
		var a: Vector2 = _game.point_positions[i] - center
		var b: Vector2 = _game.point_positions[nxt] - center
		var al: float = a.length()
		var bl: float = b.length()
		if al < 3.0 or bl < 3.0:
			continue
		var cr: float = a.x * b.y - a.y * b.x
		if cr >= 0.0:
			continue
		var gmul: float = 1.0
		if i < guide_constraint_mul.size() and nxt < guide_constraint_mul.size():
			gmul = minf(guide_constraint_mul[i], guide_constraint_mul[nxt])
		if gmul < 0.001:
			continue
		var perp: Vector2 = Vector2(-a.y, a.x)
		var pl: float = perp.length()
		if pl < 1e-5:
			continue
		perp /= pl
		var mag: float = POLYGON_CCW_ORDER_STRENGTH * clampf((-cr) / (al * bl + 80.0), 0.04, 3.0) * gmul
		if not _is_locked(nxt):
			forces[nxt] += perp * mag
		if not _is_locked(i):
			forces[i] -= perp * mag * 0.42


func _get_player_force_mode() -> int:
	if player_force_attracting == player_force_repelling:
		return 0
	return 1 if player_force_attracting else -1


func _is_player_repelling_only() -> bool:
	return _get_player_force_mode() == -1


func _apply_playfield_edge_return_forces(forces: Array[Vector2], _lo: Vector2, _hi: Vector2) -> void:
	var zone: float = VIEWPORT_EDGE_REPULSE_ZONE
	if zone <= 0.001:
		return
	var vp: Vector2 = _game.get_viewport_rect().size
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		var pos: Vector2 = _game.point_positions[i]
		var vel: Vector2 = point_velocities[i]
		var f_add := Vector2.ZERO
		# 左: 画面左端からの距離
		var dl: float = pos.x
		if dl < zone:
			var vel_out: float = maxf(0.0, -vel.x)
			var t: float = clampf(1.0 - dl / zone, 0.0, 1.0)
			var mul: float = t * t * (1.0 + PLAYFIELD_EDGE_RETURN_VEL_BOOST * vel_out) * PLAYFIELD_EDGE_RETURN_REPULSE_MUL
			f_add.x += PLAYFIELD_EDGE_RETURN_STRENGTH * mul
		# 右
		var dr: float = vp.x - pos.x
		if dr < zone:
			var vel_out_r: float = maxf(0.0, vel.x)
			var t2: float = clampf(1.0 - dr / zone, 0.0, 1.0)
			var mul2: float = t2 * t2 * (1.0 + PLAYFIELD_EDGE_RETURN_VEL_BOOST * vel_out_r) * PLAYFIELD_EDGE_RETURN_REPULSE_MUL
			f_add.x -= PLAYFIELD_EDGE_RETURN_STRENGTH * mul2
		# 上
		var dt: float = pos.y
		if dt < zone:
			var vel_out_b: float = maxf(0.0, -vel.y)
			var t3: float = clampf(1.0 - dt / zone, 0.0, 1.0)
			var mul3: float = t3 * t3 * (1.0 + PLAYFIELD_EDGE_RETURN_VEL_BOOST * vel_out_b) * PLAYFIELD_EDGE_RETURN_REPULSE_MUL
			f_add.y += PLAYFIELD_EDGE_RETURN_STRENGTH * mul3
		# 下
		var db: float = vp.y - pos.y
		if db < zone:
			var vel_out_t: float = maxf(0.0, vel.y)
			var t4: float = clampf(1.0 - db / zone, 0.0, 1.0)
			var mul4: float = t4 * t4 * (1.0 + PLAYFIELD_EDGE_RETURN_VEL_BOOST * vel_out_t) * PLAYFIELD_EDGE_RETURN_REPULSE_MUL
			f_add.y -= PLAYFIELD_EDGE_RETURN_STRENGTH * mul4
		forces[i] += f_add


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
	if _get_player_force_mode() == 0:
		return false
	var influence_limit: float = _get_effective_player_force_limit()
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
	while _ax_spacing_vertex_dwell_ms.size() < _game.point_positions.size():
		_ax_spacing_vertex_dwell_ms.append(0.0)
	while _ax_spacing_vertex_dwell_ms.size() > _game.point_positions.size():
		_ax_spacing_vertex_dwell_ms.pop_back()


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
	var pf_mode_peel: int = _get_player_force_mode()
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		var feature: Dictionary = nearest_features[i] as Dictionary
		if _is_guide_snap_bypassed_by_player_force(i, feature):
			continue
		var pos: Vector2 = _game.point_positions[i]
		var edge_dist: float = feature.get("edge_dist", INF) as float
		var vertex_dist: float = feature.get("vertex_dist", INF) as float
		var edge_pass_through: bool = _is_edge_pass_through(feature, pos, point_velocities[i])
		# ガイド付近 32px 以内かつ自キャラが頂点に近いときだけ剥がしやすく弱める（遠距離からの力ではガイドを維持）
		var peel_mul: float = 1.0
		if pf_mode_peel != 0 and edge_dist < GUIDE_PEEL_DISTANCE_PX:
			var dist_player_pt: float = player_position.distance_to(pos)
			if dist_player_pt <= GUIDE_ATTRACT_FREE_PROXIMITY_PX:
				peel_mul = clampf(edge_dist / GUIDE_PEEL_DISTANCE_PX, GUIDE_PEEL_SNAP_FLOOR, 1.0)
		if edge_dist < GUIDE_EDGE_SNAP_RADIUS and not edge_pass_through:
			var edge_strength: float = 1.0 - edge_dist / GUIDE_EDGE_SNAP_RADIUS
			var edge_spring: float = GUIDE_EDGE_SPRING
			if edge_dist < GUIDE_EDGE_SUCTION_RADIUS:
				var suction_t: float = 1.0 - edge_dist / GUIDE_EDGE_SUCTION_RADIUS
				edge_spring += GUIDE_EDGE_SUCTION_SPRING * suction_t * suction_t
			var edge_spring_mul: float = 1.0 + GUIDE_STICK_EDGE_SPRING_EXTRA * edge_strength
			var edge_snap_damp_mul: float = 1.0 + GUIDE_STICK_SNAP_DAMP_EXTRA * edge_strength
			var edge_target: Vector2 = feature.get("edge_point", pos) as Vector2
			var edge_normal: Vector2 = _feature_edge_normal(feature, pos)
			var normal_velocity: Vector2 = edge_normal * point_velocities[i].dot(edge_normal)
			forces[i] += (edge_target - pos) * (edge_spring * edge_strength * peel_mul * edge_spring_mul)
			forces[i] -= normal_velocity * (GUIDE_SNAP_DAMPING * edge_strength * peel_mul * edge_snap_damp_mul)
			if edge_dist < GUIDE_EDGE_GLIDE_RADIUS and vertex_dist >= GUIDE_VERTEX_LOCK_RADIUS:
				var glide_t: float = 1.0 - edge_dist / GUIDE_EDGE_GLIDE_RADIUS
				var glide_damp_mul: float = 1.0 + GUIDE_STICK_EDGE_GLIDE_DAMP_EXTRA * glide_t
				forces[i] -= normal_velocity * (GUIDE_EDGE_GLIDE_DAMPING * glide_t * peel_mul * glide_damp_mul)
		if vertex_dist < GUIDE_VERTEX_SNAP_RADIUS:
			var vertex_strength: float = 1.0 - vertex_dist / GUIDE_VERTEX_SNAP_RADIUS
			var vertex_spring_mul: float = 1.0 + GUIDE_STICK_VERTEX_SPRING_EXTRA * vertex_strength
			var vertex_damp_mul: float = 1.0 + GUIDE_STICK_SNAP_DAMP_EXTRA * vertex_strength
			var vertex_target: Vector2 = feature.get("vertex_pos", pos) as Vector2
			forces[i] += (vertex_target - pos) * (GUIDE_VERTEX_SPRING * vertex_strength * peel_mul * vertex_spring_mul)
			forces[i] -= point_velocities[i] * (GUIDE_SNAP_DAMPING * vertex_strength * peel_mul * vertex_damp_mul)
		var lock_data: Dictionary = vertex_locks.get(i, {}) as Dictionary
		if lock_data.is_empty():
			continue
		var lock_pos: Vector2 = lock_data.get("vertex_pos", pos) as Vector2
		var lock_dist: float = pos.distance_to(lock_pos)
		var lock_strength: float = clampf(1.0 - lock_dist / maxf(GUIDE_VERTEX_LOCK_RADIUS, 0.001), 0.0, 1.0)
		var player_touching: bool = _is_player_touching_point(i)
		var lock_mul: float = GUIDE_VERTEX_CONTACT_RELEASE_MUL if player_touching else 1.0
		var lock_spring_mul: float = 1.0 + GUIDE_STICK_VERTEX_LOCK_SPRING_EXTRA * lock_strength
		var lock_damp_mul: float = 1.0 + GUIDE_STICK_SNAP_DAMP_EXTRA * 0.55 * lock_strength
		forces[i] += (lock_pos - pos) * (GUIDE_VERTEX_LOCK_SPRING * lock_mul * peel_mul * lock_spring_mul)
		forces[i] -= point_velocities[i] * (GUIDE_VERTEX_LOCK_DAMPING * lock_mul * peel_mul * lock_damp_mul)


func _constrain_forces_for_edge_slide(forces: Array[Vector2], nearest_features: Array, vertex_locks: Dictionary) -> void:
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		var feature: Dictionary = nearest_features[i] as Dictionary
		if _is_guide_snap_bypassed_by_player_force(i, feature):
			continue
		var pos: Vector2 = _game.point_positions[i]
		var edge_dist: float = feature.get("edge_dist", INF) as float
		if edge_dist >= GUIDE_EDGE_GLIDE_RADIUS:
			continue
		if _is_edge_pass_through(feature, pos, point_velocities[i]):
			continue
		var glide_t: float = 1.0 - edge_dist / GUIDE_EDGE_GLIDE_RADIUS
		var tangent: Vector2 = _feature_edge_tangent(feature)
		var tangent_force: Vector2 = tangent * forces[i].dot(tangent)
		var edge_target: Vector2 = feature.get("edge_point", pos) as Vector2
		var slide_stick: float = 1.0 + GUIDE_STICK_EDGE_SLIDE_TRACK_EXTRA * glide_t
		var track_force: Vector2 = (edge_target - pos) * (GUIDE_EDGE_SLIDE_TRACK_SPRING * glide_t * slide_stick)
		forces[i] = tangent_force + track_force
		if _get_player_force_mode() != 0:
			var pf: Vector2 = _compute_player_force(i)
			if player_position.distance_to(pos) > GUIDE_ATTRACT_FREE_PROXIMITY_PX:
				pf = _remap_player_force_when_distant_on_guide(i, feature, pf)
			var pl: float = pf.length()
			if pl > 0.5:
				var par: Vector2 = tangent * pf.dot(tangent)
				var par_sq: float = par.length_squared()
				var pf_sq: float = pl * pl
				if par_sq < pf_sq * 0.14:
					var crs: float = pf.cross(tangent)
					var sign_slide: float = signf(crs)
					if absf(sign_slide) < 0.001:
						sign_slide = signf(pf.dot(tangent))
					if absf(sign_slide) < 0.001:
						sign_slide = 1.0
					forces[i] += tangent * (pl * GUIDE_REPEL_SLIDE_ASSIST * sign_slide)


func _build_fixed_guide_snap_loops() -> Array:
	var loops: Array = _game.stage_manager.get_active_guide_loops_world()
	var filtered: Array = []
	for loop in loops:
		var points: Array = loop as Array
		if points.size() >= 2:
			filtered.append(points)
	return filtered


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
			"edge_tangent": Vector2.RIGHT,
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
					var edge_tangent: Vector2 = (loop[next_idx] as Vector2) - vertex_pos
					if edge_tangent.length_squared() > 0.0001:
						edge_tangent = edge_tangent.normalized()
					else:
						edge_tangent = Vector2.RIGHT
					best["edge_dist"] = edge_dist
					best["edge_point"] = edge_point
					best["edge_start_idx"] = vertex_idx
					best["edge_loop"] = loop_idx
					best["edge_tangent"] = edge_tangent
					best["loop_size"] = loop_size
		features.append(best)
	return features


func _apply_post_move_guide_constraints(nearest_features: Array, vertex_locks: Dictionary) -> void:
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		var feature: Dictionary = nearest_features[i] as Dictionary
		if _is_guide_snap_bypassed_by_player_force(i, feature):
			continue
		var pos: Vector2 = _game.point_positions[i]
		if vertex_locks.has(i):
			var lock_data: Dictionary = vertex_locks.get(i, {}) as Dictionary
			var lock_pos: Vector2 = lock_data.get("vertex_pos", pos) as Vector2
			var lock_dist: float = pos.distance_to(lock_pos)
			if lock_dist <= GUIDE_VERTEX_LOCK_RADIUS:
				var lock_t: float = 1.0 - lock_dist / maxf(GUIDE_VERTEX_LOCK_RADIUS, 0.001)
				var lk_lerp: float = clampf(0.18 + 0.42 * lock_t + GUIDE_STICK_POST_LOCK_LERP_ADD * lock_t * lock_t, 0.0, 1.0)
				_game.point_positions[i] = pos.lerp(lock_pos, lk_lerp)
				point_velocities[i] *= maxf(0.0, 1.0 - 0.82 * lock_t)
				continue
		var edge_dist: float = feature.get("edge_dist", INF) as float
		if edge_dist >= GUIDE_EDGE_GLIDE_RADIUS:
			continue
		if _is_edge_pass_through(feature, pos, point_velocities[i]):
			continue
		var edge_target: Vector2 = feature.get("edge_point", pos) as Vector2
		var edge_tangent: Vector2 = _feature_edge_tangent(feature)
		var tangent_speed: float = point_velocities[i].dot(edge_tangent)
		var glide_t: float = 1.0 - edge_dist / GUIDE_EDGE_GLIDE_RADIUS
		var eg_lerp: float = clampf(0.20 + 0.45 * glide_t + GUIDE_STICK_POST_EDGE_LERP_ADD * glide_t * glide_t, 0.0, 1.0)
		_game.point_positions[i] = pos.lerp(edge_target, eg_lerp)
		point_velocities[i] = edge_tangent * tangent_speed * (1.0 - 0.10 * glide_t)


func _feature_edge_tangent(feature: Dictionary) -> Vector2:
	var tangent: Vector2 = feature.get("edge_tangent", Vector2.RIGHT) as Vector2
	if tangent.length_squared() <= 0.0001:
		return Vector2.RIGHT
	return tangent.normalized()


func _feature_edge_normal(feature: Dictionary, pos: Vector2) -> Vector2:
	var edge_target: Vector2 = feature.get("edge_point", pos) as Vector2
	var delta: Vector2 = edge_target - pos
	if delta.length_squared() > 0.0001:
		return delta.normalized()
	var tangent: Vector2 = _feature_edge_tangent(feature)
	return Vector2(-tangent.y, tangent.x)


func _is_edge_pass_through(feature: Dictionary, pos: Vector2, velocity: Vector2) -> bool:
	if velocity.length_squared() <= 0.0001:
		return false
	var tangent: Vector2 = _feature_edge_tangent(feature)
	var normal: Vector2 = _feature_edge_normal(feature, pos)
	var normal_speed: float = absf(velocity.dot(normal))
	if normal_speed < GUIDE_EDGE_PASS_THROUGH_SPEED:
		return false
	var tangent_speed: float = absf(velocity.dot(tangent))
	return normal_speed > tangent_speed * GUIDE_EDGE_PASS_THROUGH_RATIO


func _compute_vertex_locks(_nearest_features: Array) -> Dictionary:
	# 旧: ガイド頂点へ GUIDE_VERTEX_LOCK_* で強固定していたが、角で「レール」が途切れるため無効化。
	return {}


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


func _get_loop_bounds_for_index(_idx: int) -> Vector2i:
	return Vector2i(0, _game.point_positions.size())


func _get_loop_perimeter(start_idx: int, end_idx: int) -> float:
	if _game.is_polygon_walk_order_active():
		var seg_len: int = end_idx - start_idx
		var order: PackedInt32Array = _game.polygon_walk_order
		var perimeter: float = 0.0
		for s in range(seg_len):
			var a: int = order[start_idx + s]
			var b: int = order[start_idx + ((s + 1) % seg_len)]
			perimeter += _game.point_positions[a].distance_to(_game.point_positions[b])
		return perimeter
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
	if _game.is_polygon_walk_order_active():
		var seg_len: int = end_idx - start_idx
		var order: PackedInt32Array = _game.polygon_walk_order
		for s in range(seg_len):
			if order[start_idx + s] != idx:
				continue
			var delta: int = 1 if direction >= 0 else -1
			var ns: int = (s + delta) % seg_len
			if ns < 0:
				ns += seg_len
			return order[start_idx + ns]
		return idx
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


func get_effective_player_force_visual_radius() -> float:
	"""薄い影響円用。静止チャージの幾何拡張を含む実効距離（中心〜ポイント側の限界）。"""
	return _get_effective_player_force_limit()


func get_base_player_force_visual_radius() -> float:
	"""チャージ前の基準半径（PLAYER_FORCE_RADIUS + ポイント半径）。引力グラデの内側アンカー用。"""
	return PLAYER_FORCE_RADIUS + _game.ui_renderer.POINT_RADIUS


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
