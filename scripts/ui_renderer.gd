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

# --- Title Intro Animation ---
var _title_intro_time: float = -1.0   # タイトルイントロ開始時刻
var _title_intro_skip: bool = false    # スキップ中
var _title_intro_skip_time: float = -1.0  # スキップ開始時刻
const TITLE_INTRO_SKIP_FADE := 1.0    # スキップ時のクロスフェード秒数

# フェーズタイミング（秒、後から調整しやすいよう定数化）
const TI_PHASE0_DUR := 1.7   # No.0: 最初の点が出現（0.5秒で縮小 + 1.2秒待機）
const TI_PHASE1_DUR := 6.0   # No.1: 点が線を描きKを形成
const TI_PHASE2_DUR := 1.0   # No.2: 右上端が白点に変化
const TI_PHASE3_DUR := 1.0   # No.3: 白点が右上へ変形
const TI_PHASE4_DUR := 1.0   # No.4: Kが左上に移動
const TI_PHASE5_DUR := 3.5   # No.5: ATA-DRAWスライドイン
const TI_PHASE6_DUR := 0.7   # No.6: ロゴ完成状態で静止
const TI_PHASE7_DUR := 0.5   # No.7: タイトル画面へクロスフェード
const TI_TOTAL_DUR := 15.4   # 合計
const TI_DOT_APPEAR_DUR := 0.5  # 点出現アニメーション（5000%→100%縮小）

# Kの12頂点（K中心を原点とした相対座標）
# ロゴSVGパスデータから正確に算出。中心=(965.99, 527.00)で原点化。
# アルファベットKの外周（アウトライン）を一筆書きで描く閉じたポリゴン。
# 交差する線は無く、12辺で構成される単純な閉路。
#
#   V10 --- V11
#    |        |
#    |        V0        V1 -- V2 (白点)
#    |          \      /
#    |           V3 ←─┘
#    |          /
#    |        V6
#    |         \
#    |          V7
#    |          |       V5 -- V4
#    |          V8        \  /
#    |          |          \/
#   V9 ------- +    (V8=V9のx差=44.3)
#
# 描画順（一筆書き）:
#  V0→V1 斜め右上 → V1→V2 水平右 → V2→V3 斜め左下
#  V3→V4 斜め右下 → V4→V5 水平左 → V5→V6 斜め左上
#  V6→V7 斜め左下(最短) → V7→V8 真下 → V8→V9 水平左
#  V9→V10 真上 → V10→V11 水平右 → V11→V0 真下
#
var K_VERTICES: Array = [
	Vector2(-22, -43),    # V0:  バー右辺・上腕下辺の始点（ジャンクション上）
	Vector2(10, -150),    # V1:  上腕先端・左端
	Vector2(84, -175),    # V2:  上腕先端・右端（白点）※変形後の最終位置
	Vector2(18, -26),     # V3:  ジャンクション中央・上腕上辺の終点
	Vector2(66, 150),     # V4:  下腕先端・右端
	Vector2(16, 150),     # V5:  下腕先端・左端
	Vector2(-11, 39),     # V6:  ジャンクション中央・下腕下辺の終点
	Vector2(-22, 75),     # V7:  バー右辺・ジャンクション下
	Vector2(-22, 150),    # V8:  バー右下
	Vector2(-66, 150),    # V9:  バー左下
	Vector2(-66, -150),   # V10: バー左上
	Vector2(-22, -150),   # V11: バー右上
]

# 白点インデックス（上腕右先端）
const K_WHITE_DOT_IDX := 2

# Kの辺（閉じたポリゴンの12辺、順番に接続）
var K_EDGES: Array = [
	[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6],
	[6, 7], [7, 8], [8, 9], [9, 10], [10, 11], [11, 0],
]

# 白点の変形前位置（初期K描画時の位置、Phase 5でK_VERTICES[2]へ移動）
var K_P2_INITIAL := Vector2(59, -150)

# 描画パス（一筆書き: V0→V1→...→V11→V0）
var K_DRAW_PATH: Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0]

# SE用トラッキング
var _ti_prev_visited_count: int = 0
var _ti_move_playing: bool = false
var _ti_catch_played: bool = false
var _ti_point_played: bool = false  # Phase0: stageclear SE再生済み
var _ti_dot_landed: bool = false    # Phase0: 縮小完了時point SE再生済み
var _ti_motion_played: bool = false  # Phase5: motion.mp3再生済み
const TI_MOTION_FADE_DUR := 1.5  # motion.mp3のフェードアウト秒数

# --- game 参照 (Node2D/CanvasItem) ---
var _game: Node2D
var _stage_renderer: StageRenderer


func _init(game: Node2D) -> void:
	_game = game
	_stage_renderer = StageRenderer.new(game, self)


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
		_title_intro_time = Time.get_ticks_msec() / 1000.0
		_title_intro_skip = false
		_title_intro_skip_time = -1.0
		_ti_prev_visited_count = 0
		_ti_move_playing = false
		_ti_catch_played = false
		_ti_point_played = false
		_ti_dot_landed = false
		_ti_motion_played = false
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
			_draw_title_intro(vp)
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

	# 画面遷移フェードオーバーレイ
	if _transition_alpha < 1.0:
		var fade_a: float = 1.0 - _transition_alpha
		_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(_game.BG_COLOR.r, _game.BG_COLOR.g, _game.BG_COLOR.b, fade_a))


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
# Title Intro Animation (No.1-8)
# =============================================================================

