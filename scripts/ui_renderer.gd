# =============================================================================
# UIRenderer - 描画モジュール
# =============================================================================
# ロゴ、タイトル、メニュー、ゲーム画面、HUD、パーティクル等の描画を担当。
# game の _draw() から draw() / draw_pause_overlay() を呼び出す。

class_name UIRenderer
extends RefCounted

# --- Button constants (rules / guide_info / cleared / results) ---
const BTN_HEIGHT := 56.0
const BTN_FONT_SIZE := 40
const BTN_PADDING_X := 50.0  # cleared/results の左右余白

# --- Particle constants ---
const PARTICLE_COUNT := 60
const PARTICLE_LIFETIME := 2.5
const PARTICLE_SPEED_MIN := 150.0
const PARTICLE_SPEED_MAX := 500.0
const PARTICLE_COLORS: Array[Color] = [
	Color(0.95, 0.19, 0.32),  # accent red
	Color(0.98, 0.45, 0.50),  # light red
	Color(0.75, 0.15, 0.25),  # dark red
	Color(1.0, 0.937, 0.89), # white base
	Color(0.85, 0.30, 0.40),  # medium red
	Color(0.40, 0.25, 0.32),  # dark muted red
]

# --- Spore particle constants (選択中ポイントの胞子エフェクト) ---
# ポイント選択: 胞子量すくなめ、スピードゆっくり、LIFETIME で飛ぶ距離が決まる
const SPORE_SELECTION_LIFETIME := 0.8
const SPORE_SELECTION_SPEED_MIN := 8.0
const SPORE_SELECTION_SPEED_MAX := 22.0
const SPORE_SELECTION_SPAWN_INTERVAL := 0.28  # 長い＝胞子少なめ
# つかみ状態: 胞子量おおめ、スピード速く、LIFETIME で飛ぶ距離が決まる
const SPORE_GRAB_LIFETIME := 0.6
const SPORE_GRAB_SPEED_MIN := 25.0
const SPORE_GRAB_SPEED_MAX := 55.0
const SPORE_GRAB_SPAWN_INTERVAL := 0.06  # 短い＝胞子多め
# 共通
const SPORE_SIZE_MIN := 5.5
const SPORE_SIZE_MAX := 15.5
const SPORE_MOVE_BURST_COUNT := 2   # つかんで移動時（後から変更する可能性あり、処理は残す）
const SPORE_SELECTION_BURST_COUNT := 12  # 選択変更時（左スティック・十字キー等）に追加で飛ばす胞子の数
const SPORE_CONVERGE_SPAWN_RADIUS_MIN := 35.0  # つかみ状態: 胞子の発生距離（中心からの最小）
const SPORE_CONVERGE_SPAWN_RADIUS_MAX := 65.0  # つかみ状態: 胞子の発生距離（中心からの最大）
const SPORE_CONVERGE_REMOVE_DIST := 8.0  # 収束胞子が中心に近づいたら削除する距離
const SPORE_COLOR_WHITE := Color(1.0, 0.937, 0.89)   # 白の点
const SPORE_COLOR_GLOW := Color(0.95, 0.19, 0.32, 1.0)  # 赤（alpha は LAYERS で制御）
# 外周へ行くほど透過する同心円の [半径倍率, alpha]（外側→内側の順）
const SPORE_GLOW_LAYERS: Array[Array] = [
	[1.6, 0.03],
	[1.4, 0.08],
	[1.25, 0.15],
	[1.1, 0.25],
	[0.95, 0.38],
]

# --- 選択していないポイント・線 ---
const LINE_COLOR := Color(0.26, 0.21, 0.28)
const LINE_COLOR_2 := Color(0.55, 0.20, 0.30)
const POINT_COLOR := Color(0.26, 0.21, 0.28)
const POINT_COLOR_2 := Color(0.55, 0.20, 0.30)
const POINT_RADIUS := 9.0
const POINT_RADIUS_HOVER := 13.0
const LINE_WIDTH := 4.0
# ガイド線から遠いほど大きい円（px 半径）。距離は get_distance_to_hint_guide_outline 基準
const POINT_RADIUS_GUIDE_NEAR_MIN := 5.0
const POINT_RADIUS_GUIDE_FAR_MAX := 25.0
const POINT_RADIUS_GUIDE_DIST_FULL_PX := 120.0  # この距離以上で最大半径
# 未ロックのポイント同士で比較し、ズレが最大のものほど上記半径をさらに大きく（最小側はやや小さく）
const POINT_RADIUS_RELATIVE_SPREAD := 0.22  # 最悪点は +(22%)、最良点は −(22%) 相当の倍率

# --- 選択ポイント（白円 + 黒の同心円）---
const SELECTED_POINT_WHITE := Color(1.0, 0.937, 0.89, 1.0)
const SELECTED_POINT_BLACK := Color(0.26, 0.21, 0.28, 1.0)  # alpha は LAYERS で制御
const SELECTED_POINT_BLACK_LAYERS: Array[Array] = [
	[2.0, 0.06],   # [半径倍率, alpha] 黒の同心円（白円に対する倍率）
	[1.5, 0.14],
	[1.25, 0.24],
	[1.10, 0.38],
]

# --- 選択ポイントから接続2点へのレーザーエフェクト ---
const LASER_BLUE := Color(0.95, 0.19, 0.32, 1.0)
const LASER_WHITE := Color(1.0, 0.937, 0.89, 1.0)
const LASER_LENGTH_RATIO := 2.0 / 3.0  # ポイント間距離の何割で消えるか
const LASER_SEGMENTS := 16
const LASER_THICK_LAYERS: Array[Array] = [  # [幅, alpha] 外側→内側
	[14.0, 0.08],
	[10.0, 0.18],
	[6.0, 0.35],
	[3.0, 0.55],
]
const LASER_WHITE_WIDTH := 1.5

# --- Particle state ---
var particles: Array[Dictionary] = []
var particle_spawn_time: float = 0.0
var spore_particles: Array[Dictionary] = []
var _spore_spawn_accum: float = 0.0

# --- Animation state ---
var _prev_state: String = ""          # 前フレームのゲームステート
var _transition_alpha: float = 1.0    # 画面遷移フェード（0=暗転中, 1=表示中）
var _transition_dir: int = 0          # 0=なし, 1=フェードイン, -1=フェードアウト
var _transition_speed: float = 4.0    # 1/秒（0.25秒で完了）
var _pending_state: String = ""       # フェードアウト完了後に切り替えるステート

var _btn_hover_scales: Dictionary = {}  # ボタンID → 現在のスケール（1.0〜1.05）
var _btn_hover_shadows: Dictionary = {} # ボタンID → 現在のシャドウ追加量
var _btn_hover_targets: Dictionary = {} # ボタンID → スケールの目標値（ホバー中は1.05）
var _btn_hover_active: Dictionary = {}  # ボタンID → 前フレームでホバーだったか
var _btn_press_timers: Dictionary = {}  # ボタンID → 押下アニメ進行（0.0〜1.0, -1で無効）
const BTN_PRESS_DURATION := 0.18       # 押下縮小アニメの所要時間（秒）
var _btn_press_callback: Callable      # 押下アニメ完了後に実行するコールバック
var _btn_press_pending: bool = false    # 押下アニメ待機中（遷移を遅延させる）
var _hover_sfx_suppress_until: float = 0.0  # ホバーSE抑制タイマー

var _guide_info_time: float = 0.0     # guide_info 表示開始からの経過時間
var _countdown_scales: Dictionary = {} # カウントダウン数字 → スケールアニメ用
var _countdown_prev: int = -1

var _clear_anim_time: float = -1.0    # クリア演出の開始時刻
var _pause_anim_time: float = -1.0    # ポーズ開演出の開始時刻
var _pause_closing: bool = false       # ポーズ閉じ中
var _stage_intro_time: float = -1.0   # ステージ開始演出の開始時刻
const STAGE_INTRO_DURATION := 0.5     # 演出の長さ（秒）
var _results_anim_time: float = -1.0  # リザルト画面の開始時刻
const RESULTS_SLIDE_DURATION := 0.7   # スライドイン所要時間（秒）
# Result 画面の見出し・TOTAL ラベル（基準からの倍率）
const RESULT_SCREEN_TITLE_FS := 120  # 48 * 2.5
const RESULT_TOTAL_LABEL_FS := 84  # 28 * 3
# playing 中のポイント描画フレーム用: 未ロック各点のガイド距離の min/max（相対的な円サイズ用）
var _guide_dist_min: float = 0.0
var _guide_dist_max: float = 0.0
var _guide_dist_have_bounds: bool = false

# --- Title Intro Animation（描画・タイムラインは title_intro_animation.gd）---
var title_intro: TitleIntroAnimator

# --- game 参照 (Node2D/CanvasItem) ---
var _game: Node2D
var _stage_renderer: StageRenderer


func _init(game: Node2D) -> void:
	_game = game
	title_intro = TitleIntroAnimator.new(_game, Callable(self, "suppress_hover_sfx"))
	_stage_renderer = StageRenderer.new(game, self)


func capture_stage_result_shapes() -> Dictionary:
	return _stage_renderer.capture_result_loops()


# --- Background ---

func _draw_bg(vp: Vector2) -> void:
	"""背景画像を描画。テクスチャがない場合は白でフォールバック"""
	if _game.bg_texture:
		_game.draw_texture_rect(_game.bg_texture, Rect2(Vector2.ZERO, vp), false)
	else:
		_game.draw_rect(Rect2(Vector2.ZERO, vp), Color.WHITE)


# --- Animation helpers ---

func _ease_out_cubic(t: float) -> float:
	var t1: float = 1.0 - t
	return 1.0 - t1 * t1 * t1

func get_stage_intro_progress() -> float:
	"""ステージ開始演出の進行度 0.0〜1.0（1.0で完了）"""
	if _stage_intro_time < 0.0:
		return 1.0
	var t: float = (Time.get_ticks_msec() / 1000.0 - _stage_intro_time) / STAGE_INTRO_DURATION
	return clampf(t, 0.0, 1.0)

func is_stage_intro_done() -> bool:
	return get_stage_intro_progress() >= 1.0

func _ease_out_back(t: float) -> float:
	"""少し弾むイーズアウト"""
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	var t1: float = t - 1.0
	return 1.0 + c3 * t1 * t1 * t1 + c1 * t1 * t1

func _ease_in_out_cubic(t: float) -> float:
	"""イージーイーズ（加速→減速）"""
	if t < 0.5:
		return 4.0 * t * t * t
	else:
		var p: float = -2.0 * t + 2.0
		return 1.0 - p * p * p / 2.0

func update_animations(delta: float) -> void:
	"""game._process() から毎フレーム呼ぶ"""
	# 画面遷移フェード
	if _transition_dir != 0:
		_transition_alpha += _transition_dir * _transition_speed * delta
		_transition_alpha = clampf(_transition_alpha, 0.0, 1.0)
		if _transition_dir == -1 and _transition_alpha <= 0.0:
			# フェードアウト完了 → ステート切替 → フェードイン開始
			if _pending_state != "":
				_game.game_state = _pending_state
				_pending_state = ""
			_transition_dir = 1
		elif _transition_dir == 1 and _transition_alpha >= 1.0:
			_transition_dir = 0

	# guide_info タイマー
	if _game.game_state == "guide_info":
		_guide_info_time += delta

	# 前フレームでホバーされなかったボタンの目標を1.0に戻す
	for key in _btn_hover_targets.keys():
		if not _btn_hover_active.get(key, false):
			_btn_hover_targets[key] = 1.0

	# ボタンホバーアニメーション（目標値に向かってスムーズに収束）
	for key in _btn_hover_scales.keys():
		var target: float = _btn_hover_targets.get(key, 1.0)
		if absf(_btn_hover_scales[key] - target) > 0.001:
			# 1.3→1.05 の収束（約0.1秒）
			_btn_hover_scales[key] = move_toward(_btn_hover_scales[key], target, delta * 3.0)
		else:
			_btn_hover_scales[key] = target
		# シャドウ: ホバー中は3.5に向かって上昇、非ホバーは0に減衰
		var shadow_target: float = 3.5 if target > 1.0 else 0.0
		_btn_hover_shadows[key] = move_toward(_btn_hover_shadows[key], shadow_target, delta * 25.0)

	# 押下アニメーション進行
	var finished_keys: Array = []
	for key in _btn_press_timers.keys():
		if _btn_press_timers[key] >= 0.0:
			_btn_press_timers[key] += delta / BTN_PRESS_DURATION
			if _btn_press_timers[key] > 1.0:
				_btn_press_timers[key] = 1.0
				finished_keys.append(key)
	for key in finished_keys:
		_btn_press_timers.erase(key)
	# 押下アニメ完了 → コールバック実行
	if _btn_press_pending and _btn_press_timers.is_empty():
		_btn_press_pending = false
		if _btn_press_callback.is_valid():
			_btn_press_callback.call()
			_btn_press_callback = Callable()

	# フレーム終了時にホバーフラグをリセット（次フレームの set_btn_hover で再設定される）
	for key in _btn_hover_active.keys():
		_btn_hover_active[key] = false

func set_btn_hover(btn_id: String) -> void:
	"""ボタンがホバー/選択状態であることを通知（毎フレーム _draw 内から呼ばれる）"""
	var is_new_hover: bool = false
	# 初めてこのIDが登場した場合のみ 1.15 に瞬間拡大
	if not _btn_hover_scales.has(btn_id):
		_btn_hover_scales[btn_id] = 1.15
		_btn_hover_shadows[btn_id] = 0.0
		_btn_hover_targets[btn_id] = 1.05
		is_new_hover = true
	elif _btn_hover_targets.get(btn_id, 1.0) <= 1.001:
		# 非ホバー→ホバーに復帰: 再度バウンス開始
		_btn_hover_scales[btn_id] = 1.15
		_btn_hover_shadows[btn_id] = _btn_hover_shadows.get(btn_id, 0.0)
		_btn_hover_targets[btn_id] = 1.05
		is_new_hover = true
	else:
		# 既にホバー中: 目標だけ維持
		_btn_hover_targets[btn_id] = 1.05
	_btn_hover_active[btn_id] = true
	if is_new_hover:
		var now_sec: float = Time.get_ticks_msec() / 1000.0
		if now_sec >= _hover_sfx_suppress_until and _game.game_state != "title_intro":
			_game._play_sfx(_game.sfx_on)

func suppress_hover_sfx(duration: float) -> void:
	"""ホバーSEを一定時間抑制する"""
	_hover_sfx_suppress_until = Time.get_ticks_msec() / 1000.0 + duration

func set_btn_press(btn_id: String) -> void:
	"""ボタン押下アニメーションを開始（即時、遷移遅延なし）"""
	_btn_press_timers[btn_id] = 0.0

func set_btn_press_with_callback(btn_id: String, callback: Callable, play_click_se: bool = true) -> void:
	"""ボタン押下アニメーションを開始し、完了後にコールバックを実行"""
	_btn_press_timers[btn_id] = 0.0
	_btn_press_callback = callback
	_btn_press_pending = true
	if play_click_se:
		_game._play_sfx(_game.sfx_click)

func get_btn_scale(btn_id: String) -> float:
	# 押下アニメ中はそちらが優先
	if _btn_press_timers.has(btn_id) and _btn_press_timers[btn_id] >= 0.0:
		var t: float = _btn_press_timers[btn_id]
		var eased: float = _ease_in_out_cubic(t)
		var base_sc: float = _btn_hover_scales.get(btn_id, 1.0)
		return lerpf(base_sc, 0.0, eased)
	return _btn_hover_scales.get(btn_id, 1.0)

func get_btn_shadow_extra(btn_id: String) -> float:
	# 押下アニメ中はシャドウも縮小
	if _btn_press_timers.has(btn_id) and _btn_press_timers[btn_id] >= 0.0:
		var t: float = _btn_press_timers[btn_id]
		var eased: float = _ease_in_out_cubic(t)
		var base_sh: float = _btn_hover_shadows.get(btn_id, 0.0)
		return lerpf(base_sh, 0.0, eased)
	return _btn_hover_shadows.get(btn_id, 0.0)

func start_transition(to_state: String) -> void:
	"""フェードアウト→ステート切替→フェードインの画面遷移を開始"""
	_pending_state = to_state
	_transition_dir = -1

func on_state_changed(new_state: String) -> void:
	"""ステート変更時に呼ぶ（演出タイマーリセット等）"""
	if new_state == "guide_info":
		_guide_info_time = 0.0
	if new_state == "cleared":
		_clear_anim_time = Time.get_ticks_msec() / 1000.0
	if new_state == "playing":
		_stage_intro_time = Time.get_ticks_msec() / 1000.0
	if new_state == "results":
		_results_anim_time = Time.get_ticks_msec() / 1000.0
	if new_state == "title_intro":
		title_intro.reset()
	_prev_state = new_state


# =============================================================================
# Public API
# =============================================================================

func draw(state: String, vp: Vector2) -> void:
	# ステート変更検出
	if state != _prev_state:
		on_state_changed(state)

	match state:
		"logo":
			_draw_logo(vp)
		"title_intro":
			title_intro.draw(vp)
		"title":
			_draw_title(vp)
		"menu":
			_draw_menu(vp)
		"config":
			_draw_config(vp)
		"rules":
			_draw_rules(vp)
		"rules_confirm":
			_draw_rules(vp)
			_draw_rules_confirm(vp)
		"guide_info":
			_draw_guide_info(vp)
		"guide_countdown":
			_draw_guide_countdown(vp)
		"playing":
			_draw_game(vp)
		"cleared":
			_draw_game(vp)
			_draw_clear_overlay(vp)
			_draw_particles()
		"results":
			_draw_results(vp)
		"stage_debug":
			_draw_stage_debug(vp)
		"stage_edit":
			_draw_stage_edit(vp)

	# 画面遷移フェードオーバーレイ
	if _transition_alpha < 1.0:
		var fade_a: float = 1.0 - _transition_alpha
		_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(_game.BG_COLOR.r, _game.BG_COLOR.g, _game.BG_COLOR.b, fade_a))

	if _game.debug_stage_test_mode and state == "playing":
		_draw_debug_log_button(vp)


func draw_pause_overlay(vp: Vector2) -> void:
	_draw_pause_overlay(vp)


func spawn_particles(center: Vector2) -> void:
	particles.clear()
	particle_spawn_time = Time.get_ticks_msec() / 1000.0
	for i in range(PARTICLE_COUNT):
		var angle: float = randf() * TAU
		var speed: float = randf_range(PARTICLE_SPEED_MIN, PARTICLE_SPEED_MAX)
		var p := {
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"color": PARTICLE_COLORS[i % PARTICLE_COLORS.size()],
			"size": randf_range(3.0, 7.0),
			"gravity": randf_range(100.0, 250.0),
		}
		particles.append(p)


func update_particles(delta: float) -> void:
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - particle_spawn_time
	if elapsed > PARTICLE_LIFETIME:
		particles.clear()
		return
	for p in particles:
		p["vel"] = p["vel"] as Vector2 + Vector2(0, p["gravity"] as float) * delta
		p["pos"] = p["pos"] as Vector2 + (p["vel"] as Vector2) * delta


func clear_spore_particles() -> void:
	"""ステージ切り替え時に胞子をクリア"""
	spore_particles.clear()
	_spore_spawn_accum = 0.0


func spawn_spore_burst(positions: Array[Vector2], burst_count: int = -1) -> void:
	"""胞子を追加発生。burst_count: 1ポイントあたりの数（-1でSPORE_SELECTION_BURST_COUNTを使用）"""
	var n: int = burst_count if burst_count >= 0 else SPORE_SELECTION_BURST_COUNT
	for pos in positions:
		for _i in range(n):
			_add_spore_at(pos)


