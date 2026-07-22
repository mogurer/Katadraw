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
const DRAG_VELOCITY_DAMPING := 9.0
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
const GUIDE_VERTEX_LOCK_PERSIST_RELEASE_RADIUS := 30.0
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
## ガイド辺の空間グリッドセルサイズ (px)。スナップ半径 26px の約 3 倍で余裕を確保。
const _GUIDE_GRID_CELL := 80.0
const POINT_PAIR_REPULSE_STRENGTH := 2600.0
const POINT_PAIR_REPULSE_MIN_DISTANCE := 2.0
## ideal_points へのパッシブドリフト
const IDEAL_VERTEX_SPRING := 8.0
const IDEAL_VERTEX_REPEL_STRENGTH := 12.0
const IDEAL_VERTEX_ATTRACT_RANGE := 200.0
const IDEAL_VERTEX_OCCUPIED_RADIUS := 20.0
const IDEAL_DRIFT_DURATION := 3.0
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
## 引力でガイドへ向かって接近中のポイントを弾く判定速度閾値（px/s）
const GUIDE_ATTRACT_APPROACH_THRESHOLD := 20.0
## 引力がガイド方向へ向いていると判定する最小力量（force 単位）
const GUIDE_ATTRACT_TOWARD_GUIDE_MIN := 10.0
## 引力接近時にポイントをガイドから弾く斥力強度
const GUIDE_ATTRACT_REPEL_STRENGTH := 4000.0
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
## マウス追従 lerp 係数。ステージセレクトの _CHAR_LERP と同じ値。
const PLAYER_MOUSE_LERP := 10.0
## 自キャラ〜頂点がこの距離以内かつガイド上のとき、引力・斥力でガイド吸着を無視（edge_dist が EDGE 以下＝ガイド上）
const GUIDE_ATTRACT_FREE_PROXIMITY_PX := 64.0
const GUIDE_ATTRACT_FREE_EDGE_DIST_PX := 10.0
## 自キャラが上記より遠く、かつガイド辺に乗っているときの引力・斥力: 法線を弱め接線を強めて剥がれにくく滑らせる
const PLAYER_DISTANT_ON_GUIDE_NORMAL_SCALE := 0.28
const PLAYER_DISTANT_ON_GUIDE_TANGENT_SCALE := 1.18

# --- ガイド辺空間グリッド（_compute_nearest_guide_features の O(N) → O(k) 高速化） ---
var _guide_grid: Dictionary = {}       # Vector2i セル → Array [[va, vb, vi, loop_idx, loop_sz], ...]
var _guide_grid_n: int = -1            # 前回ビルド時の総頂点数（変化時のみ再構築）
var _guide_loops_cache: Array = []     # _build_fixed_guide_snap_loops() の結果をキャッシュ
var _guide_loops_cache_n: int = -1     # キャッシュ無効化用頂点数

# --- 安定化力アクティブゾーン（引力・斥力時の非影響ポイントをスキップ） ---
var _phys_active_mask: PackedByteArray = PackedByteArray()  # 1=アクティブ, 0=スキップ
var _phys_mask_enabled: bool = false   # false のとき全点対象（マスク無効）
var _vertex_lock_flags: PackedByteArray = PackedByteArray()  # 1=頂点ロック済み（未使用・互換性のため残存）
var _stabilize_skip_frame: bool = false  # フレームスロットル用フラグ

# --- 新スナップシステム（アリジゴク型） ---
## コーナー占有管理: corner_index → point_index（そのコーナーを確保したポイント番号）
var _snap_corner_occupant: Dictionary = {}
## 各ポイントのスナップ状態: 0=未吸着, 1=コーナー吸着中, 2=辺吸着中
var _snap_point_state: PackedByteArray = PackedByteArray()
## playing 中に A+X（またはマウス左右）同時押し中（ガイド近接表示用）
var ax_combo_held: bool = false
## ネコアニメーション: A+X 立ち上がりエッジで true にセット。ui_renderer が消費する。
var cat_anim_triggered: bool = false
var _ax_combo_prev_held: bool = false
## スナップ先のワールド座標（吸着確定後の引き戻し先）
var _snap_point_target: Array[Vector2] = []
## スナップ先のコーナーインデックス（-1 = 辺スナップ）
var _snap_point_corner_idx: PackedInt32Array = PackedInt32Array()
## ガイドデータのフレームキャッシュ（update_drag_physics で1回だけ更新）
var _snap_cached_corner_world: Array = []
var _snap_cached_guide_loops: Array = []
## スナップ強度ランプアップ経過時間（秒）。playing 中のみ進行し、SNAP_RAMP_DURATION で上限
var snap_ramp_elapsed: float = 0.0

# --- 交差判定スロットル（3フレームに1回、空間グリッドで O(N²)→O(N×k) に削減） ---
var _isect_throttle: int = 0
## スワップ発生後のクールダウン（サブステップ単位）。
## この値が正の間は折り返し検出を停止し振動を防ぐ。実交差は引き続き検出する。
const FOLDBACK_COOLDOWN_STEPS: int = 18  # ≒ 60fps × 3サブステップ × 0.1秒
var _foldback_cooldown: int = 0

# --- デバッグ: 再接続ハイライト（赤円で発火ポイントを表示）---
## point_index -> expire_msec: この時刻まで赤ハイライト表示する
var _debug_reconnect_highlight: Dictionary = {}
const _DEBUG_RECONNECT_HIGHLIGHT_MS: int = 2000  # 2秒間赤表示

const _ISECT_THROTTLE_EVERY: int = 3
## 鋭角折り返し（ヘアピン）検出の内積閾値。
## 連続する2辺の方向ベクトルの内積がこの値未満なら折り返しとみなす（-1.0=180°, 0.0=90°）。
const FOLDBACK_DOT_THRESHOLD: float = -0.70

## ===== アリジゴク型スナップシステム =====
## スナップステップ周期（秒）: この間隔で未吸着ポイントをガイドへ引き寄せる
const SNAP_STEP_PERIOD: float = 1.0
## 1ステップあたりの引き寄せ割合（0.18 = 距離の18%を縮める）
const SNAP_STEP_RATIO: float = 0.18
## コーナー吸着確定半径（px）: この距離以内に入ったらコーナーへ確定吸着
const SNAP_CORNER_RADIUS: float = 20.0
## 辺吸着確定半径（px）: コーナーが取れないとき、この距離以内なら辺に確定吸着
const SNAP_EDGE_RADIUS: float = 20.0
## コーナー検索優先半径（px）: この距離以内のコーナーを辺より優先して検索する
const SNAP_CORNER_PREFER_RADIUS: float = 60.0
## 吸着解除距離（px）: 吸着確定後にターゲットからこれ以上離れたら解除
const SNAP_RELEASE_RADIUS: float = 30.0
## 吸着後の弱いバネ係数（px/s² per px）
const SNAP_SPRING: float = 80.0
## 吸着後のダンピング係数
const SNAP_DAMPING: float = 12.0
## 未吸着時のアプローチバネ係数: 常時ガイドへ引き寄せる（スムーズ移動を実現）
const SNAP_APPROACH_SPRING: float = 8.0
## 未吸着ポイント間の分離最小距離 (px) = 2 × POINT_RADIUS（視覚的重なり防止）
const SNAP_SEPARATION_DISTANCE: float = 18.0
## 未吸着ポイント間の分離力強度
const SNAP_SEPARATION_STRENGTH: float = 2400.0
## スナップ強度のランプアップ時間（秒）: ゲーム開始から SNAP_RAMP_DURATION 秒かけて通常強度に達する
const SNAP_RAMP_DURATION: float = 120.0
## ===== 近接スナップシステム =====
## 未吸着時にバネ引力が始まる距離（px）
const SNAP_VERTEX_ATTRACT_RADIUS: float = 80.0
## 未吸着時のアプローチバネ係数
const SNAP_VERTEX_APPROACH_SPRING: float = 30.0
## 占有済み頂点からの斥力が始まる距離（px）
const SNAP_REPEL_RADIUS: float = 60.0
## 占有済み頂点斥力の最大強度（二次減衰）
const SNAP_REPEL_STRENGTH: float = 1500.0

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
var _prev_force_attracting: bool = false  # [DEBUG] SE遷移検出用
var _prev_force_repelling: bool = false   # [DEBUG] SE遷移検出用
var player_has_motion_input: bool = false
var player_force_active: bool = false
var player_influenced_point_count: int = 0
var mouse_force_pressed: bool = false

## パッド移動の速度（マウス操作時は毎フレームゼロに戻す）
var player_velocity: Vector2 = Vector2.ZERO
## マウス入力の仮想ターゲット位置。player_position は毎フレーム lerp で追従する
var _mouse_target: Vector2 = Vector2.ZERO
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