func start_title_intro_skip() -> void:
	if _title_intro_skip:
		return
	_title_intro_skip = true
	_title_intro_skip_time = Time.get_ticks_msec() / 1000.0

func is_title_intro_done() -> bool:
	if _title_intro_time < 0.0:
		return true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _title_intro_time
	return elapsed >= TI_TOTAL_DUR

func is_title_intro_skip_done() -> bool:
	if not _title_intro_skip or _title_intro_skip_time < 0.0:
		return false
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _title_intro_skip_time
	return elapsed >= TITLE_INTRO_SKIP_FADE


func _get_k_center_screen(vp: Vector2) -> Vector2:
	"""Phase 1-5: K描画時の画面中央位置"""
	return Vector2(vp.x / 2.0, vp.y / 2.0)


func _get_k_logo_position(vp: Vector2) -> Dictionary:
	"""Phase 6以降: Kがロゴ位置に移動した後の中心とスケール"""
	var draw_w: float = vp.x * 0.85 * 1.2
	var tex_w: float = 1456.0  # ロゴ画像のサイズ
	var tex_h: float = 816.0
	var scale_f: float = draw_w / tex_w
	var draw_h: float = tex_h * scale_f
	var logo_cy: float = vp.y * 0.38 * 0.8
	var logo_pos := Vector2((vp.x - draw_w) / 2.0, logo_cy - draw_h / 2.0)
	# K部分のロゴ画像内での中心（ピクセル座標、拡大画像から計測）
	# x: 195→265 に補正（完成ロゴとの位置ズレを解消: +128-58=+70）
	var k_img_center := Vector2(275.0, 408.0)
	var k_screen_center := logo_pos + k_img_center * scale_f
	# K_VERTICESの座標単位 → ロゴ画像ピクセルへのスケール
	# 描画時100%に対し完成ロゴは91%サイズなので、0.91倍に縮小
	var k_scale: float = scale_f * 0.91
	return {"center": k_screen_center, "scale": k_scale}


func _get_k_draw_scale(vp: Vector2) -> float:
	"""Phase 1-5: 画面中央でのKの描画スケール（Kが画面の45%程度に収まるサイズ）"""
	var target_h: float = vp.y * 0.45
	var k_raw_h: float = 325.0  # K_VERTICESのY範囲（-175〜150、変形含む）
	return target_h / k_raw_h


func _draw_title_intro(vp: Vector2) -> void:
	# 背景（本編と同じBG画像を使用）
	_draw_bg(vp)

	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - _title_intro_time

	# スキップ中のクロスフェード
	var skip_alpha: float = 0.0
	if _title_intro_skip:
		var skip_elapsed: float = now - _title_intro_skip_time
		skip_alpha = clampf(skip_elapsed / TITLE_INTRO_SKIP_FADE, 0.0, 1.0)

	# フェーズ判定
	var phase0_end: float = TI_PHASE0_DUR
	var phase1_end: float = phase0_end + TI_PHASE1_DUR
	var phase2_end: float = phase1_end + TI_PHASE2_DUR
	var phase3_end: float = phase2_end + TI_PHASE3_DUR
	var phase4_end: float = phase3_end + TI_PHASE4_DUR
	var phase5_end: float = phase4_end + TI_PHASE5_DUR
	var phase6_end: float = phase5_end + TI_PHASE6_DUR
	var phase7_end: float = phase6_end + TI_PHASE7_DUR

	if not _title_intro_skip:
		# Phase 0: 最初の点が出現（5000%→100%に縮小、透明→不透明）
		if elapsed < phase0_end:
			_draw_ti_dot_appear(vp, elapsed)
			# SE: 冒頭にui_point
			if not _ti_point_played:
				_game._play_sfx(_game.sfx_point)
				_ti_point_played = true
		# Phase 1: K描画アニメーション
		elif elapsed < phase1_end:
			_draw_ti_k_drawing(vp, (elapsed - phase0_end) / TI_PHASE1_DUR)
			# SE: 線描画中はsfx_moveをループ再生（途切れたら再開）
			_game._start_sfx_move()
			_ti_move_playing = true
		# Phase 2: 白点変化
		elif elapsed < phase2_end:
			_draw_ti_k_white_dot(vp, (elapsed - phase1_end) / TI_PHASE2_DUR)
			# SE: 描画完了、moveを停止
			if _ti_move_playing:
				_game._stop_sfx_move()
				_ti_move_playing = false
		# Phase 3: 白点変形
		elif elapsed < phase3_end:
			_draw_ti_k_deform(vp, (elapsed - phase2_end) / TI_PHASE3_DUR)
			# SE: キャッチ音 + ドラッグ音
			if not _ti_catch_played:
				_game._play_sfx(_game.sfx_catch)
				_ti_catch_played = true
			if not _ti_move_playing:
				_game._start_sfx_move()
				_ti_move_playing = true
		# Phase 4: K移動
		elif elapsed < phase4_end:
			_draw_ti_k_move(vp, (elapsed - phase3_end) / TI_PHASE4_DUR)
			if _ti_move_playing:
				_game._stop_sfx_move()
				_ti_move_playing = false
		# Phase 5: ATA-DRAWスライドイン
		elif elapsed < phase5_end:
			var phase5_t: float = (elapsed - phase4_end) / TI_PHASE5_DUR
			_draw_ti_logo_reveal(vp, phase5_t)
			# SE: motion.mp3 再生開始
			if not _ti_motion_played:
				_game._play_sfx(_game.sfx_motion)
				_ti_motion_played = true
			# フェードアウト: Phase5終了の1.0秒前から音量を下げる
			var remaining: float = phase5_end - elapsed
			if remaining < TI_MOTION_FADE_DUR and _game.sfx_motion.playing:
				var fade_t: float = remaining / TI_MOTION_FADE_DUR  # 1.0→0.0
				_game.sfx_motion.volume_db = -14.5 + linear_to_db(maxf(fade_t, 0.001))
		# Phase 6: ロゴ完成状態で静止（1.5秒）
		elif elapsed < phase6_end:
			_draw_ti_logo_reveal(vp, 1.0)
			# motion.mp3 停止
			if _game.sfx_motion.playing:
				_game.sfx_motion.stop()
		# Phase 7: タイトル画面へクロスフェード
		elif elapsed < phase7_end:
			_draw_ti_logo_reveal(vp, 1.0)
			var fade_t: float = (elapsed - phase6_end) / TI_PHASE7_DUR
			suppress_hover_sfx(0.5)  # クロスフェード中のホバーSE抑制
			_draw_title_content(vp, _ease_in_out_cubic(fade_t))
		# Phase 8: 完了（タイトル画面）
		else:
			_draw_ti_logo_reveal(vp, 1.0)
			_draw_title_content(vp, 1.0)

	# スキップ時クロスフェード: タイトル画面を重ねてフェードイン
	if _title_intro_skip:
		# SE停止
		if _ti_move_playing:
			_game._stop_sfx_move()
			_ti_move_playing = false
		if _game.sfx_motion.playing:
			_game.sfx_motion.stop()
		# 裏でイントロ最終フレームを描画
		_draw_ti_logo_reveal(vp, 1.0)
		# タイトル画面をフェードインで重ねる
		_draw_title_content(vp, skip_alpha)