func update_spore_particles(delta: float) -> void:
	"""胞子パーティクルの更新: 選択中は外へ拡散、つかみ状態は中心へ収束"""
	var now: float = Time.get_ticks_msec() / 1000.0
	var grab_active: bool = _game.input_handler.grab_input_active
	var selected_positions: Array[Vector2] = []
	for idx in _game.selected_indices:
		if idx >= 0 and idx < _game.point_positions.size() and not _game._is_locked(idx):
			selected_positions.append(_game.point_positions[idx])
	var spawn_interval: float = SPORE_GRAB_SPAWN_INTERVAL if grab_active else SPORE_SELECTION_SPAWN_INTERVAL
	_spore_spawn_accum += delta
	while _spore_spawn_accum >= spawn_interval:
		_spore_spawn_accum -= spawn_interval
		for pos in selected_positions:
			_add_spore_at(pos, grab_active)
	# 既存パーティクルの更新
	var i: int = spore_particles.size() - 1
	while i >= 0:
		var p: Dictionary = spore_particles[i]
		var age: float = now - (p["spawn_time"] as float)
		var lifetime: float = SPORE_GRAB_LIFETIME if p.get("converging", false) else SPORE_SELECTION_LIFETIME
		if age > lifetime:
			spore_particles.remove_at(i)
			i -= 1
			continue
		var converging: bool = p.get("converging", false)
		var pos: Vector2 = p["pos"] as Vector2
		var vel: Vector2 = p["vel"] as Vector2
		# 収束胞子: 中心に近づいたら削除
		if converging:
			var center: Vector2 = p["center"] as Vector2
			if pos.distance_to(center) < SPORE_CONVERGE_REMOVE_DIST:
				spore_particles.remove_at(i)
				i -= 1
				continue
			# 中心方向へ軽く補正（ふわふわしつつ収束）
			var to_center: Vector2 = (center - pos).normalized()
			vel = vel.lerp(to_center * vel.length(), 0.15)
		else:
			# 拡散胞子: ふわふわ
			vel += Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0)) * delta
			vel = vel.limit_length(SPORE_SELECTION_SPEED_MAX * 1.2)
		p["vel"] = vel
		p["pos"] = pos + vel * delta
		i -= 1


func _add_spore_at(center: Vector2, converging: bool = false) -> void:
	"""胞子を1つ追加。converging: true なら中心へ収束する胞子（つかみ状態用）"""
	var angle: float = randf() * TAU
	var speed: float
	if converging:
		speed = randf_range(SPORE_GRAB_SPEED_MIN, SPORE_GRAB_SPEED_MAX)
	else:
		speed = randf_range(SPORE_SELECTION_SPEED_MIN, SPORE_SELECTION_SPEED_MAX)
	var pos: Vector2
	var vel: Vector2
	var spawn_dist: float = 0.0
	if converging:
		spawn_dist = randf_range(SPORE_CONVERGE_SPAWN_RADIUS_MIN, SPORE_CONVERGE_SPAWN_RADIUS_MAX)
		pos = center + Vector2(cos(angle), sin(angle)) * spawn_dist
		vel = (center - pos).normalized() * speed
	else:
		pos = center
		vel = Vector2(cos(angle), sin(angle)) * speed
	var p: Dictionary = {
		"pos": pos,
		"vel": vel,
		"spawn_time": Time.get_ticks_msec() / 1000.0,
		"size": randf_range(SPORE_SIZE_MIN, SPORE_SIZE_MAX),
		"converging": converging,
		"center": center,
	}
	if converging:
		p["spawn_dist"] = spawn_dist
	spore_particles.append(p)


# =============================================================================
# Drawing - Logo / Title / Menu / Config / Rules
# =============================================================================

func _draw_logo(vp: Vector2) -> void:
	_draw_bg(vp)

	if not _game.logo_texture:
		return

	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _game.logo_start_time
	var alpha: float = 0.0

	if elapsed < GameConfig.LOGO_WAIT1:
		alpha = 0.0
	elif elapsed < GameConfig.LOGO_WAIT1 + GameConfig.LOGO_FADE_IN:
		alpha = (elapsed - GameConfig.LOGO_WAIT1) / GameConfig.LOGO_FADE_IN
	elif elapsed < GameConfig.LOGO_WAIT1 + GameConfig.LOGO_FADE_IN + GameConfig.LOGO_HOLD:
		alpha = 1.0
	elif elapsed < GameConfig.LOGO_WAIT1 + GameConfig.LOGO_FADE_IN + GameConfig.LOGO_HOLD + GameConfig.LOGO_FADE_OUT:
		alpha = 1.0 - (elapsed - GameConfig.LOGO_WAIT1 - GameConfig.LOGO_FADE_IN - GameConfig.LOGO_HOLD) / GameConfig.LOGO_FADE_OUT
	else:
		alpha = 0.0

	var tex_size: Vector2 = _game.logo_texture.get_size()
	var draw_w: float = vp.x * 0.28
	var scale_f: float = draw_w / tex_size.x
	var draw_h: float = tex_size.y * scale_f
	var pos := Vector2((vp.x - draw_w) / 2.0, (vp.y - draw_h) / 2.0)

	_game.draw_texture_rect(_game.logo_texture, Rect2(pos, Vector2(draw_w, draw_h)), false, Color(1, 1, 1, alpha))


# =============================================================================
# Title Intro Animation（実装は title_intro_animation.gd）
# =============================================================================

func start_title_intro_skip() -> void:
	title_intro.start_skip()


func is_title_intro_done() -> bool:
	return title_intro.is_done()


func is_title_intro_skip_done() -> bool:
	return title_intro.is_skip_done()


func _draw_title(vp: Vector2) -> void:
	_draw_bg(vp)

	var fade: float = clampf((Time.get_ticks_msec() / 1000.0 - _game.title_start_time) / GameConfig.TITLE_FADE_IN, 0.0, 1.0)
	var cy: float = vp.y * 0.38 * 0.8  # 20%上へ

	if _game.title_logo_texture:
		var tex_size: Vector2 = _game.title_logo_texture.get_size()
		var draw_w: float = vp.x * 0.85 * 1.2  # 1.2倍
		var scale_f: float = draw_w / tex_size.x
		var draw_h: float = tex_size.y * scale_f
		var pos := Vector2((vp.x - draw_w) / 2.0, cy - draw_h / 2.0)
		_game.draw_texture_rect(_game.title_logo_texture, Rect2(pos, Vector2(draw_w, draw_h)), false, Color(1, 1, 1, fade))
	else:
		_game.draw_string(_game.font, Vector2(0, cy), tr("TITLE_NAME"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 168, Color(0.26, 0.21, 0.28, fade))

	# ボタン・クレジットはロゴ表示完了後に遅延フェードイン
	var time_since: float = Time.get_ticks_msec() / 1000.0 - _game.title_start_time
	var bottom_alpha: float = clampf((time_since - GameConfig.TITLE_FADE_IN - 0.3) / 0.5, 0.0, 1.0)
	var alpha: float = _crossfade_alpha() * bottom_alpha
	var btn_center := Vector2(vp.x / 2.0, (vp.y / 2.0 + 40.0) * 1.2 + 50.0)  # 20%下へ + 50px
	_draw_auto_button_with_shadow(btn_center, tr("TITLE_START"), BTN_FONT_SIZE, alpha, false, vp.x * 0.375)

	_game.draw_string(_game.font, Vector2(0, vp.y - 30), tr("TITLE_COPYRIGHT"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 32, Color(0.45, 0.38, 0.45, bottom_alpha))


func get_menu_btn_cy(vp: Vector2, index: int, count: int) -> float:
	# 画面の57%〜85%に均等配置し、上下をそれぞれ20px中央に寄せる
	var area_top: float = vp.y * 0.57
	var area_bottom: float = vp.y * 0.85
	var btn_spacing: float = (area_bottom - area_top) / maxf(count - 1, 1)
	var base_y: float = area_top + index * btn_spacing
	if index == 0:
		base_y += 20.0
	elif index == count - 1:
		base_y -= 20.0
	return base_y


func _draw_menu(vp: Vector2) -> void:
	_draw_bg(vp)

	var cy: float = vp.y / 2.0

	if _game.title_logo_texture:
		var tex_size: Vector2 = _game.title_logo_texture.get_size()
		var draw_w: float = vp.x * 0.85 * 1.2
		var scale_f: float = draw_w / tex_size.x
		var draw_h: float = tex_size.y * scale_f
		var logo_cy: float = vp.y * 0.38 * 0.8
		var pos := Vector2((vp.x - draw_w) / 2.0, logo_cy - draw_h / 2.0)
		_game.draw_texture_rect(_game.title_logo_texture, Rect2(pos, Vector2(draw_w, draw_h)), false)
	else:
		_game.draw_string(_game.font, Vector2(0, cy - 50), tr("TITLE_NAME"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 168, Color(0.26, 0.21, 0.28))

	var menu_count: int = 3
	var labels: Array[String] = [tr("MENU_GAME_START"), tr("MENU_CONFIG"), tr("MENU_QUIT")]
	for i in range(menu_count):
		var btn_center_y: float = get_menu_btn_cy(vp, i, menu_count)
		var is_sel: bool = (i == _game.menu_index)
		var is_off: bool = not is_sel
		_draw_auto_button_with_shadow(Vector2(vp.x / 2.0, btn_center_y), labels[i], BTN_FONT_SIZE, 1.0, is_off, vp.x * 0.375)

	_game.draw_string(_game.font, Vector2(0, vp.y - 30), tr("TITLE_COPYRIGHT"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 32, Color(0.45, 0.38, 0.45))

	# 終了確認ダイアログ
	if _game.menu_confirm_quit:
		_draw_menu_quit_confirm(vp)


func _draw_menu_quit_confirm(vp: Vector2) -> void:
	# 画面全体を暗転
	_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.26, 0.21, 0.28, 0.50))
	var cx: float = vp.x / 2.0
	var dlg_cy: float = vp.y / 2.0
	var dlg_w: float = 700.0
	var dlg_h: float = 260.0
	var dlg_rect := Rect2(Vector2(cx - dlg_w / 2.0, dlg_cy - dlg_h / 2.0), Vector2(dlg_w, dlg_h))
	# 白背景ダイアログ
	var dlg_shadow := Vector2(15.0, 15.0)
	_game.draw_rect(Rect2(dlg_rect.position + dlg_shadow, dlg_rect.size), Color(0.26, 0.21, 0.28, 0.25))
	_game.draw_rect(dlg_rect, Color(1.0, 1.0, 1.0))
	_game.draw_rect(dlg_rect, Color(0.26, 0.21, 0.28), false, 5.75)
	# テキスト
	_game.draw_string(_game.font_bold, Vector2(cx - dlg_w / 2.0, dlg_cy - 45.0), tr("MENU_QUIT_CONFIRM"), HORIZONTAL_ALIGNMENT_CENTER, dlg_w, 42, Color(0.95, 0.19, 0.32))
	# ボタン
	var cbtn_w: float = 220.0
	var cbtn_gap: float = cbtn_w / 2.0 + 30.0
	var cbtn_cy: float = dlg_cy + 50.0
	var yes_off: bool = _game.menu_confirm_index != 0
	var no_off: bool = _game.menu_confirm_index != 1
	_draw_auto_button_with_shadow(Vector2(cx - cbtn_gap, cbtn_cy), tr("PAUSE_CONFIRM_YES"), BTN_FONT_SIZE, 1.0, yes_off, cbtn_w)
	_draw_auto_button_with_shadow(Vector2(cx + cbtn_gap, cbtn_cy), tr("PAUSE_CONFIRM_NO"), BTN_FONT_SIZE, 1.0, no_off, cbtn_w)


func _draw_rules_confirm(vp: Vector2) -> void:
	# ルール画面の上に操作デバイス確認（メニュー終了確認と同レイアウト）
	_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.26, 0.21, 0.28, 0.50))
	var cx: float = vp.x / 2.0
	var dlg_cy: float = vp.y / 2.0
	var dlg_w: float = 700.0
	var dlg_h: float = 260.0
	var dlg_rect := Rect2(Vector2(cx - dlg_w / 2.0, dlg_cy - dlg_h / 2.0), Vector2(dlg_w, dlg_h))
	var dlg_shadow := Vector2(15.0, 15.0)
	_game.draw_rect(Rect2(dlg_rect.position + dlg_shadow, dlg_rect.size), Color(0.26, 0.21, 0.28, 0.25))
	_game.draw_rect(dlg_rect, Color(1.0, 1.0, 1.0))
	_game.draw_rect(dlg_rect, Color(0.26, 0.21, 0.28), false, 5.75)
	var title_key: String = "RULES_CONFIRM_MOUSE_TITLE" if _game.rules_confirm_kind == "mouse" else "RULES_CONFIRM_PAD_TITLE"
	_game.draw_string(_game.font_bold, Vector2(cx - dlg_w / 2.0, dlg_cy - 45.0), tr(title_key), HORIZONTAL_ALIGNMENT_CENTER, dlg_w, 42, Color(0.95, 0.19, 0.32))
	var cbtn_w: float = 220.0
	var cbtn_gap: float = cbtn_w / 2.0 + 30.0
	var cbtn_cy: float = dlg_cy + 50.0
	var yes_off: bool = _game.rules_confirm_index != 0
	var no_off: bool = _game.rules_confirm_index != 1
	_draw_auto_button_with_shadow(Vector2(cx - cbtn_gap, cbtn_cy), tr("PAUSE_CONFIRM_YES"), BTN_FONT_SIZE, 1.0, yes_off, cbtn_w)
	_draw_auto_button_with_shadow(Vector2(cx + cbtn_gap, cbtn_cy), tr("PAUSE_CONFIRM_NO"), BTN_FONT_SIZE, 1.0, no_off, cbtn_w)


func _draw_icon_outline_closed(pts_norm: Array, center: Vector2, r: float, col: Color) -> void:
	"""正規化された閉じた輪郭（原点周り・おおよそ半径1）をアイコン円内に収めて描画"""
	if pts_norm.size() < 2:
		return
	var max_d: float = 0.001
	for p in pts_norm:
		if p is Vector2:
			max_d = maxf(max_d, (p as Vector2).length())
	var scale: float = (r * 0.92) / max_d
	var n: int = pts_norm.size()
	for i in range(n):
		var a: Vector2 = center + (pts_norm[i] as Vector2) * scale
		var b: Vector2 = center + (pts_norm[(i + 1) % n] as Vector2) * scale
		_game.draw_line(a, b, col, 2.0, true)


func _draw_stage_custom_shape_preview(verts: Array[Vector2], edges: Array[Dictionary], preview_rect: Rect2, line_col: Color) -> void:
	var n: int = verts.size()
	if n < 3:
		return
	var ne: int = mini(edges.size(), n)
	for ei in range(ne):
		var ed: Dictionary = edges[ei]
		var p0s: Vector2 = StageEditPolygonTools.norm_to_screen(verts[ei], preview_rect)
		var p1s: Vector2 = StageEditPolygonTools.norm_to_screen(verts[(ei + 1) % n], preview_rect)
		if ed.get("type", "line") == "arc" and ed.has("arc_control"):
			var acs: Vector2 = StageEditPolygonTools.norm_to_screen(ed["arc_control"], preview_rect)
			var arc_pts: Array = StageEditPolygonTools.sample_arc_3points(p0s, p1s, acs)
			if arc_pts.size() >= 2:
				for j in range(arc_pts.size() - 1):
					_game.draw_line(arc_pts[j], arc_pts[j + 1], line_col, 1.5, true)
		else:
			_game.draw_line(p0s, p1s, line_col, 1.75, true)


func _draw_stage_debug_type_icon(center: Vector2, r: float, type_str: String, c: Color) -> void:
	if type_str == "fish" or type_str == "cat_face":
		var pts: Array = _game.stage_manager.get_normalized_outline_for_icon_debug(type_str)
		if pts.size() >= 2:
			_draw_icon_outline_closed(pts, center, r, c)
			return
	var nseg: int = 32
	match type_str:
		"triangle":
			for i in range(3):
				var a0: float = -PI * 0.5 + TAU * float(i) / 3.0
				var a1: float = -PI * 0.5 + TAU * float(i + 1) / 3.0
				_game.draw_line(center + Vector2(cos(a0), sin(a0)) * r, center + Vector2(cos(a1), sin(a1)) * r, c, 2.0)
		"square":
			var s: float = r * 0.82
			_game.draw_rect(Rect2(center.x - s, center.y - s, s * 2.0, s * 2.0), c, false, 2.0)
		"circle":
			_game.draw_arc(center, r, 0.0, TAU, nseg, c, 2.0)
		"two_circles":
			var rr: float = r * 0.42
			_game.draw_arc(center + Vector2(-r * 0.38, 0.0), rr, 0.0, TAU, 24, c, 2.0)
			_game.draw_arc(center + Vector2(r * 0.38, 0.0), rr, 0.0, TAU, 24, c, 2.0)
		"star":
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var rad: float = r * (0.42 if i % 2 == 0 else 0.88)
				var ang: float = -PI * 0.5 + TAU * float(i) / 10.0
				pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
			pts.append(pts[0])
			_game.draw_polyline(pts, c, 2.0)
		"heptagram", "heptagram_silhouette":
			var pts2: PackedVector2Array = PackedVector2Array()
			for i in range(7):
				var ang2: float = -PI * 0.5 + TAU * float(i * 2) / 7.0
				pts2.append(center + Vector2(cos(ang2), sin(ang2)) * r * 0.85)
			pts2.append(pts2[0])
			_game.draw_polyline(pts2, c, 2.0)
		_:
			_game.draw_rect(Rect2(center.x - r * 0.65, center.y - r * 0.65, r * 1.3, r * 1.3), c, false, 2.0)


func _draw_stage_debug_text_action_button(r: Rect2, label: String, text_c: Color) -> void:
	_game.draw_rect(r, Color(0.96, 0.94, 0.95))
	_game.draw_rect(r, Color(0.45, 0.4, 0.48), false, 1.0)
	var fs_btn: int = 9
	var sz: Vector2 = _game.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_btn)
	var tx: float = clampf(r.position.x + (r.size.x - sz.x) * 0.5, r.position.x + 2.0, r.position.x + maxf(2.0, r.size.x - sz.x - 2.0))
	var ty: float = r.position.y + (r.size.y + sz.y) * 0.5 - 1.0
	_game.draw_string(_game.font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_btn, text_c)