func get_repel_charge_progress() -> float:
	var max_charge_ms: float = float(EMPTY_FORCE_RADIUS_TICK_CAP - 1) * float(EMPTY_FORCE_RADIUS_TICK_MS)
	if max_charge_ms <= 0.0:
		return 0.0
	return clampf(_empty_repulse_stationary_ms / max_charge_ms, 0.0, 1.0)

func get_attract_charge_progress() -> float:
	var max_charge_ms: float = float(EMPTY_FORCE_RADIUS_TICK_CAP - 1) * float(EMPTY_FORCE_RADIUS_TICK_MS)
	if max_charge_ms <= 0.0:
		return 0.0
	return clampf(_empty_attract_stationary_ms / max_charge_ms, 0.0, 1.0)
## ideal_points ドリフト: プレイヤーが離れた後も物理ループを継続する残り時間（秒）
var _ideal_drift_timer: float = 0.0
var _prev_player_force_active: bool = false

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
	player_velocity = Vector2.ZERO
	_empty_repulse_stationary_ms = 0.0
	_empty_attract_stationary_ms = 0.0
	_empty_repulse_radius_bonus = 0.0
	_empty_attract_radius_bonus = 0.0
	_mouse_rel_motion_for_charge = 0.0
	_pad_move_ramp_ms = 0.0
	_foldback_cooldown = 0
	_debug_reconnect_highlight.clear()
	_snap_corner_occupant.clear()
	_snap_point_state.clear()
	_snap_point_target.clear()
	_snap_point_corner_idx.clear()
	_snap_cached_corner_world.clear()
	_snap_cached_guide_loops.clear()
	snap_ramp_elapsed = 0.0
	_reset_player_position()
	_presnap_at_corners()


func _reset_player_position() -> void:
	player_position = _default_player_position()
	_mouse_target = player_position
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
	_mouse_target = mouse
	if not player_position_initialized:
		player_position = mouse
		player_position_initialized = true
	player_velocity = Vector2.ZERO
	player_has_motion_input = false
	_last_input_method = "mouse"
	_refresh_hovered_point()
	_game.queue_redraw()