func _get_k_vertex(idx: int, deform_t: float = 0.0) -> Vector2:
	"""頂点位置を取得（白点P2は変形前後を補間）"""
	if idx == K_WHITE_DOT_IDX:
		return K_P2_INITIAL.lerp(K_VERTICES[K_WHITE_DOT_IDX], deform_t)
	return K_VERTICES[idx]


func _draw_ti_dot_appear(vp: Vector2, elapsed: float) -> void:
	"""Phase 0: 最初の点が出現（1000%→100%に縮小、透明→不透明、0.5秒）"""
	var center: Vector2 = _get_k_center_screen(vp)
	var sc: float = _get_k_draw_scale(vp)
	# 描画開始点（K_DRAW_PATH[0] = V0）の位置
	var dot_pos: Vector2 = center + _get_k_vertex(K_DRAW_PATH[0]) * sc
	var dot_radius: float = 7.0
	var dot_color := Color(0.26, 0.21, 0.28)

	var anim_t: float = clampf(elapsed / TI_DOT_APPEAR_DUR, 0.0, 1.0)
	var eased: float = _ease_in_out_cubic(anim_t)
	# スケール: 50.0（5000%）→ 1.0（100%）
	var scale_mul: float = lerpf(50.0, 1.0, eased)
	# 透明度: 0.0 → 1.0
	var alpha: float = eased

	var draw_color := Color(dot_color.r, dot_color.g, dot_color.b, alpha)
	_game.draw_circle(dot_pos, dot_radius * scale_mul, draw_color)


func _draw_ti_k_drawing(vp: Vector2, t: float) -> void:
	"""Phase 1: 点と線でKを描画するアニメーション"""
	var center: Vector2 = _get_k_center_screen(vp)
	var sc: float = _get_k_draw_scale(vp)
	var path_count: int = K_DRAW_PATH.size() - 1  # セグメント数 = 14
	var progress: float = t * path_count  # 0.0 〜 14.0
	var current_seg: int = mini(int(progress), path_count - 1)
	var seg_t: float = clampf(progress - current_seg, 0.0, 1.0)

	var dot_color := Color(0.26, 0.21, 0.28)
	var line_color := Color(0.26, 0.21, 0.28)
	var dot_radius: float = 7.0
	var line_width: float = 3.0

	# 描画済みの辺を収集
	var drawn_edges: Dictionary = {}
	for s in range(current_seg):
		var a: int = K_DRAW_PATH[s]
		var b: int = K_DRAW_PATH[s + 1]
		var key: String = str(mini(a, b)) + "_" + str(maxi(a, b))
		drawn_edges[key] = true

	# 完了した辺を描画
	for key in drawn_edges:
		var parts: PackedStringArray = key.split("_")
		var a: int = int(parts[0])
		var b: int = int(parts[1])
		var pa: Vector2 = center + _get_k_vertex(a) * sc
		var pb: Vector2 = center + _get_k_vertex(b) * sc
		_game.draw_line(pa, pb, line_color, line_width, true)

	# 現在描画中のセグメント（部分的な線）
	var seg_a: int = K_DRAW_PATH[current_seg]
	var seg_b: int = K_DRAW_PATH[current_seg + 1]
	var pa: Vector2 = center + _get_k_vertex(seg_a) * sc
	var pb: Vector2 = center + _get_k_vertex(seg_b) * sc
	var current_pos: Vector2 = pa.lerp(pb, seg_t)
	# 既に描画済みの辺でなければ部分線を描く
	var seg_key: String = str(mini(seg_a, seg_b)) + "_" + str(maxi(seg_a, seg_b))
	if not drawn_edges.has(seg_key):
		_game.draw_line(pa, current_pos, line_color, line_width, true)

	# 訪問済み頂点にドットを描画
	var visited: Dictionary = {}
	for s in range(current_seg + 1):
		visited[K_DRAW_PATH[s]] = true

	# SE: 新しい頂点が出現したらsfx_onを再生
	var visited_count: int = visited.size()
	if visited_count > _ti_prev_visited_count:
		_game._play_sfx(_game.sfx_on)
		_ti_prev_visited_count = visited_count

	for v_idx in visited:
		var p: Vector2 = center + _get_k_vertex(v_idx) * sc
		_game.draw_circle(p, dot_radius, dot_color)

	# traveling dot（現在位置）
	_game.draw_circle(current_pos, dot_radius + 2.0, dot_color)