func _draw_stage_debug(vp: Vector2) -> void:
	_draw_bg(vp)
	var split: float = _game._stage_debug_split_x(vp)
	var list_bottom: float = vp.y - _game.STAGE_DEBUG_CONTENT_BOTTOM_MARGIN
	var accent: Color = Color(0.95, 0.19, 0.32)
	var text_c: Color = Color(0.26, 0.21, 0.28)
	var guide_w: float = minf(vp.x - 280.0, 560.0)
	_game.draw_string(_game.font_bold, Vector2(24, 48), "STAGE DEBUG (F2)", HORIZONTAL_ALIGNMENT_LEFT, guide_w, 36, accent)
	_game.draw_string(_game.font, Vector2(24, 86), "Wheel: スクロール | ESC: タイトル | [C]=custom_stages | 左で選択 | 右で編集・図形編集 | Tab/Enter", HORIZONTAL_ALIGNMENT_LEFT, guide_w, 18, Color(0.35, 0.28, 0.35))
	if _game.stage_debug_last_error != "":
		_game.draw_string(_game.font, Vector2(24, 112), _game.stage_debug_last_error, HORIZONTAL_ALIGNMENT_LEFT, guide_w, 18, Color(0.95, 0.3, 0.2))
	if _game._debug_tools_enabled():
		var nr: Rect2 = _game._stage_debug_new_custom_button_rect(vp)
		_game.draw_rect(nr, Color(0.95, 0.19, 0.32, 0.2))
		_game.draw_rect(nr, Color(0.26, 0.21, 0.28), false, 2.0)
		_game.draw_string(_game.font, Vector2(nr.position.x + 8.0, nr.position.y + 21.0), "新規", HORIZONTAL_ALIGNMENT_LEFT, nr.size.x - 16.0, 13, Color(0.26, 0.21, 0.28))
	# 右側パネル（白）+ 区切り線
	var panel_top: float = _game._stage_debug_fields_start_y() - 8.0
	var panel_rect := Rect2(split + 4.0, panel_top, vp.x - split - 8.0, vp.y - panel_top - _game.STAGE_DEBUG_CONTENT_BOTTOM_MARGIN)
	_game.draw_rect(panel_rect, Color(1.0, 1.0, 1.0, 0.94))
	_game.draw_rect(panel_rect, Color(0.85, 0.82, 0.86), false, 1.5)
	_game.draw_line(Vector2(split, _game.STAGE_DEBUG_LIST_TOP_Y - 4.0), Vector2(split, vp.y - _game.STAGE_DEBUG_CONTENT_BOTTOM_MARGIN), text_c, 2.0)
	# 左: ステージ一覧（マスタ + user://custom_stages の Edit 産）
	var total_rows: int = _game._stage_debug_total_rows()
	var master_n: int = _game._stage_debug_master_count()
	var y0: float = _game.STAGE_DEBUG_LIST_TOP_Y - _game.stage_debug_scroll
	var fs: int = 16
	var list_left: float = 8.0
	var list_w: float = split - list_left - 8.0
	var icon_r: float = minf(26.0, (_game.STAGE_DEBUG_ROW_H - 12.0) * 0.45)
	var prev_sz: float = minf(icon_r * 2.5, _game.STAGE_DEBUG_ROW_H - 10.0)
	for i in range(total_rows):
		var y: float = y0 + float(i) * _game.STAGE_DEBUG_ROW_H
		if y + _game.STAGE_DEBUG_ROW_H < _game.STAGE_DEBUG_LIST_TOP_Y or y > list_bottom:
			continue
		var cfg: Dictionary = {}
		var tname: String = "?"
		var raw_custom: Dictionary = {}
		var label_max_w: float = list_w - icon_r * 2.0 - 20.0
		if i < master_n:
			cfg = StageDebugOverrides.build_config_for_index(i, _game.stage_debug_pending.get(i, {}))
			tname = str(cfg.get("type", "?"))
		else:
			raw_custom = _game._stage_debug_custom_raw_merged(_game._stage_debug_custom_path_at(i))
			label_max_w = list_w - prev_sz - 22.0
			if not raw_custom.is_empty():
				var cfg_part: Dictionary = raw_custom["config"] as Dictionary
				tname = str(cfg_part.get("shape_type", cfg_part.get("type", "?")))
				cfg = CustomStageFile.effective_config_with_shape(raw_custom)
		var sel: bool = i == _game.stage_debug_selected
		var row_rect := Rect2(list_left, y, list_w, _game.STAGE_DEBUG_ROW_H - 4.0)
		if sel:
			_game.draw_rect(row_rect, Color(0.95, 0.19, 0.32, 0.14))
		_game.draw_rect(row_rect, Color(0.88, 0.86, 0.88), false, 1.5)
		var row_lbl: String = _game._stage_debug_list_row_label(i)
		_game.draw_string(_game.font, Vector2(list_left + 10.0, y + 30.0), row_lbl, HORIZONTAL_ALIGNMENT_LEFT, label_max_w, fs, text_c)
		var icx: float = list_left + list_w - icon_r - 12.0
		var icy: float = y + _game.STAGE_DEBUG_ROW_H * 0.5 - 2.0
		var drew_preview: bool = false
		if i >= master_n and not raw_custom.is_empty():
			var sh_pv: Variant = raw_custom.get("shape", {})
			if typeof(sh_pv) == TYPE_DICTIONARY:
				var se: Dictionary = StageEditPolygonTools.shape_polygon_vertices_and_edges(sh_pv as Dictionary)
				if se.get("ok", false):
					var pr: Rect2 = Rect2(icx - prev_sz * 0.5, icy - prev_sz * 0.5, prev_sz, prev_sz)
					_game.draw_rect(pr, Color(1.0, 1.0, 1.0, 0.92))
					_game.draw_rect(pr, Color(0.82, 0.8, 0.84), false, 1.0)
					var verts_pv: Array[Vector2] = se["verts"] as Array[Vector2]
					var edges_pv: Array[Dictionary] = se["edges"] as Array[Dictionary]
					_draw_stage_custom_shape_preview(verts_pv, edges_pv, pr, accent if sel else text_c)
					drew_preview = true
		if not drew_preview:
			_draw_stage_debug_type_icon(Vector2(icx, icy), icon_r, tname, accent if sel else text_c)
	# ボタン（テスト・保存・図形編集・設定リセット | 右上 全リセット・戻る）
	var rects: Array[Rect2] = _game._stage_debug_button_rects(vp)
	var bl: Array[String] = ["テスト", "保存", "図形編集", "設定リセット", "全リセット", "戻る"]
	for bi in range(rects.size()):
		var r: Rect2 = rects[bi]
		_game.draw_rect(r, Color(0.95, 0.19, 0.32, 0.18))
		_game.draw_rect(r, text_c, false, 2.0)
		var fs_btn: int = 11 if r.size.x < 58.0 else (12 if r.size.x < 72.0 else 13)
		_game.draw_string(_game.font, Vector2(r.position.x + 4.0, r.position.y + 21.0), bl[bi], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8.0, fs_btn, text_c)
	# 右: ラベル列（固定・幅は最長ラベルを測定）+ 値入力欄
	var dbg_margin: float = 12.0
	var label_w: float = _game._stage_debug_field_label_column_width()
	var label_left: float = split + dbg_margin
	var gap_dbg: float = _game.STAGE_DEBUG_FIELD_VALUE_GAP
	var fs_lbl: int = _game.STAGE_DEBUG_FIELD_LABEL_FS
	var grid_c: Color = Color(0.85, 0.82, 0.86)
	var n_fields: int = _game.STAGE_DEBUG_FIELD_KEYS.size()
	if n_fields > 0:
		var fr0: Rect2 = _game._stage_debug_field_value_rect(vp, 0)
		var frN: Rect2 = _game._stage_debug_field_value_rect(vp, n_fields - 1)
		var div_x: float = label_left + label_w + gap_dbg * 0.5
		_game.draw_line(Vector2(div_x, fr0.position.y - 2.0), Vector2(div_x, frN.position.y + frN.size.y + 4.0), grid_c, 1.0)
	for fi in range(n_fields):
		var fr_val: Rect2 = _game._stage_debug_field_value_rect(vp, fi)
		var fk: String = _game.STAGE_DEBUG_FIELD_KEYS[fi]
		var buf: String = str(_game.stage_debug_field_buffers.get(fk, ""))
		var focus: bool = fi == _game.stage_debug_field_focus_idx
		var row_bottom: float = fr_val.position.y + fr_val.size.y + 4.0
		_game.draw_line(Vector2(label_left, row_bottom), Vector2(vp.x - dbg_margin, row_bottom), grid_c, 1.0)
		if fi == 0:
			_game.draw_line(Vector2(label_left, fr_val.position.y - 2.0), Vector2(vp.x - dbg_margin, fr_val.position.y - 2.0), grid_c, 1.0)
		var lbl_txt: String = "%s:" % fk
		var lbl_sz: Vector2 = _game.font.get_string_size(lbl_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_lbl)
		var lbl_x: float = label_left + label_w - lbl_sz.x - 4.0
		var lbl_y: float = fr_val.position.y + 16.0
		if fk == "description":
			lbl_y = fr_val.position.y + fr_val.size.y * 0.5 - lbl_sz.y * 0.5
		_game.draw_string(_game.font, Vector2(lbl_x, lbl_y), lbl_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_lbl, text_c)
		_game.draw_rect(fr_val, Color(1.0, 1.0, 1.0))
		_game.draw_rect(fr_val, accent if focus else Color(0.26, 0.21, 0.28), false, 5.75 if focus else 1.25)
		var show: String = buf
		if focus:
			show = _game.stage_debug_edit_buffer
		if fk == "description":
			var desc_fs: int = _game.STAGE_DEBUG_DESC_LINE_FS
			var pad_t: float = _game.STAGE_DEBUG_DESC_PAD_TOP
			var lgap: float = _game.STAGE_DEBUG_DESC_LINE_INNER_GAP
			var lines_d: PackedStringArray = show.split("\n")
			var max_draw: int = _game.STAGE_DEBUG_DESC_MAX_LINES
			var n_draw: int = mini(lines_d.size(), max_draw)
			var ly: float = fr_val.position.y + pad_t + _game.font.get_ascent(desc_fs)
			for dli in range(n_draw):
				_game.draw_string(
					_game.font, Vector2(fr_val.position.x + 4.0, ly), lines_d[dli],
					HORIZONTAL_ALIGNMENT_LEFT, fr_val.size.x - 8.0, desc_fs, text_c
				)
				ly += _game.font.get_height(desc_fs) + lgap
		elif fk == "stage_name":
			var fs_sn: int = 14
			var baseline_sn: float = fr_val.position.y + (fr_val.size.y - _game.font.get_height(fs_sn)) * 0.5 + _game.font.get_ascent(fs_sn)
			_game.draw_string(_game.font, Vector2(fr_val.position.x + 4, baseline_sn), show, HORIZONTAL_ALIGNMENT_LEFT, fr_val.size.x - 8, fs_sn, text_c)
		else:
			_game.draw_string(_game.font, Vector2(fr_val.position.x + 4, fr_val.position.y + 16), show, HORIZONTAL_ALIGNMENT_LEFT, fr_val.size.x - 8, 14, text_c)
		if _game._stage_debug_is_custom_row(_game.stage_debug_selected):
			if fk == "stage_name":
				_draw_stage_debug_text_action_button(_game._stage_debug_stage_name_action_button_rect(vp, 0), "コピー", text_c)
				_draw_stage_debug_text_action_button(_game._stage_debug_stage_name_action_button_rect(vp, 1), "消去", text_c)
				_draw_stage_debug_text_action_button(_game._stage_debug_stage_name_action_button_rect(vp, 2), "貼り付け", text_c)
			elif fk == "description":
				_draw_stage_debug_text_action_button(_game._stage_debug_description_action_button_rect(vp, 0), "コピー", text_c)
				_draw_stage_debug_text_action_button(_game._stage_debug_description_action_button_rect(vp, 1), "消去", text_c)
				_draw_stage_debug_text_action_button(_game._stage_debug_description_action_button_rect(vp, 2), "貼り付け", text_c)


## 正規化座標で半面に含まれる辺を鏡映し、キャンバス上に薄く描く（◀右→左 ▶左→右 ▲下→上 ▼上→下）
func _stage_edit_draw_mirror_previews(canvas_r: Rect2, verts: Array[Vector2], edges: Array, n: int) -> void:
	var pv: Array[bool] = _game.stage_edit_mirror_preview
	if not (pv[0] or pv[1] or pv[2] or pv[3]):
		return
	if n < 2 or edges.is_empty():
		return
	var ghost_line := Color(0.42, 0.38, 0.48, 0.22)
	var ghost_arc := Color(0.48, 0.44, 0.55, 0.22)
	var lw: float = 1.5
	for ei in range(edges.size()):
		var p0: Vector2 = verts[ei]
		var p1: Vector2 = verts[(ei + 1) % n]
		var ed: Dictionary = edges[ei]
		var is_arc: bool = ed.get("type", "line") == "arc" and ed.has("arc_control")
		if pv[0] and p0.x > 0.0 and p1.x > 0.0:
			_stage_edit_draw_one_mirror_edge(canvas_r, p0, p1, ed, is_arc, ghost_line, ghost_arc, lw, false)
		if pv[1] and p0.x <= 0.0 and p1.x <= 0.0:
			_stage_edit_draw_one_mirror_edge(canvas_r, p0, p1, ed, is_arc, ghost_line, ghost_arc, lw, false)
		if pv[2] and p0.y >= 0.0 and p1.y >= 0.0:
			_stage_edit_draw_one_mirror_edge(canvas_r, p0, p1, ed, is_arc, ghost_line, ghost_arc, lw, true)
		if pv[3] and p0.y < 0.0 and p1.y < 0.0:
			_stage_edit_draw_one_mirror_edge(canvas_r, p0, p1, ed, is_arc, ghost_line, ghost_arc, lw, true)


func _stage_edit_draw_one_mirror_edge(
	canvas_r: Rect2,
	p0: Vector2,
	p1: Vector2,
	ed: Dictionary,
	is_arc: bool,
	ghost_line: Color,
	ghost_arc: Color,
	lw: float,
	vertical_axis: bool
) -> void:
	var mp0: Vector2
	var mp1: Vector2
	if vertical_axis:
		mp0 = Vector2(p0.x, -p0.y)
		mp1 = Vector2(p1.x, -p1.y)
	else:
		mp0 = Vector2(-p0.x, p0.y)
		mp1 = Vector2(-p1.x, p1.y)
	var p0s: Vector2 = _game._stage_edit_canvas_norm_to_screen(mp0, canvas_r)
	var p1s: Vector2 = _game._stage_edit_canvas_norm_to_screen(mp1, canvas_r)
	if is_arc:
		var ac: Vector2 = ed["arc_control"] as Vector2
		var mac: Vector2 = Vector2(ac.x, -ac.y) if vertical_axis else Vector2(-ac.x, ac.y)
		var acs: Vector2 = _game._stage_edit_canvas_norm_to_screen(mac, canvas_r)
		var arc_pts: Array = StageEditPolygonTools.sample_arc_3points(p0s, p1s, acs)
		if arc_pts.size() >= 2:
			for j in range(arc_pts.size() - 1):
				_game.draw_line(arc_pts[j], arc_pts[j + 1], ghost_arc, lw, true)
	else:
		_game.draw_line(p0s, p1s, ghost_line, lw, true)


func _stage_edit_draw_canvas_grid(canvas_r: Rect2) -> void:
	var cell: float = _game._stage_edit_grid_cell_px(canvas_r)
	var cx: float = canvas_r.position.x + canvas_r.size.x * 0.5
	var cy: float = canvas_r.position.y + canvas_r.size.y * 0.5
	var dot_col := Color(0.78, 0.76, 0.82, 0.5)
	var major_col := Color(0.68, 0.66, 0.72, 0.65)
	var axis_col := Color(0.45, 0.42, 0.48, 0.75)
	var i0x: int = int(floor((canvas_r.position.x - cx) / cell)) - 1
	var i1x: int = i0x + int(ceil(canvas_r.size.x / cell)) + 3
	for i in range(i0x, i1x + 1):
		var xf: float = cx + float(i) * cell
		if xf < canvas_r.position.x or xf > canvas_r.position.x + canvas_r.size.x:
			continue
		var is_axis: bool = absf(xf - cx) < 0.5
		var is_major: bool = (i % 5) == 0
		var col: Color = axis_col if is_axis else (major_col if is_major else dot_col)
		var w: float = 1.5 if is_axis else (1.2 if is_major else 1.0)
		_game.draw_line(Vector2(xf, canvas_r.position.y), Vector2(xf, canvas_r.position.y + canvas_r.size.y), col, w, true)
	var i0y: int = int(floor((canvas_r.position.y - cy) / cell)) - 1
	var i1y: int = i0y + int(ceil(canvas_r.size.y / cell)) + 3
	for j in range(i0y, i1y + 1):
		var yf: float = cy + float(j) * cell
		if yf < canvas_r.position.y or yf > canvas_r.position.y + canvas_r.size.y:
			continue
		var is_axis: bool = absf(yf - cy) < 0.5
		var is_major: bool = (j % 5) == 0
		var col: Color = axis_col if is_axis else (major_col if is_major else dot_col)
		var w: float = 1.5 if is_axis else (1.2 if is_major else 1.0)
		_game.draw_line(Vector2(canvas_r.position.x, yf), Vector2(canvas_r.position.x + canvas_r.size.x, yf), col, w, true)