func handle_mouse_press(mouse: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	_last_input_method = "mouse"
	if _game.game_state == "rules":
		return
	_mouse_target = mouse
	if not player_position_initialized:
		player_position = mouse
		player_position_initialized = true
	player_velocity = Vector2.ZERO
	if button == MOUSE_BUTTON_LEFT:
		if _game._is_a_button_disabled_stage():
			return
		player_force_repelling = true
		player_force_attracting = false
	elif button == MOUSE_BUTTON_RIGHT:
		if _game._is_x_button_disabled_stage():
			return
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
	if _game.game_state == "rules":
		return
	if btn == JOY_BUTTON_A:
		if pressed and _game._is_a_button_disabled_stage():
			return
		player_force_repelling = pressed
	elif btn == JOY_BUTTON_X:
		if pressed and _game._is_x_button_disabled_stage():
			return
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


func get_last_input_method() -> String:
	return _last_input_method


func sync_mouse_target_to_player() -> void:
	_mouse_target = player_position


func notify_pad_steering_active() -> void:
	_last_input_method = "pad"
	sync_mouse_target_to_player()


## マウス入力時の自キャラ lerp 追従。毎フレーム _process から呼ぶ。
## 最後の入力がマウスの場合のみ player_position を _mouse_target へ近づける。
func process_mouse_lerp(delta: float) -> void:
	if _last_input_method != "mouse":
		return
	if _game.game_state == "playing" and not _game.playing_mouse_steers_player:
		return
	if not player_position_initialized:
		return
	player_position = player_position.lerp(_mouse_target, PLAYER_MOUSE_LERP * delta)
	_clamp_player_to_viewport()
	_refresh_hovered_point()
	_game.queue_redraw()


func process_pad(delta: float) -> void:
	if _game.game_state != "playing" and _game.game_state != "rules":
		ax_combo_held = false
		player_has_motion_input = false
		player_force_attracting = false
		player_force_repelling = false
		grab_input_active = false
		_empty_repulse_stationary_ms = 0.0
		_empty_attract_stationary_ms = 0.0
		_pad_move_ramp_ms = 0.0
		return
	if _game.game_state == "rules" and _game.rules_focus_button:
		ax_combo_held = false
		player_has_motion_input = false
		player_force_attracting = false
		player_force_repelling = false
		grab_input_active = false
		_empty_repulse_stationary_ms = 0.0
		_empty_attract_stationary_ms = 0.0
		_pad_move_ramp_ms = 0.0
		return
	if _game.point_positions.is_empty():
		ax_combo_held = false
		player_has_motion_input = false
		player_force_attracting = false
		player_force_repelling = false
		grab_input_active = false
		_empty_repulse_stationary_ms = 0.0
		_empty_attract_stationary_ms = 0.0
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
	var _ax_now: bool = (
		_game.game_state == "playing"
		and not pad_b
		and ((pad_a and pad_x) or (mouse_left and mouse_right))
	)
	ax_combo_held = _ax_now

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
	elif _ax_now:
		# A+X 同時（またはマウス左右同時）: ネコアニメーション（立ち上がりエッジで発火）
		if not _ax_combo_prev_held:
			cat_anim_triggered = true
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

	_ax_combo_prev_held = _ax_now

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

	player_position += player_velocity * delta
	if wish.length_squared() > 0.0001 or player_velocity.length_squared() > 3600.0:
		moved = true

	player_has_motion_input = moved
	if not _game.selected_indices.is_empty():
		_game.selected_indices.clear()
	if moved:
		_clamp_player_to_viewport()
		_last_input_method = "pad"
		notify_pad_steering_active()
		_game.queue_redraw()
	_refresh_hovered_point()
	grab_input_active = (
		_get_player_force_mode() != 0
		or player_force_active
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


func _has_active_snap_state() -> bool:
	for s in _snap_point_state:
		if s != 0:
			return true
	return false


## 吸着済みポイントのうち、まだターゲットに到達していないものがあるか確認
func _snap_is_actively_pulling() -> bool:
	var n: int = _snap_point_state.size()
	var tn: int = _snap_point_target.size()
	for i in range(n):
		if _snap_point_state[i] == 0:
			continue
		if i >= _game.point_positions.size():
			continue
		if i >= tn:
			continue
		if _game.point_positions[i].distance_to(_snap_point_target[i]) > DRAG_POSITION_EPSILON:
			return true
	return false


## 未吸着の（ロックされていない）ポイントが存在するか確認（Fix #2: 常に移動させる）
func _has_unsnapped_active_points() -> bool:
	var n: int = _game.point_positions.size()
	var sn: int = _snap_point_state.size()
	for i in range(n):
		if _is_locked(i):
			continue
		if i >= sn or _snap_point_state[i] == 0:
			return true
	return false


func update_drag_physics(delta: float) -> void:
	_ensure_drag_state_arrays()
	# スナップ配列もここで同期し、_snap_is_actively_pulling() などが
	# 古いサイズの配列を参照しないようにする
	_snap_ensure_arrays()
	if not player_position_initialized:
		_reset_player_position()

	# 引力・斥力の遷移を検出してSEを制御
	if player_force_attracting and not _prev_force_attracting:
		_game.play_sfx_ui_in()
	elif not player_force_attracting and _prev_force_attracting:
		_game.stop_sfx_ui_in()
	if player_force_repelling and not _prev_force_repelling:
		_game.play_sfx_ui_out()
	elif not player_force_repelling and _prev_force_repelling:
		_game.stop_sfx_ui_out()
	_prev_force_attracting = player_force_attracting
	_prev_force_repelling = player_force_repelling

	# [DISABLED] Layer 4: _ideal_drift_timer
	# [DISABLED] Layer 1: snap_ramp_elapsed

	if (
		not player_force_active
		and not _has_points_within_player_force()
		and not _has_active_point_velocity()
	):
		return

	# ガイドデータをフレームごとに1回キャッシュ（サブステップで使い回すため、物理実行時のみ）
	_snap_cached_corner_world = _game.stage_manager.get_corner_positions_world()
	_snap_cached_guide_loops = _game.stage_manager.get_active_guide_loops_world()

	var steps: int = maxi(1, int(ceil(delta / DRAG_STEP_MAX)))
	var step_delta: float = delta / float(steps)
	var moved: bool = false
	for _i in range(steps):
		moved = _step_drag_physics(step_delta) or moved

	# [DISABLED] Layer 4: _ideal_drift_timer = IDEAL_DRIFT_DURATION
	_prev_player_force_active = player_force_active

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

	player_force_active = player_influenced_point_count > 0
	grab_input_active = (
		player_force_active
		or _get_player_force_mode() != 0
	)

	if player_force_active:
		var _ar: float = _get_effective_player_force_limit() + POINT_PAIR_REPULSE_DISTANCE
		_build_phys_active_mask(player_position, _ar * _ar)
		_stabilize_skip_frame = not _stabilize_skip_frame
	_apply_playfield_edge_return_forces(forces, lo, hi)

	# === スナップ力（頂点近接吸着 + 確定保持バネ + 未吸着分離）===
	_snap_ensure_arrays()
	_apply_snap_vertex_forces(forces)
	_apply_snap_spring_forces(forces)
	_apply_snap_separation_forces(forces)

	var damping: float = exp(-DRAG_VELOCITY_DAMPING * delta)

	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			point_velocities[i] = Vector2.ZERO
			continue
		point_velocities[i] += forces[i] * delta
		point_velocities[i] *= damping
		_game.point_positions[i] += point_velocities[i] * delta
		_clamp_point_to_viewport(i, lo, hi)

	# 交差判定: 3フレームに1回、空間グリッドで O(N²)→O(N×k) に削減
	# 案A: 実交差がなくても鋭角折り返し（ヘアピン）を検出して再接続を試みる
	# クールダウン中は折り返し検出を停止して振動（チカチカ）を防ぐ
	_isect_throttle = (_isect_throttle + 1) % _ISECT_THROTTLE_EVERY
	if _foldback_cooldown > 0:
		_foldback_cooldown -= 1
	var topology_changed: bool = false
	if _isect_throttle == 0 and _has_any_unlocked_polygon_vertex():
		var _n_pts: int = _game.point_positions.size()
		var _now_ms: int = Time.get_ticks_msec()
		var _exp_ms: int = _now_ms + _DEBUG_RECONNECT_HIGHLIGHT_MS
		if _polygon_edges_have_interior_intersection():
			# デバッグ: 最初の交差辺ペアを記録・表示
			var dbg_pair: Vector2i = _find_first_crossing_edge_indices()
			if dbg_pair.x >= 0:
				var _pa: int = dbg_pair.x
				var _pb: int = (dbg_pair.x + 1) % _n_pts
				var _pc: int = dbg_pair.y
				var _pd: int = (dbg_pair.y + 1) % _n_pts
				for _hi in [_pa, _pb, _pc, _pd]:
					_debug_reconnect_highlight[_hi] = _exp_ms
				print("[ISECT] 交差: 辺(%d→%d) × 辺(%d→%d)  pos: %v→%v × %v→%v" % [
					_pa, _pb, _pc, _pd,
					_game.point_positions[_pa].snapped(Vector2.ONE),
					_game.point_positions[_pb].snapped(Vector2.ONE),
					_game.point_positions[_pc].snapped(Vector2.ONE),
					_game.point_positions[_pd].snapped(Vector2.ONE),
				])
			topology_changed = true
			if _game.game_state == "rules":
				# rules デモ: 固定3点を含む2-optは _enforce_rules_demo_locked_points() により毎フレーム無効化される。
				# 代わりに動く点だけをコーナーへ直接リセットして交差を解消する。
				var _ridx: int = _game._rules_demo_move_idx
				if _ridx >= 0 and _ridx < _game.point_positions.size():
					var _rc: Array = _game.stage_manager.get_corner_positions_world()
					if _rc.size() > _ridx:
						_game.point_positions[_ridx] = _rc[_ridx]
						if _ridx < point_velocities.size():
							point_velocities[_ridx] = Vector2.ZERO
			else:
				_resolve_intersections_2opt(lo, hi)
			_foldback_cooldown = FOLDBACK_COOLDOWN_STEPS
		elif _foldback_cooldown == 0:
			var fb_k: int = _find_first_foldback_vertex_index(FOLDBACK_DOT_THRESHOLD)
			if fb_k >= 0:
				# デバッグ: 折り返し頂点を記録・表示
				# ポイントはリング状のため、先頭・末尾でモジュロ折り返しが必要
				var _fb_prev: int = (fb_k - 1 + _n_pts) % _n_pts
				var _fb_nxt: int = (fb_k + 1) % _n_pts
				var _d_in: Vector2 = _game.point_positions[fb_k] - _game.point_positions[_fb_prev]
				var _d_out: Vector2 = _game.point_positions[_fb_nxt] - _game.point_positions[fb_k]
				var _dot_v: float = _d_in.dot(_d_out) / maxf(_d_in.length() * _d_out.length(), 1e-6)
				for _hi in [fb_k - 2, fb_k - 1, fb_k, fb_k + 1, fb_k + 2]:
					if _hi >= 0 and _hi < _n_pts:
						_debug_reconnect_highlight[_hi] = _exp_ms
				topology_changed = true
				var _fold_ok: bool = _resolve_foldback_at_vertex(fb_k)
				if _fold_ok:
					print("[FOLD]  折返解消: k=%d(ei=%d,ej=%d) dot=%.3f  pos:%v" % [
						fb_k, fb_k - 2, fb_k + 1, _dot_v,
						_game.point_positions[fb_k].snapped(Vector2.ONE),
					])
					_foldback_cooldown = FOLDBACK_COOLDOWN_STEPS
				else:
					# swap すると交差が生じるため取り消し → この折り返しは受け入れる
					print("[FOLD]  折返=交差と両立不可、現状維持: k=%d dot=%.3f" % [fb_k, _dot_v])
					# 長いクールダウンで同じ試行を繰り返さない
					_foldback_cooldown = FOLDBACK_COOLDOWN_STEPS * 10

	# 交差解消後: 位置が変わったスナップ点を解除（案Y: 交差解消優先）
	if topology_changed:
		_snap_release_far_points()

	# スナップ状態の整合性チェック（ghost occupancy・二重スナップを検出・修正）
	_snap_validate_and_fix_consistency()

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
	_snap_permute_after_reorder(ord)


func _get_effective_player_force_limit() -> float:
	var bonus: float = 0.0
	var fm: int = _get_player_force_mode()
	if fm > 0:
		bonus = _empty_attract_radius_bonus
	elif fm < 0:
		bonus = _empty_repulse_radius_bonus
	return PLAYER_FORCE_RADIUS + _game.ui_renderer.POINT_RADIUS + bonus


func _is_guide_snap_bypassed_by_player_force(point_idx: int, _feature: Dictionary) -> bool:
	if _get_player_force_mode() == 0:
		return false
	if point_idx < 0 or point_idx >= _game.point_positions.size():
		return false
	return _is_player_touching_point(point_idx)


func _remap_player_force_when_distant_on_guide(point_idx: int, feature: Dictionary, pf: Vector2) -> Vector2:
	if pf.length_squared() < 0.0001:
		return pf
	var edge_dist: float = feature.get("edge_dist", INF) as float
	if edge_dist >= GUIDE_EDGE_GLIDE_RADIUS:
		return pf  # ガイド外: リマップなし
	if _is_player_touching_point(point_idx):
		return pf  # 接触中: フルフォース（ガイドから外れることを許可）
	# ガイド上で非接触: 接線成分のみ（法線ゼロ → ガイドから外れない）
	var tangent: Vector2 = _feature_edge_tangent(feature)
	return tangent * pf.dot(tangent)


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
	var mask_n: int = _phys_active_mask.size() if _phys_mask_enabled else 0
	for i in range(n_vert):
		if _is_locked(i):
			continue
		var i_active: bool = not _phys_mask_enabled or (i < mask_n and _phys_active_mask[i] != 0)
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
					var j_active: bool = not _phys_mask_enabled or (j < mask_n and _phys_active_mask[j] != 0)
					if not i_active and not j_active:
						continue  # 両方非アクティブ → スキップ
					var delta: Vector2 = _game.point_positions[j] - pi
					var dist_sq: float = delta.length_squared()
					if dist_sq > threshold_sq:
						continue
					var dist: float = maxf(sqrt(dist_sq), POINT_PAIR_REPULSE_MIN_DISTANCE)
					var falloff: float = 1.0 - dist / thr
					var dir: Vector2 = delta / dist
					var force: Vector2 = dir * (POINT_PAIR_REPULSE_STRENGTH * falloff * falloff)
					# 頂点ロック済みポイントには斥力を加えない（頂点から押し出されないよう保護）
					var i_locked: bool = i < _vertex_lock_flags.size() and _vertex_lock_flags[i] != 0
					var j_locked: bool = j < _vertex_lock_flags.size() and _vertex_lock_flags[j] != 0
					if i_active and not i_locked:
						forces[i] -= force
					if j_active and not j_locked:
						forces[j] += force


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


## 鋭角折り返し（ヘアピン）頂点を検索する。
## 連続する入辺・出辺の方向ベクトルの内積が threshold 未満の最初の頂点インデックスを返す。
## 隣接する辺が極めて逆方向（約 170°以上の折り返し）を向いているとき、
## 視覚的には交差に見えるが幾何学的交差判定では検出されないケースを補足する。
func _find_first_foldback_vertex_index(threshold: float) -> int:
	var n: int = _game.point_positions.size()
	if n < 3:
		return -1
	for i in range(n):
		var prev: int = (i - 1 + n) % n
		var nxt: int = (i + 1) % n
		var d_in: Vector2 = _game.point_positions[i] - _game.point_positions[prev]
		var d_out: Vector2 = _game.point_positions[nxt] - _game.point_positions[i]
		var li: float = d_in.length()
		var lo_len: float = d_out.length()
		if li < 1e-6 or lo_len < 1e-6:
			continue
		if d_in.dot(d_out) / (li * lo_len) < threshold:
			return i
	return -1


## 折り返し頂点 k の近傍3頂点 [k-1, k, k+1] を 2-opt swap で反転して解消する。
## ラップアラウンドが必要なケース（k が 0, 1, n-1 付近）はスキップする。
## swap 後に幾何学的交差が生じた場合は swap を取り消して元の状態（折り返しあり・交差なし）を維持する。
## 戻り値: swap が有効に適用された場合 true、取り消した場合 false。
func _resolve_foldback_at_vertex(k: int) -> bool:
	var n: int = _game.point_positions.size()
	if n < 5:
		return false
	# 2-opt swap (ei, ej) は [ei+1 .. ej] を逆順にする。
	# 折り返しが頂点 k にある場合、ei = k-2, ej = k+1 で [k-1, k, k+1] を反転する。
	var ei: int = k - 2
	var ej: int = k + 1
	# ei < 0 または ej >= n の場合はラップアラウンドが必要 → スキップ
	if ei < 0 or ej >= n:
		return false
	if ej - ei < 2:
		return false
	_2opt_swap_and_permute_state(ei, ej)
	# swap 後に新たな交差が生じた場合は元に戻す（同じ swap は自己逆置換）
	if _polygon_edges_have_interior_intersection():
		_2opt_swap_and_permute_state(ei, ej)
		return false
	return true


func _polygon_edges_have_interior_intersection() -> bool:
	var edges: Array[Vector2i] = _get_polygon_edges_for_repulsion()
	var n_edges: int = edges.size()
	if n_edges < 4:
		return false
	# 空間グリッド: 各辺の「バウンディングボックスが重なる全セル」に登録し、同セル内ペアのみ判定する。
	# （両端点近傍のみの登録だと、長い辺同士が両端から離れた場所で交差する場合に見落とすため、
	#   辺全体を覆うセルに登録するよう変更した。O(N²=1770) → O(N×k)（k=セル内辺数）に削減。）
	const CELL: float = 128.0
	var inv: float = 1.0 / CELL
	var grid: Dictionary = {}
	for ei in range(n_edges):
		var e: Vector2i = edges[ei]
		var p1: Vector2 = _game.point_positions[e.x]
		var p2: Vector2 = _game.point_positions[e.y]
		var min_cx: int = int(floor(minf(p1.x, p2.x) * inv)) - 1
		var max_cx: int = int(floor(maxf(p1.x, p2.x) * inv)) + 1
		var min_cy: int = int(floor(minf(p1.y, p2.y) * inv)) - 1
		var max_cy: int = int(floor(maxf(p1.y, p2.y) * inv)) + 1
		for cy in range(min_cy, max_cy + 1):
			for cx in range(min_cx, max_cx + 1):
				var key: Vector2i = Vector2i(cx, cy)
				if not grid.has(key):
					grid[key] = []
				(grid[key] as Array).append(ei)
	# セル内ペアを確認（checked で重複ペアをスキップ）
	var checked: Dictionary = {}
	for cell_raw in grid.values():
		var cell: Array = cell_raw as Array
		var m: int = cell.size()
		for a in range(m):
			var ei: int = cell[a] as int
			var e1: Vector2i = edges[ei]
			for b in range(a + 1, m):
				var ej: int = cell[b] as int
				if ei == ej:
					continue
				var pk: int = mini(ei, ej) * n_edges + maxi(ei, ej)
				if checked.has(pk):
					continue
				checked[pk] = true
				var e2: Vector2i = edges[ej]
				if _polygon_edges_share_vertex(e1, e2):
					continue
				if _segment_intersect_strict_interior(
						_game.point_positions[e1.x], _game.point_positions[e1.y],
						_game.point_positions[e2.x], _game.point_positions[e2.y]):
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
						if _phys_mask_enabled and k < _phys_active_mask.size() and _phys_active_mask[k] == 0:
							continue  # 非アクティブポイントへの辺斥力はスキップ
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
						# 頂点ロック済みポイントは辺斥力からも保護
						if k < _vertex_lock_flags.size() and _vertex_lock_flags[k] != 0:
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
	var mask_n: int = _phys_active_mask.size() if _phys_mask_enabled else 0
	for offset in range(idx_count):
		var i: int = idx_start + offset
		var nxt: int = idx_start + ((offset + 1) % idx_count)
		if _is_locked(i) and _is_locked(nxt):
			continue
		if _phys_mask_enabled:
			var i_act: bool = i < mask_n and _phys_active_mask[i] != 0
			var nxt_act: bool = nxt < mask_n and _phys_active_mask[nxt] != 0
			if not i_act and not nxt_act:
				continue  # 両隣接点が非アクティブ → スキップ
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
		if not _is_locked(nxt) and not (nxt < _vertex_lock_flags.size() and _vertex_lock_flags[nxt] != 0):
			forces[nxt] += perp * mag
		if not _is_locked(i) and not (i < _vertex_lock_flags.size() and _vertex_lock_flags[i] != 0):
			forces[i] -= perp * mag * 0.42


func _apply_ccw_order_for_walk_segment(forces: Array[Vector2], seg_start_in_order: int, seg_len: int, center: Vector2, guide_constraint_mul: PackedFloat32Array) -> void:
	if seg_len < 3:
		return
	var order: PackedInt32Array = _game.polygon_walk_order
	var mask_n: int = _phys_active_mask.size() if _phys_mask_enabled else 0
	for t in range(seg_len):
		var i: int = order[seg_start_in_order + t]
		var nxt: int = order[seg_start_in_order + ((t + 1) % seg_len)]
		if _is_locked(i) and _is_locked(nxt):
			continue
		if _phys_mask_enabled:
			var i_act: bool = i < mask_n and _phys_active_mask[i] != 0
			var nxt_act: bool = nxt < mask_n and _phys_active_mask[nxt] != 0
			if not i_act and not nxt_act:
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
		if not _is_locked(nxt) and not (nxt < _vertex_lock_flags.size() and _vertex_lock_flags[nxt] != 0):
			forces[nxt] += perp * mag
		if not _is_locked(i) and not (i < _vertex_lock_flags.size() and _vertex_lock_flags[i] != 0):
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


func _zero_all_point_velocities() -> void:
	for i in range(point_velocities.size()):
		point_velocities[i] = Vector2.ZERO
	for i in range(point_stop_frames.size()):
		point_stop_frames[i] = 0


func _has_active_point_velocity() -> bool:
	for velocity in point_velocities:
		if velocity.length_squared() > 9.0:  # 3 px/s — sub-pixel jitter は無視
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
	var fm: int = _get_player_force_mode()
	var mask_n: int = _phys_active_mask.size() if _phys_mask_enabled else 0
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		if _phys_mask_enabled and i < mask_n and _phys_active_mask[i] == 0:
			continue  # 非アクティブポイントへのガイドスナップはスキップ
		var feature: Dictionary = nearest_features[i] as Dictionary
		if _is_guide_snap_bypassed_by_player_force(i, feature):
			continue
		var pos: Vector2 = _game.point_positions[i]
		var edge_dist: float = feature.get("edge_dist", INF) as float
		var vertex_dist: float = feature.get("vertex_dist", INF) as float
		if edge_dist < GUIDE_EDGE_SNAP_RADIUS:
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
			forces[i] += (edge_target - pos) * (edge_spring * edge_strength * edge_spring_mul)
			forces[i] -= normal_velocity * (GUIDE_SNAP_DAMPING * edge_strength * edge_snap_damp_mul)
			if edge_dist < GUIDE_EDGE_GLIDE_RADIUS and vertex_dist >= GUIDE_VERTEX_LOCK_RADIUS:
				var glide_t: float = 1.0 - edge_dist / GUIDE_EDGE_GLIDE_RADIUS
				var glide_damp_mul: float = 1.0 + GUIDE_STICK_EDGE_GLIDE_DAMP_EXTRA * glide_t
				forces[i] -= normal_velocity * (GUIDE_EDGE_GLIDE_DAMPING * glide_t * glide_damp_mul)
		if vertex_dist < GUIDE_VERTEX_SNAP_RADIUS:
			var vertex_strength: float = 1.0 - vertex_dist / GUIDE_VERTEX_SNAP_RADIUS
			var vertex_spring_mul: float = 1.0 + GUIDE_STICK_VERTEX_SPRING_EXTRA * vertex_strength
			var vertex_damp_mul: float = 1.0 + GUIDE_STICK_SNAP_DAMP_EXTRA * vertex_strength
			var vertex_target: Vector2 = feature.get("vertex_pos", pos) as Vector2
			forces[i] += (vertex_target - pos) * (GUIDE_VERTEX_SPRING * vertex_strength * vertex_spring_mul)
			forces[i] -= point_velocities[i] * (GUIDE_SNAP_DAMPING * vertex_strength * vertex_damp_mul)
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
		forces[i] += (lock_pos - pos) * (GUIDE_VERTEX_LOCK_SPRING * lock_mul * lock_spring_mul)
		forces[i] -= point_velocities[i] * (GUIDE_VERTEX_LOCK_DAMPING * lock_mul * lock_damp_mul)


func _constrain_forces_for_edge_slide(forces: Array[Vector2], nearest_features: Array, vertex_locks: Dictionary) -> void:
	var fm: int = _get_player_force_mode()
	var mask_n: int = _phys_active_mask.size() if _phys_mask_enabled else 0
	for i in range(_game.point_positions.size()):
		if _is_locked(i):
			continue
		if _phys_mask_enabled and i < mask_n and _phys_active_mask[i] == 0:
			continue  # 非アクティブポイントへの辺スライド拘束はスキップ
		var feature: Dictionary = nearest_features[i] as Dictionary
		if _is_guide_snap_bypassed_by_player_force(i, feature):
			continue
		# 頂点ロック済みポイントはスライド拘束をスキップ（角でタンジェントが不定になるため頂点ロックバネに任せる）
		if vertex_locks.has(i):
			continue
		var pos: Vector2 = _game.point_positions[i]
		var edge_dist: float = feature.get("edge_dist", INF) as float
		if edge_dist >= GUIDE_EDGE_GLIDE_RADIUS:
			continue
		# 引力操作でガイドへ向かって接近中のポイントはスライド拘束をスキップ（スナップ関数が弾く）
		if fm > 0:
			var inward_normal: Vector2 = _feature_edge_normal(feature, pos)
			if point_velocities[i].dot(inward_normal) > GUIDE_ATTRACT_APPROACH_THRESHOLD:
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


func _apply_ideal_vertex_drift(forces: Array[Vector2], nearest_features: Array) -> void:
	var corner_world: Array = _game.stage_manager.get_corner_positions_world()
	if corner_world.is_empty():
		return
	var n: int = _game.point_positions.size()
	var nc: int = corner_world.size()
	var mask_n: int = _phys_active_mask.size() if _phys_mask_enabled else 0

	# 各コーナーの占有者を事前計算: OCCUPIED_RADIUS 以内で最も近いポイント index (-1=未占有)
	var corner_occupant: Array = []
	corner_occupant.resize(nc)
	for j in range(nc):
		var c_pos: Vector2 = corner_world[j] as Vector2
		var best_k: int = -1
		var best_kd: float = IDEAL_VERTEX_OCCUPIED_RADIUS
		for k in range(n):
			if _is_locked(k):
				continue
			var d: float = _game.point_positions[k].distance_to(c_pos)
			if d < best_kd:
				best_kd = d
				best_k = k
		corner_occupant[j] = best_k

	for i in range(n):
		if _is_locked(i):
			continue
		if i < _vertex_lock_flags.size() and _vertex_lock_flags[i] != 0:
			continue
		if _phys_mask_enabled and i < mask_n and _phys_active_mask[i] == 0:
			continue
		var feature: Dictionary = nearest_features[i] as Dictionary
		if _is_guide_snap_bypassed_by_player_force(i, feature):
			continue
		var edge_dist: float = feature.get("edge_dist", INF) as float
		if edge_dist >= GUIDE_EDGE_SNAP_RADIUS:
			continue
		var pos: Vector2 = _game.point_positions[i]

		# 自分が占有者、または未占有のコーナーの中で最近のものへ引力
		var best_j: int = -1
		var best_dist: float = IDEAL_VERTEX_ATTRACT_RANGE
		for j in range(nc):
			var occ: int = corner_occupant[j]
			if occ != -1 and occ != i:
				continue  # 別ポイントが占有中
			var d: float = pos.distance_to(corner_world[j] as Vector2)
			if d < best_dist:
				best_dist = d
				best_j = j

		if best_j >= 0:
			forces[i] += (corner_world[best_j] as Vector2 - pos) * IDEAL_VERTEX_SPRING
		else:
			# 範囲内に空きコーナーなし → 最近の占有済みコーナーから押し出す斥力
			var rep_j: int = -1
			var rep_dist: float = IDEAL_VERTEX_ATTRACT_RANGE
			for j in range(nc):
				var d: float = pos.distance_to(corner_world[j] as Vector2)
				if d < rep_dist:
					rep_dist = d
					rep_j = j
			if rep_j >= 0:
				var away: Vector2 = pos - (corner_world[rep_j] as Vector2)
				var al: float = away.length()
				if al < 0.5:
					away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
					al = 1.0
				forces[i] += (away / al) * IDEAL_VERTEX_REPEL_STRENGTH


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


func _build_phys_active_mask(center: Vector2, radius_sq: float) -> void:
	var n: int = _game.point_positions.size()
	if _phys_active_mask.size() != n:
		_phys_active_mask.resize(n)
	for i in range(n):
		_phys_active_mask[i] = 1 if center.distance_squared_to(_game.point_positions[i]) <= radius_sq else 0
	_phys_mask_enabled = true


func _rebuild_guide_grid_if_needed(guide_loops: Array) -> void:
	var n: int = 0
	for lp: Array in guide_loops:
		n += lp.size()
	if n == _guide_grid_n:
		return
	_guide_grid_n = n
	_guide_grid.clear()
	var cell: float = _GUIDE_GRID_CELL
	for loop_idx in range(guide_loops.size()):
		var loop: Array = guide_loops[loop_idx] as Array
		var loop_size: int = loop.size()
		for vi in range(loop_size):
			var va: Vector2 = loop[vi] as Vector2
			var vb: Vector2 = loop[(vi + 1) % loop_size] as Vector2
			# 辺の AABB をカバーする全セルに登録
			var c0x: int = int(floor(minf(va.x, vb.x) / cell))
			var c1x: int = int(floor(maxf(va.x, vb.x) / cell))
			var c0y: int = int(floor(minf(va.y, vb.y) / cell))
			var c1y: int = int(floor(maxf(va.y, vb.y) / cell))
			for cx in range(c0x, c1x + 1):
				for cy in range(c0y, c1y + 1):
					var k := Vector2i(cx, cy)
					if not _guide_grid.has(k):
						_guide_grid[k] = []
					(_guide_grid[k] as Array).append([va, vb, vi, loop_idx, loop_size])


func _compute_nearest_guide_features(guide_loops: Array) -> Array:
	_rebuild_guide_grid_if_needed(guide_loops)
	var features: Array = []
	var cell: float = _GUIDE_GRID_CELL
	for i in range(_game.point_positions.size()):
		var pos: Vector2 = _game.point_positions[i]
		var best: Dictionary = {
			"vertex_dist": INF, "vertex_pos": pos, "vertex_idx": -1, "vertex_loop": -1,
			"edge_dist": INF, "edge_point": pos, "edge_start_idx": -1, "edge_loop": -1,
			"edge_tangent": Vector2.RIGHT, "loop_size": 0,
		}
		# ±1 セル（±80px）をクエリ → スナップ半径 26px の約 3 倍の安全マージン
		var cx0: int = int(floor((pos.x - cell) / cell))
		var cx1: int = int(floor((pos.x + cell) / cell))
		var cy0: int = int(floor((pos.y - cell) / cell))
		var cy1: int = int(floor((pos.y + cell) / cell))
		for cx in range(cx0, cx1 + 1):
			for cy in range(cy0, cy1 + 1):
				var k := Vector2i(cx, cy)
				if not _guide_grid.has(k):
					continue
				for edge in (_guide_grid[k] as Array):
					var va: Vector2 = edge[0] as Vector2
					var vb: Vector2 = edge[1] as Vector2
					var vi: int = int(edge[2])
					var li: int = int(edge[3])
					var lsz: int = int(edge[4])
					var vd: float = pos.distance_to(va)
					if vd < best["vertex_dist"]:
						best["vertex_dist"] = vd
						best["vertex_pos"] = va
						best["vertex_idx"] = vi
						best["vertex_loop"] = li
					var ep: Vector2 = _closest_point_on_segment(pos, va, vb)
					var ed: float = pos.distance_to(ep)
					if ed < best["edge_dist"]:
						var et: Vector2 = vb - va
						if et.length_squared() > 0.0001:
							et = et.normalized()
						else:
							et = Vector2.RIGHT
						best["edge_dist"] = ed
						best["edge_point"] = ep
						best["edge_start_idx"] = vi
						best["edge_loop"] = li
						best["edge_tangent"] = et
						best["loop_size"] = lsz
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


## 旧バージョンの頂点ロック関数（廃止済み）。
## 新スナップシステムへ移行のため、呼び出し元がない。互換性のため宣言のみ残す。
func _compute_vertex_locks(_nearest_features: Array) -> Dictionary:
	return {}


## ===== 新スナップシステム（アリジゴク型）=====

## ステージ開始時に、コーナー位置に一致するポイントを即座にスナップ確定させる。
## 正三角形の下辺2点など、あらかじめコーナー位置に配置されたポイント向け。
func _presnap_at_corners() -> void:
	var corners: Array = _game.stage_manager.get_corner_positions_world()
	if corners.is_empty():
		return
	_snap_ensure_arrays()
	var n: int = _game.point_positions.size()
	for i in range(n):
		if _snap_point_state[i] != 0:
			continue
		var pos: Vector2 = _game.point_positions[i]
		for ci in range(corners.size()):
			if _snap_corner_occupant.has(ci):
				continue
			if pos.distance_to(corners[ci]) <= SNAP_CORNER_RADIUS:
				_snap_point_state[i] = 1
				_snap_point_target[i] = corners[ci]
				_snap_point_corner_idx[i] = ci
				_snap_corner_occupant[ci] = i
				_game.play_sfx_spot(i, ci)
				_game.ui_renderer.trigger_snap_color(i)
				break


## スナップ状態配列のサイズをポイント数に合わせる
func _snap_ensure_arrays() -> void:
	var n: int = _game.point_positions.size()
	# PackedByteArray: resize で増減どちらも確実に処理される
	_snap_point_state.resize(n)
	# Array[Vector2]: typed Array の resize 縮小が確実に動作しない場合に備え
	# point_velocities と同様に while ループで確実に増減する
	while _snap_point_target.size() > n:
		_snap_point_target.pop_back()
	while _snap_point_target.size() < n:
		_snap_point_target.append(Vector2.ZERO)
	# PackedInt32Array: resize は新要素を 0 で初期化 → -1 で埋め直す
	if _snap_point_corner_idx.size() != n:
		var old_cn: int = _snap_point_corner_idx.size()
		_snap_point_corner_idx.resize(n)
		for i in range(old_cn, n):
			_snap_point_corner_idx[i] = -1


## ポイント i のスナップを解除し、コーナー占有も解放する
func _snap_release_point(i: int) -> void:
	if i >= _snap_point_state.size():
		return
	if _snap_point_state[i] == 1:
		var ci: int = _snap_point_corner_idx[i]
		if ci >= 0 and _snap_corner_occupant.get(ci, -1) == i:
			_snap_corner_occupant.erase(ci)
		if ci >= 0:
			_game.notify_spot_vertex_released(i, ci)
	_snap_point_state[i] = 0
	_snap_point_corner_idx[i] = -1


## プレイヤーが斥力を point i に向けて発動中かどうか
func _is_player_repelling_this_snap_point(i: int) -> bool:
	if not player_force_repelling:
		return false
	var r: float = PLAYER_FORCE_RADIUS + _empty_repulse_radius_bonus
	return player_position.distance_squared_to(_game.point_positions[i]) <= r * r


## ガイドの辺上で pos に最近接の点を返す。guide_loops は get_active_guide_loops_world() の値。
func _snap_nearest_edge_point(pos: Vector2, guide_loops: Array) -> Vector2:
	var best_pt: Vector2 = pos
	var best_d: float = INF
	for loop in guide_loops:
		var pts: Array = loop as Array
		var lsz: int = pts.size()
		if lsz < 2:
			continue
		for vi in range(lsz):
			var va: Vector2 = pts[vi] as Vector2
			var vb: Vector2 = pts[(vi + 1) % lsz] as Vector2
			var ep: Vector2 = _closest_point_on_segment(pos, va, vb)
			var d: float = pos.distance_to(ep)
			if d < best_d:
				best_d = d
				best_pt = ep
	return best_pt


## 未吸着ポイントをガイド角または辺へ常時バネ力で引き寄せる（Fix #1: スムーズ移動）。
## 吸着確定半径に入ったらその場で確定吸着する（Fix #2: 常に動作）。
## キャッシュ済みの _snap_cached_corner_world / _snap_cached_guide_loops を使用。
func _apply_snap_approach_forces(forces: Array[Vector2]) -> void:
	var n: int = _game.point_positions.size()
	# forces のサイズが n と一致しない場合は安全に早期終了
	if forces.size() != n:
		push_error("[snap_approach] forces size mismatch: forces=%d n=%d" % [forces.size(), n])
		return
	var corner_world: Array = _snap_cached_corner_world
	var guide_loops: Array = _snap_cached_guide_loops
	var n_corners: int = corner_world.size()

	# --- ランプアップ: 経過時間に応じてスナップ強度を 0 → 1 に線形増加 ---
	var snap_t: float = clampf(snap_ramp_elapsed / SNAP_RAMP_DURATION, 0.0, 1.0)
	var eff_corner_radius: float = SNAP_CORNER_RADIUS * snap_t
	var eff_edge_radius: float = SNAP_EDGE_RADIUS * snap_t
	var eff_approach_spring: float = SNAP_APPROACH_SPRING * snap_t

	var tn: int = _snap_point_target.size()
	for i in range(n):
		if _is_locked(i):
			continue
		if _snap_point_state[i] != 0:
			# 吸着済み: 解除条件チェック（遠すぎ or プレイヤー斥力）
			if i < tn:
				var dist: float = _game.point_positions[i].distance_to(_snap_point_target[i])
				if dist > SNAP_RELEASE_RADIUS or _is_player_repelling_this_snap_point(i):
					_snap_release_point(i)
			else:
				_snap_release_point(i)
			continue

		# B-2: プレイヤーが斥力を発動中のポイントはスナップしない
		if _is_player_repelling_this_snap_point(i):
			continue

		# ランプが 0 のときはスナップ・アプローチ力ともにゼロ
		if snap_t <= 0.0:
			continue

		var pos: Vector2 = _game.point_positions[i]

		# === 最近接の空きコーナーを探す（距離制限なし: Fix #2）===
		var best_ci: int = -1
		var best_cd: float = INF
		for ci in range(n_corners):
			var cp: Vector2 = corner_world[ci] as Vector2
			var d: float = pos.distance_to(cp)
			if d >= best_cd:
				continue
			# 先着方式: 空きコーナーのみ
			var occupant: int = int(_snap_corner_occupant.get(ci, -1))
			if occupant < 0 or occupant == i:
				best_cd = d
				best_ci = ci

		if best_ci >= 0:
			var target: Vector2 = corner_world[best_ci] as Vector2
			if best_cd <= eff_corner_radius:
				# コーナー確定吸着
				_snap_corner_occupant[best_ci] = i
				_snap_point_state[i] = 1
				_snap_point_target[i] = target
				_snap_point_corner_idx[i] = best_ci
				_game.point_positions[i] = target
				point_velocities[i] = Vector2.ZERO
				_game.play_sfx_spot(i, best_ci)
				_game.ui_renderer.trigger_snap_color(i)
			else:
				# 常時アプローチバネ力（スムーズ移動）
				forces[i] += (target - pos) * eff_approach_spring
			continue  # 辺スナップは不要

		# === 全コーナー占有 → 辺スナップへフォールバック ===
		if guide_loops.is_empty():
			continue
		var edge_pt: Vector2 = _snap_nearest_edge_point(pos, guide_loops)
		var edge_d: float = pos.distance_to(edge_pt)
		if edge_d <= eff_edge_radius:
			# 辺確定吸着
			_snap_point_state[i] = 2
			_snap_point_target[i] = edge_pt
			_snap_point_corner_idx[i] = -1
			_game.point_positions[i] = edge_pt
			point_velocities[i] = Vector2.ZERO
		else:
			# 常時アプローチバネ力（辺方向）
			forces[i] += (edge_pt - pos) * eff_approach_spring


## 未吸着ポイント同士が重ならないよう分離力を加える（Fix #3）。
## 吸着済みポイントは対象外（snap spring に任せる）。
func _apply_snap_separation_forces(forces: Array[Vector2]) -> void:
	var n: int = _game.point_positions.size()
	if forces.size() != n:
		push_error("[snap_sep] forces size mismatch: forces=%d n=%d" % [forces.size(), n])
		return
	var sn: int = _snap_point_state.size()
	for i in range(n - 1):
		if _is_locked(i):
			continue
		var i_snapped: bool = i < sn and _snap_point_state[i] != 0
		var pi: Vector2 = _game.point_positions[i]
		for j in range(i + 1, n):
			if _is_locked(j):
				continue
			var j_snapped: bool = j < sn and _snap_point_state[j] != 0
			# 両方吸着済みは別頂点に固定済みなのでスキップ
			if i_snapped and j_snapped:
				continue
			var pj: Vector2 = _game.point_positions[j]
			var delta_v: Vector2 = pi - pj
			var dist: float = delta_v.length()
			var dir: Vector2
			var falloff: float
			if dist < 0.001:
				# 方針2: ゼロ距離フォールバック — インデックス差から決定論的な固定方向を生成
				# 黄金比スケールにより各ペアが均等分散した異なる方向を持つ
				var angle: float = float(i - j) * PI * 0.6180339887
				dir = Vector2(cos(angle), sin(angle))
				falloff = 1.0  # 最大斥力
			elif dist >= SNAP_SEPARATION_DISTANCE:
				continue
			else:
				dir = delta_v / dist
				falloff = 1.0 - dist / SNAP_SEPARATION_DISTANCE
			var fmag: float = SNAP_SEPARATION_STRENGTH * falloff * falloff
			# 方針1: 吸着済みは固定障害物として扱い、未吸着側にのみ力を適用
			if not i_snapped:
				forces[i] += dir * fmag
			if not j_snapped:
				forces[j] -= dir * fmag


## 吸着後の弱いバネ力を forces に加算する。
## 吸着点が SNAP_RELEASE_RADIUS を超えていたら自動解除する。
## 収束後（ターゲットに十分近い）は速度をゼロにしてマイクロ振動を防ぐ。
func _apply_snap_spring_forces(forces: Array[Vector2]) -> void:
	var n: int = _snap_point_state.size()
	if n == 0:
		return
	# forces のサイズが point_positions と一致しない場合は安全に早期終了
	var fn: int = forces.size()
	if fn != _game.point_positions.size():
		push_error("[snap_spring] forces size mismatch: forces=%d pts=%d" % [fn, _game.point_positions.size()])
		return
	var tn: int = _snap_point_target.size()
	for i in range(mini(n, _game.point_positions.size())):
		if _snap_point_state[i] == 0:
			continue
		if _is_locked(i):
			_snap_release_point(i)
			continue
		if i >= tn:
			_snap_release_point(i)
			continue
		var pos: Vector2 = _game.point_positions[i]
		var target: Vector2 = _snap_point_target[i]
		var dist: float = pos.distance_to(target)
		# 吸着解除条件
		if dist > SNAP_RELEASE_RADIUS or _is_player_repelling_this_snap_point(i):
			_snap_release_point(i)
			continue
		# 収束判定: ターゲットに十分近いなら位置を固定して速度をゼロに
		if dist < DRAG_POSITION_EPSILON:
			_game.point_positions[i] = target
			point_velocities[i] = Vector2.ZERO
			continue
		# 弱いバネ力で引き戻す
		if i < fn:
			forces[i] += (target - pos) * SNAP_SPRING
			forces[i] -= point_velocities[i] * SNAP_DAMPING


## 全吸着点を走査し、ターゲットから SNAP_RELEASE_RADIUS 以上離れていたら解除する
## （交差解消後の位置変化への対応）
func _snap_release_far_points() -> void:
	var n: int = _snap_point_state.size()
	var tn: int = _snap_point_target.size()
	for i in range(mini(n, _game.point_positions.size())):
		if _snap_point_state[i] == 0:
			continue
		if i >= tn:
			_snap_release_point(i)
			continue
		if _game.point_positions[i].distance_to(_snap_point_target[i]) > SNAP_RELEASE_RADIUS:
			_snap_release_point(i)


## 全頂点が占有され、かつKATAポイントの結合順がガイド頂点順と一致（正転・逆転どちらも可）するか
func is_snap_clear() -> bool:
	var n_corners: int = _game.stage_manager.shape_corner_points.size()
	var n: int = _game.point_positions.size()
	if n_corners == 0 or n == 0 or n != n_corners:
		return false
	for ci in range(n_corners):
		if not _snap_corner_occupant.has(ci):
			return false
	var k: int = int(_snap_corner_occupant[0])
	# 正転チェック: snap[ci] == (ci + k) % n
	var forward_ok: bool = true
	for ci in range(n_corners):
		if int(_snap_corner_occupant[ci]) != (ci + k) % n:
			forward_ok = false
			break
	if forward_ok:
		return true
	# 逆転チェック: snap[ci] == (k - ci + n) % n
	for ci in range(n_corners):
		if int(_snap_corner_occupant[ci]) != (k - ci + n) % n:
			return false
	return true


## 全頂点が占有されているか（巡回順チェックなし）
## NOTE: 2026-07時点で未使用（zouステージのクリア判定フォールバックを廃止したため）
func is_all_corners_occupied() -> bool:
	var n_corners: int = _game.stage_manager.shape_corner_points.size()
	var n: int = _game.point_positions.size()
	if n_corners == 0 or n == 0 or n != n_corners:
		return false
	return _snap_corner_occupant.size() == n_corners


## スコア (0.0〜1.0) = (A + B) / (2N)
## A: 頂点に乗っているポイント数、B: 最良サイクル順で一致しているポイント数
func get_snap_score() -> float:
	var n_corners: int = _game.stage_manager.shape_corner_points.size()
	var n: int = _game.point_positions.size()
	if n_corners == 0 or n == 0 or n != n_corners:
		return 0.0
	# A: 占有されている頂点数
	var a: int = _snap_corner_occupant.size()
	# B: 最良サイクル一致数（全N通りのオフセットを正転・逆転で試す）
	var b: int = 0
	for k in range(n):
		var cnt_fwd: int = 0
		var cnt_rev: int = 0
		for ci in range(n_corners):
			var occ: int = int(_snap_corner_occupant.get(ci, -1))
			if occ < 0:
				continue
			if occ == (ci + k) % n:
				cnt_fwd += 1
			if occ == (k - ci + n) % n:
				cnt_rev += 1
		b = maxi(b, maxi(cnt_fwd, cnt_rev))
	return float(a + b) / float(2 * n_corners)


## 近接スナップシステム: 頂点への近接バネ吸着 + 占有頂点からの斥力
## - 未吸着ポイントが SNAP_VERTEX_ATTRACT_RADIUS 以内の空き頂点に近づくとバネ引力
## - SNAP_CORNER_RADIUS 以内で確定吸着（1頂点1ポイント）
## - 占有済み頂点の SNAP_REPEL_RADIUS 以内では二次減衰斥力
## - 吸着後の保持・解除は _apply_snap_spring_forces が担当
func _apply_snap_vertex_forces(forces: Array[Vector2]) -> void:
	var n: int = _game.point_positions.size()
	if forces.size() != n:
		return
	var corners: Array = _snap_cached_corner_world
	var n_corners: int = corners.size()
	if n_corners == 0:
		return

	for i in range(n):
		if _is_locked(i):
			continue
		if _snap_point_state[i] != 0:
			continue  # 吸着済みは _apply_snap_spring_forces に委ねる
		if _is_player_repelling_this_snap_point(i):
			continue

		var pos: Vector2 = _game.point_positions[i]

		# --- 空き頂点への近接バネ + 確定吸着 ---
		var best_ci: int = -1
		var best_cd: float = SNAP_VERTEX_ATTRACT_RADIUS  # この距離以内のみ対象

		for ci in range(n_corners):
			var occupant: int = int(_snap_corner_occupant.get(ci, -1))
			if occupant >= 0 and occupant != i:
				continue  # 他のポイントが占有済み
			var d: float = pos.distance_to(corners[ci] as Vector2)
			if d < best_cd:
				best_cd = d
				best_ci = ci

		if best_ci >= 0:
			var target: Vector2 = corners[best_ci] as Vector2
			if best_cd <= SNAP_CORNER_RADIUS:
				# 確定吸着: 頂点へ瞬着・占有登録
				_snap_corner_occupant[best_ci] = i
				_snap_point_state[i] = 1
				_snap_point_target[i] = target
				_snap_point_corner_idx[i] = best_ci
				_game.point_positions[i] = target
				point_velocities[i] = Vector2.ZERO
				_game.play_sfx_spot(i, best_ci)
				_game.ui_renderer.trigger_snap_color(i)
			else:
				# 近接バネ力
				forces[i] += (target - pos) * SNAP_VERTEX_APPROACH_SPRING

		# --- 占有済み頂点からの斥力（範囲制限あり・二次減衰）---
		for ci in range(n_corners):
			var occupant: int = int(_snap_corner_occupant.get(ci, -1))
			if occupant < 0 or occupant == i:
				continue
			var corner_pos: Vector2 = corners[ci] as Vector2
			var d: float = pos.distance_to(corner_pos)
			if d < SNAP_REPEL_RADIUS and d > 0.1:
				var dir: Vector2 = (pos - corner_pos) / d
				var t: float = 1.0 - d / SNAP_REPEL_RADIUS
				forces[i] += dir * (SNAP_REPEL_STRENGTH * t * t)


## 2-opt 置換後にスナップ状態配列を同じ順序で並び替える
func _snap_permute_after_reorder(ord: PackedInt32Array) -> void:
	var n: int = ord.size()
	if n == 0 or _snap_point_state.size() != n or _snap_point_target.size() != n:
		# サイズ不一致: 置換を安全に行えないため、全スナップ状態をリセットして整合性を復元する。
		# 黙って return すると座標順序だけ書き換わり、スナップ状態が旧インデックスのまま残る。
		push_warning("[snap] _snap_permute_after_reorder: サイズ不一致 ord=%d state=%d target=%d cidx=%d — 全スナップ状態をリセット" % [
			n, _snap_point_state.size(), _snap_point_target.size(), _snap_point_corner_idx.size()])
		_snap_corner_occupant.clear()
		for i in range(_snap_point_state.size()):
			_snap_point_state[i] = 0
		for i in range(_snap_point_corner_idx.size()):
			_snap_point_corner_idx[i] = -1
		return
	# 逆置換 (old_idx → new_idx)
	var inv: PackedInt32Array = PackedInt32Array()
	inv.resize(n)
	for new_i in range(n):
		inv[ord[new_i]] = new_i
	# 状態配列を置換
	var new_state: PackedByteArray = PackedByteArray()
	new_state.resize(n)
	var new_target: Array[Vector2] = []
	new_target.resize(n)
	var new_cidx: PackedInt32Array = PackedInt32Array()
	new_cidx.resize(n)
	for new_i in range(n):
		var old_i: int = ord[new_i]
		new_state[new_i] = _snap_point_state[old_i]
		new_target[new_i] = _snap_point_target[old_i]
		new_cidx[new_i] = _snap_point_corner_idx[old_i]
	_snap_point_state = new_state
	_snap_point_target = new_target
	_snap_point_corner_idx = new_cidx
	# コーナー占有辞書のポイントインデックスを新インデックスに更新。
	# old_pi の state が 0（ghost occupancy）のエントリは引き継がない。
	var new_occ: Dictionary = {}
	for ci in _snap_corner_occupant:
		var old_pi: int = int(_snap_corner_occupant[ci])
		if old_pi >= 0 and old_pi < n and _snap_point_state[old_pi] == 1:
			new_occ[ci] = inv[old_pi]
	_snap_corner_occupant = new_occ


## スナップ状態の整合性を毎フレーム検証し、ghost occupancy と二重スナップを修正する（方針2・3）
func _snap_validate_and_fix_consistency() -> void:
	var n: int = _game.point_positions.size()
	if n == 0:
		return
	var sn: int = _snap_point_state.size()
	var cn: int = _snap_point_corner_idx.size()
	var corners: Array = _snap_cached_corner_world
	var frame: int = Engine.get_process_frames()

	# Pass 1: _snap_corner_occupant の ghost エントリを除去
	# dict[ci]=pi なのに state[pi]!=1 または corner_idx[pi]!=ci のエントリ
	var ghost_cis: Array[int] = []
	for ci: int in _snap_corner_occupant:
		var pi: int = int(_snap_corner_occupant[ci])
		if pi < 0 or pi >= sn:
			ghost_cis.append(ci)
			push_warning("[snap] frame=%d ghost: ci=%d pi=%d (out of range, sn=%d n=%d)" % [frame, ci, pi, sn, n])
			continue
		var actual_state: int = int(_snap_point_state[pi])
		var actual_ci: int = int(_snap_point_corner_idx[pi]) if pi < cn else -1
		if actual_state != 1 or actual_ci != ci:
			ghost_cis.append(ci)
			push_warning("[snap] frame=%d ghost: ci=%d pi=%d state=%d corner_idx=%d (expected state=1 ci=%d)" % [
				frame, ci, pi, actual_state, actual_ci, ci])
	for ci: int in ghost_cis:
		_snap_corner_occupant.erase(ci)

	# Pass 2: 同一コーナーに state=1 が2つ以上存在する二重スナップを距離優先で解消
	# 孤立スナップ解除（Pass 3）より先に実行することで、辞書が敗者を指していても
	# 距離で正しい勝者を決定してから辞書を上書きできる。
	var corner_claimants: Dictionary = {}
	for i in range(mini(sn, n)):
		if int(_snap_point_state[i]) != 1:
			continue
		var ci: int = int(_snap_point_corner_idx[i]) if i < cn else -1
		if ci < 0:
			continue
		if not corner_claimants.has(ci):
			corner_claimants[ci] = [] as Array
		(corner_claimants[ci] as Array).append(i)

	for ci: int in corner_claimants:
		var pts: Array = corner_claimants[ci] as Array
		if pts.size() <= 1:
			continue
		var pt_states: Array = pts.map(func(p: int) -> int: return int(_snap_point_state[p]))
		push_warning("[snap] frame=%d DOUBLE SNAP ci=%d points=%s states=%s n=%d sn=%d" % [
			frame, ci, str(pts), str(pt_states), n, sn])
		var corner_pos: Vector2 = (corners[ci] as Vector2) if ci < corners.size() else Vector2.ZERO
		var best_pi: int = -1
		var best_d: float = INF
		for pi: int in pts:
			var d: float = _game.point_positions[pi].distance_to(corner_pos)
			if d < best_d:
				best_d = d
				best_pi = pi
		# 勝者を辞書に上書き（辞書が敗者を指していた場合も確実に更新）
		_snap_corner_occupant[ci] = best_pi
		for pi: int in pts:
			if pi == best_pi:
				continue
			_snap_point_state[pi] = 0
			if pi < cn:
				_snap_point_corner_idx[pi] = -1

	# Pass 3: state=1 なのに辞書と食い違うポイント（孤立スナップ）を解除
	# Pass 2 で二重スナップが解消済みのため、辞書は正しい勝者を指している前提で動作する。
	for i in range(mini(sn, n)):
		if int(_snap_point_state[i]) != 1:
			continue
		var ci: int = int(_snap_point_corner_idx[i]) if i < cn else -1
		var dict_owner: int = int(_snap_corner_occupant.get(ci, -1))
		if ci < 0 or dict_owner != i:
			push_warning("[snap] frame=%d orphan snap: pi=%d state=1 ci=%d dict_owner=%d" % [
				frame, i, ci, dict_owner])
			_snap_point_state[i] = 0
			if i < cn:
				_snap_point_corner_idx[i] = -1

	# Pass 4: 保険 — 任意2点間の完全重複（dist < 0.5px）を検出し強制分離
	# 方針1・2で通常は発生しないが、別経路の重複に対するフォールバック。
	# ロック・吸着状態に関わらずチェックし、未ロック側の座標を直接修正する。
	for i in range(n - 1):
		if _is_locked(i):
			continue
		for j in range(i + 1, n):
			if _is_locked(j):
				continue
			var pi4: Vector2 = _game.point_positions[i]
			var pj4: Vector2 = _game.point_positions[j]
			var d4: float = pi4.distance_to(pj4)
			if d4 >= 0.5:
				continue
			push_warning("[snap] frame=%d OVERLAP: pi=%d(%s) pj=%d(%s) dist=%.4f" % [
				frame, i, str(pi4), j, str(pj4), d4])
			var angle4: float = float(i - j) * PI * 0.6180339887
			var sep_dir: Vector2 = Vector2(cos(angle4), sin(angle4))
			# 片側 0.25px ずつ計 0.5px 分離
			_game.point_positions[i] = pi4 + sep_dir * 0.25
			_game.point_positions[j] = pj4 - sep_dir * 0.25


## ===== 旧スナップシステム（未使用、互換性のため残存）=====
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
	if not _game.is_inside_tree():
		return
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


func is_ax_combo_held() -> bool:
	return ax_combo_held


## ポイント point_idx をコーナー corner_idx に即座に強制スナップする（ステージ1仮実装用）
## コーナー吸着確定（_snap_point_state == 1）か
func is_point_corner_snapped(idx: int) -> bool:
	return idx < _snap_point_state.size() and _snap_point_state[idx] == 1


## 指定ポイントのスナップ状態を強制的に解除する（rulesデモの初期形状セットアップ用）。
func unsnap_point(idx: int) -> void:
	if idx < 0 or idx >= _snap_point_state.size():
		return
	if _snap_point_state[idx] == 1:
		var ci: int = _snap_point_corner_idx[idx] if idx < _snap_point_corner_idx.size() else -1
		if ci >= 0:
			_snap_corner_occupant.erase(ci)
	_snap_point_state[idx] = 0
	if idx < _snap_point_corner_idx.size():
		_snap_point_corner_idx[idx] = -1


func get_point_snap_corner_index(idx: int) -> int:
	if idx < 0 or idx >= _snap_point_corner_idx.size():
		return -1
	return _snap_point_corner_idx[idx]


## スナップ未確定のポイントかどうかを返す（ネコアニメーション描画用）
func is_point_free(i: int) -> bool:
	return i < _snap_point_state.size() and _snap_point_state[i] == 0


func _notify_points_changed() -> void:
	if on_points_changed.is_valid():
		on_points_changed.call()


func _notify_selection_changed() -> void:
	if on_selection_changed.is_valid():
		on_selection_changed.call()