func _draw_ti_k_complete(vp: Vector2, center: Vector2, sc: float, white_dot_t: float, deform_t: float) -> void:
	"""Kの完成形を描画（白点変化・変形対応）"""
	var dot_color := Color(0.26, 0.21, 0.28)
	var line_color := Color(0.26, 0.21, 0.28)
	var dot_radius: float = 7.0
	var line_width: float = 3.0

	# P2（右上先端）の変形位置を計算（初期位置→ロゴ最終位置）
	var p2_deformed: Vector2 = K_P2_INITIAL.lerp(K_VERTICES[K_WHITE_DOT_IDX], deform_t)

	# 全辺を描画
	for edge in K_EDGES:
		var a: int = edge[0]
		var b: int = edge[1]
		var va: Vector2 = K_VERTICES[a] if a != K_WHITE_DOT_IDX else p2_deformed
		var vb: Vector2 = K_VERTICES[b] if b != K_WHITE_DOT_IDX else p2_deformed
		var pa: Vector2 = center + va * sc
		var pb: Vector2 = center + vb * sc
		_game.draw_line(pa, pb, line_color, line_width, true)

	# 全頂点にドットを描画
	for i in range(K_VERTICES.size()):
		var v: Vector2 = K_VERTICES[i] if i != K_WHITE_DOT_IDX else p2_deformed
		var p: Vector2 = center + v * sc
		if i == K_WHITE_DOT_IDX:
			# P2: 白点への変化アニメーション
			var white_r: float = dot_radius + 3.0
			var border_w: float = 2.5
			var fill_color := dot_color.lerp(Color(1.0, 0.937, 0.89), white_dot_t)
			_game.draw_circle(p, lerpf(dot_radius, white_r, white_dot_t), dot_color)
			_game.draw_circle(p, lerpf(dot_radius, white_r - border_w, white_dot_t), fill_color)
		else:
			_game.draw_circle(p, dot_radius, dot_color)


func _draw_ti_k_white_dot(vp: Vector2, t: float) -> void:
	"""Phase 4: P4が黒点→白点に変化"""
	var center: Vector2 = _get_k_center_screen(vp)
	var sc: float = _get_k_draw_scale(vp)
	_draw_ti_k_complete(vp, center, sc, _ease_out_cubic(t), 0.0)


func _draw_ti_k_deform(vp: Vector2, t: float) -> void:
	"""Phase 5: 白点P4が右上に移動して変形"""
	var center: Vector2 = _get_k_center_screen(vp)
	var sc: float = _get_k_draw_scale(vp)
	_draw_ti_k_complete(vp, center, sc, 1.0, _ease_out_cubic(t))


func _draw_ti_k_move(vp: Vector2, t: float) -> void:
	"""Phase 6: Kが画面中央からロゴ位置に移動"""
	var center_start: Vector2 = _get_k_center_screen(vp)
	var logo_info: Dictionary = _get_k_logo_position(vp)
	var center_end: Vector2 = logo_info["center"]
	var sc_start: float = _get_k_draw_scale(vp)
	var sc_end: float = logo_info["scale"]

	var eased: float = _ease_out_cubic(t)
	var center: Vector2 = center_start.lerp(center_end, eased)
	var sc: float = lerpf(sc_start, sc_end, eased)
	_draw_ti_k_complete(vp, center, sc, 1.0, 1.0)