func _draw_stage_edit(vp: Vector2) -> void:
	_draw_bg(vp)
	var accent: Color = Color(0.95, 0.19, 0.32)
	var text_c: Color = Color(0.26, 0.21, 0.28)
	var split_x: float = _game._stage_edit_split_x(vp)
	var canvas_r: Rect2 = _game._stage_edit_canvas_rect(vp)
	var panel_r: Rect2 = _game._stage_edit_right_panel_rect(vp)
	var footer_top: float = vp.y - _game.STAGE_EDIT_FOOTER_H
	_game.draw_string(_game.font_bold, Vector2(20, 34), "CUSTOM STAGE EDIT (v1)", HORIZONTAL_ALIGNMENT_LEFT, vp.x - 40, 28, accent)
	_game.draw_line(Vector2(split_x, _game.STAGE_EDIT_TOP_BAR + 4), Vector2(split_x, footer_top), Color(0.78, 0.72, 0.66), 1.0)
	_game.draw_rect(panel_r, Color(0.96, 0.945, 0.92))
	_game.draw_rect(panel_r, Color(0.78, 0.72, 0.66), false, 1.0)
	var guide_w: float = panel_r.size.x - 4.0
	_game.draw_string(_game.font, Vector2(panel_r.position.x, panel_r.position.y + 10), "保存先: user://custom_stages/＜Stage ID＞.json（config.type と同一）", HORIZONTAL_ALIGNMENT_LEFT, guide_w, 13, text_c)
	_game.draw_string(_game.font, Vector2(panel_r.position.x, panel_r.position.y + 28), "fish / cat_face: 左＝辺に直線で点／頂点を左ドラッグ。右＝辺に円弧で点、頂点は短押しで削除・ドラッグで移動。", HORIZONTAL_ALIGNMENT_LEFT, guide_w, 13, Color(0.35, 0.28, 0.35))
	var fr: Rect2 = _game._stage_edit_text_rect_filename(vp)
	_game.draw_string(_game.font, Vector2(panel_r.position.x, fr.position.y - 18), "Stage ID（config.type・小文字・数字・_ のみ）", HORIZONTAL_ALIGNMENT_LEFT, guide_w, 14, text_c)
	var fn_focus: bool = _game.stage_edit_text_line == 0
	_game.draw_rect(fr, Color(1.0, 1.0, 1.0))
	_game.draw_rect(fr, accent if fn_focus else text_c, false, 3.0 if fn_focus else 1.5)
	_game.draw_string(_game.font, Vector2(fr.position.x + 6, fr.position.y + 20), _game.stage_edit_stage_id, HORIZONTAL_ALIGNMENT_LEFT, fr.size.x - 12, 16, text_c)
	_game.draw_string(_game.font, Vector2(panel_r.position.x, fr.position.y + fr.size.y + 12), "shape_type（クリックで選択）", HORIZONTAL_ALIGNMENT_LEFT, guide_w, 14, text_c)
	var n_types: int = _game.STAGE_EDIT_TYPE_OPTIONS.size()
	var tidx: int = clampi(_game.stage_edit_type_idx, 0, n_types - 1)
	for ti in range(n_types):
		var cr: Rect2 = _game._stage_edit_type_chip_rect(vp, ti)
		var nm: String = _game.STAGE_EDIT_TYPE_OPTIONS[ti]
		var sel: bool = ti == tidx
		_game.draw_rect(cr, Color(0.95, 0.19, 0.32, 0.22) if sel else Color(0.92, 0.9, 0.92))
		_game.draw_rect(cr, accent if sel else text_c, false, 2.0)
		_game.draw_string(_game.font, Vector2(cr.position.x + 6, cr.position.y + 19), nm, HORIZONTAL_ALIGNMENT_LEFT, cr.size.x - 12, 13, text_c)
	var cur_type: String = _game.STAGE_EDIT_TYPE_OPTIONS[tidx]
	var fish_on: bool = cur_type == "fish"
	var tr: Rect2 = _game._stage_edit_fish_shape_toggle_rect(vp)
	_game.draw_rect(tr, Color(1.0, 1.0, 1.0))
	_game.draw_rect(tr, text_c, false, 1.5)
	if fish_on and _game.stage_edit_include_fish_shape:
		_game.draw_line(Vector2(tr.position.x + 6, tr.position.y + 14), Vector2(tr.position.x + 11, tr.position.y + 19), accent, 2.0, true)
		_game.draw_line(Vector2(tr.position.x + 11, tr.position.y + 19), Vector2(tr.position.x + 20, tr.position.y + 8), accent, 2.0, true)
	var toggle_lbl: String = "fish の初期頂点に res://samples/custom_stage.example.json の polygon を使う"
	if not fish_on:
		toggle_lbl = "（shape_type が fish のときのみ）"
	_game.draw_string(_game.font, Vector2(tr.position.x + 34, tr.position.y + 20), toggle_lbl, HORIZONTAL_ALIGNMENT_LEFT, panel_r.size.x - 40.0, 13, text_c if fish_on else Color(0.5, 0.48, 0.52))
	_game.draw_string(_game.font, Vector2(canvas_r.position.x, canvas_r.position.y - 16), "キャンバス: グリッドスナップ（約24px）／左＝直線で点 ／ 右＝円弧で点", HORIZONTAL_ALIGNMENT_LEFT, canvas_r.size.x, 13, Color(0.4, 0.35, 0.42))
	var has_cv: bool = cur_type == "fish" or cur_type == "cat_face"
	if has_cv:
		_game.draw_rect(canvas_r, Color(0.97, 0.96, 0.97))
		_stage_edit_draw_canvas_grid(canvas_r)
		_game.draw_rect(canvas_r, Color(0.55, 0.5, 0.58), false, 1.5)
		var verts: Array[Vector2] = _game.stage_edit_canvas_vertices
		var edges: Array = _game.stage_edit_canvas_edges
		var n: int = verts.size()
		_stage_edit_draw_mirror_previews(canvas_r, verts, edges, n)
		var hover_e: int = _game.stage_edit_canvas_hover_edge
		var line_c: Color = Color(0.35, 0.3, 0.42)
		var line_hover_c: Color = Color(0.50, 0.55, 0.70)
		var arc_c: Color = Color(0.40, 0.45, 0.55)
		for ei in range(edges.size()):
			var p0s: Vector2 = _game._stage_edit_canvas_norm_to_screen(verts[ei], canvas_r)
			var p1s: Vector2 = _game._stage_edit_canvas_norm_to_screen(verts[(ei + 1) % n], canvas_r)
			var ed: Dictionary = edges[ei]
			var is_arc: bool = ed.get("type", "line") == "arc" and ed.has("arc_control")
			var seg_col: Color = line_hover_c if ei == hover_e else line_c
			if is_arc:
				var acs: Vector2 = _game._stage_edit_canvas_norm_to_screen(ed["arc_control"], canvas_r)
				var arc_pts: Array = StageEditPolygonTools.sample_arc_3points(p0s, p1s, acs)
				if arc_pts.size() >= 2:
					for j in range(arc_pts.size() - 1):
						_game.draw_line(arc_pts[j], arc_pts[j + 1], arc_c, 2.5, true)
			else:
				_game.draw_line(p0s, p1s, seg_col, 2.5, true)
		for vi in range(n):
			var hp: Vector2 = _game._stage_edit_canvas_norm_to_screen(verts[vi], canvas_r)
			_game.draw_circle(hp, _game.STAGE_EDIT_CANVAS_HANDLE_R, Color(0.95, 0.19, 0.32, 0.35))
			_game.draw_arc(hp, _game.STAGE_EDIT_CANVAS_HANDLE_R, 0.0, TAU, 24, Color(0.95, 0.19, 0.32), 2.0, true)
		var mrs: Array[Rect2] = _game._stage_edit_mirror_button_rects(vp)
		var mlbl: Array[String] = ["◀", "▶", "▲", "▼"]
		for mi in range(mrs.size()):
			var mr: Rect2 = mrs[mi]
			var on: bool = _game.stage_edit_mirror_preview[mi]
			_game.draw_rect(mr, Color(0.95, 0.19, 0.32, 0.24) if on else Color(0.98, 0.97, 0.99, 0.96))
			_game.draw_rect(mr, accent, false, 2.5 if on else 2.0)
			var fs_m: int = 17
			var sz_m: Vector2 = _game.font.get_string_size(mlbl[mi], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_m)
			_game.draw_string(_game.font, Vector2(mr.position.x + (mr.size.x - sz_m.x) * 0.5, mr.position.y + 24.0), mlbl[mi], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_m, text_c)
	else:
		_game.draw_rect(canvas_r, Color(0.93, 0.92, 0.93))
		_stage_edit_draw_canvas_grid(canvas_r)
		_game.draw_rect(canvas_r, Color(0.65, 0.62, 0.68), false, 1.25)
		_game.draw_string(_game.font, Vector2(canvas_r.position.x + 12, canvas_r.position.y + canvas_r.size.y * 0.45), "図形キャンバスは fish / cat_face のみ", HORIZONTAL_ALIGNMENT_LEFT, canvas_r.size.x - 24, 15, Color(0.5, 0.46, 0.52))
	var sr: Rect2 = _game._stage_edit_save_button_rect(vp)
	var cbr: Rect2 = _game._stage_edit_cancel_button_rect(vp)
	_game.draw_rect(sr, Color(0.95, 0.19, 0.32, 0.22))
	_game.draw_rect(sr, text_c, false, 2.0)
	_game.draw_string(_game.font, Vector2(sr.position.x + 10, sr.position.y + 23), "保存して一覧へ", HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 20, 14, text_c)
	_game.draw_rect(cbr, Color(0.88, 0.86, 0.88))
	_game.draw_rect(cbr, text_c, false, 2.0)
	_game.draw_string(_game.font, Vector2(cbr.position.x + 36, cbr.position.y + 23), "キャンセル", HORIZONTAL_ALIGNMENT_LEFT, cbr.size.x - 72, 14, text_c)
	if _game.stage_edit_last_error != "":
		_game.draw_string(_game.font, Vector2(panel_r.position.x, vp.y - 50), _game.stage_edit_last_error, HORIZONTAL_ALIGNMENT_LEFT, panel_r.size.x, 15, Color(0.95, 0.3, 0.2))
	_game.draw_string(_game.font, Vector2(40, vp.y - 22), "ESC: 戻る | Ctrl+Z 元に戻す | Ctrl+Y / Ctrl+Shift+Z やり直し | ◀▶▲▼ 鏡像プレビュー（クリックでオンオフ） | キャンバス: 左＝直線/ドラッグ 右＝円弧/削除", HORIZONTAL_ALIGNMENT_LEFT, vp.x - 80, 12, Color(0.45, 0.4, 0.48))


func _draw_debug_log_button(vp: Vector2) -> void:
	var w: float = 140.0
	var h: float = 36.0
	var r := Rect2(vp.x - w - 12.0, vp.y - h - 12.0, w, h)
	_game.draw_rect(r, Color(0.26, 0.21, 0.28, 0.55))
	_game.draw_rect(r, Color(1.0, 1.0, 1.0), false, 5.75)
	_game.draw_string(_game.font_bold, Vector2(r.position.x + 8, r.position.y + 24), "ログ出力", HORIZONTAL_ALIGNMENT_LEFT, w - 16, 18, Color(1.0, 1.0, 1.0))