func _draw_ti_logo_reveal(vp: Vector2, t: float) -> void:
	"""Phase 7: Kをロゴ位置に描画し、ATA-DRAWをマスクスライドで表示"""
	# ロゴ位置のKを描画
	var logo_info: Dictionary = _get_k_logo_position(vp)
	var center: Vector2 = logo_info["center"]
	var sc: float = logo_info["scale"]
	_draw_ti_k_complete(vp, center, sc, 1.0, 1.0)

	# ATA-DRAW部分（logo02）をマスクスライドで表示
	if _game.title_logo02_texture:
		var tex_size: Vector2 = _game.title_logo02_texture.get_size()
		var draw_w: float = vp.x * 0.85 * 1.2
		var logo_scale: float = draw_w / 1456.0
		var draw_h: float = tex_size.y * (draw_w / tex_size.x)
		var logo_cy: float = vp.y * 0.38 * 0.8
		var logo_pos := Vector2((vp.x - draw_w) / 2.0, logo_cy - draw_h / 2.0)

		# マスク: 左端（K部分の右端あたり）から右端へ
		var eased: float = _ease_out_cubic(t)
		var mask_x: float = logo_pos.x + draw_w * eased
		# テクスチャの表示可能範囲をClipで制限
		# draw_texture_rect_regionを使用してマスク効果を実現
		var visible_w: float = draw_w * eased
		if visible_w > 0:
			var src_w: float = tex_size.x * eased
			var src_rect := Rect2(0, 0, src_w, tex_size.y)
			var dst_rect := Rect2(logo_pos, Vector2(visible_w, draw_h))
			_game.draw_texture_rect_region(_game.title_logo02_texture, dst_rect, src_rect)


func _draw_title_content(vp: Vector2, alpha: float) -> void:
	"""タイトル画面の内容をアルファ付きで描画（クロスフェード用：ロゴとBGのみ）"""
	# 背景をアルファ付きで重ねる（クロスフェード用）
	if _game.bg_texture:
		_game.draw_texture_rect(_game.bg_texture, Rect2(Vector2.ZERO, vp), false, Color(1, 1, 1, alpha))
	else:
		_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(_game.BG_COLOR.r, _game.BG_COLOR.g, _game.BG_COLOR.b, alpha))

	var cy: float = vp.y * 0.38 * 0.8
	if _game.title_logo_texture:
		var tex_size: Vector2 = _game.title_logo_texture.get_size()
		var draw_w: float = vp.x * 0.85 * 1.2
		var scale_f: float = draw_w / tex_size.x
		var draw_h: float = tex_size.y * scale_f
		var pos := Vector2((vp.x - draw_w) / 2.0, cy - draw_h / 2.0)
		_game.draw_texture_rect(_game.title_logo_texture, Rect2(pos, Vector2(draw_w, draw_h)), false, Color(1, 1, 1, alpha))


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


func _draw_config(vp: Vector2) -> void:
	_draw_bg(vp)

	# モードタイトル
	var title_fs: int = 48
	var title_y: float = 80.0 + _game.font_bold.get_ascent(title_fs)
	_game.draw_string(_game.font_bold, Vector2(0, title_y), tr("MENU_CONFIG"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, title_fs, Color(0.95, 0.19, 0.32))

	var text_c := Color(0.26, 0.21, 0.28)
	var sel_c := Color(0.95, 0.19, 0.32)
	var val_c := Color(0.26, 0.21, 0.28)
	var sub_sel_c := Color(0.95, 0.19, 0.32)
	var sub_off_c := Color(0.26, 0.21, 0.28)

	var base_y: float = vp.y * 0.28
	var spacing: float = 103.5
	var lx: float = vp.x * 0.28
	var vx: float = vp.x * 0.42
	var box_w: float = vp.x * 0.24
	var label_fs: int = 36
	var val_fs: int = 34
	var box_h: float = (_game.font.get_ascent(val_fs) + _game.font.get_descent(val_fs)) * 1.5

	var res_label: String = tr("CONFIG_720P") if _game.current_resolution == 0 else tr("CONFIG_1080P")
	var win_label: String = tr("CONFIG_FULLSCREEN") if _game.is_fullscreen else tr("CONFIG_WINDOW")
	var _loc: String = TranslationServer.get_locale()
	var lang_label: String
	if _loc == "ja":
		lang_label = tr("CONFIG_LANG_JA")
	elif _loc == "en":
		lang_label = tr("CONFIG_LANG_EN")
	elif _loc == "zh_CN":
		lang_label = tr("CONFIG_LANG_ZH_CN")
	elif _loc == "zh_TW":
		lang_label = tr("CONFIG_LANG_ZH_TW")
	else:
		lang_label = tr("CONFIG_LANG_JA")

	var item_labels: Array[String] = [
		tr("CONFIG_RESOLUTION"), tr("CONFIG_WINDOW_MODE"), tr("CONFIG_LANGUAGE"),
		tr("CONFIG_BGM_VOLUME"), tr("CONFIG_SE_VOLUME"), tr("CONFIG_BACK")
	]
	var item_values: Array[String] = [res_label, win_label, lang_label, str(_game.bgm_volume), str(_game.se_volume), ""]

	var arrow_w: float = 36.0   # ▼▲ボタンの幅
	var arrow_fs: int = 28      # ▼▲のフォントサイズ

	for i in range(6):
		var item_y: float = base_y + i * spacing
		var is_sel: bool = (i == _game.config_index) and _game.config_sub == ""
		var is_active: bool = (i == _game.config_index)

		if i == 5:
			# 「タイトルに戻る」ボタン — ボックスと同じ幅
			var btn_center := Vector2(vp.x / 2.0, item_y + box_h / 2.0 - 16.0 + vp.y * 0.15 - 35.0)
			_draw_auto_button_with_shadow(btn_center, item_labels[i], BTN_FONT_SIZE, 1.0, false, box_w)
		elif i == 3 or i == 4:
			# --- 音量項目: ボックス + ▼▲ボタン ---
			var box_rect := Rect2(vx, item_y - 16.0, box_w, box_h)
			var shadow_offset := Vector2(12.5, 12.5)
			_game.draw_rect(Rect2(box_rect.position + shadow_offset, box_rect.size), Color(0.26, 0.21, 0.28, 0.30))
			_game.draw_rect(box_rect, Color(1.0, 1.0, 1.0))
			_game.draw_rect(box_rect, Color(0.26, 0.21, 0.28), false, 5.75)
			var val_baseline_y: float = item_y - 16.0 + (box_h + _game.font.get_ascent(val_fs) - _game.font.get_descent(val_fs)) * 0.5
			_game.draw_string(_game.font_din, Vector2(vx, val_baseline_y), item_values[i], HORIZONTAL_ALIGNMENT_CENTER, box_w, val_fs, val_c)

			# ラベル
			var c: Color = sel_c if is_sel else text_c
			var label_font: Font = _game.font_bold if is_sel else _game.font
			_game.draw_string(label_font, Vector2(lx, val_baseline_y), item_labels[i], HORIZONTAL_ALIGNMENT_LEFT, vp.x * 0.3, label_fs, c)

			# ▼ボタン（ボックス左）
			var vol: int = _game.bgm_volume if i == 3 else _game.se_volume
			var down_x: float = vx - arrow_w - 4.0
			var down_rect := Rect2(down_x, item_y - 16.0, arrow_w, box_h)
			var down_enabled: bool = vol > 0
			var down_c: Color = (sel_c if is_sel else text_c) if down_enabled else Color(0.26, 0.21, 0.28, 0.25)
			_game.draw_rect(down_rect, Color(0.26, 0.21, 0.28, 0.08))
			_game.draw_rect(down_rect, Color(0.26, 0.21, 0.28, 0.3), false, 2.0)
			var down_baseline: float = item_y - 16.0 + (box_h + _game.font.get_ascent(arrow_fs) - _game.font.get_descent(arrow_fs)) * 0.5
			_game.draw_string(_game.font_bold, Vector2(down_x, down_baseline), "◀", HORIZONTAL_ALIGNMENT_CENTER, arrow_w, arrow_fs, down_c)

			# ▲ボタン（ボックス右）
			var up_x: float = vx + box_w + 4.0
			var up_rect := Rect2(up_x, item_y - 16.0, arrow_w, box_h)
			var up_enabled: bool = vol < 10
			var up_c: Color = (sel_c if is_sel else text_c) if up_enabled else Color(0.26, 0.21, 0.28, 0.25)
			_game.draw_rect(up_rect, Color(0.26, 0.21, 0.28, 0.08))
			_game.draw_rect(up_rect, Color(0.26, 0.21, 0.28, 0.3), false, 2.0)
			_game.draw_string(_game.font_bold, Vector2(up_x, down_baseline), "▶", HORIZONTAL_ALIGNMENT_CENTER, arrow_w, arrow_fs, up_c)
		else:
			# 値ボックス（白塗り、ボタンと同じ枠）
			var box_rect := Rect2(vx, item_y - 16.0, box_w, box_h)
			var shadow_offset := Vector2(12.5, 12.5)
			_game.draw_rect(Rect2(box_rect.position + shadow_offset, box_rect.size), Color(0.26, 0.21, 0.28, 0.30))
			_game.draw_rect(box_rect, Color(1.0, 1.0, 1.0))
			_game.draw_rect(box_rect, Color(0.26, 0.21, 0.28), false, 5.75)
			var val_baseline_y: float = item_y - 16.0 + (box_h + _game.font.get_ascent(val_fs) - _game.font.get_descent(val_fs)) * 0.5
			_game.draw_string(_game.font, Vector2(vx, val_baseline_y), item_values[i], HORIZONTAL_ALIGNMENT_CENTER, box_w, val_fs, val_c)

			# ラベル（選択中はBold + 赤）— ボックス内文字と同じベースラインに揃える
			var c: Color = sel_c if is_sel else text_c
			var label_font: Font = _game.font_bold if is_sel else _game.font
			_game.draw_string(label_font, Vector2(lx, val_baseline_y), item_labels[i], HORIZONTAL_ALIGNMENT_LEFT, vp.x * 0.3, label_fs, c)

			# サブメニュー: ボックスの右側に横並びで表示
			if is_active and _game.config_sub != "":
				var sub_labels: Array[String] = _get_config_sub_labels(i)
				var sub_x: float = vx + box_w + 30.0
				var sx_cursor: float = sub_x
				for j in range(sub_labels.size()):
					var is_sub_sel: bool = (j == _game.config_sub_index)
					var sc: Color = sub_sel_c if is_sub_sel else sub_off_c
					var sub_font: Font = _game.font_bold if is_sub_sel else _game.font
					_game.draw_string(sub_font, Vector2(sx_cursor, val_baseline_y), sub_labels[j], HORIZONTAL_ALIGNMENT_LEFT, -1, val_fs, sc)
					sx_cursor += _game.font.get_string_size(sub_labels[j], HORIZONTAL_ALIGNMENT_LEFT, -1, val_fs).x + 30.0


func _get_config_sub_labels(item_index: int) -> Array[String]:
	match item_index:
		0: return [tr("CONFIG_720P"), tr("CONFIG_1080P")]
		1: return [tr("CONFIG_FULLSCREEN"), tr("CONFIG_WINDOW")]
		2: return [tr("CONFIG_LANG_JA"), tr("CONFIG_LANG_EN"), tr("CONFIG_LANG_ZH_CN"), tr("CONFIG_LANG_ZH_TW")]
	return []


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
			_draw_selected_point(pos)
			_draw_grab_state_effect(pos)
			continue
		elif _game._is_selected(i):
			# 選択中: 白円 + 黒の同心円（1.2倍、外へ透過）
			_draw_selected_point(pos)
			_draw_point_position_effect(pos)
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

	for i in range(n):
		var pos: Vector2 = _game.point_positions[i]
		var color: Color
		var radius: float
		if _game._is_locked(i):
			color = Color(0.40, 0.33, 0.38, 0.5)
			radius = POINT_RADIUS
		elif _game.input_handler.grab_input_active and _game._is_selected(i):
			# つかみ状態: 白円 + 黒の同心円（1.2倍、外へ透過）
			_draw_selected_point(pos)
			_draw_grab_state_effect(pos)
			continue
		elif _game._is_selected(i):
			# 選択中: 白円 + 黒の同心円（1.2倍、外へ透過）
			_draw_selected_point(pos)
			_draw_point_position_effect(pos)
			continue
		elif i == _game.hovered_index:
			# ホバー時も通常表示（赤いポイントは廃止）
			var alpha: float = _game._point_accuracy_alpha(i)
			var base_c: Color = _stage_renderer.get_point_base_color(i)
			color = Color(base_c.r, base_c.g, base_c.b, alpha)
			radius = POINT_RADIUS
		else:
			var alpha: float = _game._point_accuracy_alpha(i)
			var base_c: Color = _stage_renderer.get_point_base_color(i)
			color = Color(base_c.r, base_c.g, base_c.b, alpha)
			radius = POINT_RADIUS
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


func _draw_selected_point(center: Vector2) -> void:
	"""選択ポイント: 白の円 + 半径1.2倍の黒の円（中心から離れるほど透過）"""
	var r: float = POINT_RADIUS
	for layer in SELECTED_POINT_BLACK_LAYERS:
		var radius: float = r * (layer[0] as float)
		var a: float = layer[1] as float
		var black_c: Color = Color(SELECTED_POINT_BLACK.r, SELECTED_POINT_BLACK.g, SELECTED_POINT_BLACK.b, a)
		_game.draw_circle(center, radius, black_c)
	_game.draw_circle(center, r, SELECTED_POINT_WHITE)


func _draw_point_position_effect(center: Vector2) -> void:
	"""ポイント位置: 水色のサークルが1秒ごとに拡散しながら消えていくエフェクト"""
	var t: float = fmod(Time.get_ticks_msec() / 1000.0, 1.0)  # 0..1 を1秒周期で繰り返し
	var radius: float = POINT_RADIUS_HOVER + t * 25.0   # 拡散
	var alpha: float = 1.0 - t                                 # 消えていく
	var c: Color = Color(_game.POINT_POSITION_EFFECT_COLOR.r, _game.POINT_POSITION_EFFECT_COLOR.g, _game.POINT_POSITION_EFFECT_COLOR.b, alpha * 0.6)
	_game.draw_arc(center, radius, 0, TAU, 32, c, 2.5)


func _draw_grab_state_effect(center: Vector2) -> void:
	"""つかみ状態: 青色のサークルが0.5秒ごとに透明からだんだん色濃く収束してくるエフェクト"""
	var t: float = fmod(Time.get_ticks_msec() / 500.0, 1.0)   # 0..1 を0.5秒周期で繰り返し
	var alpha: float = t                                      # 透明→濃く
	var radius: float = POINT_RADIUS_HOVER + (1.0 - t) * 8.0  # 収束（大きい→小さい）
	var c: Color = Color(_game.GRAB_STATE_EFFECT_COLOR.r, _game.GRAB_STATE_EFFECT_COLOR.g, _game.GRAB_STATE_EFFECT_COLOR.b, alpha * 0.85)
	_game.draw_arc(center, radius, 0, TAU, 32, c, 3.0)


func _draw_right_stick_debug_line(vp: Vector2) -> void:
	"""右スティック倒し中: 放電エフェクトで描画"""
	if not _game.input_handler.debug_right_stick_active:
		return
	var ih: InputHandler = _game.input_handler
	var center: Vector2 = ih.debug_right_stick_center
	var dir: Vector2 = ih.debug_right_stick_direction
	if dir.length_squared() < 0.0001:
		return
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

	# 所要時間・ボタンはポップアップ下部に配置
	_draw_monospace_number(_game.font, Vector2(tx, y + h - 24.0 - btn_h_val - 50.0), tr("CLEAR_TIME") % _game.clear_time, HORIZONTAL_ALIGNMENT_CENTER, tw, 37, Color(0.26, 0.21, 0.28))

	var btn_center := Vector2(x + w / 2.0, y + h - btn_h_val / 2.0 - 24.0)
	_draw_auto_button_with_shadow(btn_center, tr("BTN_NEXT"), BTN_FONT_SIZE, 1.0, false, w * 0.6)


func _draw_results(vp: Vector2) -> void:
	_draw_bg(vp)

	# --- スライドイン演出: 上から落ちてくる ---
	var slide_t: float = 1.0
	if _results_anim_time >= 0.0:
		slide_t = clampf((Time.get_ticks_msec() / 1000.0 - _results_anim_time) / RESULTS_SLIDE_DURATION, 0.0, 1.0)
	var slide_ease: float = _ease_out_cubic(slide_t)
	var cx: float = vp.x / 2.0
	var cy: float = vp.y / 2.0
	var w: float = 780.0
	var h: float = 710.0
	var x: float = cx - w / 2.0
	var target_y: float = cy - h / 2.0
	var start_y: float = -h  # 画面上部の外
	var y: float = lerpf(start_y, target_y, slide_ease)

	var dlg_rect := Rect2(Vector2(x, y), Vector2(w, h))
	# 白背景・太枠・統一シャドウ
	var dlg_shadow := Vector2(15.0, 15.0)
	_game.draw_rect(Rect2(dlg_rect.position + dlg_shadow, dlg_rect.size), Color(0.26, 0.21, 0.28, 0.25))
	_game.draw_rect(dlg_rect, Color(1.0, 1.0, 1.0))
	_game.draw_rect(dlg_rect, Color(0.26, 0.21, 0.28), false, 5.75)

	var tx: float = x + 30
	var tw: float = w - 60

	# タイトル（10%アップ: 54→59、上部20px隙間）
	_game.draw_string(_game.font_din, Vector2(tx, y + 20.0 + 72), tr("RESULT_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, tw, 59, Color(0.95, 0.19, 0.32))

	_game.draw_line(Vector2(x + 45, y + 20.0 + 102), Vector2(x + w - 45, y + 20.0 + 102), Color(0.26, 0.21, 0.28, 0.3), 1.5, true)

	# ステージ一覧（中央寄せで空白を詰める）
	var row_y: float = y + 20.0 + 150
	var row_fs: int = 33
	var col_gap: float = 40.0  # ステージ名と秒数の間隔
	# 最長のステージ名の幅を取得
	var max_label_w: float = 0.0
	for i in range(_game.stage_times.size()):
		var lw: float = _game.font_din.get_string_size(tr("RESULT_STAGE") % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, row_fs).x
		if lw > max_label_w:
			max_label_w = lw
	# 最長の秒数の幅を取得（等幅基準）
	var max_time_w: float = 0.0
	for i in range(_game.stage_times.size()):
		var tw2: float = _get_monospace_number_width(_game.font_din, "%.1fs" % _game.stage_times[i], row_fs)
		if tw2 > max_time_w:
			max_time_w = tw2
	var row_total_w: float = max_label_w + col_gap + max_time_w
	var row_start_x: float = cx - row_total_w / 2.0
	var row_time_x: float = row_start_x + max_label_w + col_gap

	for i in range(_game.stage_times.size()):
		var stage_label: String = tr("RESULT_STAGE") % (i + 1)
		var time_str: String = "%.1fs" % _game.stage_times[i]
		_draw_monospace_number(_game.font_din, Vector2(row_start_x, row_y), stage_label, HORIZONTAL_ALIGNMENT_LEFT, -1, row_fs, Color(0.26, 0.21, 0.28))
		_draw_monospace_number(_game.font_din, Vector2(row_time_x, row_y), time_str, HORIZONTAL_ALIGNMENT_RIGHT, max_time_w, row_fs, Color(0.26, 0.21, 0.28))
		row_y += 48

	_game.draw_line(Vector2(x + 45, row_y - 12), Vector2(x + w - 45, row_y - 12), Color(0.26, 0.21, 0.28, 0.3), 1.5, true)

	var total_time: float = 0.0
	for t in _game.stage_times:
		total_time += t

	# TOTAL行（フォントが大きいので専用の幅を計算）
	row_y += 32
	var total_fs: int = 39
	var total_time_str: String = "%.1fs" % total_time
	var total_time_w: float = _get_monospace_number_width(_game.font_din, total_time_str, total_fs)
	var total_display_w: float = maxf(max_time_w, total_time_w)
	_draw_monospace_number(_game.font_din, Vector2(row_start_x, row_y), tr("RESULT_TOTAL"), HORIZONTAL_ALIGNMENT_LEFT, -1, total_fs, Color(0.26, 0.21, 0.28))
	_draw_monospace_number(_game.font_din, Vector2(row_time_x, row_y), total_time_str, HORIZONTAL_ALIGNMENT_RIGHT, total_display_w, total_fs, Color(0.95, 0.19, 0.32))

	# ボタン（下部に40px隙間）
	var btn_h_val: float = (_game.font.get_ascent(BTN_FONT_SIZE) + _game.font.get_descent(BTN_FONT_SIZE)) * 1.5
	_draw_auto_button_with_shadow(Vector2(x + w / 2.0, y + h - btn_h_val / 2.0 - 40.0), tr("BTN_TO_TITLE"), BTN_FONT_SIZE, 1.0, false, w * 0.6)


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