func _draw_config(vp: Vector2) -> void:
	_draw_bg(vp)

	# モードタイトル
	var title_fs: int = 48
	var title_y: float = 80.0 + _game.font_bold.get_ascent(title_fs)
	_game.draw_string(_game.font_bold, Vector2(0, title_y), tr("MENU_CONFIG"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, title_fs, Color(0.95, 0.19, 0.32))

	var text_c := Color(0.26, 0.21, 0.28)
	var sel_c := Color(0.95, 0.19, 0.32)
	var val_c := Color(0.26, 0.21, 0.28)

	var base_y: float = vp.y * _game.CONFIG_MENU_BASE_Y_RATIO
	var spacing: float = _game.CONFIG_MENU_SPACING
	var lx: float = vp.x * _game.CONFIG_MENU_LX_RATIO
	var box_w: float = vp.x * _game.CONFIG_MENU_BOX_W_RATIO
	var label_fs: int = 36
	var val_fs: int = 34
	var box_h: float = (_game.font.get_ascent(val_fs) + _game.font.get_descent(val_fs)) * 1.5

	var win_label: String = tr("CONFIG_FULLSCREEN") if _game.is_fullscreen else tr("CONFIG_WINDOW")
	var item_labels: Array[String] = [
		tr("CONFIG_WINDOW_MODE"), tr("CONFIG_LANGUAGE"),
		tr("CONFIG_BGM_VOLUME"), tr("CONFIG_SE_VOLUME"), tr("CONFIG_BACK")
	]
	var item_values: Array[String] = [
		win_label, _game.config_language_ui_label(), str(_game.bgm_volume), str(_game.se_volume), ""
	]

	var arrow_fs: int = 28

	for i in range(5):
		var item_y: float = base_y + i * spacing
		var is_sel: bool = (i == _game.config_index)
		if i == 4:
			# 「タイトルに戻る」— タイトルメニューと同じく is_off=非選択（薄ベージュ＋濃字）、選択時は赤
			var btn_center := Vector2(vp.x / 2.0, item_y + box_h / 2.0 - 16.0 + vp.y * 0.15 - 35.0)
			_draw_auto_button_with_shadow(btn_center, item_labels[i], BTN_FONT_SIZE, 1.0, not is_sel, box_w)
			continue
		# 0〜3: 値行は同一レイアウト（◀ ボックス ▶）。選択行はタイトルメニューと同様のホバー拡大＋シャドウ。
		var btn_id: String = _game.CONFIG_ROW_BTN_IDS[i]
		if is_sel:
			set_btn_hover(btn_id)
		var geom: Dictionary = _game.config_row_scaled_layout(vp, i)
		var G: Vector2 = geom["G"]
		var Lp: Vector2 = geom["Lp"]
		var Rp: Vector2 = geom["Rp"]
		var bw: float = geom["bw"]
		var bh: float = geom["bh"]
		var aw: float = geom["aw"]
		var shadow_extra: float = get_btn_shadow_extra(btn_id) if is_sel else 0.0
		var box_rect := Rect2(G.x - bw * 0.5, G.y - bh * 0.5, bw, bh)
		var shadow_offset := Vector2(12.5 + shadow_extra, 12.5 + shadow_extra)
		_game.draw_rect(Rect2(box_rect.position + shadow_offset, box_rect.size), Color(0.26, 0.21, 0.28, 0.30))
		_game.draw_rect(box_rect, Color(1.0, 1.0, 1.0))
		_game.draw_rect(box_rect, Color(0.26, 0.21, 0.28), false, 5.75)
		var val_baseline_y: float = box_rect.position.y + (bh + _game.font.get_ascent(val_fs) - _game.font.get_descent(val_fs)) * 0.5
		var val_font: Font = _game.font_din if (i == 2 or i == 3) else _game.font
		_game.draw_string(val_font, Vector2(box_rect.position.x, val_baseline_y), item_values[i], HORIZONTAL_ALIGNMENT_CENTER, bw, val_fs, val_c)
		var c: Color = sel_c if is_sel else text_c
		var label_font: Font = _game.font_bold if is_sel else _game.font
		var label_col_right: float = Lp.x - aw * 0.5 - _game.CONFIG_MENU_LABEL_GAP_TO_ARROW
		var label_area_w: float = maxf(0.0, label_col_right - lx)
		var lbl_fit: String = _config_fit_label_text(label_font, item_labels[i], label_area_w, label_fs)
		_game.draw_string(label_font, Vector2(lx, val_baseline_y), lbl_fit, HORIZONTAL_ALIGNMENT_RIGHT, label_area_w, label_fs, c)
		var left_enabled: bool = true
		var right_enabled: bool = true
		match i:
			2:
				left_enabled = _game.bgm_volume > 0
				right_enabled = _game.bgm_volume < 10
			3:
				left_enabled = _game.se_volume > 0
				right_enabled = _game.se_volume < 10
		var down_x: float = Lp.x - aw * 0.5
		var down_c: Color = (sel_c if is_sel else text_c) if left_enabled else Color(0.26, 0.21, 0.28, 0.25)
		var down_baseline: float = box_rect.position.y + (bh + _game.font.get_ascent(arrow_fs) - _game.font.get_descent(arrow_fs)) * 0.5
		_game.draw_string(_game.font_bold, Vector2(down_x, down_baseline), "◀", HORIZONTAL_ALIGNMENT_CENTER, aw, arrow_fs, down_c)
		var up_x: float = Rp.x - aw * 0.5
		var up_c: Color = (sel_c if is_sel else text_c) if right_enabled else Color(0.26, 0.21, 0.28, 0.25)
		_game.draw_string(_game.font_bold, Vector2(up_x, down_baseline), "▶", HORIZONTAL_ALIGNMENT_CENTER, aw, arrow_fs, up_c)


func _config_fit_label_text(font: Font, text: String, max_w: float, fs: int) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
		return text
	var ell: String = "…"
	var t: String = text
	while t.length() > 1:
		t = t.substr(0, t.length() - 1)
		if font.get_string_size(t + ell, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
			return t + ell
	return ell


# --- 操作説明の共通定義（rules / ポーズの操作説明で共有） ---
# 各要素: [key_tr, desc_tr, key_width]
const _CTRL_MOUSE_ITEMS: Array[Array] = [
	["CTRL_MOUSE_DRAG_KEY", "CTRL_MOUSE_DRAG_DESC", 180],
]
const _CTRL_PAD_ITEMS: Array[Array] = [
	["CTRL_PAD_LSTICK_KEY", "CTRL_PAD_LSTICK_DESC", 180],
	["CTRL_PAD_RSTICK_KEY", "CTRL_PAD_RSTICK_DESC", 180],
	["CTRL_PAD_DPAD_KEY", "CTRL_PAD_DPAD_DESC", 180],
	["CTRL_PAD_A_KEY", "CTRL_PAD_A_DESC", 180],
	["CTRL_PAD_LBRB_KEY", "CTRL_PAD_LBRB_DESC", 180],
]


func _draw_controls_stacked(vp: Vector2, top_y: float) -> float:
	"""操作説明を縦スタック表示。ヘッダーと最初の項目を同一行に配置。戻り値=描画終了Y"""
	var head_c := Color(0.26, 0.21, 0.28)
	var text_c := Color(0.35, 0.28, 0.35)
	var key_c := Color(0.95, 0.19, 0.32)
	var bar_c := Color(0.26, 0.21, 0.28, 0.4)

	var fs_h: int = 32       # ヘッダーフォントサイズ
	var fs: int = 28         # 項目フォントサイズ
	var line_h: float = 38.0 # 行の高さ
	var section_gap: float = 28.0  # マウス→ゲームパッド間の余白

	var label_x: float = vp.x * 0.15   # カテゴリ名のX
	var bar_x: float = vp.x * 0.28     # 縦線のX
	var key_x: float = vp.x * 0.30     # キー名のX
	var desc_x: float = vp.x * 0.44    # 説明文のX
	var desc_w: float = vp.x * 0.50    # 説明文の幅

	var y: float = top_y
	var ascent_h: float = _game.font.get_ascent(fs_h)

	# --- マウスセクション（ヘッダーと項目を同一行に） ---
	var mouse_section_top: float = y
	_game.draw_string(_game.font, Vector2(label_x, y), tr("CTRL_MOUSE_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_h, head_c)
	# マウスは項目1つだけ → ヘッダーと同じ行に描画
	if _CTRL_MOUSE_ITEMS.size() > 0:
		var item: Array = _CTRL_MOUSE_ITEMS[0]
		_game.draw_string(_game.font, Vector2(key_x, y), tr(item[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, key_c)
		_game.draw_string(_game.font, Vector2(desc_x, y), tr(item[1]), HORIZONTAL_ALIGNMENT_LEFT, desc_w, fs, text_c)
	# 縦線（マウスセクション、1行分）
	_game.draw_line(Vector2(bar_x, y - ascent_h + 4.0), Vector2(bar_x, y + 8.0), bar_c, 2.0, true)
	y += line_h

	y += section_gap

	# --- ゲームパッドセクション（ヘッダーと最初の項目を同一行に） ---
	var pad_line_h: float = line_h * 1.2  # 行間20%増量
	var pad_section_top: float = y
	_game.draw_string(_game.font, Vector2(label_x, y), tr("CTRL_PAD_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_h, head_c)
	# 最初の項目をヘッダーと同じ行に描画
	if _CTRL_PAD_ITEMS.size() > 0:
		var first: Array = _CTRL_PAD_ITEMS[0]
		_game.draw_string(_game.font, Vector2(key_x, y), tr(first[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, key_c)
		_game.draw_string(_game.font, Vector2(desc_x, y), tr(first[1]), HORIZONTAL_ALIGNMENT_LEFT, desc_w, fs, text_c)
	y += pad_line_h
	# 残りの項目を下に続ける
	for i in range(1, _CTRL_PAD_ITEMS.size()):
		var item: Array = _CTRL_PAD_ITEMS[i]
		_game.draw_string(_game.font, Vector2(key_x, y), tr(item[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, key_c)
		_game.draw_string(_game.font, Vector2(desc_x, y), tr(item[1]), HORIZONTAL_ALIGNMENT_LEFT, desc_w, fs, text_c)
		y += pad_line_h
	# 縦線（ゲームパッドセクション全体）
	_game.draw_line(Vector2(bar_x, pad_section_top - ascent_h + 4.0), Vector2(bar_x, y - pad_line_h + 8.0), bar_c, 2.0, true)

	return y


func _draw_controls_stacked_in_panel(panel_rect: Rect2, top_y: float, sc: float = 1.0) -> float:
	"""ポーズパネル内で操作説明を縦スタック表示。sc でフォント・行間をスケール。戻り値=描画終了Y"""
	var head_c := Color(0.26, 0.21, 0.28)
	var text_c := Color(0.35, 0.28, 0.35)
	var key_c := Color(0.95, 0.19, 0.32)
	var bar_c := Color(0.26, 0.21, 0.28, 0.4)

	var px: float = panel_rect.position.x
	var pw: float = panel_rect.size.x

	var fs_h: int = int(32 * sc)
	var fs: int = int(28 * sc)
	var line_h: float = 38.0 * sc
	var section_gap: float = 28.0 * sc

	var label_x: float = px + pw * 0.06
	var bar_x: float = px + pw * 0.22
	var key_x: float = px + pw * 0.24
	var desc_x: float = px + pw * 0.40
	var desc_w: float = pw * 0.55

	var y: float = top_y
	var ascent_h: float = _game.font.get_ascent(fs_h)

	# --- マウスセクション ---
	_game.draw_string(_game.font, Vector2(label_x, y), tr("CTRL_MOUSE_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_h, head_c)
	if _CTRL_MOUSE_ITEMS.size() > 0:
		var item: Array = _CTRL_MOUSE_ITEMS[0]
		_game.draw_string(_game.font, Vector2(key_x, y), tr(item[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, key_c)
		_game.draw_string(_game.font, Vector2(desc_x, y), tr(item[1]), HORIZONTAL_ALIGNMENT_LEFT, desc_w, fs, text_c)
	_game.draw_line(Vector2(bar_x, y - ascent_h + 4.0), Vector2(bar_x, y + 8.0), bar_c, 2.0, true)
	y += line_h

	y += section_gap

	# --- ゲームパッドセクション ---
	var pad_line_h: float = line_h * 1.2
	var pad_section_top: float = y
	_game.draw_string(_game.font, Vector2(label_x, y), tr("CTRL_PAD_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_h, head_c)
	if _CTRL_PAD_ITEMS.size() > 0:
		var first: Array = _CTRL_PAD_ITEMS[0]
		_game.draw_string(_game.font, Vector2(key_x, y), tr(first[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, key_c)
		_game.draw_string(_game.font, Vector2(desc_x, y), tr(first[1]), HORIZONTAL_ALIGNMENT_LEFT, desc_w, fs, text_c)
	y += pad_line_h
	for i in range(1, _CTRL_PAD_ITEMS.size()):
		var item: Array = _CTRL_PAD_ITEMS[i]
		_game.draw_string(_game.font, Vector2(key_x, y), tr(item[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, key_c)
		_game.draw_string(_game.font, Vector2(desc_x, y), tr(item[1]), HORIZONTAL_ALIGNMENT_LEFT, desc_w, fs, text_c)
		y += pad_line_h
	_game.draw_line(Vector2(bar_x, pad_section_top - ascent_h + 4.0), Vector2(bar_x, y - pad_line_h + 8.0), bar_c, 2.0, true)

	return y


func _draw_controls_content(origin: Vector2, width: float, start_y: float, fs_h: int, fs: int, line_h: float) -> void:
	"""操作説明の2カラム表示（ポーズの操作説明で使用）"""
	var head_c := Color(0.26, 0.21, 0.28)
	var text_c := Color(0.35, 0.28, 0.35)
	var key_c := Color(0.95, 0.19, 0.32)
	var lx: float = origin.x
	var rx: float = origin.x + width * 0.25
	var col_w: float = width * 0.42

	var y: float = start_y
	_game.draw_string(_game.font, Vector2(lx, y), tr("CTRL_MOUSE_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, col_w, fs_h, head_c)
	y += line_h + 4.0
	for item in _CTRL_MOUSE_ITEMS:
		var kw: float = item[2] as float
		_game.draw_string(_game.font, Vector2(lx, y), tr(item[0]), HORIZONTAL_ALIGNMENT_LEFT, kw, fs, key_c)
		_game.draw_string(_game.font, Vector2(lx + kw + 10.0, y), tr(item[1]), HORIZONTAL_ALIGNMENT_LEFT, col_w, fs, text_c)
		y += line_h

	y = start_y
	_game.draw_string(_game.font, Vector2(rx, y), tr("CTRL_PAD_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, col_w, fs_h, head_c)
	y += line_h + 4.0
	for item in _CTRL_PAD_ITEMS:
		var kw: float = item[2] as float
		_game.draw_string(_game.font, Vector2(rx, y), tr(item[0]), HORIZONTAL_ALIGNMENT_LEFT, kw, fs, key_c)
		_game.draw_string(_game.font, Vector2(rx + kw + 10.0, y), tr(item[1]), HORIZONTAL_ALIGNMENT_LEFT, col_w, fs, text_c)
		y += line_h


func _draw_rules(vp: Vector2) -> void:
	_draw_bg(vp)

	var shift_down: float = vp.y * 0.15  # ルール部分+図形を15%下へ
	var shift_up: float = vp.y * 0.05    # ヒント+ボタンを5%上へ

	# 上部: タイトル（大きめ、Bold）— さらに10%上へ
	var title_c := Color(0.26, 0.21, 0.28)
	_game.draw_string(_game.font_bold, Vector2(0, vp.y * 0.06 + shift_down - vp.y * 0.10), tr("RULES_MAIN"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 46, title_c)

	# 操作説明（縦スタック）— さらに7%上へ
	_draw_controls_stacked(vp, vp.y * 0.12 + shift_down - vp.y * 0.07)

	# 中央: デモ図形（自由に操作可能）
	_draw_rules_demo_shape(vp)

	# ヒントテキスト（Bold、大きめ）
	var hint_y: float = vp.y - 120.0 - shift_up
	if _game.rules_focus_button:
		_game.draw_string(_game.font_bold, Vector2(0, hint_y), tr("RULES_BTN_FOCUS_HINT"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 30, Color(0.35, 0.28, 0.35))
	else:
		_game.draw_string(_game.font_bold, Vector2(0, hint_y), tr("RULES_DEMO_HINT"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 30, Color(0.35, 0.28, 0.35))

	# 下部: [つぎへ]ボタン（幅広）
	var alpha: float = _crossfade_alpha()
	var btn_highlight: float = 1.0
	if _game.rules_focus_button:
		btn_highlight = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0 * 0.001 * TAU)
	var rules_btn_w: float = vp.x * 0.35
	_draw_auto_button_with_shadow(Vector2(vp.x / 2.0, vp.y - 48.0 - shift_up), tr("BTN_NEXT"), BTN_FONT_SIZE, alpha * btn_highlight, false, rules_btn_w)


func _radius_from_guide_distance_provisional(dist: float) -> float:
	var t: float = clampf(dist / POINT_RADIUS_GUIDE_DIST_FULL_PX, 0.0, 1.0)
	return lerpf(POINT_RADIUS_GUIDE_NEAR_MIN, POINT_RADIUS_GUIDE_FAR_MAX, t)


func _refresh_guide_point_distance_bounds() -> void:
	_guide_dist_have_bounds = false
	if _game.game_state != "playing":
		return
	var n: int = _game.point_positions.size()
	if n == 0:
		return
	var first: bool = true
	for i in range(n):
		if _game._is_locked(i):
			continue
		var d: float = _game.stage_manager.get_distance_to_hint_guide_outline(_game.point_positions[i])
		if first:
			_guide_dist_min = d
			_guide_dist_max = d
			first = false
		else:
			_guide_dist_min = minf(_guide_dist_min, d)
			_guide_dist_max = maxf(_guide_dist_max, d)
	_guide_dist_have_bounds = not first


func _point_radius_by_guide(idx: int) -> float:
	if _game.game_state != "playing" or idx < 0 or idx >= _game.point_positions.size():
		return POINT_RADIUS
	var d: float = _game.stage_manager.get_distance_to_hint_guide_outline(_game.point_positions[idx])
	var base_r: float = _radius_from_guide_distance_provisional(d)
	# ロック済み・比較対象がいないときは絶対距離のみ
	if _game._is_locked(idx) or not _guide_dist_have_bounds:
		return base_r
	var span: float = _guide_dist_max - _guide_dist_min
	var rel_t: float = 0.5
	if span > 1e-5:
		rel_t = clampf((d - _guide_dist_min) / span, 0.0, 1.0)
	var mult: float = lerpf(1.0 - POINT_RADIUS_RELATIVE_SPREAD, 1.0 + POINT_RADIUS_RELATIVE_SPREAD, rel_t)
	var r: float = base_r * mult
	return clampf(r, POINT_RADIUS_GUIDE_NEAR_MIN * 0.85, POINT_RADIUS_GUIDE_FAR_MAX * (1.0 + POINT_RADIUS_RELATIVE_SPREAD))


func _draw_rules_demo_shape(vp: Vector2) -> void:
	"""rules画面の中央にデモ図形を描画（操作可能）"""
	var n: int = _game.point_positions.size()
	if n == 0:
		return
	# 線
	for i in range(n):
		_game.draw_line(_game.point_positions[i], _game.point_positions[(i + 1) % n], LINE_COLOR, LINE_WIDTH, true)
	# ポイント
	for i in range(n):
		var pos: Vector2 = _game.point_positions[i]
		var color: Color
		var radius: float
		if _game.input_handler.grab_input_active and _game._is_selected(i):
			# つかみ状態: 白円 + 黒の同心円（1.2倍、外へ透過）
			radius = _point_radius_by_guide(i)
			_draw_selected_point(pos, radius)
			_draw_grab_state_effect(pos, radius)
			continue
		elif _game._is_selected(i):
			# 選択中: 白円 + 黒の同心円（1.2倍、外へ透過）
			radius = _point_radius_by_guide(i)
			_draw_selected_point(pos, radius)
			_draw_point_position_effect(pos, radius)
			continue
		elif i == _game.hovered_index:
			# ホバー時も通常表示（赤いポイントは廃止）
			color = POINT_COLOR
			radius = POINT_RADIUS
		else:
			color = POINT_COLOR
			radius = POINT_RADIUS
		_game.draw_circle(pos, radius, color)
	_draw_laser_effect()
	_draw_spore_particles()
	# 右スティックデバッグ: シアンの直線のみ
	_draw_right_stick_debug_line(vp)


# =============================================================================
# Drawing - Game / Guide / HUD
# =============================================================================

func _draw_game(vp: Vector2) -> void:
	_draw_bg(vp)

	# --- イントロ拡大→縮小演出 ---
	var intro_t: float = get_stage_intro_progress()
	var intro_scale: float = 1.0
	if intro_t < 1.0 and _game.game_state == "playing":
		var eased: float = _ease_out_cubic(intro_t)
		intro_scale = lerpf(1.5, 1.0, eased)
		# shape_center 基準でスケーリング変換を適用
		var center: Vector2 = _game.shape_center
		var xform := Transform2D()
		xform = xform.translated(-center)
		xform = xform.scaled(Vector2(intro_scale, intro_scale))
		xform = xform.translated(center)
		_game.draw_set_transform_matrix(xform)

	var n: int = _game.point_positions.size()

	# 1. ガイド（最下層）
	if _game.game_state == "playing" and _game.hint_alpha > 0.0:
		_stage_renderer.draw_hint_shape(_game.hint_alpha)

	# 1.5. 完成済みオブジェクトの塗りつぶし（線の下に描画）
	_draw_clear_fill()

	# 2. ユーザーの図形（線・ポイント・エフェクト）
	_stage_renderer.draw_stage_lines()
	_stage_renderer.draw_group_cleared_rings()

	_refresh_guide_point_distance_bounds()
	for i in range(n):
		var pos: Vector2 = _game.point_positions[i]
		var color: Color
		var radius: float
		var r_guide: float = _point_radius_by_guide(i)
		if _game._is_locked(i):
			color = Color(0.40, 0.33, 0.38, 0.5)
			radius = r_guide
		elif _game.input_handler.grab_input_active and _game._is_selected(i):
			# つかみ状態: 白円 + 黒の同心円（1.2倍、外へ透過）
			_draw_selected_point(pos, r_guide)
			_draw_grab_state_effect(pos, r_guide)
			continue
		elif _game._is_selected(i):
			# 選択中: 白円 + 黒の同心円（1.2倍、外へ透過）
			_draw_selected_point(pos, r_guide)
			_draw_point_position_effect(pos, r_guide)
			continue
		elif i == _game.hovered_index:
			# ホバー時も通常表示（赤いポイントは廃止）
			var alpha: float = _game._point_accuracy_alpha(i)
			var base_c: Color = _stage_renderer.get_point_base_color(i)
			color = Color(base_c.r, base_c.g, base_c.b, alpha)
			radius = r_guide
		else:
			var alpha: float = _game._point_accuracy_alpha(i)
			var base_c: Color = _stage_renderer.get_point_base_color(i)
			color = Color(base_c.r, base_c.g, base_c.b, alpha)
			radius = r_guide
		_game.draw_circle(pos, radius, color)

	_draw_laser_effect()
	_draw_spore_particles()

	# 3. 実現率（最上層）: 「つかむ」操作をした時だけ、そのポイントのやや右下に表示
	if _game.selected_indices.size() > 0 and _game.input_handler.grab_input_active:
		var idx: int = _game.selected_indices[0]
		if idx >= 0 and idx < _game.point_positions.size():
			var pt: Vector2 = _game.point_positions[idx]
			var offset: Vector2 = Vector2(28.0, 32.0)
			var circ_val: float
			if _game.stage_type == "two_circles" and idx >= _game.group_split:
				circ_val = _game.get_display_reproduction_rate_floor(_game.current_circularity_2)
			else:
				circ_val = _game.get_display_reproduction_rate_floor(_game.current_circularity)
			var rate_text: String = "%.1f%%" % circ_val
			var rate_color: Color = _stage_renderer.get_metric_color_for_display_rate(circ_val)
			_draw_realization_rate_with_glow(pt + offset, rate_text, rate_color)

	# イントロ演出のtransformをリセット（HUDはスケーリングしない）
	if intro_scale != 1.0:
		_game.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _game.game_state == "cleared":
		_stage_renderer.draw_ideal_shape()

	_draw_hud(vp)

	# 右スティックデバッグ: シアンの直線のみ
	_draw_right_stick_debug_line(vp)


func _draw_spore_particles() -> void:
	"""選択中: 時間経過で消える胞子。つかみ状態: 薄い→はっきり、中心に近づくほど小さくなる胞子"""
	var now: float = Time.get_ticks_msec() / 1000.0
	for p in spore_particles:
		var pos: Vector2 = p["pos"] as Vector2
		var base_sz: float = p["size"] as float
		var alpha: float
		var sz: float
		if p.get("converging", false):
			# つかみ状態: 薄い→はっきり、中心に近づくほど小さく
			var center: Vector2 = p["center"] as Vector2
			var spawn_dist: float = p["spawn_dist"] as float
			var dist: float = pos.distance_to(center)
			var dist_ratio: float = clampf(dist / spawn_dist, 0.05, 1.0)  # 中心近くで0に近づく
			alpha = 1.0 - dist_ratio  # 遠い→薄い、近い→はっきり
			sz = base_sz * dist_ratio  # 中心に近づくほど小さく
		else:
			# 選択中: 時間経過でだんだん消える
			var age: float = now - (p["spawn_time"] as float)
			var t: float = clampf(age / SPORE_SELECTION_LIFETIME, 0.0, 1.0)
			alpha = 1.0 - t * t
			sz = base_sz * (1.0 - t * 0.4)
		# 外周へ行くほど透過する同心円
		for layer in SPORE_GLOW_LAYERS:
			var r: float = sz * (layer[0] as float)
			var a: float = alpha * (layer[1] as float)
			var glow_c: Color = Color(SPORE_COLOR_GLOW.r, SPORE_COLOR_GLOW.g, SPORE_COLOR_GLOW.b, a)
			_game.draw_circle(pos, r, glow_c)
		# 白い点（中心）
		var white_c: Color = Color(SPORE_COLOR_WHITE.r, SPORE_COLOR_WHITE.g, SPORE_COLOR_WHITE.b, alpha * 0.9)
		_game.draw_circle(pos, sz * 0.55, white_c)


func _draw_laser_effect() -> void:
	"""選択ポイントから接続2点へ、青く光るレーザー状エフェクトを射出"""
	if _game.selected_indices.size() != 1:
		return
	var idx: int = _game.selected_indices[0]
	if _game._is_locked(idx):
		return
	var connected: Array[int] = _game.input_handler.get_connected_indices(idx)
	var from_pos: Vector2 = _game.point_positions[idx]
	for target_idx in connected:
		if _game._is_locked(target_idx):
			continue
		var to_pos: Vector2 = _game.point_positions[target_idx]
		var delta: Vector2 = to_pos - from_pos
		var dist: float = delta.length()
		if dist < 1.0:
			continue
		var dir: Vector2 = delta / dist
		var draw_len: float = dist * LASER_LENGTH_RATIO
		# セグメントごとに描画（長さ方向にだんだん薄く）
		for seg in range(LASER_SEGMENTS):
			var t0: float = float(seg) / float(LASER_SEGMENTS)
			var t1: float = float(seg + 1) / float(LASER_SEGMENTS)
			var p0: Vector2 = from_pos + dir * (t0 * draw_len)
			var p1: Vector2 = from_pos + dir * (t1 * draw_len)
			var seg_alpha: float = 1.0 - t0  # 始点側で濃く、終点側で消える
			if seg_alpha < 0.01:
				continue
			# 太めの青い線（外側ほど透過）
			for layer in LASER_THICK_LAYERS:
				var w: float = layer[0] as float
				var a: float = (layer[1] as float) * seg_alpha
				var c: Color = Color(LASER_BLUE.r, LASER_BLUE.g, LASER_BLUE.b, a)
				_game.draw_line(p0, p1, c, w, true)
			# 細く白い線を重ねる
			var white_c: Color = Color(LASER_WHITE.r, LASER_WHITE.g, LASER_WHITE.b, seg_alpha * 0.9)
			_game.draw_line(p0, p1, white_c, LASER_WHITE_WIDTH, true)


func _draw_selected_point(center: Vector2, base_r: float = POINT_RADIUS) -> void:
	"""選択ポイント: 白の円 + 半径1.2倍の黒の円（中心から離れるほど透過）"""
	var r: float = base_r
	for layer in SELECTED_POINT_BLACK_LAYERS:
		var radius: float = r * (layer[0] as float)
		var a: float = layer[1] as float
		var black_c: Color = Color(SELECTED_POINT_BLACK.r, SELECTED_POINT_BLACK.g, SELECTED_POINT_BLACK.b, a)
		_game.draw_circle(center, radius, black_c)
	_game.draw_circle(center, r, SELECTED_POINT_WHITE)


func _effect_hover_base(base_r: float) -> float:
	return base_r + (POINT_RADIUS_HOVER - POINT_RADIUS)


func _draw_point_position_effect(center: Vector2, base_r: float = POINT_RADIUS) -> void:
	"""ポイント位置: 水色のサークルが1秒ごとに拡散しながら消えていくエフェクト"""
	var t: float = fmod(Time.get_ticks_msec() / 1000.0, 1.0)  # 0..1 を1秒周期で繰り返し
	var radius: float = _effect_hover_base(base_r) + t * 25.0   # 拡散
	var alpha: float = 1.0 - t                                 # 消えていく
	var c: Color = Color(_game.POINT_POSITION_EFFECT_COLOR.r, _game.POINT_POSITION_EFFECT_COLOR.g, _game.POINT_POSITION_EFFECT_COLOR.b, alpha * 0.6)
	_game.draw_arc(center, radius, 0, TAU, 32, c, 2.5)


func _draw_grab_state_effect(center: Vector2, base_r: float = POINT_RADIUS) -> void:
	"""つかみ状態: 青色のサークルが0.5秒ごとに透明からだんだん色濃く収束してくるエフェクト"""
	var t: float = fmod(Time.get_ticks_msec() / 500.0, 1.0)   # 0..1 を0.5秒周期で繰り返し
	var alpha: float = t                                      # 透明→濃く
	var radius: float = _effect_hover_base(base_r) + (1.0 - t) * 8.0  # 収束（大きい→小さい）
	var c: Color = Color(_game.GRAB_STATE_EFFECT_COLOR.r, _game.GRAB_STATE_EFFECT_COLOR.g, _game.GRAB_STATE_EFFECT_COLOR.b, alpha * 0.85)
	_game.draw_arc(center, radius, 0, TAU, 32, c, 3.0)


func _smoothstep01(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## 扇形コリドー: u=0 が左境界、u=1 が右境界（中心線は u=0.5）
func _rs_corridor_dir_at_u(dir_n: Vector2, half_rad: float, u: float) -> Vector2:
	return dir_n.rotated(half_rad * (1.0 - 2.0 * clampf(u, 0.0, 1.0)))


## 中心線に近いほど 1.0、左右外周に近いほど RS_CORRIDOR_ANGULAR_EDGE_MUL に近づく
func _rs_corridor_angular_alpha_mul(u: float, edge_mul: float) -> float:
	var d: float = absf(u - 0.5) * 2.0
	return lerpf(1.0, edge_mul, _smoothstep01(d))


func _draw_right_stick_shoulder_corridor_guide(vp: Vector2) -> void:
	"""L/R 候補コリドー（扇形）。半径方向＋中心核（角度方向）の二重グラデーション。CONE_HALF_ANGLE と一致。"""
	if not _game.input_handler.debug_right_stick_active:
		return
	var dir: Vector2 = _game.input_handler.debug_right_stick_direction
	if dir.length_squared() < 0.0001:
		return
	var center: Vector2 = _game.input_handler.debug_right_stick_center
	var dir_n: Vector2 = dir.normalized()
	var line_len: float = maxf(vp.x, vp.y) * 0.6
	var half_rad: float = deg_to_rad(InputHandler.RIGHT_STICK_RAY_SHOULDER_CONE_HALF_ANGLE_DEG)
	var fill_rgb: Color = Color(0.95, 0.42, 0.44)
	var alpha_inner: float = 0.24
	var alpha_outer: float = 0.0
	var n_radial: int = 32
	var n_angular: int = 14
	var angular_edge_mul: float = 0.14
	for i in range(n_radial):
		var t0: float = float(i) / float(n_radial)
		var t1: float = float(i + 1) / float(n_radial)
		var su0: float = _smoothstep01(t0)
		var su1: float = _smoothstep01(t1)
		var base_a0: float = lerpf(alpha_inner, alpha_outer, su0)
		var base_a1: float = lerpf(alpha_inner, alpha_outer, su1)
		var r0: float = t0 * line_len
		var r1: float = t1 * line_len
		for j in range(n_angular):
			var u0: float = float(j) / float(n_angular)
			var u1: float = float(j + 1) / float(n_angular)
			var d0: Vector2 = _rs_corridor_dir_at_u(dir_n, half_rad, u0)
			var d1: Vector2 = _rs_corridor_dir_at_u(dir_n, half_rad, u1)
			var m0: float = _rs_corridor_angular_alpha_mul(u0, angular_edge_mul)
			var m1: float = _rs_corridor_angular_alpha_mul(u1, angular_edge_mul)
			var a00: float = base_a0 * m0
			var a01: float = base_a1 * m0
			var a11: float = base_a1 * m1
			var a10: float = base_a0 * m1
			var p00: Vector2 = center + d0 * r0
			var p01: Vector2 = center + d0 * r1
			var p11: Vector2 = center + d1 * r1
			var p10: Vector2 = center + d1 * r0
			var pts: PackedVector2Array = PackedVector2Array([p00, p01, p11, p10])
			var cols: PackedColorArray = PackedColorArray([
				Color(fill_rgb.r, fill_rgb.g, fill_rgb.b, a00),
				Color(fill_rgb.r, fill_rgb.g, fill_rgb.b, a01),
				Color(fill_rgb.r, fill_rgb.g, fill_rgb.b, a11),
				Color(fill_rgb.r, fill_rgb.g, fill_rgb.b, a10),
			])
			_game.draw_polygon(pts, cols)


func _draw_right_stick_debug_line(vp: Vector2) -> void:
	"""右スティック倒し中: コリドー帯 → 放電エフェクトで描画"""
	if not _game.input_handler.debug_right_stick_active:
		return
	var ih: InputHandler = _game.input_handler
	var center: Vector2 = ih.debug_right_stick_center
	var dir: Vector2 = ih.debug_right_stick_direction
	if dir.length_squared() < 0.0001:
		return
	_draw_right_stick_shoulder_corridor_guide(vp)
	var line_len: float = maxf(vp.x, vp.y) * 0.6
	var end_pos: Vector2 = center + dir * line_len
	var perpendicular: Vector2 = Vector2(-dir.y, dir.x)  # 法線（ジグザグ用）

	# 稲妻の経路をランダムなジグザグで生成（毎フレームで形が変わり放電風に）
	var segs: int = 14
	var points: Array[Vector2] = []
	points.append(center)
	for i in range(1, segs):
		var t: float = float(i) / float(segs)
		var base_pos: Vector2 = center.lerp(end_pos, t)
		# 法線方向にランダムオフセット（根元でやや大きめ）
		var jitter: float = randf_range(-14.0, 14.0) * (1.2 - t * 0.4)
		points.append(base_pos + perpendicular * jitter)
	points.append(end_pos)

	# 外側のグロー（太め・薄い）
	var glow_color: Color = Color(0.95, 0.19, 0.32, 0.25)
	for i in range(points.size() - 1):
		_game.draw_line(points[i], points[i + 1], glow_color, 6.0, true)
	# メインの稲妻（赤）
	var bolt_color: Color = Color(0.95, 0.25, 0.35, 0.95)
	for i in range(points.size() - 1):
		_game.draw_line(points[i], points[i + 1], bolt_color, 2.5, true)
	# 中心の白い芯
	var core_color: Color = Color(1.0, 0.937, 0.89, 1.0)
	for i in range(points.size() - 1):
		_game.draw_line(points[i], points[i + 1], core_color, 1.0, true)

	# 枝分かれスパーク（6本程度）
	for _j in range(6):
		var idx: int = randi_range(1, points.size() - 2)
		var from_p: Vector2 = points[idx]
		var branch_dir: Vector2 = (perpendicular * randf_range(-0.8, 0.8) + dir * randf_range(-0.2, 0.3)).normalized()
		var branch_len: float = randf_range(18, 52)
		var to_p: Vector2 = from_p + branch_dir * branch_len
		_game.draw_line(from_p, to_p, Color(0.98, 0.45, 0.50, 0.55), 1.5, true)


func _draw_guide_info(vp: Vector2) -> void:
	_draw_bg(vp)

	# 解像度スケール（1080p基準）
	var rs: float = vp.y / 1080.0

	var play_cx: float = vp.x / 2.0
	var text_w: float = vp.x * 0.8
	var tx: float = play_cx - text_w / 2.0
	var text_color := Color(0.26, 0.21, 0.28)

	# --- 上部テキストブロック（行間5px＝元10pxの半分、上端50px）---
	var stage_fs: int = 48
	var num_fs: int = 160
	var desc_fs: int = 38
	var gap1: float = -60.0  # STAGE ↔ ステージ数
	var gap2: float = -20.0  # ステージ数 ↔ ステージ目的

	var stage_asc: float = _game.font_din.get_ascent(stage_fs)
	var stage_desc_h: float = _game.font_din.get_descent(stage_fs)
	var num_asc: float = _game.font_din.get_ascent(num_fs)
	var num_desc_h: float = _game.font_din.get_descent(num_fs)
	var desc_asc: float = _game.font.get_ascent(desc_fs)
	var desc_desc_h: float = _game.font.get_descent(desc_fs)

	# スライドインアニメーション用タイミング
	var t: float = _guide_info_time
	var slide_px: float = 20.0  # スライド距離
	var anim_dur: float = 0.3   # 各要素のアニメ時間
	var stagger: float = 0.12   # 要素間の遅延

	# 要素ごとのアニメ進行率（0〜1）
	var t1: float = clampf((t - stagger * 0) / anim_dur, 0.0, 1.0)  # STAGE
	var t2: float = clampf((t - stagger * 1) / anim_dur, 0.0, 1.0)  # 番号
	var t3: float = clampf((t - stagger * 2) / anim_dur, 0.0, 1.0)  # 目的
	var t4: float = clampf((t - stagger * 3) / anim_dur, 0.0, 1.0)  # 図形
	var e1: float = _ease_out_cubic(t1)
	var e2: float = _ease_out_cubic(t2)
	var e3: float = _ease_out_cubic(t3)
	var e4: float = _ease_out_back(t4)

	# "STAGE"
	var y1: float = 50.0 * rs + stage_asc
	var a1: float = e1
	_game.draw_string(_game.font_din, Vector2(tx, y1 + slide_px * (1.0 - e1)), "STAGE", HORIZONTAL_ALIGNMENT_CENTER, text_w, stage_fs, Color(text_color.r, text_color.g, text_color.b, a1))

	# ステージ番号
	var y2: float = y1 + stage_desc_h + gap1 + num_asc
	var a2: float = e2
	_draw_monospace_number(_game.font_din, Vector2(tx, y2 + slide_px * (1.0 - e2)), "%d" % (_game.current_stage + 1), HORIZONTAL_ALIGNMENT_CENTER, text_w, num_fs, Color(text_color.r, text_color.g, text_color.b, a2))

	# ステージ目的
	var y3: float = y2 + num_desc_h + gap2 + desc_asc
	var a3: float = e3
	var type_desc: String = _stage_renderer.get_type_description()
	if _game.debug_stage_test_mode and _game.debug_stage_test_meta_stage_name.strip_edges() != "":
		type_desc = _game.debug_stage_test_meta_stage_name
	_game.draw_string(_game.font, Vector2(tx, y3 + slide_px * (1.0 - e3)), type_desc, HORIZONTAL_ALIGNMENT_CENTER, text_w, desc_fs, Color(0.35, 0.28, 0.35, a3))

	# 上部ブロックの下端
	var top_block_bottom: float = y3 + desc_desc_h

	# --- 下部テキスト（画面下端50px上に固定）---
	var start_fs: int = int(38 * rs)
	if start_fs < 24: start_fs = 24
	var start_desc_h: float = _game.font_bold.get_descent(start_fs)
	var start_text_y: float = vp.y - 50.0 * rs - start_desc_h
	var start_asc: float = _game.font_bold.get_ascent(start_fs)
	var bottom_text_top: float = start_text_y - start_asc

	# "クリックでスタート" は図形アニメ完了後にフェードイン
	var t5: float = clampf((t - stagger * 4) / anim_dur, 0.0, 1.0)
	var blink: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 0.5)
	_game.draw_string(_game.font_bold, Vector2(tx, start_text_y), tr("GUIDE_CLICK_START"), HORIZONTAL_ALIGNMENT_CENTER, text_w, start_fs, Color(0.95, 0.19, 0.32, t5 * blink))

	# --- 図形イメージ（スケール0→1のバウンスアニメ）---
	var available_h: float = bottom_text_top - top_block_bottom
	var available_w: float = text_w
	var shape_cy: float = top_block_bottom + available_h / 2.0
	if e4 > 0.001:
		_stage_renderer.draw_guide_shape_side_by_side(Vector2(play_cx, shape_cy), available_w * e4, available_h * e4, e4, 2.5)


func _draw_guide_countdown(vp: Vector2) -> void:
	_draw_bg(vp)

	var play_cx: float = vp.x / 2.0
	var cy: float = vp.y / 2.0
	var base_fs: int = 540

	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _game.guide_start_time
	var remaining: float = maxf(0.0, 3.0 - elapsed)
	var countdown: int = ceili(remaining)

	# 数字切り替え時のスケールアニメ（1.3→1.0 を0.3秒で）
	if countdown != _countdown_prev:
		_countdown_prev = countdown
		_countdown_scales[countdown] = Time.get_ticks_msec() / 1000.0
	var num_start: float = _countdown_scales.get(countdown, Time.get_ticks_msec() / 1000.0)
	var num_t: float = clampf((Time.get_ticks_msec() / 1000.0 - num_start) / 0.3, 0.0, 1.0)
	var num_ease: float = _ease_out_cubic(num_t)
	var scale_val: float = lerp(1.3, 1.0, num_ease)
	var alpha_val: float = lerp(0.0, 1.0, minf(num_t * 3.0, 1.0))  # 素早くフェードイン
	var fs: int = int(base_fs * scale_val)

	var asc: float = _game.font_din.get_ascent(fs)
	var desc_h: float = _game.font_din.get_descent(fs)
	var baseline_y: float = cy - (asc + desc_h) / 2.0 + asc - vp.y * 0.08
	_draw_monospace_number(_game.font_din, Vector2(play_cx - vp.x / 2.0, baseline_y), "%d" % countdown, HORIZONTAL_ALIGNMENT_CENTER, vp.x, fs, Color(0.263, 0.212, 0.278, alpha_val))


func _draw_ui_panel(vp: Vector2) -> void:
	var ui_w: float = vp.x * 0.25
	var h: float = vp.y

	_game.draw_rect(Rect2(Vector2.ZERO, Vector2(ui_w, h)), Color(0.26, 0.21, 0.28))

	var stripe_w: float = 3.0
	var gap: float = 18.0
	var x: float = stripe_w
	while x < ui_w - 4.0:
		_game.draw_rect(Rect2(Vector2(x, 0), Vector2(1.0, h)), Color(0.30, 0.24, 0.32, 0.35))
		x += gap

	var margin: float = 8.0
	var frame_rect := Rect2(Vector2(margin, margin), Vector2(ui_w - margin * 2.0, h - margin * 2.0))
	_game.draw_rect(frame_rect, Color(1.0, 0.937, 0.89, 0.08))
	_game.draw_rect(frame_rect, Color(0.85, 0.72, 0.60, 0.25), false, 1.0)

	var corner_len: float = 20.0
	var corner_t: float = 1.5
	var cc := Color(0.85, 0.72, 0.60, 0.35)
	_game.draw_line(Vector2(margin, margin), Vector2(margin + corner_len, margin), cc, corner_t, true)
	_game.draw_line(Vector2(margin, margin), Vector2(margin, margin + corner_len), cc, corner_t, true)
	_game.draw_line(Vector2(ui_w - margin, margin), Vector2(ui_w - margin - corner_len, margin), cc, corner_t, true)
	_game.draw_line(Vector2(ui_w - margin, margin), Vector2(ui_w - margin, margin + corner_len), cc, corner_t, true)
	_game.draw_line(Vector2(margin, h - margin), Vector2(margin + corner_len, h - margin), cc, corner_t, true)
	_game.draw_line(Vector2(margin, h - margin), Vector2(margin, h - margin - corner_len), cc, corner_t, true)
	_game.draw_line(Vector2(ui_w - margin, h - margin), Vector2(ui_w - margin - corner_len, h - margin), cc, corner_t, true)
	_game.draw_line(Vector2(ui_w - margin, h - margin), Vector2(ui_w - margin, h - margin - corner_len), cc, corner_t, true)

	_game.draw_line(Vector2(ui_w - 1.0, 0), Vector2(ui_w - 1.0, h), Color(0.85, 0.72, 0.60, 0.30), 1.0, true)

	var deco_y: float = 62.0
	_game.draw_line(Vector2(margin + 6.0, deco_y), Vector2(ui_w - margin - 6.0, deco_y), Color(0.70, 0.58, 0.50, 0.20), 1.0, true)

	var deco_y2: float = h - 100.0
	_game.draw_line(Vector2(margin + 6.0, deco_y2), Vector2(ui_w - margin - 6.0, deco_y2), Color(0.70, 0.58, 0.50, 0.20), 1.0, true)



func _draw_auto_button_with_shadow(center: Vector2, text: String, fs: int = BTN_FONT_SIZE, alpha: float = 1.0, is_off: bool = false, fixed_w: float = -1.0) -> Rect2:
	"""ボタンを描画。選択(is_off=false)時はホバーアニメーション付き"""
	var btn_w: float = fixed_w if fixed_w > 0.0 else _game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 1.5
	var btn_h: float = (_game.font.get_ascent(fs) + _game.font.get_descent(fs)) * 1.5

	# ホバーアニメーション（選択中ボタンのみ）
	var btn_id: String = text
	if not is_off:
		set_btn_hover(btn_id)
	var sc: float = get_btn_scale(btn_id) if not is_off else 1.0
	var shadow_extra: float = get_btn_shadow_extra(btn_id) if not is_off else 0.0
	# 押下アニメーション中のフェードアウト
	if _btn_press_timers.has(btn_id) and _btn_press_timers[btn_id] >= 0.0:
		var press_t: float = _ease_in_out_cubic(_btn_press_timers[btn_id])
		alpha *= (1.0 - press_t)
	var draw_w: float = btn_w * sc
	var draw_h: float = btn_h * sc

	# スケールまたはアルファが0以下なら描画スキップ
	if sc < 0.001 or alpha < 0.001:
		return Rect2(center.x - btn_w / 2.0, center.y - btn_h / 2.0, btn_w, btn_h)

	var rect := Rect2(center.x - draw_w / 2.0, center.y - draw_h / 2.0, draw_w, draw_h)
	var shadow_offset := Vector2(12.5 + shadow_extra, 12.5 + shadow_extra)
	_game.draw_rect(Rect2(rect.position + shadow_offset, rect.size), Color(0.26, 0.21, 0.28, 0.30 * alpha))
	if is_off:
		_game.draw_rect(rect, Color(1.0, 0.937, 0.89, alpha))
	else:
		_game.draw_rect(rect, Color(0.95, 0.19, 0.32, 0.9 * alpha))
	_game.draw_rect(rect, Color(0.26, 0.21, 0.28, alpha), false, 5.75)
	var ascent: float = _game.font.get_ascent(fs)
	var descent: float = _game.font.get_descent(fs)
	var baseline_y: float = rect.position.y + (draw_h + ascent - descent) * 0.5
	var text_color: Color
	if is_off:
		text_color = Color(0.26, 0.21, 0.28, alpha)
	else:
		text_color = Color(1.0, 0.937, 0.89, alpha)
	_game.draw_string(_game.font, Vector2(rect.position.x, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, draw_w, fs, text_color)
	# ヒット判定用に元サイズのrectを返す
	return Rect2(center.x - btn_w / 2.0, center.y - btn_h / 2.0, btn_w, btn_h)


func _draw_monospace_number(font: Font, pos: Vector2, text: String, alignment: int, width: float, fs: int, color: Color) -> void:
	"""数字を等幅で描画。'0'の幅を基準に全数字文字を固定幅で配置。非数字はそのまま描画。"""
	var zero_w: float = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# 文字列全体の幅を計算
	var total_w: float = 0.0
	for ch in text:
		if ch >= "0" and ch <= "9":
			total_w += zero_w
		else:
			total_w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# アライメントに基づいてオフセット計算
	var offset_x: float = 0.0
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		if width > 0.0:
			offset_x = (width - total_w) / 2.0
		else:
			offset_x = -total_w / 2.0
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		if width > 0.0:
			offset_x = width - total_w
		else:
			offset_x = -total_w
	# 1文字ずつ描画
	var cx: float = pos.x + offset_x
	for ch in text:
		if ch >= "0" and ch <= "9":
			var ch_w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pad: float = (zero_w - ch_w) / 2.0
			_game.draw_string(font, Vector2(cx + pad, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
			cx += zero_w
		else:
			_game.draw_string(font, Vector2(cx, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
			cx += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

func _get_monospace_number_width(font: Font, text: String, fs: int) -> float:
	"""等幅数字での文字列幅を取得"""
	var zero_w: float = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total_w: float = 0.0
	for ch in text:
		if ch >= "0" and ch <= "9":
			total_w += zero_w
		else:
			total_w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return total_w


func _draw_dialog_with_shadow(rect: Rect2) -> void:
	"""シャドウ付きダイアログ背景を描画"""
	var shadow_offset := Vector2(15.0, 15.0)
	var shadow_rect := Rect2(rect.position + shadow_offset, rect.size)
	_game.draw_rect(shadow_rect, Color(0.26, 0.21, 0.28, 0.25))
	_game.draw_rect(rect, Color(1.0, 0.937, 0.89))
	_game.draw_rect(rect, Color(0.26, 0.21, 0.28), false, 3.45)


func _draw_realization_rate_with_glow(pos: Vector2, text: String, main_color: Color) -> void:
	"""実現率テキストを黒い光るエフェクト付きで描画。内側→外側の多段リングでブラー風グロー"""
	var fs: int = 36
	# 8方向の単位ベクトル（正規化済み）
	var dirs: Array[Vector2] = [
		Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
		Vector2(-0.707, -0.707), Vector2(0.707, -0.707), Vector2(-0.707, 0.707), Vector2(0.707, 0.707)
	]
	# 内側リング: 濃いめ、近いオフセット
	var inner_dist: float = 1.0
	var inner_color: Color = Color(0.26, 0.21, 0.28, 0.55)
	# 中間リング: 中程度の距離
	var mid_dist: float = 2.2
	var mid_color: Color = Color(0.26, 0.21, 0.28, 0.4)
	# 外側リング: 遠く、薄く（ブラー風）
	var outer_dist: float = 3.8
	var outer_color: Color = Color(0.26, 0.21, 0.28, 0.28)
	# 最外側: さらに広がりを強調
	var far_dist: float = 5.5
	var far_color: Color = Color(0.26, 0.21, 0.28, 0.18)
	var x: float = pos.x
	for i in range(text.length()):
		var ch: String = text.substr(i, 1)
		var char_pos: Vector2 = Vector2(x, pos.y)
		# 外側→内側の順で描画（内側が上に乗る）
		for d in dirs:
			_game.draw_string(_game.font, char_pos + d * far_dist, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, far_color)
		for d in dirs:
			_game.draw_string(_game.font, char_pos + d * outer_dist, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outer_color)
		for d in dirs:
			_game.draw_string(_game.font, char_pos + d * mid_dist, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, mid_color)
		for d in dirs:
			_game.draw_string(_game.font, char_pos + d * inner_dist, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, inner_color)
		# メイン（グラデーション色）
		_game.draw_string(_game.font, char_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, main_color)
		var w: float = _game.font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		x += w


func _draw_string_fit(pos: Vector2, text: String, max_w: float, base_fs: int, color: Color, min_fs: int = 20) -> void:
	var fs: int = base_fs
	while fs > min_fs:
		var tw: float = _get_monospace_number_width(_game.font, text, fs)
		if tw <= max_w:
			break
		fs -= 2
	_draw_monospace_number(_game.font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, max_w, fs, color)


func _get_fixed_digit_advance(fs: int) -> float:
	"""0-9, '.', ' ' の最大幅を返す（等幅表示用）"""
	var chars: String = "0123456789. "
	var max_w: float = 0.0
	for i in range(chars.length()):
		var c: String = chars.substr(i, 1)
		var w: float = _game.font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w > max_w:
			max_w = w
	return max_w


func _draw_hud_time_fixed_width(pos: Vector2, elapsed: float, fs: int, color: Color) -> float:
	"""秒数をケタ固定幅で描画し、描画幅を返す。カウント時のブレを防ぐ"""
	var fmt: String = tr("HUD_TIME")
	var digit_advance: float = _get_fixed_digit_advance(fs)
	var prefix: String = fmt.substr(0, fmt.find("%"))
	var suffix: String = fmt.substr(fmt.find("f") + 1)
	var number_part: String = "%5.1f" % elapsed  # "  9.0" or " 10.0" など5文字
	var x: float = pos.x
	_game.draw_string(_game.font, Vector2(x, pos.y), prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	x += _game.font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	for i in range(number_part.length()):
		var c: String = number_part.substr(i, 1)
		_game.draw_string(_game.font, Vector2(x, pos.y), c, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
		x += digit_advance
	_game.draw_string(_game.font, Vector2(x, pos.y), suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	x += _game.font.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return x - pos.x


func _draw_hud(vp: Vector2) -> void:
	var right_margin: float = 24.0
	var label_fs: int = 36
	var value_fs: int = int(52 * 0.85)  # 85%に縮小
	var hud_black: Color = Color(0.26, 0.21, 0.28)
	var box_w: float = 350.0
	var box_h: float = 60.0
	var shadow_offset := Vector2(12.5, 12.5)

	var elapsed: float
	if _game.game_state == "cleared":
		elapsed = _game.clear_time
	elif _game.pause_active:
		elapsed = _game.pause_elapsed
	else:
		elapsed = maxf(0.0, Time.get_ticks_msec() / 1000.0 - _game.start_time)

	# ラベル幅を計算
	var stage_label: String = "STAGE"
	var time_label: String = "TIME"
	var label_w: float = _game.font_din.get_string_size(stage_label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs).x
	var time_label_w: float = _game.font_din.get_string_size(time_label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs).x
	var max_label_w: float = maxf(label_w, time_label_w)
	var label_gap: float = 12.0

	var box_x_base: float = vp.x - right_margin - box_w - 10.0  # 左に10pix移動
	var label_x_base: float = box_x_base - max_label_w - label_gap - 10.0  # 左に10pix移動

	# --- スライドイン演出 ---
	var intro_t: float = get_stage_intro_progress()
	var slide_dist: float = box_w + max_label_w + label_gap + right_margin + 40.0  # 画面外に出る距離
	# STAGE: 即座にスライド開始
	var stage_slide_t: float = clampf(intro_t / 0.8, 0.0, 1.0)  # 0〜80%の区間で完了
	var stage_offset_x: float = slide_dist * (1.0 - _ease_out_cubic(stage_slide_t))
	# TIME: 少し遅れてスライド開始
	var time_slide_t: float = clampf((intro_t - 0.2) / 0.8, 0.0, 1.0)  # 20%〜100%の区間で完了
	var time_offset_x: float = slide_dist * (1.0 - _ease_out_cubic(time_slide_t))

	var box_x: float = box_x_base + stage_offset_x
	var label_x: float = label_x_base + stage_offset_x

	# STAGE ボックス
	var stage_y: float = 20.0
	_game.draw_string(_game.font_din, Vector2(label_x, stage_y + 42.0), stage_label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs, hud_black)
	var stage_box := Rect2(box_x, stage_y, box_w, box_h)
	_game.draw_rect(Rect2(stage_box.position + shadow_offset, stage_box.size), Color(0.26, 0.21, 0.28, 0.30))
	_game.draw_rect(stage_box, Color(1.0, 1.0, 1.0))
	_game.draw_rect(stage_box, Color(0.26, 0.21, 0.28), false, 5.75)
	var stage_val: String = "%d" % (_game.current_stage + 1)
	var stage_baseline: float = stage_y + (box_h + _game.font_din.get_ascent(value_fs) - _game.font_din.get_descent(value_fs)) * 0.5 - 3.0
	_draw_monospace_number(_game.font_din, Vector2(box_x, stage_baseline), stage_val, HORIZONTAL_ALIGNMENT_CENTER, box_w, value_fs, hud_black)

	# TIME ボックス（STAGE枠の下端から20px空ける）— 別のオフセット
	var time_box_x: float = box_x_base + time_offset_x
	var time_label_x: float = label_x_base + time_offset_x
	var time_y: float = stage_y + box_h + 20.0
	_game.draw_string(_game.font_din, Vector2(time_label_x, time_y + 42.0), time_label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs, hud_black)
	var time_box := Rect2(time_box_x, time_y, box_w, box_h)
	_game.draw_rect(Rect2(time_box.position + shadow_offset, time_box.size), Color(0.26, 0.21, 0.28, 0.30))
	_game.draw_rect(time_box, Color(1.0, 1.0, 1.0))
	_game.draw_rect(time_box, Color(0.26, 0.21, 0.28), false, 5.75)
	var time_val: String = "%.1fs" % elapsed
	var time_baseline: float = time_y + (box_h + _game.font_din.get_ascent(value_fs) - _game.font_din.get_descent(value_fs)) * 0.5 - 3.0
	_draw_monospace_number(_game.font_din, Vector2(time_box_x, time_baseline), time_val, HORIZONTAL_ALIGNMENT_CENTER, box_w, value_fs, hud_black)


# =============================================================================
# Drawing - Clear / Results / Pause / Particles
# =============================================================================

func _draw_clear_fill() -> void:
	"""完成した図形の内側を50%透過の#f23052で塗りつぶす。
	   複数オブジェクトの場合、個別に完成した時点で塗りつぶす。"""
	var positions: Array = _game.point_positions
	var n: int = positions.size()
	if n < 3:
		return
	var fill_color := Color(0.949, 0.188, 0.322, 0.5)  # #f23052, 50%透過
	if _game.stage_type == "two_circles":
		# グループ1: 完成済みなら塗りつぶし
		if _game.group1_cleared:
			var poly1 := PackedVector2Array()
			for i in range(_game.group_split):
				poly1.append(positions[i])
			if poly1.size() >= 3:
				_game.draw_colored_polygon(poly1, fill_color)
		# グループ2: 完成済みなら塗りつぶし
		if _game.group2_cleared:
			var poly2 := PackedVector2Array()
			for i in range(_game.group_split, n):
				poly2.append(positions[i])
			if poly2.size() >= 3:
				_game.draw_colored_polygon(poly2, fill_color)
	else:
		# 単一オブジェクト: clearedステートでのみ塗りつぶし
		if _game.game_state == "cleared":
			var poly := PackedVector2Array()
			for i in range(n):
				poly.append(positions[i])
			_game.draw_colored_polygon(poly, fill_color)


func _draw_clear_overlay(vp: Vector2) -> void:
	# クリア演出アニメーション（スケール0.8→1.0 + フェードイン 0.3秒）
	var clear_elapsed: float = Time.get_ticks_msec() / 1000.0 - _clear_anim_time if _clear_anim_time > 0.0 else 10.0
	var clear_t: float = clampf(clear_elapsed / 0.3, 0.0, 1.0)
	var clear_ease: float = _ease_out_cubic(clear_t)
	var clear_scale: float = lerp(0.8, 1.0, clear_ease)
	var clear_alpha: float = clear_ease

	_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.26, 0.21, 0.28, 0.35 * clear_alpha))

	var cx: float = vp.x / 2.0
	var cy: float = vp.y / 2.0
	var w: float = 850.0 * 1.2 * clear_scale
	var h: float = 520.0 * 1.2 * clear_scale
	var x: float = cx - w / 2.0
	var y: float = cy - h / 2.0

	var dlg_rect := Rect2(Vector2(x, y), Vector2(w, h))
	# 白背景・太枠・統一シャドウ
	var dlg_shadow := Vector2(15.0, 15.0)
	_game.draw_rect(Rect2(dlg_rect.position + dlg_shadow, dlg_rect.size), Color(0.26, 0.21, 0.28, 0.25))
	_game.draw_rect(dlg_rect, Color(1.0, 1.0, 1.0, 0.8))
	_game.draw_rect(dlg_rect, Color(0.26, 0.21, 0.28), false, 5.75)

	var tx: float = x + 17
	var tw: float = w - 34

	_game.draw_string(_game.font_din, Vector2(tx, y + 85), tr("CLEAR_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, tw, 68, Color(0.95, 0.19, 0.32))

	# 目標ガイドと実現図形の表示エリア
	var btn_h_val: float = (_game.font.get_ascent(BTN_FONT_SIZE) + _game.font.get_descent(BTN_FONT_SIZE)) * 1.5
	var bottom_pad: float = 24.0 + 50.0 + btn_h_val + 24.0
	var shapes_top: float = y + 110
	var shapes_bottom: float = y + h - bottom_pad
	var shapes_h: float = shapes_bottom - shapes_top
	var shapes_rect := Rect2(x + 24, shapes_top, w - 48, shapes_h)
	_stage_renderer.draw_clear_shapes(shapes_rect)

	# 所要時間・動かした回数・ボタンはポップアップ下部に配置
	var time_y: float = y + h - 24.0 - btn_h_val - 50.0
	_draw_monospace_number(_game.font, Vector2(tx, time_y), tr("CLEAR_TIME") % _game.clear_time, HORIZONTAL_ALIGNMENT_CENTER, tw, 37, Color(0.26, 0.21, 0.28))
	_game.draw_string(_game.font, Vector2(tx, time_y + 34.0), tr("CLEAR_MOVE_COUNT") % _game.stage_move_count, HORIZONTAL_ALIGNMENT_CENTER, tw, 30, Color(0.26, 0.21, 0.28))

	var btn_center := Vector2(x + w / 2.0, y + h - btn_h_val / 2.0 - 18.0)
	_draw_auto_button_with_shadow(btn_center, tr("BTN_NEXT"), BTN_FONT_SIZE, 1.0, false, w * 0.6)


func _draw_results_sidebar_title_fallback(vp: Vector2, bar_w: float, a: float) -> void:
	var kata: String = "KATA"
	var draw_word: String = "DRAW"
	var fs_kata: int = 22
	var fs_draw: int = 18
	var c_kata: Color = Color(0.95, 0.19, 0.32, a)
	var c_draw: Color = Color(0.06, 0.06, 0.08, a)
	var w_k: float = _game.font_bold.get_string_size(kata, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_kata).x
	var gap_block: float = 18.0
	var asc_k: float = _game.font_bold.get_ascent(fs_kata)
	var dsc_k: float = _game.font_bold.get_descent(fs_kata)
	var asc_d: float = _game.font_bold.get_ascent(fs_draw)
	var dsc_d: float = _game.font_bold.get_descent(fs_draw)
	var stack_h: float = asc_k + dsc_k + gap_block + asc_d + dsc_d
	var baseline_k: float = vp.y * 0.5 - stack_h * 0.5 + asc_k
	var baseline_d: float = baseline_k + dsc_k + gap_block + asc_d
	var x_k: float = (bar_w - w_k) * 0.5
	var x_d: float = (bar_w - _game.font_bold.get_string_size(draw_word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_draw).x) * 0.5
	_game.draw_string(_game.font_bold, Vector2(x_k, baseline_k), kata, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_kata, c_kata)
	_game.draw_string(_game.font_bold, Vector2(x_d, baseline_d), draw_word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_draw, c_draw)


func _result_grid_fit_font_size(font: Font, text: String, max_w: float, fs_start: int, fs_min: int) -> int:
	"""セル幅に収まるまでフォントサイズを下げる（秒・回の単位まで含めて表示）"""
	var f: int = fs_start
	while f > fs_min:
		var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, f)
		if sz.x <= max_w:
			return f
		f -= 1
	return fs_min


func _results_logo_scaled_dims(vp: Vector2, bar_w: float) -> Vector2:
	"""リザルト左バー用ロゴの描画サイズ（未回転の w×h）。+90° 回転後の横方向の見かけの幅は h に相当。
	kata-draw_Resultlogo は透過トリム済みを等比でバー幅・縦幅に収める（追加の倍率なし）。"""
	var tex: Texture2D = _game.result_logo_texture
	if tex == null:
		tex = _game.title_logo_texture
	if tex == null:
		return Vector2.ZERO
	var tex_w: float = tex.get_width()
	var tex_h: float = tex.get_height()
	const H_PAD: float = 6.0
	const V_PAD: float = 20.0
	var s: float = minf((bar_w - H_PAD) / maxf(tex_h, 0.001), (vp.y - V_PAD) / maxf(tex_w, 0.001))
	var draw_w: float = s * tex_w
	var draw_h: float = s * tex_h
	return Vector2(draw_w, draw_h)


func _draw_results_sidebar_logo(vp: Vector2, bar_w: float, a: float) -> void:
	"""res://assets/UI/kata-draw_Resultlogo.png を +90° 回転して左バーに配置（無いときはタイトルロゴで代替）"""
	var tex: Texture2D = _game.result_logo_texture
	if tex == null:
		tex = _game.title_logo_texture
	if tex == null:
		_draw_results_sidebar_title_fallback(vp, bar_w, a)
		return
	var dims: Vector2 = _results_logo_scaled_dims(vp, bar_w)
	var draw_w: float = dims.x
	var draw_h: float = dims.y
	if draw_w <= 0.0 or draw_h <= 0.0:
		_draw_results_sidebar_title_fallback(vp, bar_w, a)
		return
	var pos := Vector2((bar_w - draw_w) * 0.5, (vp.y - draw_h) * 0.5)
	var pivot: Vector2 = pos + Vector2(draw_w * 0.5, draw_h * 0.5)
	var rot: float = PI / 2.0
	var xf: Transform2D = Transform2D(0.0, pivot) * Transform2D(rot, Vector2.ZERO) * Transform2D(0.0, -pivot)
	_game.draw_set_transform_matrix(xf)
	_game.draw_texture_rect(tex, Rect2(pos, Vector2(draw_w, draw_h)), false, Color(1.0, 1.0, 1.0, a))
	_game.draw_set_transform_matrix(Transform2D())


func _compute_results_sidebar_width(vp: Vector2) -> float:
	"""ロゴを +90° したときに収まる最小幅（上限は従来どおりビュー幅の割合でクランプ）"""
	const H_PAD: float = 6.0
	const V_PAD: float = 20.0
	var tex: Texture2D = _game.result_logo_texture
	if tex == null:
		tex = _game.title_logo_texture
	if tex == null:
		return 108.0
	var tex_w: float = tex.get_width()
	var tex_h: float = tex.get_height()
	var max_bar: float = clampf(vp.x * 0.22, 140.0, 300.0)
	var s: float = minf((max_bar - H_PAD) / maxf(tex_h, 0.001), (vp.y - V_PAD) / maxf(tex_w, 0.001))
	return s * tex_h + H_PAD


func _compute_results_layout(vp: Vector2) -> Dictionary:
	"""Result 画面のブロック位置・NEXT 座標（描画とヒット判定で共通）"""
	const RESULTS_MARGIN: float = 20.0
	const TOP_Y: float = 32.0
	const BLOCK_W_RATIO: float = 0.8
	const GAP_GRID_TOTAL: float = 14.0
	var sidebar_w: float = _compute_results_sidebar_width(vp)
	var content_x0: float = sidebar_w + RESULTS_MARGIN
	var content_w: float = vp.x - content_x0 - RESULTS_MARGIN
	var block_w: float = content_w * BLOCK_W_RATIO
	var block_x: float = content_x0
	var btn_res_h: float = 120.0
	var next_s: float = 88.0
	var grid_top: float = TOP_Y + _game.font_din.get_ascent(RESULT_SCREEN_TITLE_FS) + _game.font_din.get_descent(RESULT_SCREEN_TITLE_FS) + 28.0
	var bottom_reserve: float = btn_res_h + RESULTS_MARGIN * 2.0 + GAP_GRID_TOTAL
	var grid_h: float = maxf(160.0, vp.y - grid_top - bottom_reserve)
	var total_bar_y: float = grid_top + grid_h + GAP_GRID_TOTAL
	var gap_x0: float = block_x + block_w
	var gap_w: float = content_w - block_w
	var btn_cx: float = gap_x0 + gap_w * 0.5
	var btn_cy: float = total_bar_y + btn_res_h * 0.5 + 10.0
	return {
		"content_x0": content_x0,
		"content_w": content_w,
		"block_x": block_x,
		"block_w": block_w,
		"grid_top": grid_top,
		"grid_h": grid_h,
		"total_bar_y": total_bar_y,
		"btn_res_h": btn_res_h,
		"next_cx": btn_cx,
		"next_cy": btn_cy,
		"next_s": next_s,
	}


func get_results_next_button_rect(vp: Vector2) -> Rect2:
	var lay: Dictionary = _compute_results_layout(vp)
	var s: float = lay["next_s"]
	var cx: float = lay["next_cx"]
	var cy: float = lay["next_cy"]
	return Rect2(cx - s * 0.5, cy - s * 0.5, s, s)


func _draw_results_title_justified(block_x: float, top_y: float, span_w: float, fs: int, color: Color) -> void:
	"""メイングリッド左端〜右端に RESULT_TITLE を字間均等で収める（カーニング込みの累進幅で字送り）"""
	var font: Font = _game.font_din
	var text: String = tr("RESULT_TITLE")
	var n: int = text.length()
	if n == 0:
		return
	var total_adv: float = 0.0
	var advances: Array = []
	for i in range(n):
		var w0: float = font.get_string_size(text.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w1: float = font.get_string_size(text.substr(0, i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		advances.append(w1 - w0)
		total_adv += advances[i]
	var gap_extra: float = 0.0
	if n > 1:
		gap_extra = (span_w - total_adv) / float(n - 1)
	var x: float = block_x
	var baseline_y: float = top_y + font.get_ascent(fs)
	for i in range(n):
		var ch: String = text.substr(i, 1)
		_game.draw_string(font, Vector2(x, baseline_y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
		x += advances[i]
		if i < n - 1:
			x += gap_extra


func _draw_results(vp: Vector2) -> void:
	_draw_bg(vp)

	var fade_t: float = 1.0
	if _results_anim_time >= 0.0:
		fade_t = clampf((Time.get_ticks_msec() / 1000.0 - _results_anim_time) / RESULTS_SLIDE_DURATION, 0.0, 1.0)
	var fade_ease: float = _ease_out_cubic(fade_t)
	var a: float = fade_ease

	var lay: Dictionary = _compute_results_layout(vp)
	var RESULTS_SIDEBAR_W: float = _compute_results_sidebar_width(vp)
	var content_x0: float = lay["content_x0"]
	var content_w: float = lay["content_w"]
	var block_x: float = lay["block_x"]
	var block_w: float = lay["block_w"]
	var grid_top: float = lay["grid_top"]
	var grid_h: float = lay["grid_h"]
	var total_bar_y: float = lay["total_bar_y"]
	var btn_res_h: float = lay["btn_res_h"]
	var next_cx: float = lay["next_cx"]
	var next_cy: float = lay["next_cy"]
	var next_s: float = lay["next_s"]

	var c_text: Color = Color(0.26, 0.21, 0.28, a)
	var c_red: Color = Color(0.95, 0.19, 0.32, a)
	var c_blue_tint: Color = Color(0.72, 0.84, 0.94, a)
	var c_beige_mix: Color = Color(0.96, 0.93, 0.86, a)
	var c_white_mix: Color = Color(1.0, 1.0, 1.0, a)
	var c_sidebar_bg: Color = Color(
		c_blue_tint.r * 0.05 + c_beige_mix.r * 0.6 + c_white_mix.r * 0.35,
		c_blue_tint.g * 0.05 + c_beige_mix.g * 0.6 + c_white_mix.g * 0.35,
		c_blue_tint.b * 0.05 + c_beige_mix.b * 0.6 + c_white_mix.b * 0.35,
		a
	)
	var c_total_label_bg: Color = Color(0.42, 0.35, 0.58, a)

	_game.draw_rect(Rect2(0, 0, RESULTS_SIDEBAR_W, vp.y), c_sidebar_bg)
	_draw_results_sidebar_logo(vp, RESULTS_SIDEBAR_W, a)

	var top_y: float = 32.0
	var title_fs: int = RESULT_SCREEN_TITLE_FS
	_draw_results_title_justified(block_x, top_y, block_w, title_fs, c_red)

	var n_stages: int = _game.stage_times.size()
	var row_h: float = grid_h / 5.0
	var col_gap: float = 14.0
	var col_w: float = (block_w - col_gap) * 0.5
	const GRID_BORDER_W: float = 1.75 * 3.0
	const CELL_BORDER_W: float = 1.25 * 3.0
	var stat_fs: int = mini(76, maxi(24, int(19 * 4)))
	stat_fs = mini(stat_fs, int(row_h * 0.42))
	stat_fs = maxi(1, int(round(float(stat_fs) * 0.9 * 0.82)))
	var grid_frame := Rect2(block_x, grid_top, block_w, grid_h)
	_game.draw_rect(grid_frame, Color(1.0, 1.0, 1.0, 0.97 * a))
	_game.draw_rect(grid_frame, Color(0.12, 0.1, 0.14, 0.55 * a), false, GRID_BORDER_W)

	for row in range(5):
		for col in range(2):
			var idx: int = row + col * 5
			var cx: float = block_x + float(col) * (col_w + col_gap)
			var cy: float = grid_top + float(row) * row_h
			var cell_rect := Rect2(cx, cy, col_w, row_h - 6.0)
			if idx >= n_stages:
				_game.draw_rect(cell_rect, Color(1.0, 1.0, 1.0, 0.05 * a))
				_game.draw_rect(cell_rect, Color(0.26, 0.21, 0.28, 0.2 * a), false, CELL_BORDER_W)
				continue
			var cw: float = cell_rect.size.x
			var ch: float = cell_rect.size.y
			var pad: float = 4.0
			var thumb_col_w: float = cw * 0.36
			var mid_col_w: float = cw * 0.32
			var right_col_w: float = cw - thumb_col_w - mid_col_w - pad * 2.0
			var side: float = minf(thumb_col_w - pad * 2.0, ch - pad * 2.0)
			var thumb_x: float = cell_rect.position.x + (thumb_col_w - side) * 0.5
			var thumb_y: float = cell_rect.position.y + (ch - side) * 0.5
			var thumb_rect := Rect2(thumb_x, thumb_y, side, side)
			var shape_dat: Dictionary = {}
			if idx < _game.stage_result_shapes.size():
				shape_dat = _game.stage_result_shapes[idx] as Dictionary
			var ideal_l: Array = shape_dat.get("ideal", [])
			var player_l: Array = shape_dat.get("player", [])
			if not ideal_l.is_empty() or not player_l.is_empty():
				_stage_renderer.draw_result_thumbnail(thumb_rect, ideal_l, player_l)
			else:
				_game.draw_rect(thumb_rect, Color(1.0, 1.0, 1.0, 0.1 * a))
			var t_s: float = _game.stage_times[idx]
			var mv: int = _game.stage_move_counts[idx] if idx < _game.stage_move_counts.size() else 0
			var time_str: String = tr("RESULT_TIME_UNIT") % t_s
			var move_str: String = tr("RESULT_MOVE_UNIT") % mv
			var mid_x: float = cell_rect.position.x + thumb_col_w + pad
			var right_x: float = mid_x + mid_col_w + pad
			var fs_t: int = _result_grid_fit_font_size(_game.font, time_str, mid_col_w * 0.97, stat_fs, 8)
			var fs_m: int = _result_grid_fit_font_size(_game.font, move_str, right_col_w * 0.97, stat_fs, 8)
			var fs_cell: int = mini(fs_t, fs_m)
			var row_baseline: float = cell_rect.position.y + (ch + _game.font.get_ascent(fs_cell) - _game.font.get_descent(fs_cell)) * 0.5
			_game.draw_string(_game.font, Vector2(mid_x, row_baseline), time_str, HORIZONTAL_ALIGNMENT_CENTER, mid_col_w, fs_cell, c_text)
			_game.draw_string(_game.font, Vector2(right_x, row_baseline), move_str, HORIZONTAL_ALIGNMENT_CENTER, right_col_w, fs_cell, c_text)

	const TOTAL_BORDER_W: float = 2.0 * 3.0
	var total_bar_rect := Rect2(block_x, total_bar_y, block_w, btn_res_h)
	_game.draw_rect(total_bar_rect, Color(1.0, 1.0, 1.0, 0.96 * a))
	_game.draw_rect(total_bar_rect, Color(0.26, 0.21, 0.28, 0.35 * a), false, TOTAL_BORDER_W)
	var total_label_w: float = minf(160.0 * 2.0, block_w * 0.22 * 2.0)
	total_label_w = minf(total_label_w, block_w * 0.48 - 8.0)
	var tl_rect := Rect2(total_bar_rect.position, Vector2(total_label_w, btn_res_h))
	_game.draw_rect(tl_rect, c_total_label_bg)
	var total_lbl_fs: int = RESULT_TOTAL_LABEL_FS
	var total_lbl_y: float = tl_rect.position.y + (btn_res_h + _game.font_bold.get_ascent(total_lbl_fs) - _game.font_bold.get_descent(total_lbl_fs)) * 0.5
	_game.draw_string(_game.font_bold, Vector2(tl_rect.position.x, total_lbl_y), tr("RESULT_TOTAL"), HORIZONTAL_ALIGNMENT_CENTER, total_label_w, total_lbl_fs, Color(1.0, 1.0, 1.0, a))

	var total_time: float = 0.0
	for t in _game.stage_times:
		total_time += t
	var total_moves: int = 0
	for m in _game.stage_move_counts:
		total_moves += m
	var tot_area_x: float = total_bar_rect.position.x + total_label_w + 12.0
	var tot_area_w: float = total_bar_rect.position.x + total_bar_rect.size.x - tot_area_x - 12.0
	var tot_time_str: String = tr("RESULT_TIME_UNIT") % total_time
	var tot_move_str: String = tr("RESULT_MOVE_UNIT") % total_moves
	var fs_tim: int = 28 * 2
	var fs_mov: int = 28 * 2
	fs_tim = mini(fs_tim, int(btn_res_h * 0.55))
	fs_mov = fs_tim
	var half_val: float = tot_area_w * 0.5
	var bl_tot: float = total_bar_rect.position.y + (btn_res_h + _game.font.get_ascent(fs_tim) - _game.font.get_descent(fs_tim)) * 0.5
	_game.draw_string(_game.font, Vector2(tot_area_x, bl_tot), tot_time_str, HORIZONTAL_ALIGNMENT_CENTER, half_val - 4.0, fs_tim, c_red)
	_game.draw_string(_game.font, Vector2(tot_area_x + half_val, bl_tot), tot_move_str, HORIZONTAL_ALIGNMENT_CENTER, half_val - 4.0, fs_mov, c_red)

	_draw_results_next_button(Vector2(next_cx, next_cy), tr("RESULT_BTN_NEXT"), 26, a, next_s)


func _results_rect_perimeter_point(r: Rect2, dist: float) -> Vector2:
	"""矩形の周上を時計回り（上辺左→右、右辺上→下、…）。dist は周長上の距離"""
	var w: float = r.size.x
	var h: float = r.size.y
	var x0: float = r.position.x
	var y0: float = r.position.y
	var per: float = 2.0 * w + 2.0 * h
	var d: float = fmod(dist, per)
	if d < 0.0:
		d += per
	if d < w:
		return Vector2(x0 + d, y0)
	d -= w
	if d < h:
		return Vector2(x0 + w, y0 + d)
	d -= w
	if d < w:
		return Vector2(x0 + w - d, y0 + h)
	d -= h
	return Vector2(x0, y0 + h - d)


func _draw_results_next_button(center: Vector2, text: String, fs: int, alpha: float, side: float = 88.0) -> void:
	"""Result 専用: 正方形・太枠・黒文字・枠上を移動する ●"""
	var btn_w: float = side
	var btn_h: float = side
	var btn_id: String = text
	set_btn_hover(btn_id)
	var sc: float = get_btn_scale(btn_id)
	if _btn_press_timers.has(btn_id) and _btn_press_timers[btn_id] >= 0.0:
		var press_t: float = _ease_in_out_cubic(_btn_press_timers[btn_id])
		alpha *= (1.0 - press_t)
	var draw_w: float = btn_w * sc
	var draw_h: float = btn_h * sc
	if sc < 0.001 or alpha < 0.001:
		return
	var rect := Rect2(center.x - draw_w * 0.5, center.y - draw_h * 0.5, draw_w, draw_h)
	const LINE_W: float = 2.0 * 3.0
	_game.draw_rect(rect, Color(1.0, 0.99, 0.97, alpha))
	_game.draw_rect(rect, Color(0.12, 0.12, 0.14, alpha), false, LINE_W)
	# 枠線は rect の辺を中心に描かれるため、● の中心も同じ周辺（rect の周長）上に乗せる
	var per: float = 2.0 * rect.size.x + 2.0 * rect.size.y
	var t_sec: float = Time.get_ticks_msec() / 1000.0
	var dist: float = fmod(t_sec * 88.0, per)
	var dot_center: Vector2 = _results_rect_perimeter_point(rect, dist)
	var dot_r: float = LINE_W * 2.0
	_game.draw_circle(dot_center, dot_r, Color(0.12, 0.12, 0.14, alpha))
	var ascent: float = _game.font.get_ascent(fs)
	var descent: float = _game.font.get_descent(fs)
	var baseline_y: float = rect.position.y + (draw_h + ascent - descent) * 0.5
	_game.draw_string(_game.font, Vector2(rect.position.x, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, draw_w, fs, Color(0.2, 0.2, 0.22, alpha))


func _draw_pause_overlay(vp: Vector2) -> void:
	var ui_w: float = vp.x * GameConfig.UI_WIDTH_RATIO
	var play_w: float = vp.x - ui_w
	var play_rect := Rect2(ui_w, 0.0, play_w, vp.y)
	var play_cx: float = ui_w + play_w / 2.0
	var play_cy: float = vp.y / 2.0

	# ポーズ開閉アニメーション（開: 0.2秒、閉: 0.15秒）
	var pause_elapsed: float = Time.get_ticks_msec() / 1000.0 - _pause_anim_time if _pause_anim_time > 0.0 else 10.0
	var pause_dur: float = 0.15 if _pause_closing else 0.2
	var pause_t: float = clampf(pause_elapsed / pause_dur, 0.0, 1.0)
	var pause_ease: float = _ease_out_cubic(pause_t)
	var pause_alpha: float = pause_ease if not _pause_closing else 1.0 - pause_ease
	var pause_scale: float = lerp(0.95, 1.0, pause_ease) if not _pause_closing else lerp(1.0, 0.95, pause_ease)

	# インゲーム領域のみ暗転（左UIにはかぶらない）
	_game.draw_rect(play_rect, Color(0.26, 0.21, 0.28, 0.50 * pause_alpha))

	if _game.pause_confirm_title:
		# 確認ダイアログ（白背景、大きめ、ボタン幅広）
		var dlg_w: float = 640.0
		var dlg_h: float = 260.0
		var dlg_rect := Rect2(Vector2(play_cx - dlg_w / 2.0, play_cy - dlg_h / 2.0), Vector2(dlg_w, dlg_h))
		# 白背景で描画
		var dlg_shadow := Vector2(15.0, 15.0)
		_game.draw_rect(Rect2(dlg_rect.position + dlg_shadow, dlg_rect.size), Color(0.26, 0.21, 0.28, 0.25))
		_game.draw_rect(dlg_rect, Color(1.0, 1.0, 1.0))
		_game.draw_rect(dlg_rect, Color(0.26, 0.21, 0.28), false, 5.75)
		# テキスト（Bold、大きめ）
		_game.draw_string(_game.font_bold, Vector2(play_cx - dlg_w / 2.0, play_cy - 45.0), tr("PAUSE_CONFIRM_MSG"), HORIZONTAL_ALIGNMENT_CENTER, dlg_w, 42, Color(0.95, 0.19, 0.32))
		# ボタン（幅広、間隔広め）
		var cbtn_w: float = 220.0
		var cbtn_gap: float = cbtn_w / 2.0 + 30.0
		var cbtn_cy: float = play_cy + 50.0
		var yes_off: bool = _game.pause_confirm_index != 0
		var no_off: bool = _game.pause_confirm_index != 1
		_draw_auto_button_with_shadow(Vector2(play_cx - cbtn_gap, cbtn_cy), tr("PAUSE_CONFIRM_YES"), BTN_FONT_SIZE, 1.0, yes_off, cbtn_w)
		_draw_auto_button_with_shadow(Vector2(play_cx + cbtn_gap, cbtn_cy), tr("PAUSE_CONFIRM_NO"), BTN_FONT_SIZE, 1.0, no_off, cbtn_w)
	else:
		# メイン: パネル90%縮小、インゲーム領域中央配置
		var ps: float = 0.9  # パネルスケール
		var full_w: float = play_w - 48.0
		var full_h: float = vp.y - 48.0
		var panel_w: float = full_w * ps
		var panel_h: float = full_h * ps
		var panel_x: float = play_rect.position.x + (play_w - panel_w) / 2.0
		var panel_y: float = (vp.y - panel_h) / 2.0
		var panel_rect := Rect2(Vector2(panel_x, panel_y), Vector2(panel_w, panel_h))
		# パネル背景を白(#ffffff)で描画
		var shadow_offset := Vector2(15.0, 15.0)
		_game.draw_rect(Rect2(panel_rect.position + shadow_offset, panel_rect.size), Color(0.26, 0.21, 0.28, 0.25))
		_game.draw_rect(panel_rect, Color(1.0, 1.0, 1.0))
		_game.draw_rect(panel_rect, Color(0.26, 0.21, 0.28), false, 3.45)

		# 上部: 操作ガイド（90%スケール）
		var controls_top_y: float = panel_rect.position.y + 40.0 * ps + 50.0 * ps
		var controls_bottom_y: float = _draw_controls_stacked_in_panel(panel_rect, controls_top_y, ps)

		# 下部: [とじる][やりなおす][タイトルへ] — 同一サイズで横並び
		var btn_w: float = panel_w * 0.27
		var btn_gap: float = panel_w * 0.03
		var base_cy: float = panel_rect.end.y - 56.0 * ps - 50.0 * ps
		var labels: Array[String] = [tr("PAUSE_CLOSE"), tr("PAUSE_RETRY"), tr("PAUSE_TITLE")]
		var total_w: float = btn_w * 3.0 + btn_gap * 2.0
		var btn_start_x: float = play_cx - total_w / 2.0 + btn_w / 2.0
		for i in range(3):
			var bcx: float = btn_start_x + i * (btn_w + btn_gap)
			var sel: bool = (i == _game.pause_index)
			var is_off: bool = not sel
			_draw_auto_button_with_shadow(Vector2(bcx, base_cy), labels[i], BTN_FONT_SIZE, 1.0, is_off, btn_w)

		# 中央: ステージのお手本（操作ガイド下端とボタン上端の中間）
		var btn_top: float = base_cy - (_game.font.get_ascent(BTN_FONT_SIZE) + _game.font.get_descent(BTN_FONT_SIZE)) * 1.5 / 2.0
		var shape_available_h: float = btn_top - controls_bottom_y
		var shape_available_w: float = panel_w * 0.9
		var shape_cy: float = controls_bottom_y + shape_available_h / 2.0
		_stage_renderer.draw_guide_shape_side_by_side(Vector2(play_cx, shape_cy), shape_available_w, shape_available_h, 1.0, 2.5)


func _draw_particles() -> void:
	if particles.is_empty():
		return
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - particle_spawn_time
	var t: float = clampf(elapsed / PARTICLE_LIFETIME, 0.0, 1.0)
	var alpha: float = 1.0 - t * t
	for p in particles:
		var c: Color = p["color"] as Color
		c.a = alpha
		var sz: float = (p["size"] as float) * (1.0 - t * 0.5)
		_game.draw_circle(p["pos"] as Vector2, sz, c)


# =============================================================================
# Drawing - Utilities (ring, star, bounding box, crossfade)
# =============================================================================

func _crossfade_alpha() -> float:
	var t: float = Time.get_ticks_msec() / 1000.0
	var cycle: float = fmod(t, 2.7)
	if cycle < 2.0:
		return 1.0
	var fade_t: float = (cycle - 2.0) / 0.7
	return 1.0 - sin(fade_t * PI)


func _draw_bounding_box() -> void:
	if _game.selected_indices.size() < 2 or _game.is_dragging:
		return
	var r: Rect2 = _game.input_handler.get_bb_rect()
	if r.size.x < 1.0 and r.size.y < 1.0:
		return
	var bb_color := Color(0.95, 0.19, 0.32, 1.0)
	_game.draw_rect(r, bb_color, false, 3.0)
	var anchors: Array[Vector2] = _game.input_handler.get_bb_anchors(r)
	var anchor_fill := Color(1.0, 0.937, 0.89, 1.0)
	var anchor_border := Color(0.95, 0.19, 0.32, 1.0)
	for a in anchors:
		var ar: Rect2 = Rect2(a - Vector2(InputHandler.BB_ANCHOR_SIZE, InputHandler.BB_ANCHOR_SIZE) * 0.5, Vector2(InputHandler.BB_ANCHOR_SIZE, InputHandler.BB_ANCHOR_SIZE))
		_game.draw_rect(ar, anchor_fill)
		_game.draw_rect(ar, anchor_border, false, 3.0)
	var center: Vector2 = r.position + r.size * 0.5
	var s: float = InputHandler.BB_CENTER_SIZE
	var diamond: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -s),
		center + Vector2(s, 0),
		center + Vector2(0, s),
		center + Vector2(-s, 0),
	])
	_game.draw_colored_polygon(diamond, anchor_fill)
	_game.draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), anchor_border, 3.0, true)
