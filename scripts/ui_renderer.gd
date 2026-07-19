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
const APP_VERSION: String = "v0.50.03"
const LINE_COLOR := GameConfig.INK_COLOR
const LINE_COLOR_2 := Color(0.55, 0.20, 0.30)
const POINT_COLOR := GameConfig.INK_COLOR
const POINT_COLOR_2 := Color(0.55, 0.20, 0.30)
const POINT_RADIUS := 9.0
const POINT_RADIUS_HOVER := 13.0
const LINE_WIDTH := 5.0
# ガイド線から遠いほど大きい円（px 半径）。距離は get_distance_to_hint_guide_outline 基準
const POINT_RADIUS_GUIDE_NEAR_MIN := 5.0
const POINT_RADIUS_GUIDE_FAR_MAX := 25.0
const POINT_RADIUS_GUIDE_DIST_FULL_PX := 120.0  # この距離以上で最大半径
# 未ロックのポイント同士で比較し、ズレが最大のものほど上記半径をさらに大きく（最小側はやや小さく）
const POINT_RADIUS_RELATIVE_SPREAD := 0.22  # 最悪点は +(22%)、最良点は −(22%) 相当の倍率

# --- 選択ポイント（白円 + 黒の同心円）---
const SELECTED_POINT_WHITE := Color(1.0, 0.937, 0.89, 1.0)
const SELECTED_POINT_BLACK := LINE_COLOR
const SELECTED_POINT_BLACK_LAYERS: Array[Array] = [
	[2.0, 0.06],   # [半径倍率, alpha] 黒の同心円（白円に対する倍率）
	[1.5, 0.14],
	[1.25, 0.24],
	[1.10, 0.38],
]

# --- 選択ポイントから接続2点へのレーザー／稲妻放電／右スティックコリドー塗りのベース（RGB 黒、アルファで濃淡）
const LASER_BLUE := Color(0, 0, 0, 1.0)
const LASER_WHITE := Color(0, 0, 0, 1.0)
const LASER_LENGTH_RATIO := 2.0 / 3.0  # ポイント間距離の何割で消えるか
const LASER_SEGMENTS := 16
const LASER_THICK_LAYERS: Array[Array] = [  # [幅, alpha] 外側→内側
	[14.0, 0.08],
	[10.0, 0.18],
	[6.0, 0.35],
	[3.0, 0.55],
]
const LASER_WHITE_WIDTH := 1.5

# X（引力）: 1 周期の秒当たり回転（従来同等）。**半径方向の遅速**は相対位相 s→q（非線形）で出す
const PLAYER_ATTRACT_INWARD_WAVE_HZ := 0.75
const PLAYER_ATTRACT_INWARD_WAVE_LAYERS: int = 6
# 外周でのみ「早く進む」倍率 F の上限。内側 s→1 では常に q'(1)=1（従来の周期終端感）
const PLAYER_ATTRACT_F_OUTER_MAX := 3.2
# 実効/基準半径比の扱いに使う上限制限（可視上の F の上限用）
const PLAYER_ATTRACT_EXPAND_RATIO_CAP := 4.0
# A（斥力）: 外向き円波の秒間回数（長押しでは変えない）
const PLAYER_REPULSE_OUTWARD_WAVE_HZ := 1.0
# 引力・斥力の実効範囲（field_r）に塗る薄い色（波は後から上に重ねる）
const PLAYER_FORCE_FIELD_FILL_ATTRACT := Color(0.42, 0.78, 1.0, 0.075)
const PLAYER_FORCE_FIELD_FILL_REPEL := Color(1.0, 0.48, 0.62, 0.065)

# assets/UI 画像（操作デモ・プレイ中ヒント）。大きさ・位置は下記フラクションで調整
const _UI_ASSETS_DIR := "res://assets/UI/"
# rules 画面: 上半分付近の左右配置。各画像の長辺 = min(画面) * この値
const RULES_CTRL_IMAGES_SIZE_FRAC := 2.0 / 5.0
const RULES_CTRL_IMAGES_CENTER_Y_FRAC := 0.15  # 上半分の中央付近（+ _draw_rules の shift_down）
# playing: 左下角付近。長辺 = min(画面) * この値
const STAGE_CTRL_HINT_SIZE_FRAC := 1.0 / 2.0
const STAGE_CTRL_HINT_BL_MARGIN_LEFT_PX := 32.0   # 左端からのマージン（px）
const STAGE_CTRL_HINT_BL_MARGIN_BOTTOM_PX := 32.0  # 下端からのマージン（px）
# square（ピンク）／ hex（水色）のコーナー説明ループ用。0.5s 非表示→2.5s 拡大・位置共通
const PLAYING_BTN_DEMO_PAUSE_SEC := 0.5
const PLAYING_BTN_DEMO_EXPAND_SEC := 2.5
const PLAYING_BTN_DEMO_CENTER_X_FRAC := 0.14
const PLAYING_BTN_DEMO_ABOVE_CONTROLLER_FRAC := 0.07
const PLAYING_BTN_DEMO_MAX_R_FRAC := 0.22
const PLAYING_BTN_DEMO_RING_ALPHA_MUL := 2.0  # 拡大する円の塗り・縁のみ濃く（ダミー自キャラは対象外）
# --- Particle state ---
var particles: Array[Dictionary] = []
var particle_spawn_time: float = 0.0
var spore_particles: Array[Dictionary] = []
var _spore_spawn_accum: float = 0.0

# --- Snap color effect (スナップ時: 赤→黒フェード) ---
const SNAP_COLOR_DUR := 2.0
var _snap_color_effects: Dictionary = {}  # {point_idx: elapsed}

# --- 終了確認ダイアログ ボーダーアニメーション ---
const QUIT_BORDER_CYCLE:    float = 2.0
const QUIT_BORDER_ANIM_DUR: float = 1.0
const QUIT_BORDER_LINE_LEN: float = 350.0
const QUIT_BORDER_WAIT:     float = QUIT_BORDER_CYCLE - QUIT_BORDER_ANIM_DUR
var _quit_border_phase_t: float = QUIT_BORDER_WAIT  # 開いた瞬間から即走行

# --- ネコアニメーション ---
var _cat_phase: int = 0   # 0=IDLE 1=MORPHIN 2=WIGGLE 3=MORPHOUT
var _cat_elapsed: float = 0.0
const _CAT_SIZE_PX: float = 32.0
const _CAT_MORPH_IN_SEC: float = 0.2
const _CAT_WIGGLE_SEC: float = 0.8
const _CAT_MORPH_OUT_SEC: float = 0.2
const _CAT_WIGGLE_DEG: float = 5.0
const _CAT_WIGGLE_FREQ: float = 5.0
var _cat_texture: Texture2D = null
var _tri_deco_texture: Texture2D = null

# --- ステージ1〜3: ボタン押下ヒント（手＋バー）のアニメーション状態 ---
var _press_hint_current_y: float = 0.0
var _press_hint_anim_from_y: float = 0.0
var _press_hint_target_y: float = 0.0
var _press_hint_anim_start: float = 0.0
const PRESS_HINT_ANIM_DUR: float = 0.1
var _ig_esc_key_texture: Texture2D = null
var _ig_start_pad_texture: Texture2D = null
var _ig_hint_style: StyleBoxFlat = null

# --- Animation state ---
var _prev_state: String = ""          # 前フレームのゲームステート
var _transition_alpha: float = 1.0    # 画面遷移フェード（0=暗転中, 1=表示中）
var _transition_dir: int = 0          # 0=なし, 1=フェードイン, -1=フェードアウト
var _transition_speed: float = 4.0    # 1/秒（0.25秒で完了）
var _pending_state: String = ""       # フェードアウト完了後に切り替えるステート

# 自キャラ円中心から実現率テキストをずらす（右＋上＝+x, -y）
const REPRO_RATE_OFFSET_FROM_PLAYER := Vector2(32.0, -28.0)
const REPRO_FLOAT_CHANGE_MIN_PCT := 0.02
const REPRO_ANIM_DURATION_MS: int = 600   # 値が変化した時のカウントアップアニメーション時間
const REPRO_HOLD_AFTER_ANIM_MS: int = 1400  # アニメーション完了後の表示維持時間
var _repro_prev_stable: float = -1000.0   # 前回の安定値（変化検出用）
var _repro_anim_from: float = 0.0         # アニメーション開始値
var _repro_anim_to: float = 0.0           # アニメーション目標値
var _repro_anim_start_msec: int = -1      # アニメーション開始時刻（-1=未開始）
var _result_mouse_pos: Vector2 = Vector2(-1.0, -1.0)  # リザルト画面のマウス座標
## 0=スクリーンショット 1=Twitter 2=NEXT（マウスが各ボタン上ならそちらを優先）
var results_action_focus_index: int = 2

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
var _guide_typewriter_done: bool = false  # タイプライター演出完了フラグ
var _countdown_scales: Dictionary = {} # カウントダウン数字 → スケールアニメ用
var _countdown_prev: int = -1

var _clear_anim_time: float = -1.0    # クリア演出の開始時刻
var _clear_card_canvas: Node2D = null  # 透視シェーダー付き Node2D（game.gd が設定）
var _pause_anim_time: float = -1.0    # ポーズ開演出の開始時刻
var _pause_closing: bool = false       # ポーズ閉じ中
var _stage_intro_time: float = -1.0   # ステージ開始演出の開始時刻
const STAGE_INTRO_DURATION := 0.7     # 演出の長さ（秒）
# HUD 秒表示: 一度左上に逃げたら、自キャラが左上エリアに入るまで左上のまま
var _hud_time_dock_left: bool = false
var _results_anim_time: float = -1.0  # リザルト画面の開始時刻
const RESULTS_SLIDE_DURATION := 0.7   # スライドイン所要時間（秒。現在は個別フェーズ演出に置き換え済み・未使用）
var _results_skip_offset: float = 0.0  # フェーズスキップで加算した時間（体験版リザルト演出用）
# Result 画面の見出し・TOTAL ラベル（基準からの倍率）
const RESULT_SCREEN_TITLE_FS := 120  # 48 * 2.5
const RESULT_TOTAL_LABEL_FS := 84  # 28 * 3
# playing 中のポイント描画フレーム用: 未ロック各点のガイド距離の min/max（相対的な円サイズ用）
var _guide_dist_min: float = 0.0
var _guide_dist_max: float = 0.0
var _guide_dist_have_bounds: bool = false
var _guide_point_distances: Array[float] = []
## assets/UI 内テクスチャのキャッシュ（ファイル名 → Texture2D）
var _ui_texture_cache: Dictionary = {}

# --- Title Intro Animation（描画・タイムラインは title_intro_animation.gd）---
var title_intro: TitleIntroAnimator

# --- game 参照 (Node2D/CanvasItem) ---
var _game: Node2D
var _stage_renderer: StageRenderer
var _font_din_tight: FontVariation = null        # font_din の字間詰めバリアント（spacing_glyph = 0、net +5px）KATA-DRAW用
var _font_din_num: FontVariation = null          # 数値表示専用（spacing_glyph = -1、net +4px）
var _font_din_result: FontVariation = null       # #N/RESULT 専用（spacing_glyph = -2、net +3px）
var _font_din_config_logo: FontVariation = null  # CONFIG ロゴ専用（spacing_glyph = -10、net -5px）
var _font_din_stat_val_cache: Dictionary = {}    # リザルト CLEAR TIME/TRY COUNT・TOTAL値専用（spacing_glyphごとにFontVariationをキャッシュ。カードは-1、TOTALは-2がデフォルト）
var _font_din_stat_label: FontVariation = null   # リザルト CLEAR/TIME/TRY/COUNT/TOTAL等の項目文字列専用（spacing_glyph = 0、net +5px）
var _font_din_card_num: FontVariation = null     # リザルト ステージカードの#N番号ヘッダ専用（spacing_glyph = 0、net +5px）
var _credit_kata_lbl: Label = null   # クレジット用 KATA-DRAW ラベル
var _credit_staff_lbl: Label = null  # クレジット用 STAFF ラベル
var _font_stage: FontVariation = null      # STAGE 専用: CLEAR 幅に合わせて字間を自動調整
var _font_clear: FontVariation = null      # CLEAR 専用: spacing_glyph = -7（net -2px）


func _init(game: Node2D) -> void:
	_game = game
	title_intro = TitleIntroAnimator.new(_game, Callable(self, "suppress_hover_sfx"))
	_stage_renderer = StageRenderer.new(game, self)
	_cat_texture = load("res://assets/UI/cat.png") as Texture2D
	_tri_deco_texture = load("res://assets/UI/tri_deco.svg") as Texture2D
	_ig_esc_key_texture   = load("res://assets/UI/esc_key.svg")   as Texture2D
	_ig_start_pad_texture = load("res://assets/UI/start_pad.svg") as Texture2D
	_ig_hint_style = StyleBoxFlat.new()
	_ig_hint_style.bg_color = Color(0.263, 0.212, 0.278, 0.9)
	_ig_hint_style.set_corner_radius_all(10)
	_ig_hint_style.content_margin_left   = 10.0
	_ig_hint_style.content_margin_right  = 10.0
	_ig_hint_style.content_margin_top    = 6.0
	_ig_hint_style.content_margin_bottom = 6.0


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

func is_guide_typewriter_done() -> bool:
	return _guide_typewriter_done

func skip_guide_typewriter() -> void:
	_guide_typewriter_done = true

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

	if _cat_phase != 0:
		_cat_elapsed += delta
		match _cat_phase:
			1:  # MORPHIN
				if _cat_elapsed >= _CAT_MORPH_IN_SEC:
					_cat_elapsed = 0.0
					_cat_phase = 2
			2:  # WIGGLE
				if _cat_elapsed >= _CAT_WIGGLE_SEC:
					_cat_elapsed = 0.0
					_cat_phase = 3
			3:  # MORPHOUT
				if _cat_elapsed >= _CAT_MORPH_OUT_SEC:
					_cat_elapsed = 0.0
					_cat_phase = 0

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

	# スナップカラーエフェクト更新
	var _snap_done: Array = []
	for key in _snap_color_effects.keys():
		_snap_color_effects[key] += delta
		if _snap_color_effects[key] >= SNAP_COLOR_DUR:
			_snap_done.append(key)
	for key in _snap_done:
		_snap_color_effects.erase(key)

	# 終了確認ダイアログ ボーダータイマー
	if _game.menu_confirm_quit:
		_quit_border_phase_t = fmod(_quit_border_phase_t + delta, QUIT_BORDER_CYCLE)
	else:
		_quit_border_phase_t = QUIT_BORDER_WAIT

func update_result_mouse_pos(pos: Vector2) -> void:
	_result_mouse_pos = pos

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
		_guide_typewriter_done = false
	if new_state == "cleared":
		_clear_anim_time = Time.get_ticks_msec() / 1000.0
		if _clear_card_canvas != null:
			_clear_card_canvas.visible = true
	elif _clear_card_canvas != null and _clear_card_canvas.visible:
		_clear_card_canvas.visible = false
	if new_state == "playing":
		_stage_intro_time = Time.get_ticks_msec() / 1000.0
		_hud_time_dock_left = false
	if new_state == "results":
		_results_anim_time = Time.get_ticks_msec() / 1000.0
		_results_skip_offset = 0.0
		results_action_focus_index = 2
		if _game.has_method("_reset_ui_menu_stick_navigation"):
			_game._reset_ui_menu_stick_navigation()
	if new_state == "title_intro":
		title_intro.reset()
	# 一致度の「変化直後」表示: プレイ/ルール以外に出たらリセット
	if new_state != "playing" and new_state != "rules":
		_repro_prev_stable = -1000.0
		_repro_anim_start_msec = -1
	elif new_state == "playing" or new_state == "rules":
		_repro_prev_stable = -1000.0
		_repro_anim_start_msec = -1
	_prev_state = new_state


# =============================================================================
# Public API
# =============================================================================

func draw(state: String, vp: Vector2) -> void:
	# ステート変更検出
	if state != _prev_state:
		on_state_changed(state)

	# credit 以外のステートではロゴラベルを非表示
	if state != "credit":
		if _credit_kata_lbl != null:
			_credit_kata_lbl.visible = false
			_credit_staff_lbl.visible = false

	match state:
		"logo":
			_draw_logo(vp)
		"title_intro":
			title_intro.draw(vp)
		"title":
			_draw_title(vp)
		"menu":
			_draw_menu(vp)
		"ta_info":
			_draw_ta_info(vp)
		"ta_results":
			_draw_ta_results(vp)
		"config":
			_draw_config(vp)
		"se_config":
			_draw_se_config(vp)
		"credit":
			_draw_credit(vp)
		"rules":
			_draw_rules(vp)
		"guide_info":
			_draw_guide_info(vp)
		"guide_countdown":
			_draw_guide_countdown(vp)
		"playing":
			_draw_game(vp)
			if _game.current_stage == StageSelectManager._zou_stage_idx:
				_draw_zou_staff_roll(vp)
		"cleared":
			_draw_game(vp)
			if _game.current_stage == StageSelectManager._zou_stage_idx:
				_draw_zou_staff_roll(vp)
			_draw_clear_overlay(vp)
			_draw_particles()
		"zou_ending":
			_draw_zou_ending(vp)
		"zou_ta_unlock":
			_draw_zou_ta_unlock(vp)
		"results":
			_draw_results(vp)
		"stage_debug":
			_draw_stage_debug(vp)
		"stage_edit":
			_draw_stage_edit(vp)
		"play_balance_debug":
			_draw_play_balance_debug(vp)

	# 画面遷移フェードオーバーレイ
	if _transition_alpha < 1.0:
		var fade_a: float = 1.0 - _transition_alpha
		_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(_game.BG_COLOR.r, _game.BG_COLOR.g, _game.BG_COLOR.b, fade_a))

	#if _game.stage_session.debug_test_mode and state == "playing":
		#_draw_debug_log_button(vp)

	if not _game.pause_active and state != "logo" and state != "title_intro" and state != "zou_ending" and state != "zou_ta_unlock":
		var _show_avatar: bool = true
		if state == "title":
			var _t: float = Time.get_ticks_msec() / 1000.0 - _game.title_start_time
			_show_avatar = (_t - GameConfig.TITLE_FADE_IN - 0.3) > 0.0 and not _game._cursor_pad_override_hidden
		elif state == "menu":
			_show_avatar = not _game._cursor_pad_override_hidden
		if _show_avatar:
			_draw_player_avatar()

	# デバッグ起動時: バージョン番号をプレイ中以外で表示
	if _game._debug_tools_enabled() and state != "playing":
		_game.draw_string(_game.font, Vector2(16, vp.y - 14), APP_VERSION, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.45, 0.38, 0.45, 0.8))


func draw_pause_overlay(vp: Vector2) -> void:
	_draw_pause_overlay(vp)


func trigger_snap_color(point_idx: int) -> void:
	"""スナップ時カラーエフェクトを登録（input_handler から呼ぶ）"""
	_snap_color_effects[point_idx] = 0.0


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


func start_cat_anim() -> void:
	_cat_phase = 1  # MORPHIN
	_cat_elapsed = 0.0


func _draw_cat_anim_point(pos: Vector2, base_radius: float) -> void:
	if _cat_texture == null:
		return
	var size_px: float
	var rot_rad: float = 0.0
	match _cat_phase:
		1:  # MORPHIN
			var t: float = clampf(_cat_elapsed / _CAT_MORPH_IN_SEC, 0.0, 1.0)
			size_px = lerpf(base_radius * 2.0, _CAT_SIZE_PX * 2.0, t)
		2:  # WIGGLE
			size_px = _CAT_SIZE_PX * 2.0
			rot_rad = deg_to_rad(_CAT_WIGGLE_DEG) * sin(_cat_elapsed * TAU * _CAT_WIGGLE_FREQ)
		3:  # MORPHOUT
			var t: float = 1.0 - clampf(_cat_elapsed / _CAT_MORPH_OUT_SEC, 0.0, 1.0)
			size_px = lerpf(base_radius * 2.0, _CAT_SIZE_PX * 2.0, t)
		_:
			return
	var half: float = size_px * 0.5
	_game.draw_set_transform(pos, rot_rad, Vector2.ONE)
	_game.draw_texture_rect(_cat_texture, Rect2(Vector2(-half, -half), Vector2(size_px, size_px)), false)
	_game.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
		_game.draw_string(_game.font, Vector2(0, cy), tr("TITLE_NAME"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 168, Color(LINE_COLOR,fade))

	# ボタン・クレジットはロゴ表示完了後に遅延フェードイン
	var time_since: float = Time.get_ticks_msec() / 1000.0 - _game.title_start_time
	var bottom_alpha: float = clampf((time_since - GameConfig.TITLE_FADE_IN - 0.3) / 0.5, 0.0, 1.0)
	var alpha: float = _crossfade_alpha() * bottom_alpha
	var btn_center := Vector2(vp.x / 2.0, (vp.y / 2.0 + 40.0) * 1.2 + 50.0)  # 20%下へ + 50px
	_draw_auto_button_with_shadow(btn_center, tr("TITLE_START"), BTN_FONT_SIZE, alpha, false, vp.x * 0.375)

	_game.draw_string(_game.font, Vector2(0, vp.y - 30), tr("TITLE_COPYRIGHT"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 32, Color(0.45, 0.38, 0.45, bottom_alpha))
	_game.draw_string(_game.font, Vector2(16, vp.y - 14), APP_VERSION, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.45, 0.38, 0.45, bottom_alpha))



func get_menu_btn_cy(vp: Vector2, index: int, count: int) -> float:
	# ゲームスタートボタンを基準に、ボタン間20px間隔で固定配置
	var first_btn_cy: float = vp.y * 0.57 - 5.0
	if index == 0:
		return first_btn_cy
	var btn_h: float = get_menu_btn_h()
	return first_btn_cy + index * (btn_h + 20.0)


func get_menu_btn_h() -> float:
	return (_game.font.get_ascent(BTN_FONT_SIZE) + _game.font.get_descent(BTN_FONT_SIZE)) * 1.5 * 0.9


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
		_game.draw_string(_game.font, Vector2(0, cy - 50), tr("TITLE_NAME"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 168, LINE_COLOR)

	var menu_count: int = _game._title_menu_count()
	var labels: Array[String] = _game._title_menu_labels()
	for i in range(menu_count):
		var btn_center_y: float = get_menu_btn_cy(vp, i, menu_count)
		var is_sel: bool = (i == _game.menu_index)
		var is_off: bool = not is_sel
		_draw_auto_button_with_shadow(Vector2(vp.x / 2.0, btn_center_y), labels[i], BTN_FONT_SIZE, 1.0, is_off, vp.x * 0.375, get_menu_btn_h())

	_game.draw_string(_game.font, Vector2(0, vp.y - 30), tr("TITLE_COPYRIGHT"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 32, Color(0.45, 0.38, 0.45))

	# 終了確認ダイアログ
	if _game.menu_confirm_quit:
		_draw_menu_quit_confirm(vp)


func _draw_ta_unlock_dialog_box(vp: Vector2) -> void:
	var cx: float = vp.x / 2.0
	var dlg_cy: float = vp.y / 2.0
	var dlg_w: float = 836.0
	var dlg_h: float = 260.0
	var dlg_rect := Rect2(Vector2(cx - dlg_w / 2.0, dlg_cy - dlg_h / 2.0), Vector2(dlg_w, dlg_h))
	var dlg_shadow := Vector2(15.0, 15.0)
	_game.draw_rect(Rect2(dlg_rect.position + dlg_shadow, dlg_rect.size), Color(LINE_COLOR, 0.25))
	_game.draw_rect(dlg_rect, Color(1.0, 1.0, 1.0))
	_draw_rect_border_with_corners(dlg_rect, LINE_COLOR, 5.75)
	_game.draw_string(_game.font_bold, Vector2(cx - dlg_w / 2.0 + 30.0, dlg_cy - 40.0),
		tr("TA_UNLOCK_MESSAGE"), HORIZONTAL_ALIGNMENT_CENTER, dlg_w - 60.0, 38, Color(0.95, 0.19, 0.32))
	_game.draw_string(_game.font, Vector2(cx - dlg_w / 2.0 + 30.0, dlg_cy + 50.0),
		tr("TA_UNLOCK_HINT"), HORIZONTAL_ALIGNMENT_CENTER, dlg_w - 60.0, 24, Color(0.45, 0.38, 0.45))


func _draw_menu_quit_confirm(vp: Vector2) -> void:
	# 画面全体を暗転
	_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(LINE_COLOR,0.50))
	var cx: float = vp.x / 2.0
	var dlg_cy: float = vp.y / 2.0
	var dlg_w: float = 700.0
	var dlg_h: float = 250.0
	var dlg_rect := Rect2(Vector2(cx - dlg_w / 2.0, dlg_cy - dlg_h / 2.0), Vector2(dlg_w, dlg_h))
	# 白背景ダイアログ
	var dlg_shadow := Vector2(15.0, 15.0)
	_game.draw_rect(Rect2(dlg_rect.position + dlg_shadow, dlg_rect.size), Color(LINE_COLOR,0.25))
	_game.draw_rect(dlg_rect, Color(1.0, 1.0, 1.0))
	_draw_rect_border_with_corners(dlg_rect, LINE_COLOR, 5.75)
	# テキスト
	_game.draw_string(_game.font_bold, Vector2(cx - dlg_w / 2.0, dlg_cy - 45.0), tr("MENU_QUIT_CONFIRM"), HORIZONTAL_ALIGNMENT_CENTER, dlg_w, 42, Color(0.95, 0.19, 0.32))
	# ボタン
	var cbtn_w: float = 220.0
	var cbtn_gap: float = cbtn_w / 2.0 + 30.0
	var cbtn_cy: float = dlg_cy + 50.0
	var yes_off: bool = _game.menu_confirm_index != 0
	var no_off: bool = _game.menu_confirm_index != 1
	_draw_auto_button_with_shadow(Vector2(cx - cbtn_gap, cbtn_cy), tr("PAUSE_CONFIRM_YES"), BTN_FONT_SIZE, 1.0, yes_off, cbtn_w, 64.0)
	_draw_auto_button_with_shadow(Vector2(cx + cbtn_gap, cbtn_cy), tr("PAUSE_CONFIRM_NO"), BTN_FONT_SIZE, 1.0, no_off, cbtn_w, 64.0)

	if _quit_border_phase_t >= QUIT_BORDER_WAIT:
		var anim_t: float = minf((_quit_border_phase_t - QUIT_BORDER_WAIT) / QUIT_BORDER_ANIM_DUR, 1.0)
		var perimeter: float = 2.0 * (dlg_w + dlg_h)
		var head_d: float = anim_t * (perimeter + QUIT_BORDER_LINE_LEN)
		var tail_d: float = head_d - QUIT_BORDER_LINE_LEN
		_draw_border_line_topleft_ui(dlg_rect.position.x, dlg_rect.position.y, dlg_w, dlg_h,
				tail_d, head_d, Color(0.95, 0.19, 0.32))


func _draw_ta_info(vp: Vector2) -> void:
	_draw_bg(vp)
	var cx: float = vp.x / 2.0
	var panel_w: float = minf(720.0, vp.x * 0.85)
	var panel_x: float = cx - panel_w / 2.0
	var top_y: float = vp.y * 0.18

	# タイトル
	_game.draw_string(_game.font_bold, Vector2(panel_x, top_y), tr("TA_INFO_TITLE"),
			HORIZONTAL_ALIGNMENT_CENTER, panel_w, 52, LINE_COLOR)

	# 説明文 3行
	var body_keys: Array[String] = ["TA_INFO_BODY_1", "TA_INFO_BODY_2", "TA_INFO_BODY_3"]
	var body_y: float = top_y + 80.0
	var line_gap: float = 60.0
	for i in range(body_keys.size()):
		_game.draw_string(_game.font, Vector2(panel_x, body_y + float(i) * line_gap),
				tr(body_keys[i]), HORIZONTAL_ALIGNMENT_LEFT, panel_w, 28, LINE_COLOR)

	# 開始ボタン
	var btn_cy: float = body_y + float(body_keys.size()) * line_gap + 60.0
	_draw_auto_button_with_shadow(Vector2(cx, btn_cy), tr("TA_INFO_START_BUTTON"),
			BTN_FONT_SIZE, 1.0, false, panel_w * 0.7)

	# ESC/B で戻るヒント
	_game.draw_string(_game.font, Vector2(0.0, vp.y - 62.0), tr("BACK_HINT_ESC"),
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, 26, Color(0.6, 0.55, 0.6))

	_game.draw_string(_game.font, Vector2(0.0, vp.y - 30.0), tr("TITLE_COPYRIGHT"),
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, 32, Color(0.45, 0.38, 0.45))


## タイムアタック専用リザルト画面（仮実装）。既存の _draw_results()（体験版用）とは独立した専用実装。
## 演出タイムラインは _game._ta_results_timeline() を単一の情報源として参照する。
func _draw_ta_results(vp: Vector2) -> void:
	_draw_bg(vp)
	var tl: Dictionary = _game._ta_results_timeline()
	var elapsed: float = tl.elapsed
	var times: Array[float] = _game.stage_session.stage_times
	var stage_count: int = times.size()

	# 1. 「Result」タイトル: 中央表示 → 上部へスクロールして停止
	var title_top_y: float = vp.y * 0.08
	var title_center_y: float = vp.y * 0.5
	var scroll_t: float = clampf((elapsed - tl.title_show_dur) / tl.title_scroll_dur, 0.0, 1.0)
	var ease_t: float = scroll_t * scroll_t * (3.0 - 2.0 * scroll_t)
	var title_y: float = lerp(title_center_y, title_top_y, ease_t)
	var title_alpha: float = clampf(elapsed / 0.3, 0.0, 1.0)
	_draw_ta_hud_text(Vector2(0, title_y), "Result", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 64, Color(1.0, 1.0, 1.0, title_alpha))

	# 2. 横4分割: 2列目=ステージ別タイム、3列目=トータルタイム / 縦4分割の中央2つ分に表示を限定
	var col_w: float = vp.x / 4.0
	var col2_x: float = col_w * 1.0
	var col3_x: float = col_w * 2.0
	var band_top: float = vp.y * 0.25
	var band_bottom: float = vp.y * 0.75

	if elapsed >= tl.listing_start and stage_count > 0:
		var list_elapsed: float = elapsed - tl.listing_start
		var scroll_speed: float = tl.row_h / tl.row_interval
		var revealed: int = mini(stage_count, int(list_elapsed / tl.row_interval) + 1)
		var total_shown: float = 0.0
		for i in range(revealed):
			total_shown += times[i]
			var row_appear_time: float = float(i) * tl.row_interval
			var row_y: float = band_bottom - tl.row_h - (list_elapsed - row_appear_time) * scroll_speed
			if row_y < band_top - tl.row_h or row_y > band_bottom + tl.row_h:
				continue
			var stage_no: String = "%02d" % (i + 1)
			var row_text: String = "%s: %.2f" % [stage_no, times[i]]
			_draw_ta_hud_text(Vector2(col2_x, row_y), row_text, HORIZONTAL_ALIGNMENT_LEFT, col_w, 24, Color(1.0, 1.0, 1.0))
		var total_text: String = "%.2f" % total_shown
		_draw_ta_hud_text(Vector2(col3_x, (band_top + band_bottom) * 0.5), total_text, HORIZONTAL_ALIGNMENT_LEFT, col_w, 32, Color(1.0, 1.0, 1.0))

	# 3. THANK YOU FOR PLAYING !!
	if elapsed >= tl.thank_you_time:
		var ty_alpha: float = clampf((elapsed - tl.thank_you_time) / 0.5, 0.0, 1.0)
		_draw_ta_hud_text(Vector2(0, vp.y * 0.9), "THANK YOU FOR PLAYING !!", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 36, Color(1.0, 1.0, 1.0, ty_alpha))

	# 4. 操作ボタン（体験版のResult画面と同一のアイコン・配置・遷移関数を再利用）: THANK YOU 表示の3秒後から表示
	if elapsed >= tl.buttons_time:
		var btn_alpha: float = clampf((elapsed - tl.buttons_time) / 0.3, 0.0, 1.0)
		const NEXT_BTN_S: float = 128.0
		const IG_GAP: float = 120.0
		var ig_size: float = 88.0
		var next_cx: float = vp.x - 100.0 - NEXT_BTN_S * 0.5
		var ig_cy: float = vp.y - 100.0 - NEXT_BTN_S * 0.5
		var tw_cx: float = next_cx - ig_size - IG_GAP
		var cam_cx: float = tw_cx - ig_size - IG_GAP
		var icon_draw_size: float = ig_size * 1.50 * 0.90 * 1.50
		var res_act: int = get_results_active_focus(vp)
		_draw_result_camera_btn(Vector2(cam_cx - icon_draw_size * 0.5, ig_cy - icon_draw_size * 0.5), icon_draw_size, btn_alpha, res_act == 0)
		_draw_result_twitter_btn(Vector2(tw_cx - icon_draw_size * 0.5, ig_cy - icon_draw_size * 0.5), icon_draw_size, btn_alpha, res_act == 1)
		_draw_results_next_button(Vector2(next_cx, ig_cy), tr("TA_RESULT_BTN_TITLE"), 35, btn_alpha, NEXT_BTN_S, res_act == 2)


func _get_perimeter_pos_topleft_ui(d: float, bx: float, by: float, bw: float, bh: float) -> Vector2:
	var d0: float = bw
	var d1: float = d0 + bh
	var d2: float = d1 + bw
	var d3: float = d2 + bh
	if d < d0:
		return Vector2(bx + d, by)
	elif d < d1:
		return Vector2(bx + bw, by + (d - d0))
	elif d < d2:
		return Vector2(bx + bw - (d - d1), by + bh)
	elif d < d3:
		return Vector2(bx, by + bh - (d - d2))
	else:
		return Vector2(bx + (d - d3), by)


func _draw_border_line_topleft_ui(bx: float, by: float, bw: float, bh: float,
		tail_d: float, head_d: float, color: Color) -> void:
	var perimeter: float = 2.0 * (bw + bh)
	var d0: float = bw
	var d1: float = d0 + bh
	var d2: float = d1 + bw
	var d3: float = d2 + bh
	var vis_tail: float = maxf(tail_d, 0.0)
	var vis_head: float = minf(head_d, perimeter)
	if vis_tail >= vis_head:
		return
	var bp: Array[float] = [vis_tail, vis_head]
	for corner in [d0, d1, d2, d3]:
		if corner > vis_tail and corner < vis_head:
			bp.append(corner)
	bp.sort()
	for i in range(bp.size() - 1):
		var from_pos: Vector2 = _get_perimeter_pos_topleft_ui(bp[i],     bx, by, bw, bh)
		var to_pos:   Vector2 = _get_perimeter_pos_topleft_ui(bp[i + 1], bx, by, bw, bh)
		_game.draw_line(from_pos, to_pos, color, 5.0, true)


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
	if type_str == "fish" or type_str == "cat_face" or type_str == "rugby_ball":
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
		"hexagon":
			for i in range(6):
				var ah0: float = -PI * 0.5 + TAU * float(i) / 6.0
				var ah1: float = -PI * 0.5 + TAU * float(i + 1) / 6.0
				_game.draw_line(center + Vector2(cos(ah0), sin(ah0)) * r * 0.92, center + Vector2(cos(ah1), sin(ah1)) * r * 0.92, c, 2.0)
		"circle":
			_game.draw_arc(center, r, 0.0, TAU, nseg, c, 2.0)
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


func _draw_play_balance_debug(vp: Vector2) -> void:
	_draw_bg(vp)
	var accent: Color = Color(0.95, 0.19, 0.32)
	var text_c: Color = LINE_COLOR
	var muted_c: Color = Color(0.55, 0.50, 0.58)
	var panel: Rect2 = _game._pbd_panel_rect(vp)
	_game.draw_rect(panel, Color(1.0, 1.0, 1.0, 0.97))
	_game.draw_rect(panel, Color(0.85, 0.82, 0.86), false, 1.5)
	# ヘッダー
	_game.draw_string(_game.font_bold, Vector2(panel.position.x + 16.0, panel.position.y + 38.0),
		"バランス調整: " + _game._pbd_stage_label(),
		HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 32.0, 24, accent)
	_game.draw_line(
		Vector2(panel.position.x + 12.0, panel.position.y + _game.PBD_HEADER_H - 4.0),
		Vector2(panel.position.x + panel.size.x - 12.0, panel.position.y + _game.PBD_HEADER_H - 4.0),
		Color(0.90, 0.88, 0.92), 1.0)
	# フィールド行
	var fi: int = _game.stage_debug_state.field_focus_idx
	for i in range(_game.PBD_FIELD_KEYS.size()):
		var fk: String = _game.PBD_FIELD_KEYS[i]
		var lbl: String = _game.PBD_FIELD_LABELS[i]
		var val_rect: Rect2 = _game._pbd_field_value_rect(i, panel)
		var row_y_center: float = panel.position.y + _game.PBD_HEADER_H + i * _game.PBD_ROW_H + _game.PBD_ROW_H * 0.5
		# 区切り線
		if i > 0:
			_game.draw_line(
				Vector2(panel.position.x + 12.0, panel.position.y + _game.PBD_HEADER_H + i * _game.PBD_ROW_H),
				Vector2(panel.position.x + panel.size.x - 12.0, panel.position.y + _game.PBD_HEADER_H + i * _game.PBD_ROW_H),
				Color(0.93, 0.91, 0.95), 1.0)
		# ラベル
		_game.draw_string(_game.font, Vector2(panel.position.x + 16.0, row_y_center + 7.0),
			lbl, HORIZONTAL_ALIGNMENT_LEFT, 196.0, 15, text_c)
		# 値フィールド
		var focused: bool = i == fi
		var field_bg: Color = Color(0.95, 0.90, 0.97) if focused else Color(0.97, 0.96, 0.98)
		var field_border: Color = accent if focused else Color(0.80, 0.77, 0.84)
		_game.draw_rect(val_rect, field_bg)
		_game.draw_rect(val_rect, field_border, false, 1.5 if focused else 1.0)
		var display_text: String
		if focused:
			display_text = _game.stage_debug_state.edit_buffer + "|"
		else:
			display_text = _game.stage_debug_state.field_buffers.get(fk, "")
			# pending があれば強調
			var pending_dict: Dictionary = _game.stage_debug_state.pending.get(_game.current_stage, {}) as Dictionary
			if pending_dict.has(fk):
				field_border = Color(0.95, 0.60, 0.20)
				_game.draw_rect(val_rect, field_border, false, 1.5)
		_game.draw_string(_game.font, Vector2(val_rect.position.x + 8.0, val_rect.position.y + 24.0),
			display_text, HORIZONTAL_ALIGNMENT_LEFT, val_rect.size.x - 16.0, 16, text_c)
	# エラー / ステータス行
	if _game.stage_debug_state.last_error != "":
		var err_y: float = panel.position.y + _game.PBD_HEADER_H + _game.PBD_FIELD_KEYS.size() * _game.PBD_ROW_H + 8.0
		var err_c: Color = Color(0.20, 0.60, 0.30) if _game.stage_debug_state.last_error.begins_with("保存しました") else Color(0.90, 0.25, 0.18)
		_game.draw_string(_game.font, Vector2(panel.position.x + 16.0, err_y + 18.0),
			_game.stage_debug_state.last_error, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 32.0, 14, err_c)
	# ボタン行
	var btn_rects: Array[Rect2] = _game._pbd_btn_rects(panel)
	for bi in range(btn_rects.size()):
		var br: Rect2 = btn_rects[bi]
		var is_save_btn: bool = bi == 1
		var has_pending: bool = not (_game.stage_debug_state.pending.get(_game.current_stage, {}) as Dictionary).is_empty()
		var btn_accent: Color = accent if (is_save_btn and has_pending) else Color(0.45, 0.38, 0.52)
		_game.draw_rect(br, Color(btn_accent.r, btn_accent.g, btn_accent.b, 0.15))
		_game.draw_rect(br, btn_accent, false, 1.5)
		_game.draw_string(_game.font, Vector2(br.position.x + br.size.x * 0.5, br.position.y + 22.0),
			_game.PBD_BTN_LABELS[bi], HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 14, btn_accent)
	# 操作ガイド
	_game.draw_string(_game.font, Vector2(panel.position.x, panel.position.y + panel.size.y + 20.0),
		"クリックでフィールド選択  |  Tab: 次フィールド  |  ESC: ステージセレクトへ",
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 13, muted_c)


func _draw_stage_debug(vp: Vector2) -> void:
	_draw_bg(vp)
	var split: float = _game._stage_debug_split_x(vp)
	var list_bottom: float = vp.y - _game.STAGE_DEBUG_CONTENT_BOTTOM_MARGIN
	var accent: Color = Color(0.95, 0.19, 0.32)
	var text_c: Color = LINE_COLOR
	var guide_w: float = minf(vp.x - 280.0, 560.0)
	_game.draw_string(_game.font_bold, Vector2(24, 48), "STAGE DEBUG (F2)", HORIZONTAL_ALIGNMENT_LEFT, guide_w, 36, accent)
	_game.draw_string(_game.font, Vector2(24, 86), "ホイール: 慣性スクロール | ESC: タイトル | [C]=custom | 組み込みの恒久変更は res://…/builtin/*.json を編集（保存はカスタム行のみ）", HORIZONTAL_ALIGNMENT_LEFT, guide_w, 17, Color(0.35, 0.28, 0.35))
	if _game.stage_debug_state.last_error != "":
		_game.draw_string(_game.font, Vector2(24, 112), _game.stage_debug_state.last_error, HORIZONTAL_ALIGNMENT_LEFT, guide_w, 18, Color(0.95, 0.3, 0.2))
	if _game._debug_tools_enabled():
		var nr: Rect2 = _game._stage_debug_new_custom_button_rect(vp)
		_game.draw_rect(nr, Color(0.95, 0.19, 0.32, 0.2))
		_game.draw_rect(nr, LINE_COLOR, false, 2.0)
		_game.draw_string(_game.font, Vector2(nr.position.x + 8.0, nr.position.y + 21.0), "新規", HORIZONTAL_ALIGNMENT_LEFT, nr.size.x - 16.0, 13, LINE_COLOR)
	# 右側パネル（白）+ 区切り線
	var panel_top: float = _game._stage_debug_fields_start_y() - 8.0
	var panel_rect := Rect2(split + 4.0, panel_top, vp.x - split - 8.0, vp.y - panel_top - _game.STAGE_DEBUG_CONTENT_BOTTOM_MARGIN)
	_game.draw_rect(panel_rect, Color(1.0, 1.0, 1.0, 0.94))
	_game.draw_rect(panel_rect, Color(0.85, 0.82, 0.86), false, 1.5)
	_game.draw_line(Vector2(split, _game.STAGE_DEBUG_LIST_TOP_Y - 4.0), Vector2(split, vp.y - _game.STAGE_DEBUG_CONTENT_BOTTOM_MARGIN), text_c, 2.0)
	# 左: ステージ一覧（マスタ + user://custom_stages の Edit 産）
	var total_rows: int = _game._stage_debug_total_rows()
	var master_n: int = _game._stage_debug_master_count()
	var y0: float = _game.STAGE_DEBUG_LIST_TOP_Y - _game.stage_debug_state.scroll
	var fs: int = 16
	var list_left: float = 8.0
	var list_w: float = _game._stage_debug_list_width_for_split(split)
	var icon_r: float = minf(26.0, (_game.STAGE_DEBUG_ROW_H - 12.0) * 0.45)
	var prev_sz: float = minf(icon_r * 2.5, _game.STAGE_DEBUG_ROW_H - 10.0)
	for i in range(total_rows):
		var y: float = y0 + float(i) * _game.STAGE_DEBUG_ROW_H
		if y + _game.STAGE_DEBUG_ROW_H < _game.STAGE_DEBUG_LIST_TOP_Y or y > list_bottom:
			continue
		var cfg: Dictionary = {}
		var tname: String = "?"
		var derived_custom: Dictionary = {}
		var label_max_w: float = list_w - icon_r * 2.0 - 20.0
		if i < master_n:
			cfg = StageDebugOverrides.build_config_for_index(i, _game.stage_debug_state.pending.get(i, {}))
			tname = str(cfg.get("type", "?"))
		else:
			derived_custom = _game.stage_debug_state.custom_derived(_game._stage_debug_custom_path_at(i))
			label_max_w = list_w - prev_sz - 22.0
			cfg = derived_custom["cfg"] as Dictionary
			tname = derived_custom["tname"] as String
		var sel: bool = i == _game.stage_debug_state.selected
		var row_rect := Rect2(list_left, y, list_w, _game.STAGE_DEBUG_ROW_H - 4.0)
		if sel:
			_game.draw_rect(row_rect, Color(0.95, 0.19, 0.32, 0.14))
		_game.draw_rect(row_rect, Color(0.88, 0.86, 0.88), false, 1.5)
		var row_lbl: String = _game._stage_debug_list_row_label(i)
		_game.draw_string(_game.font, Vector2(list_left + 10.0, y + 30.0), row_lbl, HORIZONTAL_ALIGNMENT_LEFT, label_max_w, fs, text_c)
		# CLR バッジ（マスター行のみ・クリックで ON/OFF 切り替え）
		if i < master_n:
			var cleared_i: bool = StageSelectManager.get_state(i) == StageSelectManager.StageState.CLEARED
			var badge_r: Rect2 = _game._stage_debug_clear_badge_rect(y, list_left)
			if cleared_i:
				_game.draw_rect(badge_r, Color(0.95, 0.19, 0.32, 0.82))
			_game.draw_rect(badge_r, Color(0.95, 0.19, 0.32, 0.60) if cleared_i else Color(0.55, 0.50, 0.58, 0.70), false, 1.0)
			_game.draw_string(_game.font,
				Vector2(badge_r.position.x + 2.0, badge_r.position.y + 13.0),
				"CLR" if cleared_i else "---",
				HORIZONTAL_ALIGNMENT_CENTER, badge_r.size.x - 4.0, 11,
				Color.WHITE if cleared_i else Color(0.52, 0.47, 0.55))
		var icx: float = list_left + list_w - icon_r - 12.0
		var icy: float = y + _game.STAGE_DEBUG_ROW_H * 0.5 - 2.0
		var drew_preview: bool = false
		if i >= master_n and derived_custom.get("shape_ok", false):
			var pr: Rect2 = Rect2(icx - prev_sz * 0.5, icy - prev_sz * 0.5, prev_sz, prev_sz)
			_game.draw_rect(pr, Color(1.0, 1.0, 1.0, 0.92))
			_game.draw_rect(pr, Color(0.82, 0.8, 0.84), false, 1.0)
			var verts_pv: Array[Vector2] = derived_custom["verts"] as Array[Vector2]
			var edges_pv: Array[Dictionary] = derived_custom["edges"] as Array[Dictionary]
			_draw_stage_custom_shape_preview(verts_pv, edges_pv, pr, accent if sel else text_c)
			drew_preview = true
		if not drew_preview:
			_draw_stage_debug_type_icon(Vector2(icx, icy), icon_r, tname, accent if sel else text_c)
	# 左リスト右端（分割線寄り）のスクロールバー
	var smax_draw: float = _game._stage_debug_scroll_max(vp)
	var tr_sb: Rect2 = _game._stage_debug_scrollbar_track_rect(vp)
	_game.draw_rect(tr_sb, Color(0.91, 0.89, 0.93, 0.95))
	_game.draw_rect(tr_sb, Color(0.72, 0.69, 0.75), false, 1.0)
	if smax_draw > 0.5:
		var thumb_sb: Rect2 = _game._stage_debug_scrollbar_thumb_rect(vp)
		_game.draw_rect(thumb_sb, Color(0.78, 0.75, 0.82))
		_game.draw_rect(thumb_sb, Color(0.42, 0.36, 0.48), false, 1.0)
	# ボタン（テスト・保存・… | 右上 全リセット・戻る）— 保存はカスタム行のみ有効、組み込み行は無反応
	var rects: Array[Rect2] = _game._stage_debug_button_rects(vp)
	var bl: Array[String] = ["テスト", "保存", "図形編集", "設定リセット", "フォルダを開く", "全リセット", "戻る"]
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
		var buf: String = str(_game.stage_debug_state.field_buffers.get(fk, ""))
		var focus: bool = fi == _game.stage_debug_state.field_focus_idx
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
		_game.draw_rect(fr_val, accent if focus else LINE_COLOR, false, 5.75 if focus else 1.25)
		var show: String = buf
		if focus:
			show = _game.stage_debug_state.edit_buffer
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
		if _game._stage_debug_is_custom_row(_game.stage_debug_state.selected):
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
	var pv: Array[bool] = _game.stage_edit_state.mirror_preview
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
	var text_c: Color = LINE_COLOR
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
	var fn_focus: bool = _game.stage_edit_state.text_line == 0
	_game.draw_rect(fr, Color(1.0, 1.0, 1.0))
	_game.draw_rect(fr, accent if fn_focus else text_c, false, 3.0 if fn_focus else 1.5)
	_game.draw_string(_game.font, Vector2(fr.position.x + 6, fr.position.y + 20), _game.stage_edit_state.stage_id, HORIZONTAL_ALIGNMENT_LEFT, fr.size.x - 12, 16, text_c)
	_game.draw_string(_game.font, Vector2(panel_r.position.x, fr.position.y + fr.size.y + 12), "shape_type（クリックで選択）", HORIZONTAL_ALIGNMENT_LEFT, guide_w, 14, text_c)
	var n_types: int = _game.STAGE_EDIT_TYPE_OPTIONS.size()
	var tidx: int = clampi(_game.stage_edit_state.type_idx, 0, n_types - 1)
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
	if fish_on and _game.stage_edit_state.include_fish_shape:
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
		var verts: Array[Vector2] = _game.stage_edit_state.canvas_vertices
		var edges: Array = _game.stage_edit_state.canvas_edges
		var n: int = verts.size()
		_stage_edit_draw_mirror_previews(canvas_r, verts, edges, n)
		var hover_e: int = _game.stage_edit_state.canvas_hover_edge
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
			var on: bool = _game.stage_edit_state.mirror_preview[mi]
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
	if _game.stage_edit_state.last_error != "":
		_game.draw_string(_game.font, Vector2(panel_r.position.x, vp.y - 50), _game.stage_edit_state.last_error, HORIZONTAL_ALIGNMENT_LEFT, panel_r.size.x, 15, Color(0.95, 0.3, 0.2))
	_game.draw_string(_game.font, Vector2(40, vp.y - 22), "ESC: 戻る | Ctrl+Z 元に戻す | Ctrl+Y / Ctrl+Shift+Z やり直し | ◀▶▲▼ 鏡像プレビュー（クリックでオンオフ） | キャンバス: 左＝直線/ドラッグ 右＝円弧/削除", HORIZONTAL_ALIGNMENT_LEFT, vp.x - 80, 12, Color(0.45, 0.4, 0.48))


func _draw_debug_log_button(vp: Vector2) -> void:
	var w: float = 140.0
	var h: float = 36.0
	var r := Rect2(vp.x - w - 12.0, vp.y - h - 12.0, w, h)
	_game.draw_rect(r, Color(LINE_COLOR,0.55))
	_game.draw_rect(r, Color(1.0, 1.0, 1.0), false, 5.75)
	_game.draw_string(_game.font_bold, Vector2(r.position.x + 8, r.position.y + 24), "ログ出力", HORIZONTAL_ALIGNMENT_LEFT, w - 16, 18, Color(1.0, 1.0, 1.0))


func _draw_config(vp: Vector2) -> void:
	_draw_bg(vp)

	# 大きな「CONFIG」ロゴ（左上、少し切れる位置、spacing net -5px）
	if not _font_din_config_logo:
		_font_din_config_logo = FontVariation.new()
		_font_din_config_logo.base_font = _game.font_din
		_font_din_config_logo.set_spacing(TextServer.SPACING_GLYPH, -10)
	var big_fs: int = 400
	var big_y: float = _font_din_config_logo.get_ascent(big_fs) - 170.0
	_game.draw_string(_font_din_config_logo, Vector2(-20.0, big_y), "CONFIG", HORIZONTAL_ALIGNMENT_LEFT, -1, big_fs, Color(LINE_COLOR,0.2))

	# 装飾トライアングル（左下）
	var deco_w: float = 500.0
	_draw_tri_deco(Vector2(20.0, vp.y - deco_w * 0.9495 - 20.0), deco_w, Color(LINE_COLOR,0.2))

	var text_c := LINE_COLOR
	var sel_c := Color(0.95, 0.19, 0.32)
	var val_c := LINE_COLOR

	var base_y: float = vp.y * _game.CONFIG_MENU_BASE_Y_RATIO
	var spacing: float = _game.CONFIG_MENU_SPACING
	var lx: float = vp.x * _game.CONFIG_MENU_LX_RATIO
	var box_w: float = vp.x * _game.CONFIG_MENU_BOX_W_RATIO
	var label_fs: int = 36
	var box_h: float = (_game.font_din.get_ascent(50) + _game.font_din.get_descent(50)) * 1.5

	var item_labels: Array[String] = [
		tr("CONFIG_DISPLAY_MODE"),
		tr("CONFIG_MOUSE_CONFINE"),
		tr("CONFIG_LANGUAGE"),
		tr("CONFIG_BGM_VOLUME"),
		tr("CONFIG_SE_VOLUME"),
		tr("CONFIG_SE_SETTING"),
		tr("CONFIG_CREDIT"),
		tr("CONFIG_BACK"),
	]
	var item_values: Array[String] = [
		_game.config_row_display_mode_label(),
		_game.config_mouse_confine_ui_label(),
		_game.config_language_ui_label(),
		str(_game.bgm_volume),
		str(_game.se_volume),
		"",
		"",
		"",
	]

	var arrow_fs: int = 28

	for i in range(8):
		var item_y: float = base_y + i * spacing
		var is_sel: bool = (i == _game.config_index)
		if i >= 5:
			continue  # ボタン行は後続のセクションで描画
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
		_game.draw_rect(Rect2(box_rect.position + shadow_offset, box_rect.size), Color(LINE_COLOR,0.30))
		_game.draw_rect(box_rect, Color(1.0, 1.0, 1.0))
		_draw_rect_border_with_corners(box_rect, LINE_COLOR, 5.75)
		var val_font: Font = _game.font_din if (i == 3 or i == 4) else _game.font
		var val_fs: int = 50 if (i == 3 or i == 4) else (27 if i == 0 else 34)
		var val_baseline_y: float = box_rect.position.y + (bh + val_font.get_ascent(val_fs) - val_font.get_descent(val_fs)) * 0.5
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
			3:
				left_enabled = _game.bgm_volume > 0
				right_enabled = _game.bgm_volume < 10
			4:
				left_enabled = _game.se_volume > 0
				right_enabled = _game.se_volume < 10
		var down_x: float = Lp.x - aw * 0.5
		var down_c: Color = (sel_c if is_sel else text_c) if left_enabled else Color(LINE_COLOR,0.25)
		var down_baseline: float = box_rect.position.y + (bh + _game.font.get_ascent(arrow_fs) - _game.font.get_descent(arrow_fs)) * 0.5
		_game.draw_string(_game.font_bold, Vector2(down_x, down_baseline), "◀", HORIZONTAL_ALIGNMENT_CENTER, aw, arrow_fs, down_c)
		var up_x: float = Rp.x - aw * 0.5
		var up_c: Color = (sel_c if is_sel else text_c) if right_enabled else Color(LINE_COLOR,0.25)
		_game.draw_string(_game.font_bold, Vector2(up_x, down_baseline), "▶", HORIZONTAL_ALIGNMENT_CENTER, aw, arrow_fs, up_c)

	# --- 練習・クレジット・タイトルに戻る ボタン行（25px均等間隔）---
	var btn_h_act: float = (_game.font.get_ascent(BTN_FONT_SIZE) + _game.font.get_descent(BTN_FONT_SIZE)) * 1.5
	var btn_base_cy: float = base_y + 5.0 * spacing + btn_h_act * 0.5 - 16.0 + vp.y * 0.07 - 230.0
	for btn_i in range(3):
		var act_i: int = 5 + btn_i
		var btn_cy: float = btn_base_cy + float(btn_i) * (btn_h_act + 25.0)  # 25px間隔
		var is_sel_btn: bool = (act_i == _game.config_index)
		if act_i == 6:
			# スタッフクレジット本体はサイズ・位置とも変更しない
			var credit_is_on: bool = is_sel_btn and not (not GameConfig.IS_TRIAL and _game.config_row6_reset_selected)
			_draw_auto_button_with_shadow(Vector2(vp.x / 2.0, btn_cy), item_labels[act_i], BTN_FONT_SIZE, 1.0, not credit_is_on, 700.0)
			# その右に、間隔を空けて一回り小さい RESET ボタンを添える（製品版のみ）
			if not GameConfig.IS_TRIAL:
				var reset_rect: Rect2 = _game.get_config_reset_button_rect(vp)
				var reset_center := Vector2(reset_rect.position.x + reset_rect.size.x * 0.5,
											reset_rect.position.y + reset_rect.size.y * 0.5)
				var reset_is_on: bool = is_sel_btn and _game.config_row6_reset_selected
				_draw_auto_button_with_shadow(reset_center, "RESET", _game.CONFIG_RESET_BTN_FS, 1.0, not reset_is_on, _game.CONFIG_RESET_BTN_W)
		else:
			_draw_auto_button_with_shadow(Vector2(vp.x / 2.0, btn_cy), item_labels[act_i], BTN_FONT_SIZE, 1.0, not is_sel_btn, 700.0)

	# --- RESET 確認ダイアログ ---
	if _game.config_reset_confirm:
		_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.40))
		var cx: float = vp.x / 2.0
		var cy: float = vp.y / 2.0
		var dlg_w: float = 640.0
		var dlg_h: float = 260.0
		var dlg_rect := Rect2(cx - dlg_w * 0.5, cy - dlg_h * 0.5, dlg_w, dlg_h)
		_game.draw_rect(dlg_rect.grow(4.0), Color(0.95, 0.19, 0.32))
		_game.draw_rect(dlg_rect, Color(1.0, 0.98, 0.96))
		var msg_y: float = cy - dlg_h * 0.12
		_game.draw_string(_game.font, Vector2(cx - dlg_w * 0.5, msg_y),
			"プレイ履歴をすべて初期化しますか？",
			HORIZONTAL_ALIGNMENT_CENTER, dlg_w, 28, LINE_COLOR)
		var cbtn_gap: float = vp.x * 0.10
		var cbtn_cy: float = cy + dlg_h * 0.22
		var cbtn_w: float = vp.x * 0.16
		var yes_off: bool = _game.config_reset_confirm_index != 0
		var no_off: bool  = _game.config_reset_confirm_index != 1
		_draw_auto_button_with_shadow(Vector2(cx - cbtn_gap, cbtn_cy), tr("PAUSE_CONFIRM_YES"), BTN_FONT_SIZE, 1.0, yes_off, cbtn_w)
		_draw_auto_button_with_shadow(Vector2(cx + cbtn_gap, cbtn_cy), tr("PAUSE_CONFIRM_NO"),  BTN_FONT_SIZE, 1.0, no_off,  cbtn_w)



func _draw_se_config(vp: Vector2) -> void:
	_draw_bg(vp)

	# 背景大文字
	if not _font_din_config_logo:
		_font_din_config_logo = FontVariation.new()
		_font_din_config_logo.base_font = _game.font_din
		_font_din_config_logo.set_spacing(TextServer.SPACING_GLYPH, -10)
	var big_fs: int = 400
	var big_y: float = _font_din_config_logo.get_ascent(big_fs) - 170.0
	_game.draw_string(_font_din_config_logo, Vector2(-20.0, big_y), "SE", HORIZONTAL_ALIGNMENT_LEFT, -1, big_fs, Color(LINE_COLOR, 0.12))

	# 装飾トライアングル（左下）
	var deco_w: float = 500.0
	_draw_tri_deco(Vector2(20.0, vp.y - deco_w * 0.9495 - 20.0), deco_w, Color(LINE_COLOR, 0.2))

	const COL_OUT   := Color("#EB2E61")   # 斥力 pink
	const COL_OUT_DIM := Color(0.80, 0.35, 0.48, 0.45)
	const COL_IN    := Color("#338FFF")   # 引力 cyan
	const COL_IN_DIM  := Color(0.20, 0.55, 1.00, 0.45)
	const RADIO_R   := 14.0
	const LABEL_FS  := 32
	const TITLE_FS  := 38

	var ry0:   float = vp.y * 0.37
	var ystep: float = 85.0

	# ── 左パネル (OUT / 斥力) ──────────────────────────────────
	var out_rx: float = 200.0
	var panel_lx: float = 80.0
	var panel_w:  float = 400.0

	var title_ascent: float = _game.font_bold.get_ascent(TITLE_FS)
	var title_y: float = ry0 - 60.0 + title_ascent
	_game.draw_string(_game.font_bold,
		Vector2(panel_lx, title_y),
		"OUT", HORIZONTAL_ALIGNMENT_LEFT, panel_w, TITLE_FS, COL_OUT)

	var cnt_out: int = DebugSFXConfig.out_count
	var sel_out: int = DebugSFXConfig.out_idx
	var label_ascent: float = _game.font.get_ascent(LABEL_FS)
	for i in range(cnt_out):
		var cy: float = ry0 + i * ystep
		var is_sel: bool = (i == sel_out)
		var col: Color = COL_OUT if is_sel else COL_OUT_DIM
		if is_sel:
			# 選択行ハイライト背景
			_game.draw_rect(Rect2(panel_lx, cy - 30.0, panel_w, 60.0), Color(COL_OUT, 0.08))
		# ラジオ円：外枠
		_game.draw_arc(Vector2(out_rx, cy), RADIO_R, 0.0, TAU, 32, col, 2.5, true)
		if is_sel:
			_game.draw_circle(Vector2(out_rx, cy), RADIO_R * 0.55, col)
		# ラベル
		var lbl_x: float = out_rx + RADIO_R + 16.0
		var lbl_y: float = cy + label_ascent * 0.5
		_game.draw_string(_game.font, Vector2(lbl_x, lbl_y),
			"SE %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, 200.0, LABEL_FS, col)

	# ── 右パネル (IN / 引力) ──────────────────────────────────
	var in_rx:   float = vp.x - 200.0
	var panel_rx: float = vp.x - 80.0  # 右端

	_game.draw_string(_game.font_bold,
		Vector2(panel_rx - panel_w, title_y),
		"IN", HORIZONTAL_ALIGNMENT_RIGHT, panel_w, TITLE_FS, COL_IN)

	var cnt_in: int = DebugSFXConfig.in_count
	var sel_in: int = DebugSFXConfig.in_idx
	for i in range(cnt_in):
		var cy: float = ry0 + i * ystep
		var is_sel: bool = (i == sel_in)
		var col: Color = COL_IN if is_sel else COL_IN_DIM
		if is_sel:
			_game.draw_rect(Rect2(panel_rx - panel_w, cy - 30.0, panel_w, 60.0), Color(COL_IN, 0.08))
		var lbl_x: float = in_rx - RADIO_R - 16.0
		var lbl_y: float = cy + label_ascent * 0.5
		_game.draw_string(_game.font, Vector2(lbl_x - 180.0, lbl_y),
			"SE %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, 180.0, LABEL_FS, col)
		_game.draw_arc(Vector2(in_rx, cy), RADIO_R, 0.0, TAU, 32, col, 2.5, true)
		if is_sel:
			_game.draw_circle(Vector2(in_rx, cy), RADIO_R * 0.55, col)

	# ── 中央: オクタゴン + 波紋エフェクト ───────────────────────
	var cx: float = vp.x * 0.5
	var cy_c: float = vp.y * 0.50
	const OCT_R:  float = 185.0   # オクタゴン外接円半径（インゲームの force field 相当）
	const CORE_R: float = 16.0    # プレイヤーアバター半径（InputHandler.PLAYER_RADIUS と同値）

	# 波紋エフェクト（テスト中のみ。インゲームの _draw_player_force_influence_visual を流用）
	if _game._sfx_ui_in_active or _game._sfx_ui_out_active:
		var attracting: bool = _game._sfx_ui_in_active   # true=引力(IN/cyan), false=斥力(OUT/pink)
		_draw_player_force_influence_visual(Vector2(cx, cy_c), CORE_R, OCT_R, attracting, 1.0)

	# オクタゴン（8頂点を順につなぐ。インゲームの draw_stage_lines と同ロジック）
	var oct_pts := PackedVector2Array()
	for i in range(8):
		var a: float = float(i) * TAU / 8.0 - PI / 2.0  # 上頂点から時計回り
		oct_pts.append(Vector2(cx + OCT_R * cos(a), cy_c + OCT_R * sin(a)))
	for i in range(8):
		_game.draw_line(oct_pts[i], oct_pts[(i + 1) % 8], LINE_COLOR, LINE_WIDTH, true)
	for p in oct_pts:
		_game.draw_circle(p, POINT_RADIUS, LINE_COLOR)

	# プレイヤーアバター（中心円）
	_game.draw_circle(Vector2(cx, cy_c), CORE_R, LINE_COLOR)

	# 「テスト中」インジケーター
	if _game._sfx_ui_out_active:
		_game.draw_string(_game.font_bold, Vector2(cx - 200.0, cy_c - OCT_R - 40.0),
			"▶ OUT テスト中", HORIZONTAL_ALIGNMENT_CENTER, 400.0, 28, COL_OUT)
	elif _game._sfx_ui_in_active:
		_game.draw_string(_game.font_bold, Vector2(cx - 200.0, cy_c - OCT_R - 40.0),
			"▶ IN テスト中", HORIZONTAL_ALIGNMENT_CENTER, 400.0, 28, COL_IN)

	# ── 操作ヒント ────────────────────────────────────────────
	const HINT_FS := 24
	var hint_c := Color(LINE_COLOR, 0.55)
	var hint_y_pad: float = vp.y - 80.0
	var hint_y_ctrl: float = vp.y - 48.0

	_game.draw_string(_game.font, Vector2(0.0, hint_y_pad),
		"左クリック: OUTテスト  /  右クリック: INテスト",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, HINT_FS, hint_c)
	_game.draw_string(_game.font, Vector2(0.0, hint_y_ctrl),
		"L/LT: OUT選択▲▼   A: OUTテスト   R/RT: IN選択▲▼   X: INテスト   ESC/START: 保存して戻る",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, HINT_FS, hint_c)


func _draw_credit(vp: Vector2) -> void:
	_draw_bg(vp)

	# ── タイトルロゴ「KATA-DRAW / STAFF」— 別Labelオブジェクト、上端基準で20px間隔 ──
	if not _font_din_config_logo:
		_font_din_config_logo = FontVariation.new()
		_font_din_config_logo.base_font = _game.font_din
		_font_din_config_logo.set_spacing(TextServer.SPACING_GLYPH, -10)

	# ラベルを初回だけ生成してゲームノードの子に追加
	if _credit_kata_lbl == null:
		_credit_kata_lbl = Label.new()
		_credit_kata_lbl.text = "KATA-DRAW"
		_credit_kata_lbl.add_theme_font_override("font", _font_din_config_logo)
		_credit_kata_lbl.add_theme_font_size_override("font_size", 280)
		_credit_kata_lbl.add_theme_color_override("font_color", Color(LINE_COLOR,0.2))
		_credit_kata_lbl.clip_text = false
		_credit_kata_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_game.add_child(_credit_kata_lbl)

		_credit_staff_lbl = Label.new()
		_credit_staff_lbl.text = "STAFF"
		_credit_staff_lbl.add_theme_font_override("font", _font_din_config_logo)
		_credit_staff_lbl.add_theme_font_size_override("font_size", 280)
		_credit_staff_lbl.add_theme_color_override("font_color", Color(LINE_COLOR,0.2))
		_credit_staff_lbl.clip_text = false
		_credit_staff_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_game.add_child(_credit_staff_lbl)

	# KATA-DRAW: 上端を画面上端から -100px（少し上にはみ出し）
	_credit_kata_lbl.position = Vector2(-20.0, -100.0)
	_credit_kata_lbl.visible = true

	# KATA-DRAW の下端から20px空けて STAFF を配置
	# get_minimum_size().y = Label が必要とする実際の高さ
	var kata_h: float = _credit_kata_lbl.get_minimum_size().y
	_credit_staff_lbl.position = Vector2(-20.0, _credit_kata_lbl.position.y + kata_h + 20.0 - 200.0)
	_credit_staff_lbl.visible = true

	# ── クレジット本文 ──
	var text_col := LINE_COLOR
	var content_fs: int = 30
	var line_h: float = _game.font_din.get_ascent(content_fs) + _game.font_din.get_descent(content_fs) + 8.0
	var cx: float = vp.x * 0.5 - 600.0
	var start_y: float = vp.y * 0.38 - 270.0
	var lines: Array[String] = [
		"Producer / Director / UI&Logo Design : Kionachi",
		"Planner : Hirame Kumokura",
		"Stage Editing / Web Design : Irori Hibachi",
		"Title Music Composition / Sound Effect Design : tigerlily",
		"Cat : Ohagi",
		"",
		"Music Support : Diverse System",
		"  Clockwork Prophet / Solvrae",
		"  Micro'n'Macro / taqumi",
		"  TRANSFER / ZiXS",
		"  Thinking Time / U-Ruri",
		"  Small Routines / Yebisu303",
		"Licenced by Diverse System (works.16)",
		"",
		"production work : 2026 Meseed Software",
	]
	for idx in range(lines.size()):
		var ly: float = start_y + idx * line_h + _game.font_din.get_ascent(content_fs)
		_game.draw_string(_game.font_din, Vector2(cx, ly), lines[idx], HORIZONTAL_ALIGNMENT_CENTER, -1, content_fs, text_col)


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


func _get_ui_texture(filename: String) -> Texture2D:
	if _ui_texture_cache.has(filename):
		return _ui_texture_cache[filename] as Texture2D
	var path: String = _UI_ASSETS_DIR + filename
	var t: Texture2D = load(path) as Texture2D
	if t == null:
		push_warning("UIRenderer: failed to load texture: " + path)
	_ui_texture_cache[filename] = t
	return t


func _draw_ui_texture_centered(tex: Texture2D, center: Vector2, max_side: float) -> void:
	if tex == null:
		return
	var sz: Vector2 = tex.get_size()
	if sz.x < 1.0 or sz.y < 1.0:
		return
	var scale: float = max_side / maxf(sz.x, sz.y)
	var w: float = sz.x * scale
	var h: float = sz.y * scale
	var r: Rect2 = Rect2(center.x - w * 0.5, center.y - h * 0.5, w, h)
	_game.draw_texture_rect(tex, r, false, Color.WHITE)


## rules（デモ）: 上半分中央に操作デモ用の統合画像（Xbox コントローラ）
func _draw_rules_demo_control_images(vp: Vector2, shift_down: float) -> void:
	var tex: Texture2D = _get_ui_texture("demo_controller_xbox.png")
	if tex == null:
		return
	var vmin: float = minf(vp.x, vp.y)
	var max_side: float = vmin * RULES_CTRL_IMAGES_SIZE_FRAC
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * RULES_CTRL_IMAGES_CENTER_Y_FRAC + shift_down
	_draw_ui_texture_centered(tex, Vector2(cx, cy), max_side)


## playing: ステージ種別ごとに左下角付近でコントローラ画像を一定周期で切り替え
func _draw_stage_playing_controller_hint(vp: Vector2) -> void:
	if _game.game_state != "playing" or StageSelectManager.time_attack_active:
		return
	var t_first: float = 0.5
	var t_second: float
	var second_file: String
	match _game.stage_type:
		"triangle":
			t_second = 0.5
			second_file = "con_bt_A1.png"
		"square":
			t_second = 2.5
			second_file = "con_bt_A1.png"
		"hexagon":
			t_second = 2.5
			second_file = "con_bt_X1.png"
		_:
			return
	var cycle: float = t_first + t_second
	var now: float = Time.get_ticks_msec() / 1000.0
	var ph: float = fmod(now, cycle)
	var use_base: bool = ph < t_first
	var fname: String = "con_bt_non.png" if use_base else second_file
	var tex: Texture2D = _get_ui_texture(fname)
	if tex == null:
		return
	var vmin: float = minf(vp.x, vp.y)
	var max_side: float = vmin * STAGE_CTRL_HINT_SIZE_FRAC
	var sz: Vector2 = tex.get_size()
	var scale: float = max_side / maxf(sz.x, sz.y)
	var center: Vector2 = Vector2(
		STAGE_CTRL_HINT_BL_MARGIN_LEFT_PX + sz.x * scale * 0.5,
		vp.y - STAGE_CTRL_HINT_BL_MARGIN_BOTTOM_PX - sz.y * scale * 0.5
	)
	_draw_ui_texture_centered(tex, center, max_side)


## ステージ1〜3: ボタン押下ヒント（bt_hand.png + bt_A/X_ph1/2.png）。
## 既存コントローラーヒントと同周期で ON/OFF を切り替え、手画像を上下にアニメーションさせる。
## ダミー自キャラ＋波紋より奥（背面）に描画する（呼び出し順で制御）。
func _draw_stage_playing_press_hint(vp: Vector2) -> void:
	if _game.game_state != "playing" or StageSelectManager.time_attack_active:
		return
	var ph1_name: String
	var ph2_name: String
	var t_second: float
	match _game.stage_type:
		"triangle":
			ph1_name = "bt_A_ph1.png"
			ph2_name = "bt_A_ph2.png"
			t_second = 0.5
		"square":
			ph1_name = "bt_A_ph1.png"
			ph2_name = "bt_A_ph2.png"
			t_second = 2.5
		"hexagon":
			ph1_name = "bt_X_ph1.png"
			ph2_name = "bt_X_ph2.png"
			t_second = 2.5
		_:
			return
	var t_first: float = 0.5
	var cycle: float = t_first + t_second
	var now: float = Time.get_ticks_msec() / 1000.0
	var ph: float = fmod(now, cycle)
	var use_base: bool = ph < t_first  # true=「押していない」（con_bt_non 相当）

	var bar_tex: Texture2D = _get_ui_texture(ph2_name if use_base else ph1_name)
	var hand_tex: Texture2D = _get_ui_texture("bt_hand.png")
	var con_tex: Texture2D = _get_ui_texture("con_bt_non.png")
	if bar_tex == null or hand_tex == null or con_tex == null:
		return

	# con_bt画像と同じスケール・原点を使う（マウス/パッドと同じ縮尺で配置するため）
	var vmin: float = minf(vp.x, vp.y)
	var max_side: float = vmin * STAGE_CTRL_HINT_SIZE_FRAC
	var con_sz_raw: Vector2 = con_tex.get_size()  # 505 x 624
	var con_scale: float = max_side / maxf(con_sz_raw.x, con_sz_raw.y)
	var con_topleft: Vector2 = Vector2(
		STAGE_CTRL_HINT_BL_MARGIN_LEFT_PX,
		vp.y - STAGE_CTRL_HINT_BL_MARGIN_BOTTOM_PX - con_sz_raw.y * con_scale
	)

	# con_bt_non.png（505×624）上のマウス右側空きスペース中心（ローカル座標）
	var gap_center_local := Vector2(388.0, 130.0)
	var bar_center: Vector2 = con_topleft + gap_center_local * con_scale

	var bar_sz_raw: Vector2 = bar_tex.get_size()  # 141 x 37
	var bar_h: float = bar_sz_raw.y * con_scale
	var bar_max_side: float = maxf(bar_sz_raw.x, bar_sz_raw.y) * con_scale

	var hand_sz_raw: Vector2 = hand_tex.get_size()  # 141 x 121
	var hand_h: float = hand_sz_raw.y * con_scale
	var hand_max_side: float = maxf(hand_sz_raw.x, hand_sz_raw.y) * con_scale

	var not_pressed_y: float = bar_center.y - bar_h * 0.5 - hand_h * 0.5
	var pressed_y: float = not_pressed_y + bar_h * 0.5
	var target_y: float = not_pressed_y if use_base else pressed_y

	if not is_equal_approx(_press_hint_target_y, target_y):
		_press_hint_anim_from_y = _press_hint_current_y if _press_hint_anim_start > 0.0 else target_y
		_press_hint_target_y = target_y
		_press_hint_anim_start = now

	var anim_t: float = clampf((now - _press_hint_anim_start) / PRESS_HINT_ANIM_DUR, 0.0, 1.0)
	var eased_t: float = anim_t * anim_t * (3.0 - 2.0 * anim_t)
	_press_hint_current_y = lerpf(_press_hint_anim_from_y, _press_hint_target_y, eased_t)

	_draw_ui_texture_centered(bar_tex, bar_center, bar_max_side)
	_draw_ui_texture_centered(hand_tex, Vector2(bar_center.x, _press_hint_current_y), hand_max_side)


## square のみ: 「A でピンクの斥力圏」説明ループ（0.5s 非表示→2.5s 拡大）
func _draw_square_stage_repulse_demo(vp: Vector2) -> void:
	if _game.game_state != "playing" or _game.stage_type != "square" or StageSelectManager.time_attack_active:
		return
	var cycle: float = PLAYING_BTN_DEMO_PAUSE_SEC + PLAYING_BTN_DEMO_EXPAND_SEC
	var t: float = fmod(Time.get_ticks_msec() * 0.001, cycle)
	if t < PLAYING_BTN_DEMO_PAUSE_SEC:
		return
	var u: float = (t - PLAYING_BTN_DEMO_PAUSE_SEC) / PLAYING_BTN_DEMO_EXPAND_SEC
	var ease: float = u * u * (3.0 - 2.0 * u)
	var vmin: float = minf(vp.x, vp.y)
	var ctrl_y: float = vp.y - STAGE_CTRL_HINT_BL_MARGIN_BOTTOM_PX - vmin * STAGE_CTRL_HINT_SIZE_FRAC * 0.5
	var center := Vector2(
		vp.x * PLAYING_BTN_DEMO_CENTER_X_FRAC,
		ctrl_y - vmin * PLAYING_BTN_DEMO_ABOVE_CONTROLLER_FRAC
	)
	var dm: float = 0.5
	var core_r: float = InputHandler.PLAYER_RADIUS
	var max_r: float = vmin * PLAYING_BTN_DEMO_MAX_R_FRAC
	var ring_r: float = lerpf(core_r * 1.25, max_r, ease)
	var fill_a: float = clampf(lerpf(0.14, 0.06, ease) * dm * PLAYING_BTN_DEMO_RING_ALPHA_MUL, 0.0, 1.0)
	var fill_c: Color = Color(PLAYER_FORCE_FIELD_FILL_REPEL.r, PLAYER_FORCE_FIELD_FILL_REPEL.g, PLAYER_FORCE_FIELD_FILL_REPEL.b, fill_a)
	_game.draw_circle(center, ring_r, fill_c)
	var edge_a: float = clampf(lerpf(0.55, 0.22, ease) * dm * PLAYING_BTN_DEMO_RING_ALPHA_MUL, 0.0, 1.0)
	_game.draw_arc(center, ring_r, 0.0, TAU, 72, Color(0.98, 0.38, 0.55, edge_a), 3.5, true)
	_game.draw_circle(center, core_r * 1.45, Color(LINE_COLOR,0.92 * dm))
	_game.draw_circle(center, core_r, Color(LINE_COLOR,1.0 * dm))
	_game.draw_circle(center, core_r * 0.28, Color(1.0, 1.0, 1.0, 0.95 * dm))


## hexagon のみ: 「X で水色の引力圏」（square のピンクと同構成）
func _draw_hexagon_stage_attract_demo(vp: Vector2) -> void:
	if _game.game_state != "playing" or _game.stage_type != "hexagon" or StageSelectManager.time_attack_active:
		return
	var cycle: float = PLAYING_BTN_DEMO_PAUSE_SEC + PLAYING_BTN_DEMO_EXPAND_SEC
	var tt: float = fmod(Time.get_ticks_msec() * 0.001, cycle)
	if tt < PLAYING_BTN_DEMO_PAUSE_SEC:
		return
	var u: float = (tt - PLAYING_BTN_DEMO_PAUSE_SEC) / PLAYING_BTN_DEMO_EXPAND_SEC
	var ease: float = u * u * (3.0 - 2.0 * u)
	var vmin: float = minf(vp.x, vp.y)
	var ctrl_y: float = vp.y - STAGE_CTRL_HINT_BL_MARGIN_BOTTOM_PX - vmin * STAGE_CTRL_HINT_SIZE_FRAC * 0.5
	var center := Vector2(
		vp.x * PLAYING_BTN_DEMO_CENTER_X_FRAC,
		ctrl_y - vmin * PLAYING_BTN_DEMO_ABOVE_CONTROLLER_FRAC
	)
	var dm: float = 0.5
	var core_r: float = InputHandler.PLAYER_RADIUS
	var max_r: float = vmin * PLAYING_BTN_DEMO_MAX_R_FRAC
	var ring_r: float = lerpf(core_r * 1.25, max_r, ease)
	var fill_a: float = clampf(lerpf(0.16, 0.05, ease) * dm * PLAYING_BTN_DEMO_RING_ALPHA_MUL, 0.0, 1.0)
	var fill_c: Color = Color(
		PLAYER_FORCE_FIELD_FILL_ATTRACT.r,
		PLAYER_FORCE_FIELD_FILL_ATTRACT.g,
		PLAYER_FORCE_FIELD_FILL_ATTRACT.b,
		fill_a
	)
	_game.draw_circle(center, ring_r, fill_c)
	var edge_a: float = clampf(lerpf(0.52, 0.2, ease) * dm * PLAYING_BTN_DEMO_RING_ALPHA_MUL, 0.0, 1.0)
	_game.draw_arc(center, ring_r, 0.0, TAU, 72, Color(0.42, 0.82, 1.0, edge_a), 3.5, true)
	var dummy_avatar_r: float = core_r * 0.25
	_game.draw_circle(center, dummy_avatar_r * 1.45, Color(LINE_COLOR,0.92 * dm))
	_game.draw_circle(center, dummy_avatar_r, Color(LINE_COLOR,1.0 * dm))
	_game.draw_circle(center, dummy_avatar_r * 0.28, Color(1.0, 1.0, 1.0, 0.95 * dm))


## タイムアタックHUD用: 背景パネルなしでも視認できるよう、暗い縁取り＋明るい文字色で描画する。
func _draw_ta_hud_text(pos: Vector2, text: String, align: HorizontalAlignment, width: float, fs: int, main_color: Color, font: Font = null) -> void:
	var f: Font = font if font != null else _game.font
	var shadow_c := Color(0.12, 0.08, 0.10, 0.85)
	var offsets: Array[Vector2] = [
		Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5),
		Vector2(0, -2), Vector2(0, 2), Vector2(-2, 0), Vector2(2, 0),
	]
	for o in offsets:
		_game.draw_string(f, pos + o, text, align, width, fs, shadow_c)
	_game.draw_string(f, pos, text, align, width, fs, main_color)


## タイムアタックHUD用: 現在プレイ中ステージの目標図形を、実際の理想形状（曲線サンプル済み）で描画する。
## _game.ideal_outline_points は重心中心・最大半径1.0に正規化済みのため、center + p * r でそのままスケールできる。
## 三角形・四角形・ひし形・六角形・円・カスタム形状のすべてでこの点列が生成されるため、形状ごとの分岐は不要。
func _draw_ta_target_shape_icon(center: Vector2, r: float) -> void:
	var outline: Array = _game.ideal_outline_points
	if outline.is_empty():
		return
	var pts := PackedVector2Array()
	for p in outline:
		pts.append(center + (p as Vector2) * r)
	if pts.size() < 2:
		return
	_game.draw_colored_polygon(pts, Color(0.95, 0.19, 0.32, 0.28))
	_game.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 1.0, 1.0), 2.5)


## タイムアタックHUD＝「ラップタイムパネル」。
## 自キャラの位置により _game._ta_hud_side（"left"/"right"）で表示側が切り替わる。
## 構成: 0.ガイドアイコン（目標図形） 1.ラップ履歴（直近クリアした最大2ステージ分） 2.カレントラップ（現在プレイ中ステージのライブタイマー）
func _draw_ta_hud(vp: Vector2) -> void:
	if not StageSelectManager.time_attack_active or _game.game_state != "playing":
		return

	var is_right: bool = _game._ta_hud_side == "right"
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT if is_right else HORIZONTAL_ALIGNMENT_LEFT
	var margin: float = 40.0        # 画面左右の端からの余白
	var top_margin: float = 40.0    # 画面上端からの余白
	var text_w: float = 600.0
	var text_x: float = (vp.x - margin - text_w) if is_right else margin
	var row_h: float = 88.0
	var fs_value: int = 56
	var fs_badge: int = 28
	var value_color := Color(1.0, 1.0, 1.0)
	var badge_color := Color(0.98, 0.35, 0.42)
	var current_lap_gap: float = 32.0   # ラップ履歴とカレントラップの間の追加スペース（別グループであることを示す）

	# 0. ガイドアイコン（目標図形）
	var icon_r: float = 92.0
	var icon_cx: float = (vp.x - margin - icon_r) if is_right else (margin + icon_r)
	var icon_cy: float = top_margin + icon_r
	_draw_ta_target_shape_icon(Vector2(icon_cx, icon_cy), icon_r)

	# 1. ラップ履歴（直近クリアした最大2ステージ分のタイム。新記録は NEWバッジ付き）
	var times: Array[float] = _game.stage_session.stage_times
	var flags: Array[bool] = _game.ta_run_new_record_flags
	var recent_count: int = mini(2, times.size())

	var y: float = icon_cy + icon_r + 32.0
	for i in range(recent_count):
		var idx: int = times.size() - recent_count + i
		var stage_no: String = "%02d" % (idx + 1)
		var row_text: String = "%s: %.2f" % [stage_no, times[idx]]
		if idx < flags.size() and flags[idx]:
			_draw_ta_hud_text(Vector2(text_x, y), tr("TA_HUD_NEW"), align, text_w, fs_badge, badge_color)
			y += fs_badge + 8.0
		_draw_ta_hud_text(Vector2(text_x, y + fs_value), row_text, align, text_w, fs_value, value_color, _font_din_num)
		y += row_h

	# ラップ履歴が1件以上あるときだけ、カレントラップとの間に追加の余白を入れる
	if recent_count > 0:
		y += current_lap_gap

	# 2. カレントラップ（現在プレイ中ステージのライブタイマー）
	var live_time: float = maxf(0.0, Time.get_ticks_msec() / 1000.0 - _game.start_time)
	var cur_no: String = "%02d" % (_game.current_stage + 1)
	var cur_text: String = "%s: %.2f" % [cur_no, live_time]
	_draw_ta_hud_text(Vector2(text_x, y + fs_value), cur_text, align, text_w, fs_value, value_color, _font_din_num)


# --- 操作説明の共通定義（rules / ポーズの操作説明で共有） ---
# 各要素: [key_tr, desc_tr, key_width]
const _CTRL_MOUSE_ITEMS: Array[Array] = [
	["CTRL_MOUSE_REPEL_KEY", "CTRL_MOUSE_REPEL_DESC", 200],
	["CTRL_MOUSE_ATTRACT_KEY", "CTRL_MOUSE_ATTRACT_DESC", 200],
]
const _CTRL_PAD_ITEMS: Array[Array] = [
	["CTRL_PAD_LSTICK_KEY", "CTRL_PAD_LSTICK_DESC", 180],
	["CTRL_PAD_A_KEY", "CTRL_PAD_A_REPEL_DESC", 180],
	["CTRL_PAD_X_KEY", "CTRL_PAD_X_ATTRACT_DESC", 180],
	["CTRL_PAD_A_CHARGE_KEY", "CTRL_PAD_A_CHARGE_DESC", 180],
	["CTRL_PAD_X_CHARGE_KEY", "CTRL_PAD_X_CHARGE_DESC", 180],
]


func _draw_controls_stacked(vp: Vector2, top_y: float) -> float:
	"""操作説明を縦スタック表示。ヘッダーと最初の項目を同一行に配置。戻り値=描画終了Y"""
	var head_c := LINE_COLOR
	var text_c := Color(0.35, 0.28, 0.35)
	var key_c := Color(0.95, 0.19, 0.32)
	var bar_c := Color(LINE_COLOR,0.4)

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

	# --- マウスセクション（ヘッダー行 + 項目を下に続ける） ---
	var mouse_section_top: float = y
	_game.draw_string(_game.font, Vector2(label_x, y), tr("CTRL_MOUSE_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_h, head_c)
	if _CTRL_MOUSE_ITEMS.size() > 0:
		var item0: Array = _CTRL_MOUSE_ITEMS[0]
		_game.draw_string(_game.font, Vector2(key_x, y), tr(item0[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, key_c)
		_game.draw_string(_game.font, Vector2(desc_x, y), tr(item0[1]), HORIZONTAL_ALIGNMENT_LEFT, desc_w, fs, text_c)
	y += line_h
	for mi in range(1, _CTRL_MOUSE_ITEMS.size()):
		var item_m: Array = _CTRL_MOUSE_ITEMS[mi]
		_game.draw_string(_game.font, Vector2(key_x, y), tr(item_m[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, key_c)
		_game.draw_string(_game.font, Vector2(desc_x, y), tr(item_m[1]), HORIZONTAL_ALIGNMENT_LEFT, desc_w, fs, text_c)
		y += line_h
	_game.draw_line(Vector2(bar_x, mouse_section_top - ascent_h + 4.0), Vector2(bar_x, y - line_h + 8.0), bar_c, 2.0, true)

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
	var head_c := LINE_COLOR
	var text_c := Color(0.35, 0.28, 0.35)
	var key_c := Color(0.95, 0.19, 0.32)
	var bar_c := Color(LINE_COLOR,0.4)

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
	var mouse_panel_top: float = y
	_game.draw_string(_game.font, Vector2(label_x, y), tr("CTRL_MOUSE_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_h, head_c)
	if _CTRL_MOUSE_ITEMS.size() > 0:
		var item0p: Array = _CTRL_MOUSE_ITEMS[0]
		_game.draw_string(_game.font, Vector2(key_x, y), tr(item0p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, key_c)
		_game.draw_string(_game.font, Vector2(desc_x, y), tr(item0p[1]), HORIZONTAL_ALIGNMENT_LEFT, desc_w, fs, text_c)
	y += line_h
	for mip in range(1, _CTRL_MOUSE_ITEMS.size()):
		var item_p: Array = _CTRL_MOUSE_ITEMS[mip]
		_game.draw_string(_game.font, Vector2(key_x, y), tr(item_p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, key_c)
		_game.draw_string(_game.font, Vector2(desc_x, y), tr(item_p[1]), HORIZONTAL_ALIGNMENT_LEFT, desc_w, fs, text_c)
		y += line_h
	_game.draw_line(Vector2(bar_x, mouse_panel_top - ascent_h + 4.0), Vector2(bar_x, y - line_h + 8.0), bar_c, 2.0, true)

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
	var head_c := LINE_COLOR
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


const ZOU_STAFF_ROLL_LINES: PackedStringArray = [
	"Producer / Director : Kionachi",
	"Planner : Hirame Kumokura",
	"Stage Editing / Web Design : Irori Hibachi",
	"Title Music Composition / Sound Effect Design : tigerlily",
	"Music Support : Diverse System",
	"  Clockwork Prophet / Solvrae",
	"  Micro'n'Macro / taqumi",
	"  TRANSFER / ZiXS",
	"  Thinking Time / U-Ruri",
	"  Small Routines / Yebisu303",
	"Licenced by Diverse System (works.16)",
]


func _draw_zou_staff_roll(vp: Vector2) -> void:
	if not _game._zou_roll_started:
		return
	var idx: int = _game._zou_roll_index
	if idx >= ZOU_STAFF_ROLL_LINES.size():
		return
	var fnt: Font = _game.font_din if _game.font_din != null else _game.font
	const FS: int = 24
	const DISPLAY_SEC: float = 10.0
	const FADEOUT_SEC: float = 3.0
	const GAP_SEC: float = 2.0
	const FADEIN_SEC: float = 3.0
	var x: float = vp.x * 0.5 - 600.0
	var y: float = 36.0 + fnt.get_ascent(FS)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _game._zou_roll_last_time
	var cur_alpha: float = 0.0
	var next_alpha: float = 0.0
	if elapsed < DISPLAY_SEC:
		cur_alpha = 1.0
	elif elapsed < DISPLAY_SEC + FADEOUT_SEC:
		cur_alpha = 1.0 - (elapsed - DISPLAY_SEC) / FADEOUT_SEC
	elif elapsed < DISPLAY_SEC + FADEOUT_SEC + GAP_SEC:
		pass  # 無音期間
	else:
		next_alpha = clampf((elapsed - DISPLAY_SEC - FADEOUT_SEC - GAP_SEC) / FADEIN_SEC, 0.0, 1.0)
	if cur_alpha > 0.0:
		_game.draw_string(fnt, Vector2(x, y), ZOU_STAFF_ROLL_LINES[idx],
			HORIZONTAL_ALIGNMENT_CENTER, -1, FS, Color(LINE_COLOR,0.75 * cur_alpha))
	if next_alpha > 0.0 and idx + 1 < ZOU_STAFF_ROLL_LINES.size():
		_game.draw_string(fnt, Vector2(x, y), ZOU_STAFF_ROLL_LINES[idx + 1],
			HORIZONTAL_ALIGNMENT_CENTER, -1, FS, Color(LINE_COLOR,0.75 * next_alpha))


func _draw_zou_ending(vp: Vector2) -> void:
	_game.draw_rect(Rect2(Vector2.ZERO, vp), Color.WHITE)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _game._zou_ending_start
	var alpha: float
	if elapsed < 1.0:
		alpha = 0.0
	elif elapsed < 4.0:
		alpha = (elapsed - 1.0) / 3.0
	elif elapsed < 14.0:
		alpha = 1.0
	elif elapsed < 17.0:
		alpha = 1.0 - (elapsed - 14.0) / 3.0
	else:
		alpha = 0.0
	if alpha > 0.001:
		var fnt: Font = _game.font_din if _game.font_din != null else _game.font
		const FS: int = 30
		var y: float = vp.y * 0.5 + fnt.get_ascent(FS) * 0.5 - fnt.get_descent(FS) * 0.5
		_game.draw_string(fnt, Vector2(0.0, y),
			"production work : 2026 Meseed Software",
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, FS, Color(0.0, 0.0, 0.0, alpha))


func _draw_zou_ta_unlock(vp: Vector2) -> void:
	_game.draw_rect(Rect2(Vector2.ZERO, vp), Color.WHITE)
	_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, _game._zou_ta_unlock_overlay_alpha))
	if _game._zou_ta_unlock_msg_visible:
		_draw_ta_unlock_dialog_box(vp)


func _draw_rules(vp: Vector2) -> void:
	_draw_bg(vp)

	var shift_down: float = vp.y * 0.15  # ルール部分+図形を15%下へ
	var shift_up: float = vp.y * 0.05    # ヒント+ボタンを5%上へ

	# 上部: タイトル（大きめ、Bold）— さらに10%上へ
	var title_c := LINE_COLOR
	_game.draw_string(_game.font_bold, Vector2(0, vp.y * 0.06 + shift_down - vp.y * 0.10), tr("RULES_MAIN"), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 46, title_c)

	# 操作デモ: 文言の代わりに demo_controller_xbox.png を上半分中央に表示
	_draw_rules_demo_control_images(vp, shift_down)

	# 本編と同じ HUD ガイド（物理の get_active_guide_loops と一致させるため shape_center で再計算）
	if GameConfig.USE_SCREEN_HUD_GUIDE:
		_game.stage_manager.recompute_hud_guide_layout_if_needed(_game.shape_center, vp)
		_game.guide_center_1 = _game.stage_manager.guide_center_1
		_stage_renderer.draw_hud_overlay_guide(0.7)
	_refresh_guide_point_distance_bounds()

	# 中央: デモ図形の線・頂点（自キャラは [つぎへ] の上に重ねる）
	_draw_rules_demo_lines_only(vp)

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

	_draw_rules_demo_player_layer(vp)


func _radius_from_guide_distance_provisional(dist: float) -> float:
	var t: float = clampf(dist / POINT_RADIUS_GUIDE_DIST_FULL_PX, 0.0, 1.0)
	return lerpf(POINT_RADIUS_GUIDE_NEAR_MIN, POINT_RADIUS_GUIDE_FAR_MAX, t)


func permute_guide_point_distances_for_vertex_reorder(ord: PackedInt32Array) -> void:
	var n: int = ord.size()
	if n == 0 or _guide_point_distances.size() != n:
		return
	var newd: Array[float] = []
	newd.resize(n)
	for i in range(n):
		newd[i] = _guide_point_distances[ord[i]]
	for i in range(n):
		_guide_point_distances[i] = newd[i]


func _refresh_guide_point_distance_bounds() -> void:
	_guide_dist_have_bounds = false
	_guide_point_distances.clear()
	if _game.game_state != "playing" and _game.game_state != "rules":
		return
	var n: int = _game.point_positions.size()
	if n == 0:
		return
	_guide_point_distances.resize(n)
	var first: bool = true
	for i in range(n):
		_guide_point_distances[i] = INF
		if _game._is_locked(i):
			continue
		var d: float = _game.stage_manager.get_distance_to_hint_guide_outline(_game.point_positions[i])
		_guide_point_distances[i] = d
		if first:
			_guide_dist_min = d
			_guide_dist_max = d
			first = false
		else:
			_guide_dist_min = minf(_guide_dist_min, d)
			_guide_dist_max = maxf(_guide_dist_max, d)
	_guide_dist_have_bounds = not first


func _point_radius_by_guide(idx: int) -> float:
	if (_game.game_state != "playing" and _game.game_state != "rules") or idx < 0 or idx >= _game.point_positions.size():
		return POINT_RADIUS
	var d: float = INF
	if idx < _guide_point_distances.size():
		d = _guide_point_distances[idx]
	if is_inf(d):
		d = _game.stage_manager.get_distance_to_hint_guide_outline(_game.point_positions[idx])
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


func _draw_rules_demo_lines_only(vp: Vector2) -> void:
	"""デモの線・頂点のみ（UIボタンより下のレイヤー）"""
	var n: int = _game.point_positions.size()
	if n == 0:
		return
	if _game.is_polygon_walk_order_active():
		var ord: PackedInt32Array = _game.polygon_walk_order
		for k in range(n):
			var a: int = ord[k]
			var b: int = ord[(k + 1) % n]
			_game.draw_line(_game.point_positions[a], _game.point_positions[b], LINE_COLOR, LINE_WIDTH, true)
	else:
		for i in range(n):
			_game.draw_line(_game.point_positions[i], _game.point_positions[(i + 1) % n], LINE_COLOR, LINE_WIDTH, true)
	var _dbg_hl: Dictionary = _game.input_handler._debug_reconnect_highlight
	var _dbg_now: int = Time.get_ticks_msec()
	for i in range(n):
		var pos: Vector2 = _game.point_positions[i]
		var r: float = _point_radius_by_guide(i)
		_game.draw_circle(pos, r, POINT_COLOR)
		# デバッグ: 再接続発火ポイントを赤円でハイライト
		if _dbg_hl.has(i):
			var _exp: int = _dbg_hl[i] as int
			if _dbg_now < _exp:
				var _fade: float = clampf(float(_exp - _dbg_now) / 500.0, 0.0, 1.0)
				_game.draw_circle(pos, r * 1.6, Color(1.0, 0.08, 0.08, 0.72 * _fade))
				_game.draw_arc(pos, r * 1.6, 0.0, TAU, 24, Color(1.0, 0.5, 0.1, _fade), 2.5, true)
			else:
				_dbg_hl.erase(i)


func _repro_get_display_value() -> float:
	if _repro_anim_start_msec < 0:
		return _repro_anim_to
	var elapsed: float = float(Time.get_ticks_msec() - _repro_anim_start_msec) / float(REPRO_ANIM_DURATION_MS)
	var t: float = minf(elapsed, 1.0)
	var t_eased: float = 1.0 - pow(1.0 - t, 2.0)  # ease-out quadratic
	return lerpf(_repro_anim_from, _repro_anim_to, t_eased)


func _repro_rate_float_on_metric(circ_val: float) -> void:
	if _repro_prev_stable < -500.0:
		_repro_prev_stable = circ_val
		_repro_anim_from = circ_val
		_repro_anim_to = circ_val
		return
	if absf(circ_val - _repro_prev_stable) > REPRO_FLOAT_CHANGE_MIN_PCT:
		_repro_anim_from = _repro_prev_stable
		_repro_anim_to = circ_val
		_repro_anim_start_msec = Time.get_ticks_msec()
		_repro_prev_stable = circ_val


func _repro_rate_should_show_temporary() -> bool:
	if _repro_anim_start_msec < 0:
		return false
	return Time.get_ticks_msec() < _repro_anim_start_msec + REPRO_ANIM_DURATION_MS + REPRO_HOLD_AFTER_ANIM_MS


func _draw_rules_demo_player_layer(vp: Vector2) -> void:
	"""自キャラ・エフェクト（[つぎへ] より手前）"""
	if _game.point_positions.is_empty():
		return
	_draw_laser_effect()
	_draw_spore_particles()
	# 本編同様: 実現率（掴み中 or 一致度が動いた直後）
	var focus_idx: int = _game.input_handler.get_player_focus_index()
	if focus_idx >= 0 and focus_idx < _game.point_positions.size():
		var circ_val: float = _game.get_display_reproduction_rate_floor(_game.current_circularity)
		_repro_rate_float_on_metric(circ_val)
		if _game.input_handler.grab_input_active or _repro_rate_should_show_temporary():
			var pt: Vector2 = _game.input_handler.get_player_position()
			var disp_val: float = _repro_get_display_value()
			var rate_text: String = "%.1f%%" % disp_val
			var rate_color: Color = _stage_renderer.get_metric_color_for_display_rate(disp_val)
			_draw_realization_rate_with_glow(pt + REPRO_RATE_OFFSET_FROM_PLAYER, rate_text, rate_color)
	_draw_right_stick_debug_line(vp)


# =============================================================================
# Drawing - Game / Guide / HUD
# =============================================================================

func _draw_game(vp: Vector2) -> void:
	_draw_bg(vp)

	if _game.game_state == "playing" and GameConfig.USE_SCREEN_HUD_GUIDE:
		var sc: Vector2 = GameConfig.hud_playfield_shape_center(vp, _game.hud_layout_slot(_game.stage_manager.current_stage))
		_game.shape_center = sc
		_game.stage_manager.recompute_hud_guide_layout_if_needed(sc, vp)
		_game.guide_center_1 = _game.stage_manager.guide_center_1

	# プレイ中の見た目と物理座標を一致させるため、描画時の拡大変換は使わない。
	var intro_scale: float = 1.0

	var n: int = _game.point_positions.size()

	# 1. ガイド（最下層）
	if _game.game_state == "playing" and _game.hint_alpha > 0.0 and not GameConfig.USE_SCREEN_HUD_GUIDE:
		_stage_renderer.draw_hint_shape(_game.hint_alpha)

	# 1.5. 完成済みオブジェクトの塗りつぶし（線の下に描画）
	if _game.game_state != "cleared":
		_draw_clear_fill()

	# 1.6 コントローラ操作ヒント（con_bt_non.png / con_bt_*1.png の切り替え）: 図形・自キャラより下に重ねる
	_draw_stage_playing_controller_hint(vp)

	# 2. ユーザーの図形（線・ポイント・エフェクト）—クリア後は非表示
	if _game.game_state != "cleared":
		_stage_renderer.draw_stage_lines()

		_refresh_guide_point_distance_bounds()
		var focus_idx: int = _game.input_handler.get_player_focus_index()
		for i in range(n):
			var pos: Vector2 = _game.point_positions[i]
			var color: Color
			var radius: float
			var r_guide: float = _point_radius_by_guide(i)
			var d_outline: float = INF
			if i < _guide_point_distances.size():
				d_outline = _guide_point_distances[i]
			var on_guide_outline: bool = (
				not _game._is_locked(i)
				and not is_inf(d_outline)
				and d_outline <= InputHandler.GUIDE_ATTRACT_FREE_EDGE_DIST_PX
			)
			var skip_fill_circle: bool = false
			if _game._is_stage1_fixed_point(i):
				color = Color(0.40, 0.33, 0.38, 0.5)
				radius = r_guide
			elif on_guide_outline and not (_cat_phase != 0 and _game.input_handler.is_point_free(i)):
				if _snap_color_effects.has(i):
					var snap_t: float = clampf(_snap_color_effects[i] / SNAP_COLOR_DUR, 0.0, 1.0)
					var snap_col: Color = Color(0.95, 0.19, 0.32).lerp(LINE_COLOR, snap_t)
					var snap_r: float = StageRenderer.HUD_GUIDE_LINE_WIDTH_PX * 2.5
					_game.draw_circle(pos, snap_r, snap_col)
				else:
					_draw_guide_snapped_point_black_disc(pos)
				skip_fill_circle = true
			elif i == _game.hovered_index:
				# ホバー時も通常表示（赤いポイントは廃止）
				color = _stage_renderer.get_point_base_color(i)
				radius = r_guide
			else:
				color = _stage_renderer.get_point_base_color(i)
				radius = r_guide
			if not skip_fill_circle:
				if _cat_phase != 0 and _game.input_handler.is_point_free(i):
					_draw_cat_anim_point(pos, radius)
				elif _game._is_stage1_fixed_point(i):
					var half: float = radius * 0.85
					_game.draw_rect(Rect2(pos - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), Color(0.40, 0.33, 0.38, 0.9))
				else:
					_game.draw_circle(pos, radius, color)
			if i == focus_idx and _game.input_handler.grab_input_active:
				_draw_point_position_effect(pos, r_guide)

		_draw_spore_particles()

	# 実現率の内部トラッキングは他機能（波紋エフェクトの80%判定等）で使うため維持する。
	# 画面上へのパーセンテージ表示自体は撤去した。
	if _game.game_state == "playing":
		var circ_tracked: float = _game.get_display_reproduction_rate_floor(_game.current_circularity)
		_repro_rate_float_on_metric(circ_tracked)

	# イントロ演出のtransformをリセット（HUDはスケーリングしない）
	if intro_scale != 1.0:
		_game.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _game.game_state == "playing" and GameConfig.USE_SCREEN_HUD_GUIDE:
		_stage_renderer.draw_guide_proximity_reveal()

	# ステージ1〜3: ボタン押下ヒント（奥）→ ダミー自キャラ＋波紋（手前）の順で描画
	_draw_stage_playing_press_hint(vp)
	_draw_square_stage_repulse_demo(vp)
	_draw_hexagon_stage_attract_demo(vp)
	_draw_ta_hud(vp)

	# C案 ステージ開始演出: 白フラッシュ後にKATAフェードイン
	if _game.game_state == "playing" and not is_stage_intro_done():
		var t: float = get_stage_intro_progress()
		# KATAフェードイン（0.2→0.85）: クリームオーバーレイを徐々に消す
		var kata_fade: float = clampf((t - 0.2) / 0.65, 0.0, 1.0)
		if kata_fade < 1.0:
			_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 0.937, 0.89, 1.0 - kata_fade))
		# 白フラッシュ（0→0.25）: KATAオーバーレイの上に重ねる
		var flash_a: float = 1.0 - clampf(t / 0.25, 0.0, 1.0)
		if flash_a > 0.001:
			_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 1.0, 1.0, flash_a))

	if _game.game_state != "cleared" and not StageSelectManager.time_attack_active:
		_draw_hud(vp)
	if _game.game_state == "playing" and not StageSelectManager.time_attack_active:
		_draw_ingame_menu_hint(vp)
	if _game.game_state == "playing":
		_draw_ripple_effects()

	# 右スティック: ピンクのガイド線（先端へ向かってフェード）
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
	"""隣接連動仕様の廃止に伴い、レーザー演出は無効化。"""
	return
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


func _attract_f_outer_from_expand_ratio(expand_ratio: float) -> float:
	"""影響範囲（field/基準）が広いほど、**外周でだけ**大きい F（=そこで早く飛ばす）。"""
	var r: float = clampf(expand_ratio, 1.0, PLAYER_ATTRACT_EXPAND_RATIO_CAP)
	if PLAYER_ATTRACT_EXPAND_RATIO_CAP <= 1.0:
		return 1.0
	var t: float = (r - 1.0) / (PLAYER_ATTRACT_EXPAND_RATIO_CAP - 1.0)
	return lerpf(1.0, PLAYER_ATTRACT_F_OUTER_MAX, t)


## 1 周期内の線形相対時間 s から、半径 0(外)〜1(内) への道のり q。q'(0)=F, q'(1)=1
func _attract_inward_path_q(s: float, f_outer: float) -> float:
	var F: float = clampf(f_outer, 1.0, PLAYER_ATTRACT_F_OUTER_MAX)
	return s + (F - 1.0) * s * (1.0 - s) * (1.0 - s)


func _draw_player_attract_inward_waves(center: Vector2, inner_r: float, field_r: float, core_r: float, alpha_scale: float = 1.0) -> void:
	"""X 長押し: 一周期内は周波数一定。沖（外）ほど d(半径位置)/d(時間) が大きく、内（s→1）では当初と同程度。"""
	var t_sec: float = Time.get_ticks_msec() * 0.001
	var hz: float = PLAYER_ATTRACT_INWARD_WAVE_HZ
	var n_waves: int = maxi(3, PLAYER_ATTRACT_INWARD_WAVE_LAYERS)
	var base_fr: float = _game.input_handler.get_base_player_force_visual_radius()
	var f_outer: float = _attract_f_outer_from_expand_ratio(field_r / maxf(base_fr, 1.0))
	var outer_rr: float = maxf(field_r - 1.5, inner_r + 6.0)
	var inner_limit: float = maxf(inner_r + 3.0, core_r * 1.75)
	if inner_limit >= outer_rr - 2.0:
		inner_limit = outer_rr * 0.28
	# 各層: 一周期内の線形位相 s → 道のり q(s)（外速・内遅＆内終端 q'=1）→ smoothstep で半径
	for wave_idx in range(n_waves):
		var s: float = fmod(t_sec * hz + float(wave_idx) / float(n_waves), 1.0)
		var q: float = _attract_inward_path_q(s, f_outer)
		var p_ease: float = q * q * (3.0 - 2.0 * q)
		var rr: float = lerpf(outer_rr, inner_limit, p_ease)
		var crest: float = pow(sin(s * PI), 0.75)
		if crest < 0.02:
			continue
		# まだ外にいる波ほど発光（寄せてくる途中を強調）
		var from_outside: float = sqrt(1.0 - p_ease * p_ease)
		var head_boost: float = 0.35 + 0.65 * (0.45 + 0.55 * from_outside)
		# 半径オフセット・幅: [外＝先走りの薄帯, 中＝高さ, 内＝引き摺る尾]
		var wave_layers: Array = [
			[3.0, 0.14, 16.0, 0.26],
			[1.0, 0.4, 12.0, 0.55],
			[0.0, 1.0, 5.0, 0.88],
			[-1.2, 0.22, 9.0, 0.28],
		]
		for wl in wave_layers:
			var d_r: float = float(wl[0])
			var w_mul: float = float(wl[1])
			var w_pix: float = float(wl[2])
			var a_mul: float = float(wl[3])
			var r_draw: float = rr + d_r
			if r_draw < inner_limit * 0.85 or r_draw > outer_rr + 5.0:
				continue
			var ring_a: float = crest * 0.5 * head_boost * a_mul * w_mul
			var t_in: float = clampf((r_draw - inner_limit) / maxf(outer_rr - inner_limit, 0.001), 0.0, 1.0)
			var c_soft: Color = Color(0.28, 0.62, 1.0, _attract_ring_alpha_from_base(ring_a, 0.75, t_in) * alpha_scale)
			var c_core: Color = Color(0.2, 0.56, 1.0, _attract_ring_alpha_from_base(ring_a, 0.98, t_in) * alpha_scale)
			_game.draw_arc(center, r_draw, 0.0, TAU, 88, c_soft, w_pix, true)
			_game.draw_arc(center, r_draw, 0.0, TAU, 88, c_core, w_pix * 0.4, true)


## _draw_player_attract_inward_waves 用: 沖寄りほど濃く、中心寄りほど抜ける
func _attract_ring_alpha_from_base(base: float, peak_mul: float, t_toward_center: float) -> float:
	return clampf(base * peak_mul * lerpf(1.0, 0.18, t_toward_center * t_toward_center * t_toward_center), 0.0, 1.0)


func _draw_player_repulse_outward_waves(center: Vector2, inner_r: float, field_r: float, core_r: float, alpha_scale: float = 1.0) -> void:
	"""A 長押し（斥力）: 円弧が中心→外周へ広がり、最外周に近いほど色が濃くなる。"""
	var t_sec: float = Time.get_ticks_msec() * 0.001
	var hz: float = PLAYER_REPULSE_OUTWARD_WAVE_HZ
	var outer_rr: float = maxf(field_r - 1.5, inner_r + 6.0)
	var inner_limit: float = maxf(inner_r + 3.0, core_r * 1.75)
	if inner_limit >= outer_rr - 2.0:
		inner_limit = outer_rr * 0.28
	for wave_idx in range(4):
		var p: float = fmod(t_sec * hz + float(wave_idx) * 0.25, 1.0)
		var p_ease: float = p * p * (3.0 - 2.0 * p)
		var rr: float = lerpf(inner_limit, outer_rr, p_ease)
		var ring_alpha: float = pow(sin(p * PI), 1.15) * 0.42
		# p=0 で内側＝淡い、p→1 で外周ほど濃い
		var t_edge: float = p * p * (3.0 - 2.0 * p)
		var c_faint_glow := Color(1.0, 0.94, 0.96, ring_alpha * 0.06)
		var c_strong_glow := Color(0.98, 0.32, 0.48, ring_alpha * 0.75)
		var c_faint_core := Color(1.0, 0.82, 0.88, ring_alpha * 0.05)
		var c_strong_core := Color(0.92, 0.18, 0.38, ring_alpha * 0.98)
		var c_soft: Color = c_faint_glow.lerp(c_strong_glow, t_edge)
		var c_bright: Color = c_faint_core.lerp(c_strong_core, t_edge)
		c_soft.a *= alpha_scale
		c_bright.a *= alpha_scale
		const W_SOFT := 13.6
		const W_CORE := 5.4
		_game.draw_arc(center, rr, 0.0, TAU, 80, c_soft, W_SOFT, true)
		_game.draw_arc(center, rr, 0.0, TAU, 80, c_bright, W_CORE, true)


func _draw_player_force_influence_visual(center: Vector2, core_r: float, field_r: float, attracting: bool, alpha_scale: float = 1.0) -> void:
	"""影響範囲：薄塗り → 引力は内向き円波、斥力は外向き円波（最外周の固定ラインは描かない）。"""
	if field_r > 1.0:
		var fill_c: Color = (
			PLAYER_FORCE_FIELD_FILL_ATTRACT if attracting else PLAYER_FORCE_FIELD_FILL_REPEL
		)
		fill_c.a *= alpha_scale
		_game.draw_circle(center, field_r, fill_c)
	var base_fr: float = _game.input_handler.get_base_player_force_visual_radius()
	var inner_r: float = maxf(core_r * 1.2, base_fr * 0.2)
	if attracting:
		_draw_player_attract_inward_waves(center, inner_r, field_r, core_r, alpha_scale)
	else:
		_draw_player_repulse_outward_waves(center, inner_r, field_r, core_r, alpha_scale)


## 右スティックのデバッグ線／A+X 斥力可視化の共用: 2 点間の稲妻状放電
func _draw_discharge_lightning_between(
	p0: Vector2, p1: Vector2, alpha_mul: float = 1.0, jitter_scale: float = 1.0
) -> void:
	var delta: Vector2 = p1 - p0
	var dist: float = delta.length()
	if dist < 1.5:
		return
	var dir: Vector2 = delta / dist
	var perpendicular: Vector2 = Vector2(-dir.y, dir.x)
	var bolt_rgb: Color = LASER_BLUE
	var segs: int = clampi(int(dist / 42.0) + 7, 7, 18)
	var points: Array[Vector2] = []
	points.append(p0)
	for i in range(1, segs):
		var t: float = float(i) / float(segs)
		var base_pos: Vector2 = p0.lerp(p1, t)
		var jitter: float = randf_range(-14.0, 14.0) * jitter_scale * (1.2 - t * 0.4)
		points.append(base_pos + perpendicular * jitter)
	points.append(p1)
	var last: int = points.size() - 1
	for i in range(last):
		var t_mid: float = (float(i) + 0.5) / float(last)
		var fade: float = pow(1.0 - t_mid, 0.85) * alpha_mul
		if fade < 0.02:
			continue
		var glow_color: Color = Color(bolt_rgb.r, bolt_rgb.g, bolt_rgb.b, 0.25 * fade)
		_game.draw_line(points[i], points[i + 1], glow_color, 6.0, true)
		var bolt_color: Color = Color(bolt_rgb.r, bolt_rgb.g, bolt_rgb.b, 0.95 * fade)
		_game.draw_line(points[i], points[i + 1], bolt_color, 2.5, true)
		var core_color: Color = Color(LASER_BLUE.r, LASER_BLUE.g, LASER_BLUE.b, 0.95 * fade)
		_game.draw_line(points[i], points[i + 1], core_color, 1.0, true)
	var n_branch: int = clampi(int(dist / 100.0) + 3, 2, 8)
	for _j in range(n_branch):
		var idx: int = randi_range(1, points.size() - 2)
		var from_p: Vector2 = points[idx]
		var branch_dir: Vector2 = (
			perpendicular * randf_range(-0.8, 0.8) + dir * randf_range(-0.2, 0.3)
		).normalized()
		var branch_len: float = randf_range(18.0, 52.0) * jitter_scale
		var to_p: Vector2 = from_p + branch_dir * branch_len
		var branch_fade: float = pow(1.0 - float(idx) / float(last), 0.85) * alpha_mul
		_game.draw_line(from_p, to_p, Color(bolt_rgb.r, bolt_rgb.g, bolt_rgb.b, 0.55 * branch_fade), 1.5, true)


func _draw_charge_gauge(center: Vector2, radius: float, progress: float, color: Color) -> void:
	var p: float = clampf(progress, 0.0, 1.0)
	if p <= 0.0:
		return
	var start_angle: float = -PI / 2.0
	var end_angle: float = start_angle + TAU * p
	var segments: int = maxi(2, int(64.0 * p))
	var points := PackedVector2Array()
	points.append(center)
	for i in range(segments + 1):
		var a: float = lerpf(start_angle, end_angle, float(i) / float(segments))
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	_game.draw_colored_polygon(points, color)


func _draw_player_avatar() -> void:
	if not _game.input_handler.has_player_avatar():
		return

	var center: Vector2 = _game.input_handler.get_player_position()
	var core_r: float = InputHandler.PLAYER_RADIUS
	var field_r: float = _game.input_handler.get_effective_player_force_visual_radius()
	var attracting: bool = _game.input_handler.is_player_attracting()
	var repelling: bool = _game.input_handler.is_player_repelling()
	var av_mul: float = 1.0
	var ring_color: Color = Color(0.58, 0.62, 0.74, 0.08 * av_mul)
	var edge_color: Color = Color(0.88, 0.9, 0.97, 0.18 * av_mul)
	if attracting:
		ring_color = Color(0.55, 0.78, 1.0, 0.16 * av_mul)
		edge_color = Color(0.86, 0.93, 1.0, 0.36 * av_mul)
	elif repelling:
		ring_color = Color(1.0, 0.55, 0.62, 0.14 * av_mul)
		edge_color = Color(1.0, 0.82, 0.86, 0.28 * av_mul)
	# 無効ボタン押下時の縮小・振動演出（ステージ1〜3でのみ発動）
	var av_scale: float = 1.0
	var jitter: Vector2 = Vector2.ZERO
	if _game._frozen_avatar_blocked_active:
		av_scale = _game.FROZEN_AVATAR_SHRINK_SCALE
		var t_now: float = Time.get_ticks_msec() / 1000.0
		var jitter_amp: float = core_r * 0.18
		jitter = Vector2(sin(t_now * 45.0), cos(t_now * 53.0)) * jitter_amp
	elif _game._frozen_avatar_return_start >= 0.0:
		var t_since: float = (Time.get_ticks_msec() / 1000.0) - _game._frozen_avatar_return_start
		if t_since < _game.FROZEN_AVATAR_RETURN_DUR:
			var rt: float = t_since / _game.FROZEN_AVATAR_RETURN_DUR
			av_scale = lerpf(_game.FROZEN_AVATAR_SHRINK_SCALE, 1.0, 1.0 - pow(1.0 - rt, 3.0))
	var draw_center: Vector2 = center + jitter
	if attracting or repelling:
		_draw_player_force_influence_visual(draw_center, core_r * av_scale, field_r * av_scale, attracting, av_mul)
	else:
		_game.draw_circle(draw_center, field_r * av_scale, ring_color)
		_game.draw_arc(draw_center, field_r * av_scale, 0.0, TAU, 64, edge_color, 2.0)
	_game.draw_circle(draw_center, core_r * 1.45 * av_scale, Color(LINE_COLOR, 0.92 * av_mul))
	_game.draw_circle(draw_center, core_r * av_scale, Color(LINE_COLOR, 1.0 * av_mul))
	_game.draw_arc(draw_center, core_r * 0.72 * av_scale, 0.0, TAU, 48, Color(0.82, 0.9, 1.0, 0.7 * av_mul), 2.5)
	_game.draw_circle(draw_center, core_r * 0.28 * av_scale, Color(1.0, 1.0, 1.0, 0.95 * av_mul))
	if repelling:
		var repel_prog: float = _game.input_handler.get_repel_charge_progress()
		if repel_prog > 0.0:
			_draw_charge_gauge(draw_center, core_r * 1.5 * av_scale, repel_prog, Color(0.95, 0.19, 0.32, 0.85))
	elif attracting:
		var attract_prog: float = _game.input_handler.get_attract_charge_progress()
		if attract_prog > 0.0:
			_draw_charge_gauge(draw_center, core_r * 1.5 * av_scale, attract_prog, Color(0.2, 0.56, 1.0, 0.85))


func _draw_selected_point(center: Vector2, base_r: float = POINT_RADIUS) -> void:
	"""選択ポイント: 白の円 + 半径1.2倍の黒の円（中心から離れるほど透過）"""
	var r: float = base_r
	for layer in SELECTED_POINT_BLACK_LAYERS:
		var radius: float = r * (layer[0] as float)
		var a: float = layer[1] as float
		var black_c: Color = Color(SELECTED_POINT_BLACK.r, SELECTED_POINT_BLACK.g, SELECTED_POINT_BLACK.b, a)
		_game.draw_circle(center, radius, black_c)
	_game.draw_circle(center, r, SELECTED_POINT_WHITE)


## ガイド輪郭上: ガイド線幅の5倍の直径の黒塗り円（`StageRenderer.HUD_GUIDE_LINE_WIDTH_PX` と同期）
func _draw_guide_snapped_point_black_disc(center: Vector2) -> void:
	var diameter: float = StageRenderer.HUD_GUIDE_LINE_WIDTH_PX * 5.0
	var r: float = diameter * 0.5
	if r < 0.5:
		return
	_game.draw_circle(center, r, LINE_COLOR)


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
	var fill_rgb: Color = LASER_BLUE
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


func _draw_ripple_effects() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for r in _game._ripple_effects:
		var t: float = (now - float(r.start_time)) / _game.RIPPLE_DURATION_SEC
		if t < 0.0 or t > 1.0:
			continue
		var radius: float = lerpf(6.0, _game.RIPPLE_MAX_RADIUS, t)
		var alpha: float = (1.0 - t) * 0.65
		_game.draw_arc(r.pos, radius, 0.0, TAU, 32, Color(_game.GUIDE_COLOR, alpha), 2.0, true)


## インゲーム左下: ポーズメニューを開くための操作ガイド
func _draw_ingame_menu_hint(vp: Vector2) -> void:
	if _game.pause_active or _ig_hint_style == null:
		return
	if not is_stage_intro_done():
		return
	var is_pad: bool = _game.input_handler.get_last_input_method() == "pad"
	var icon_tex: Texture2D = _ig_start_pad_texture if is_pad else _ig_esc_key_texture
	var hint_txt: String = tr("MENU_OPEN_HINT")
	var hint_fs: int = 16
	var icon_h: float = 26.0
	var gap: float = 8.0
	var icon_w: float = icon_h
	if icon_tex != null:
		icon_w = icon_h * float(icon_tex.get_width()) / float(icon_tex.get_height())
	var txt_w: float = _game.font.get_string_size(hint_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_fs).x
	var panel_w: float = _ig_hint_style.content_margin_left + icon_w + gap + txt_w + _ig_hint_style.content_margin_right
	var panel_h: float = _ig_hint_style.content_margin_top + icon_h + _ig_hint_style.content_margin_bottom
	var panel_x: float = 20.0
	var panel_y: float = vp.y - 14.0 - panel_h
	_game.draw_style_box(_ig_hint_style, Rect2(panel_x, panel_y, panel_w, panel_h))
	if icon_tex != null:
		_game.draw_texture_rect(icon_tex, Rect2(panel_x + _ig_hint_style.content_margin_left, panel_y + _ig_hint_style.content_margin_top, icon_w, icon_h), false)
	_game.draw_string(_game.font, Vector2(panel_x + _ig_hint_style.content_margin_left + icon_w + gap, panel_y + panel_h - _ig_hint_style.content_margin_bottom - 2.0), hint_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_fs, Color(1.0, 0.9, 1.0, 0.9))


func _draw_right_stick_debug_line(vp: Vector2) -> void:
	"""右スティック倒し中: コリドー帯 → 放電エフェクトで描画（ピンクは根元→先へフェード）"""
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
	_draw_discharge_lightning_between(center, end_pos, 1.0, 1.0)


func _draw_guide_info(vp: Vector2) -> void:
	_draw_bg(vp)

	# 解像度スケール（1080p基準）
	var rs: float = vp.y / 1080.0

	var play_cx: float = vp.x / 2.0
	var text_w: float = vp.x * 0.8
	var tx: float = play_cx - text_w / 2.0
	var text_color := LINE_COLOR

	var stage_fs: int = 48
	var num_fs: int = 160
	var desc_fs: int = 76
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
	var slide_px: float = 20.0
	var anim_dur: float = 0.3
	var stagger: float = 0.12

	# 要素ごとのアニメ進行率（0〜1）
	var t1: float = clampf((t - stagger * 0) / anim_dur, 0.0, 1.0)
	var t2: float = clampf((t - stagger * 1) / anim_dur, 0.0, 1.0)
	var t3: float = clampf((t - stagger * 2) / anim_dur, 0.0, 1.0)
	var e1: float = _ease_out_cubic(t1)
	var e2: float = _ease_out_cubic(t2)
	var e3: float = _ease_out_cubic(t3)

	# --- 下部テキスト（画面下端50px上に固定）---
	var start_fs: int = int(38 * rs)
	if start_fs < 24: start_fs = 24
	var start_desc_h: float = _game.font_bold.get_descent(start_fs)
	var start_asc: float = _game.font_bold.get_ascent(start_fs)
	var start_text_y: float = vp.y - 50.0 * rs - start_desc_h
	var bottom_text_top: float = start_text_y - start_asc

	# テキストブロック全体の高さを計算して垂直中央に配置
	var total_block_h: float = stage_asc + stage_desc_h + gap1 + num_asc + num_desc_h + gap2 + desc_asc + desc_desc_h
	var center_y: float = bottom_text_top / 2.0
	var block_top: float = center_y - total_block_h / 2.0

	# "STAGE"
	var y1: float = block_top + stage_asc
	_game.draw_string(_game.font_din, Vector2(tx, y1 + slide_px * (1.0 - e1)), "STAGE", HORIZONTAL_ALIGNMENT_CENTER, text_w, stage_fs, Color(text_color.r, text_color.g, text_color.b, e1))

	# ステージ番号
	var y2: float = y1 + stage_desc_h + gap1 + num_asc
	_draw_monospace_number(_game.font_din, Vector2(tx, y2 + slide_px * (1.0 - e2)), _game._stage_display_number_text(), HORIZONTAL_ALIGNMENT_CENTER, text_w, num_fs, Color(text_color.r, text_color.g, text_color.b, e2))

	# ステージ目的（タイプライター演出）
	var y3: float = y2 + num_desc_h + gap2 + desc_asc
	var type_desc: String = _stage_renderer.get_type_description()
	if _game.stage_session.debug_test_mode and _game.stage_session.debug_test_meta_stage_name.strip_edges() != "":
		type_desc = _game.stage_session.debug_test_meta_stage_name

	const TYPEWRITER_START: float = 0.54
	const TYPEWRITER_CPS: float = 12.0
	var tw_elapsed: float = maxf(0.0, t - TYPEWRITER_START)
	var visible_chars: int
	if _guide_typewriter_done:
		visible_chars = type_desc.length()
	else:
		visible_chars = mini(int(tw_elapsed * TYPEWRITER_CPS), type_desc.length())
		if visible_chars >= type_desc.length():
			_guide_typewriter_done = true
	var visible_text: String = type_desc.substr(0, visible_chars)
	_game.draw_string(_game.font, Vector2(tx, y3 + slide_px * (1.0 - e3)), visible_text, HORIZONTAL_ALIGNMENT_CENTER, text_w, desc_fs, Color(0.35, 0.28, 0.35, e3))

	# "クリックでスタート" はタイプライター完了後にフェードイン
	var t5: float = clampf((t - stagger * 4) / anim_dur, 0.0, 1.0) if _guide_typewriter_done else 0.0
	var blink: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 0.5)
	_game.draw_string(_game.font_bold, Vector2(tx, start_text_y), tr("GUIDE_CLICK_START"), HORIZONTAL_ALIGNMENT_CENTER, text_w, start_fs, Color(0.95, 0.19, 0.32, t5 * blink))


func _draw_guide_countdown(vp: Vector2) -> void:
	_draw_bg(vp)

	var play_cx: float = vp.x / 2.0
	var cy: float = vp.y / 2.0
	var base_fs: int = 540

	var count_speed: float = 3.0 if _game.pause_retry_elapsed >= 0.0 else 1.0
	var elapsed: float = (Time.get_ticks_msec() / 1000.0 - _game.guide_start_time) * count_speed
	var remaining: float = maxf(0.0, 3.0 - elapsed)
	var countdown: int = ceili(remaining)

	# 数字切り替え時のスケールアニメ（1.3→1.0 を0.3秒で、リトライ時は1/3の速さ）
	if countdown != _countdown_prev:
		_countdown_prev = countdown
		_countdown_scales[countdown] = Time.get_ticks_msec() / 1000.0
	var num_start: float = _countdown_scales.get(countdown, Time.get_ticks_msec() / 1000.0)
	var anim_dur: float = 0.3 / count_speed
	var num_t: float = clampf((Time.get_ticks_msec() / 1000.0 - num_start) / anim_dur, 0.0, 1.0)
	var num_ease: float = _ease_out_cubic(num_t)
	var scale_val: float = lerp(1.3, 1.0, num_ease)
	var alpha_val: float = lerp(0.0, 1.0, minf(num_t * 3.0, 1.0))  # 素早くフェードイン
	var fs: int = int(base_fs * scale_val)

	var asc: float = _game.font_din.get_ascent(fs)
	var desc_h: float = _game.font_din.get_descent(fs)
	var baseline_y: float = cy - (asc + desc_h) / 2.0 + asc - vp.y * 0.08
	_draw_monospace_number(_game.font_din, Vector2(play_cx - vp.x / 2.0, baseline_y), "%d" % countdown, HORIZONTAL_ALIGNMENT_CENTER, vp.x, fs, Color(LINE_COLOR,alpha_val))


func _draw_ui_panel(vp: Vector2) -> void:
	var ui_w: float = vp.x * 0.25
	var h: float = vp.y

	_game.draw_rect(Rect2(Vector2.ZERO, Vector2(ui_w, h)), LINE_COLOR)

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



func _draw_rect_border_with_corners(rect: Rect2, color: Color, border_w: float, canvas: Node2D = null) -> void:
	var c: Node2D = canvas if canvas != null else _game
	var dot_r: float = border_w * 1.25
	c.draw_rect(rect, color, false, border_w)
	c.draw_circle(rect.position, dot_r, color)
	c.draw_circle(Vector2(rect.end.x, rect.position.y), dot_r, color)
	c.draw_circle(Vector2(rect.position.x, rect.end.y), dot_r, color)
	c.draw_circle(rect.end, dot_r, color)


func _draw_auto_button_with_shadow(center: Vector2, text: String, fs: int = BTN_FONT_SIZE, alpha: float = 1.0, is_off: bool = false, fixed_w: float = -1.0, fixed_h: float = -1.0) -> Rect2:
	"""ボタンを描画。選択(is_off=false)時はホバーアニメーション付き"""
	var btn_w: float = fixed_w if fixed_w > 0.0 else _game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 1.5
	var btn_h: float = fixed_h if fixed_h > 0.0 else (_game.font.get_ascent(fs) + _game.font.get_descent(fs)) * 1.5

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

	# スケールまたはアルファが極小なら描画スキップ（サブピクセル多角形は triangulation failed になる）
	if sc < 0.01 or alpha < 0.001 or draw_w < 2.0 or draw_h < 2.0:
		return Rect2(center.x - btn_w / 2.0, center.y - btn_h / 2.0, btn_w, btn_h)

	var rect := Rect2(center.x - draw_w / 2.0, center.y - draw_h / 2.0, draw_w, draw_h)
	var shadow_offset := Vector2(12.5 + shadow_extra, 12.5 + shadow_extra)
	var border_c := Color(LINE_COLOR,alpha)
	const BTN_BW: float = 5.75
	var text_color: Color
	if is_off:
		_game.draw_rect(Rect2(rect.position + shadow_offset, rect.size), Color(LINE_COLOR, 0.30 * alpha))
		var off_pts := PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
		var off_grad := PackedColorArray([
			Color(1.00, 0.937, 0.890, alpha),
			Color(1.00, 0.937, 0.890, alpha),
			Color(0.80, 0.750, 0.712, alpha),
			Color(0.80, 0.750, 0.712, alpha),
		])
		_game.draw_polygon(off_pts, off_grad)
		# ハイライトストライプ（上部 26% に白シーン）
		_game.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.26)), Color(1.0, 1.0, 1.0, 0.22 * alpha))
		_draw_rect_border_with_corners(rect, border_c, BTN_BW)
		text_color = Color(LINE_COLOR, alpha)
	else:
		# ONボタン：四隅が時刻ベースのサイン波でゆっくり動き続ける（OFFで正矩形に戻る）
		var t: float = Time.get_ticks_msec() / 500.0
		# mo をボタンサイズの 45% に制限: 頂点が交差して triangulation failed になるのを防ぐ
		var mo: float = minf(5.0, minf(draw_w, draw_h) * 0.45)
		var pts := PackedVector2Array([
			Vector2(rect.position.x + sin(t * 0.71 + 0.00) * mo, rect.position.y + sin(t * 0.53 + 1.10) * mo),
			Vector2(rect.end.x      + sin(t * 0.63 + 2.30) * mo, rect.position.y + sin(t * 0.79 + 3.50) * mo),
			Vector2(rect.end.x      + sin(t * 0.58 + 4.70) * mo, rect.end.y      + sin(t * 0.67 + 5.90) * mo),
			Vector2(rect.position.x + sin(t * 0.82 + 7.10) * mo, rect.end.y      + sin(t * 0.61 + 8.30) * mo),
		])
		# シャドウも同じ変形ポリゴンをオフセットして描画
		var pts_shadow := PackedVector2Array([
			pts[0] + shadow_offset, pts[1] + shadow_offset,
			pts[2] + shadow_offset, pts[3] + shadow_offset,
		])
		_game.draw_colored_polygon(pts_shadow, Color(LINE_COLOR, 0.30 * alpha))
		# 頂点グラデーション（上: 明るい赤、下: 暗い赤）
		var on_grad := PackedColorArray([
			Color(1.00, 0.28, 0.40, 0.9 * alpha),
			Color(1.00, 0.28, 0.40, 0.9 * alpha),
			Color(0.50, 0.07, 0.14, 0.9 * alpha),
			Color(0.50, 0.07, 0.14, 0.9 * alpha),
		])
		_game.draw_polygon(pts, on_grad)
		# ハイライトストライプ（上部 26% にクリームシーン）
		var hl_pts := PackedVector2Array([
			pts[0], pts[1],
			pts[1].lerp(pts[2], 0.26),
			pts[0].lerp(pts[3], 0.26),
		])
		_game.draw_colored_polygon(hl_pts, Color(1.0, 0.937, 0.89, 0.12 * alpha))
		var dot_r: float = BTN_BW * 1.25
		for i in range(4):
			_game.draw_line(pts[i], pts[(i + 1) % 4], border_c, BTN_BW, true)
		for c in pts:
			_game.draw_circle(c, dot_r, border_c)
		text_color = Color(1.0, 0.937, 0.89, alpha)
	var ascent: float = _game.font.get_ascent(fs)
	var descent: float = _game.font.get_descent(fs)
	var baseline_y: float = rect.position.y + (draw_h + ascent - descent) * 0.5
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
	_game.draw_rect(shadow_rect, Color(LINE_COLOR,0.25))
	_game.draw_rect(rect, Color(1.0, 0.937, 0.89))
	_game.draw_rect(rect, LINE_COLOR, false, 3.45)


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
	var inner_color: Color = Color(LINE_COLOR,0.55)
	# 中間リング: 中程度の距離
	var mid_dist: float = 2.2
	var mid_color: Color = Color(LINE_COLOR,0.4)
	# 外側リング: 遠く、薄く（ブラー風）
	var outer_dist: float = 3.8
	var outer_color: Color = Color(LINE_COLOR,0.28)
	# 最外側: さらに広がりを強調
	var far_dist: float = 5.5
	var far_color: Color = Color(LINE_COLOR,0.18)
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
	# 経過秒（小数第2位）。枠なし・等幅7文字で桁ブレ抑制。右上が塞がれたら左上へ逃げ、左上に戻るまで左上維持。
	const HUD_CORNER_ZONE_W: float = 280.0
	const HUD_CORNER_ZONE_H: float = 110.0
	var right_margin: float = 24.0
	var left_margin: float = 24.0
	var value_fs: int = int(52 * 0.85)  # 85%に縮小
	var hud_black: Color = LINE_COLOR
	var top_y: float = 20.0

	var elapsed: float
	if _game.game_state == "cleared":
		elapsed = _game.clear_time
	elif _game.pause_active:
		elapsed = _game.pause_elapsed
	else:
		elapsed = maxf(0.0, Time.get_ticks_msec() / 1000.0 - _game.start_time)

	var e_snapped: float = snappedf(clampf(elapsed, 0.0, 9999.99), 0.01)
	var bare: String = "%.2f" % e_snapped
	var time_str: String = bare
	while time_str.length() < 7:
		time_str = " " + time_str

	var adv: float = 0.0
	var adv_chars: String = "0123456789. "
	for i in range(adv_chars.length()):
		var ch0: String = adv_chars.substr(i, 1)
		adv = maxf(adv, _game.font_din.get_string_size(ch0, HORIZONTAL_ALIGNMENT_LEFT, -1, value_fs).x)
	var text_w: float = adv * float(time_str.length())

	if _game.input_handler.has_player_avatar():
		var pr: float = InputHandler.PLAYER_RADIUS + 28.0
		var ppos: Vector2 = _game.input_handler.get_player_position()
		var in_tr: bool = (ppos.x + pr > vp.x - HUD_CORNER_ZONE_W) and (ppos.y - pr < HUD_CORNER_ZONE_H)
		var in_tl: bool = (ppos.x - pr < HUD_CORNER_ZONE_W) and (ppos.y - pr < HUD_CORNER_ZONE_H)
		if in_tr:
			_hud_time_dock_left = true
		elif in_tl:
			_hud_time_dock_left = false

	var dock_left: bool = _hud_time_dock_left

	var text_x_base: float
	if dock_left:
		text_x_base = left_margin
	else:
		text_x_base = vp.x - right_margin - text_w

	var intro_t: float = get_stage_intro_progress()
	var slide_t: float = clampf(intro_t / 0.8, 0.0, 1.0)
	var slide_dist: float = text_w + right_margin + left_margin + 40.0
	var intro_offset_x: float
	if dock_left:
		intro_offset_x = -slide_dist * (1.0 - _ease_out_cubic(slide_t))
	else:
		intro_offset_x = slide_dist * (1.0 - _ease_out_cubic(slide_t))
	var x: float = text_x_base + intro_offset_x

	var baseline_y: float = top_y + _game.font_din.get_ascent(value_fs) - 3.0
	for i in range(time_str.length()):
		var c: String = time_str.substr(i, 1)
		_game.draw_string(_game.font_din, Vector2(x, baseline_y), c, HORIZONTAL_ALIGNMENT_LEFT, -1, value_fs, hud_black)
		x += adv


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
	# 単一オブジェクト: clearedステートでのみ塗りつぶし
	if _game.game_state == "cleared":
		var poly := PackedVector2Array()
		if _game.is_polygon_walk_order_active():
			var ord: PackedInt32Array = _game.polygon_walk_order
			for k in range(n):
				poly.append(positions[ord[k]])
		else:
			for i in range(n):
				poly.append(positions[i])
		_game.draw_colored_polygon(poly, fill_color)


func _draw_clear_overlay(vp: Vector2) -> void:
	var clear_elapsed: float = Time.get_ticks_msec() / 1000.0 - _clear_anim_time if _clear_anim_time > 0.0 else 10.0
	var clear_t: float = clampf(clear_elapsed / 0.3, 0.0, 1.0)
	var a: float = _ease_out_cubic(clear_t)
	# 背景ディムは _game に描画（透視変換の対象外）
	_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(LINE_COLOR,0.35 * a))
	# tri_deco 背景デコレーション（左右）
	if _tri_deco_texture != null:
		const SVG_W: float = 1920.0
		const SVG_H: float = 1080.0
		var deco_alpha: float = 0.1 * a
		var size_l := Vector2(SVG_W * 7.0, SVG_H * 7.0)
		var size_r := Vector2(SVG_W * 5.0, SVG_H * 5.0)
		var center_l := Vector2(vp.x * 0.3, vp.y * 0.5 - 10.0 * clear_elapsed)
		var center_r := Vector2(vp.x * 0.7, vp.y * 0.5 + 20.0 * clear_elapsed)
		_game.draw_texture_rect(_tri_deco_texture, Rect2(center_l - size_l * 0.5, size_l), false, Color(1, 1, 1, deco_alpha))
		_game.draw_texture_rect(_tri_deco_texture, Rect2(center_r - size_r * 0.5, size_r), false, Color(1, 1, 1, deco_alpha))
	# _clear_card_canvas が設定済みの場合はカード描画を draw シグナル経由に委譲
	# （_on_clear_card_canvas_draw → _draw_card_content_to で透視シェーダーが適用される）
	# 未設定の場合は _game に直接フォールバック
	if _clear_card_canvas == null:
		_draw_card_content_to(_game, vp, clear_elapsed)


func _draw_card_content_to(canvas: Node2D, vp: Vector2, clear_elapsed: float) -> void:
	const POP_DUR: float = 0.5
	var clear_t: float = clampf(clear_elapsed / POP_DUR, 0.0, 1.0)
	var clear_ease: float = _ease_out_cubic(clear_t)
	var clear_scale: float = lerp(10.0, 1.0, clear_ease)
	var a: float = clear_ease

	# カードサイズ（スケールアニメーション適用）
	var base_w: float = vp.x * 0.745 * 0.85
	var base_h: float = vp.y * 0.77 * 0.85 - 100.0
	var card_w: float = base_w * clear_scale
	var card_h: float = base_h * clear_scale
	var card_x: float = (vp.x - card_w) * 0.5
	var card_y: float = (vp.y - card_h) * 0.5

	var c_white: Color = Color(1.0, 1.0, 1.0, a)
	var c_red:   Color = Color(0.9490, 0.1882, 0.3216, a)
	var c_dark:  Color = Color(LINE_COLOR,a)
	var c_cream: Color = Color(1.0, 0.937, 0.89, a)

	# シャドウ・白背景
	canvas.draw_rect(Rect2(Vector2(card_x + 15.0, card_y + 15.0), Vector2(card_w, card_h)), Color(LINE_COLOR,0.25 * a))
	canvas.draw_rect(Rect2(Vector2(card_x, card_y), Vector2(card_w, card_h)), c_white)

	# ─── 各部寸法 ───
	var stripe_w: float = card_w * 0.046
	var left_w: float   = card_w * 0.50
	var bar_h: float    = card_h * 0.1734
	var pad: float      = stripe_w * 0.40
	var ch: float       = card_h * 1.1875

	# ─── 左ストライプ ───
	var red_h: float = card_h * 0.375 + 30.0
	canvas.draw_rect(Rect2(card_x, card_y, stripe_w, card_h), c_dark)

	# ストライプ下部の矢印パターン
	var diag_top: float = card_y + red_h
	var diag_bot: float = card_y + card_h - bar_h
	var stripe_right: float = card_x + stripe_w
	var tri_count: int = 10
	const TRI_SCALE: float = 0.8
	var tri_mid_x: float = card_x + stripe_w * 0.5 - 1.0
	var tri_sw: float    = stripe_w * TRI_SCALE
	var tri_left: float  = tri_mid_x - tri_sw * 0.5
	var tri_right: float = tri_mid_x + tri_sw * 0.5
	var shape_h: float   = tri_sw * 1.155
	var half_h: float    = shape_h * 0.5
	var notch_h: float   = shape_h * 0.25
	var spacing_v: float = tri_sw * 0.712
	var last_cy: float   = diag_bot - half_h - 5.0 + 100.0
	var first_cy: float  = last_cy - float(tri_count - 1) * spacing_v
	for tri_i in range(tri_count):
		var cy: float = first_cy + float(tri_i) * spacing_v
		var tri_a: float = float(tri_i + 1) * 0.10
		var tri_color: Color = Color(c_red.r, c_red.g, c_red.b, c_red.a * tri_a)
		var pts: PackedVector2Array
		if tri_i % 2 == 0:
			pts = PackedVector2Array([
				Vector2(tri_left,  cy - half_h),
				Vector2(tri_mid_x, cy - notch_h),
				Vector2(tri_right, cy),
				Vector2(tri_mid_x, cy + notch_h),
				Vector2(tri_left,  cy + half_h),
			])
		else:
			pts = PackedVector2Array([
				Vector2(tri_right, cy - half_h),
				Vector2(tri_right, cy + half_h),
				Vector2(tri_mid_x, cy + notch_h),
				Vector2(tri_left,  cy),
				Vector2(tri_mid_x, cy - notch_h),
			])
		canvas.draw_colored_polygon(pts, tri_color)

	# 「KATA-DRAW」縦書きテキスト
	if _font_din_tight == null:
		_font_din_tight = FontVariation.new()
		_font_din_tight.base_font = _game.font_din
		_font_din_tight.spacing_glyph = 0
	var fdt: FontVariation = _font_din_tight
	if _font_din_num == null:
		_font_din_num = FontVariation.new()
		_font_din_num.base_font = _game.font_din
		_font_din_num.spacing_glyph = -1
	if _font_din_result == null:
		_font_din_result = FontVariation.new()
		_font_din_result.base_font = _game.font_din
		_font_din_result.spacing_glyph = -2
	var kata_str: String = "KATA-DRAW"
	var kata_fs: int = maxi(8, int(stripe_w * 0.37))
	var kata_w: float = fdt.get_string_size(kata_str, HORIZONTAL_ALIGNMENT_LEFT, -1, kata_fs).x
	var kata_asc: float = fdt.get_ascent(kata_fs)
	var kata_dsc: float = fdt.get_descent(kata_fs)
	var kata_cx: float = card_x + (kata_asc + kata_dsc) * 0.55
	var kata_cy: float = card_y + stripe_w * 0.25 + kata_w * 0.5
	var kata_pivot := Vector2(kata_cx, kata_cy)
	var kata_xf: Transform2D = Transform2D(0.0, kata_pivot) * Transform2D(PI * 0.5, Vector2.ZERO) * Transform2D(0.0, -kata_pivot)
	canvas.draw_set_transform_matrix(kata_xf)
	canvas.draw_string(fdt, Vector2(kata_cx - kata_w * 0.5, kata_cy + (kata_asc - kata_dsc) * 0.5), kata_str, HORIZONTAL_ALIGNMENT_LEFT, -1, kata_fs, Color(1.0, 1.0, 1.0, a * 0.85))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

	# ─── 左テキストコンテンツ ───
	var tx: float = card_x + stripe_w + pad
	var tw: float = left_w - stripe_w - pad * 2.0

	if _font_clear == null:
		_font_clear = FontVariation.new()
		_font_clear.base_font = _game.font_din
		_font_clear.spacing_glyph = -7

	var stage_fs: int = int(ch * 0.219)
	var clear_str_w: float = _font_clear.get_string_size("CLEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, stage_fs).x
	var stage_str_w_base: float = fdt.get_string_size("STAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, stage_fs).x
	var stage_extra: int = maxi(0, roundi((clear_str_w - stage_str_w_base) / 4.0))
	if _font_stage == null:
		_font_stage = FontVariation.new()
		_font_stage.base_font = _game.font_din
	_font_stage.spacing_glyph = -5 + stage_extra
	var stage_str_w: float = _font_stage.get_string_size("STAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, stage_fs).x
	var stage_right: float = tx + maxf(stage_str_w, clear_str_w) - 8.0
	var stage_base_y: float = card_y + ch * 0.185
	canvas.draw_string(_font_stage, Vector2(tx, stage_base_y), "STAGE", HORIZONTAL_ALIGNMENT_LEFT, tw, stage_fs, c_red)
	var clear_base_y: float = card_y + ch * 0.358
	canvas.draw_string(_font_clear, Vector2(tx - 5.0, clear_base_y), "CLEAR", HORIZONTAL_ALIGNMENT_LEFT, tw, stage_fs, c_red)

	var num_fs: int = int(ch * 0.1203) - 2
	var num_base_y: float = card_y + ch * 0.498
	var stage_num_str: String = "#%d" % (_game.current_stage + 1)
	canvas.draw_string(_font_din_result, Vector2(tx, num_base_y), stage_num_str, HORIZONTAL_ALIGNMENT_LEFT,  stage_right - tx - 16.0, num_fs, c_dark)
	canvas.draw_string(_font_din_result, Vector2(tx, num_base_y), "RESULT",      HORIZONTAL_ALIGNMENT_RIGHT, stage_right - tx - 16.0, num_fs, c_dark)

	# ─── ラベルボックス + 数値 ───
	var box_w: float = left_w * 0.155
	var box_h: float = ch * 0.113
	var lbl_fs: int = maxi(8, int(box_h * 0.290))
	var val_fs: int = int(ch * 0.155)
	var val_asc: float = fdt.get_ascent(val_fs)
	var val_dsc: float = fdt.get_descent(val_fs)
	var lbl_asc: float = fdt.get_ascent(lbl_fs)
	var lbl_dsc: float = fdt.get_descent(lbl_fs)
	var lbl_top_pad: float = 0.0
	var lbl_l1_off: float = lbl_top_pad + lbl_asc
	var lbl_l2_off: float = lbl_l1_off + lbl_asc * 0.85
	var lbl_inner_pad: float = box_w * 0.08
	var ct_val_x: float = tx + box_w + pad
	var ct_val_w: float = maxf(0.0, stage_right - ct_val_x - 16.0)

	var ct_box_y: float = card_y + ch * 0.542 + 5.0
	canvas.draw_rect(Rect2(tx, ct_box_y, box_w, box_h), c_dark)
	canvas.draw_string(fdt, Vector2(tx + lbl_inner_pad, ct_box_y + lbl_l1_off), "CLEAR", HORIZONTAL_ALIGNMENT_LEFT, box_w - lbl_inner_pad, lbl_fs, c_white)
	canvas.draw_string(fdt, Vector2(tx + lbl_inner_pad, ct_box_y + lbl_l2_off), "TIME",  HORIZONTAL_ALIGNMENT_LEFT, box_w - lbl_inner_pad, lbl_fs, c_white)
	const SLOT_DUR: float = 0.5
	var ct_display: String
	var mc_display: String
	if clear_elapsed < SLOT_DUR:
		var slot_t: float = clear_elapsed / SLOT_DUR
		var freq: float = lerp(30.0, 3.0, slot_t * slot_t)
		var ct_range: float = maxf(_game.clear_time * 1.5, 15.0)
		var mc_range: float = float(maxi(_game.stage_move_count * 2, 9))
		ct_display = "%.2f" % (absf(sin(clear_elapsed * freq * TAU)) * ct_range)
		mc_display = "%d"   % int(absf(sin(clear_elapsed * freq * TAU * 1.37)) * mc_range)
	else:
		ct_display = "%.2f" % _game.clear_time
		mc_display = "%d"   % _game.stage_move_count

	var bar_progress: float = clampf(clear_elapsed / SLOT_DUR, 0.0, 1.0)
	var val_bg: Color = Color(0.87, 0.87, 0.87, a)
	var val_bg_x: float = tx + box_w
	var val_bg_w: float = ct_val_w + pad
	var ct_val_base: float = ct_box_y + (box_h + val_asc - val_dsc) * 0.5 - 10.0
	canvas.draw_rect(Rect2(val_bg_x, ct_box_y, val_bg_w * bar_progress, box_h), val_bg)
	canvas.draw_string(_font_din_num, Vector2(ct_val_x, ct_val_base), ct_display, HORIZONTAL_ALIGNMENT_RIGHT, ct_val_w, val_fs, c_dark)

	var tc_box_y: float = card_y + ch * 0.676 + 17.0
	canvas.draw_rect(Rect2(tx, tc_box_y, box_w, box_h), c_dark)
	canvas.draw_string(fdt, Vector2(tx + lbl_inner_pad, tc_box_y + lbl_l1_off), "TRY",   HORIZONTAL_ALIGNMENT_LEFT, box_w - lbl_inner_pad, lbl_fs, c_white)
	canvas.draw_string(fdt, Vector2(tx + lbl_inner_pad, tc_box_y + lbl_l2_off), "COUNT", HORIZONTAL_ALIGNMENT_LEFT, box_w - lbl_inner_pad, lbl_fs, c_white)
	var tc_val_base: float = tc_box_y + (box_h + val_asc - val_dsc) * 0.5 - 10.0
	canvas.draw_rect(Rect2(val_bg_x, tc_box_y, val_bg_w * bar_progress, box_h), val_bg)
	canvas.draw_string(_font_din_num, Vector2(ct_val_x, tc_val_base), mc_display, HORIZONTAL_ALIGNMENT_RIGHT, ct_val_w, val_fs, c_dark)

	# ─── NEW RECORD! バッジ ───
	const NR_FS: int = 15
	const NR_TEXT: String = "NEW RECORD!"
	const NR_PAD_X: float = 4.0
	const NR_PAD_Y: float = 2.0
	const NR_TAG_EXT: float = 10.0
	var nr_badge_a: float = a * clampf((clear_elapsed - SLOT_DUR) / 0.3, 0.0, 1.0)
	if nr_badge_a > 0.0:
		var nr_asc: float = _game.font_din.get_ascent(NR_FS)
		var nr_dsc: float = _game.font_din.get_descent(NR_FS)
		var nr_text_w: float = fdt.get_string_size(NR_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, NR_FS).x
		var nr_w: float = nr_text_w + NR_PAD_X * 2.0
		var nr_h: float = nr_asc + nr_dsc + NR_PAD_Y * 2.0 - 5.0
		var nr_right: float = val_bg_x + val_bg_w
		var nr_c_red: Color = Color(c_red.r, c_red.g, c_red.b, nr_badge_a)
		var nr_c_white: Color = Color(1.0, 1.0, 1.0, nr_badge_a)
		if _game._new_record_time:
			var ct_nr_y: float = ct_box_y - nr_h
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(nr_right - nr_w, ct_nr_y),
				Vector2(nr_right, ct_nr_y),
				Vector2(nr_right, ct_nr_y + nr_h),
				Vector2(nr_right - nr_w - NR_TAG_EXT, ct_nr_y + nr_h),
			]), nr_c_red)
			canvas.draw_string(fdt, Vector2(nr_right - nr_w + NR_PAD_X, ct_nr_y + (nr_h + nr_asc - nr_dsc) * 0.5), NR_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, NR_FS, nr_c_white)
		if _game._new_record_moves:
			var tc_nr_y: float = tc_box_y - nr_h
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(nr_right - nr_w, tc_nr_y),
				Vector2(nr_right, tc_nr_y),
				Vector2(nr_right, tc_nr_y + nr_h),
				Vector2(nr_right - nr_w - NR_TAG_EXT, tc_nr_y + nr_h),
			]), nr_c_red)
			canvas.draw_string(fdt, Vector2(nr_right - nr_w + NR_PAD_X, tc_nr_y + (nr_h + nr_asc - nr_dsc) * 0.5), NR_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, NR_FS, nr_c_white)

	# ─── 右：見本の図形 ───
	var shape_x: float = card_x + left_w
	var shape_w: float = card_w - left_w
	var shape_full_h: float = card_h - bar_h
	var shape_mx: float = shape_w * 0.075
	var shape_my: float = shape_full_h * 0.075
	var shape_rect := Rect2(shape_x + shape_mx - 53.0, card_y + shape_my + 50.0, shape_w - shape_mx * 2.0, shape_full_h - shape_my * 2.0)
	var fill_c := Color(c_red.r, c_red.g, c_red.b, c_red.a * 0.22)
	_stage_renderer._draw_canvas = canvas
	_stage_renderer.draw_ideal_filled(shape_rect, fill_c, c_red, maxf(2.5, shape_w * 0.006), shape_w * 0.013)
	_stage_renderer._draw_canvas = null

	# カード外枠
	_draw_rect_border_with_corners(Rect2(Vector2(card_x, card_y), Vector2(card_w, card_h)), c_dark, 5.75, canvas)


func _draw_results_stat_row(rect: Rect2, label_lines: Array, label_w: float, value_num: float, value_format: String, value_is_int: bool, a: float, label_x_offset: float = 0.0, value_fs_scale: float = 1.0, value_fs_override: int = 0, value_y_offset: float = 0.0, value_spacing_glyph: int = -2, slot_elapsed: float = -1.0, slot_phase_mult: float = 1.0) -> void:
	"""ダークラベルボックス＋グレー値エリアの統計行。ステージ結果カードの CLEAR TIME/TRY COUNT(2行)と
	   TOTAL バーの TOTAL CLEAR TIME/TOTAL TRY COUNT(3行)で共通利用する。
	   slot_elapsed >= 0 の間は、ステージクリアカード(_draw_card_content_to)と同じスロット演出技法で数値を仮表示する"""
	var c_white: Color = Color(1.0, 1.0, 1.0, a)
	var c_dark:  Color = Color(LINE_COLOR, a)
	var c_val_bg: Color = Color(0.87, 0.87, 0.87, a)

	if _font_din_stat_label == null:
		_font_din_stat_label = FontVariation.new()
		_font_din_stat_label.base_font = _game.font_din
		_font_din_stat_label.spacing_glyph = 0
	var lbl_rect := Rect2(rect.position, Vector2(label_w, rect.size.y))
	_game.draw_rect(lbl_rect, c_dark)
	var n: int = label_lines.size()
	var lfs: int = maxi(8, int(rect.size.y / maxf(float(n), 1.0) * 0.42 * 1.5))
	var lasc: float = _font_din_stat_label.get_ascent(lfs)
	var ldsc: float = _font_din_stat_label.get_descent(lfs)
	var lh: float = (lasc + ldsc) * 0.72
	var block_h: float = lh * float(n - 1) + lasc + ldsc
	var ty: float = lbl_rect.position.y + (rect.size.y - block_h) * 0.5 + lasc
	var tx: float = lbl_rect.position.x + label_w * 0.12 + label_x_offset
	var tw: float = label_w - label_w * 0.12 - 4.0
	for i in range(n):
		_game.draw_string(_font_din_stat_label, Vector2(tx, ty + lh * float(i)), str(label_lines[i]), HORIZONTAL_ALIGNMENT_LEFT, tw, lfs, c_white)

	if not _font_din_stat_val_cache.has(value_spacing_glyph):
		var fv := FontVariation.new()
		fv.base_font = _game.font_din
		fv.spacing_glyph = value_spacing_glyph
		_font_din_stat_val_cache[value_spacing_glyph] = fv
	var font_val: FontVariation = _font_din_stat_val_cache[value_spacing_glyph]
	var val_rect := Rect2(rect.position.x + label_w, rect.position.y, rect.size.x - label_w, rect.size.y)
	_game.draw_rect(val_rect, c_val_bg)

	# ─── 数値スロット演出（製品版ステージクリアカード _draw_card_content_to と同じ技法を引用） ───
	var value_str: String
	if slot_elapsed >= 0.0 and slot_elapsed < RESULTS_SLOT_DUR:
		var slot_t: float = slot_elapsed / RESULTS_SLOT_DUR
		var freq: float = lerp(30.0, 3.0, slot_t * slot_t)
		var wave: float = absf(sin(slot_elapsed * freq * TAU * slot_phase_mult))
		if value_is_int:
			var range_i: float = float(maxi(int(round(absf(value_num))) * 2, 9))
			value_str = value_format % int(wave * range_i)
		else:
			var range_f: float = maxf(absf(value_num) * 1.5, 15.0)
			value_str = value_format % (wave * range_f)
	else:
		value_str = (value_format % int(value_num)) if value_is_int else (value_format % value_num)

	var vfs: int = value_fs_override if value_fs_override > 0 else int(rect.size.y * 0.56 * 1.5 * value_fs_scale)
	var vasc: float = font_val.get_ascent(vfs)
	var vdsc: float = font_val.get_descent(vfs)
	var vy: float = val_rect.position.y + (rect.size.y + vasc - vdsc) * 0.5 + value_y_offset
	_game.draw_string(font_val, Vector2(val_rect.position.x, vy), value_str, HORIZONTAL_ALIGNMENT_RIGHT, val_rect.size.x - rect.size.y * 0.18, vfs, c_dark)


func _draw_results_stage_card(rect: Rect2, idx: int, a: float, slot_elapsed: float = -1.0) -> void:
	"""phase02〜03: 1ステージ分の結果ミニカード。ステージセレクトの吹き出し(_draw_bubble)の
	   外観(左ストライプ+三角装飾・#N+ステージ名ヘッダ・図形エリア)を踏襲しつつ、
	   CLEAR TIME/TRY COUNTのラベルはステージクリアカード(_draw_card_content_to)と同じ2行表記にする"""
	var c_white: Color = Color(1.0, 1.0, 1.0, a)
	var c_red:   Color = Color(0.9490, 0.1882, 0.3216, a)
	var c_dark:  Color = Color(LINE_COLOR, a)

	var bx: float = rect.position.x
	var by: float = rect.position.y
	var bw: float = rect.size.x
	var bh: float = rect.size.y
	var str_w: float = bw * 0.10

	# 外枠・右側コンテンツ背景
	_game.draw_rect(rect, c_dark)
	var cx: float = bx + str_w
	var cw: float = bw - str_w
	_game.draw_rect(Rect2(cx, by, cw, bh), c_white)

	# ─── 左ストライプ内の三角装飾（▷◁ 下から濃く） ───
	var tri_count: int = 8
	var tri_mid_x: float = bx + str_w * 0.5
	var shape_h: float = str_w * 1.155
	var half_h: float = shape_h * 0.5
	var notch_h: float = shape_h * 0.25
	var spacing_v: float = str_w * 0.712
	var last_cy: float = by + bh - half_h - 6.0
	var first_cy: float = last_cy - float(tri_count - 1) * spacing_v
	for tri_i in range(tri_count):
		var tcy: float = first_cy + float(tri_i) * spacing_v
		var tri_a: float = float(tri_i + 1) * 0.10
		var tri_color: Color = Color(c_red.r, c_red.g, c_red.b, c_red.a * tri_a)
		var pts: PackedVector2Array
		if tri_i % 2 == 0:
			pts = PackedVector2Array([
				Vector2(bx,          tcy - half_h),
				Vector2(tri_mid_x,   tcy - notch_h),
				Vector2(bx + str_w,  tcy),
				Vector2(tri_mid_x,   tcy + notch_h),
				Vector2(bx,          tcy + half_h),
			])
		else:
			pts = PackedVector2Array([
				Vector2(bx + str_w, tcy - half_h),
				Vector2(bx + str_w, tcy + half_h),
				Vector2(tri_mid_x,  tcy + notch_h),
				Vector2(bx,         tcy),
				Vector2(tri_mid_x,  tcy - notch_h),
			])
		_game.draw_colored_polygon(pts, tri_color)

	# ─── ヘッダ: #N + ステージ名 ───
	if _font_din_card_num == null:
		_font_din_card_num = FontVariation.new()
		_font_din_card_num.base_font = _game.font_din
		_font_din_card_num.spacing_glyph = 0
	var pad: float = cw * 0.07
	var num_fs: int = maxi(10, int(bh * 0.13))
	var num_str: String = "#%d" % (idx + 1)
	var num_y: float = by + pad * 0.6 + _font_din_card_num.get_ascent(num_fs)
	_game.draw_string(_font_din_card_num, Vector2(cx + pad, num_y), num_str, HORIZONTAL_ALIGNMENT_LEFT, cw - pad * 2.0, num_fs, c_dark)

	var name_fs: int = maxi(8, int(bh * 0.07))
	var name_str: String = ""
	var stage_ids: Array = _game._trial_stage_ids
	if idx < stage_ids.size():
		name_str = StageSelectManager.get_stage_name(stage_ids[idx])
	var hdr_h: float = bh * 0.28
	if not name_str.is_empty():
		var name_y: float = num_y + _font_din_card_num.get_descent(num_fs) + _game.font.get_ascent(name_fs) + 4.0 - 5.0
		_game.draw_string(_game.font, Vector2(cx + pad, name_y), name_str, HORIZONTAL_ALIGNMENT_LEFT, cw - pad * 2.0, name_fs, c_dark)

	# ─── 図形エリア（実際のプレイヤー描画結果 + 理想形を重ねたサムネイル） ───
	var rows_h: float = bh * 0.30
	var fig_top: float = by + hdr_h
	var fig_h: float = bh - hdr_h - rows_h - pad
	var side: float = minf(cw - pad * 2.0, fig_h)
	var thumb_rect := Rect2(cx + (cw - side) * 0.5, fig_top + maxf(0.0, (fig_h - side) * 0.5), side, side)
	var shape_dat: Dictionary = {}
	if idx < _game.stage_session.stage_result_shapes.size():
		shape_dat = _game.stage_session.stage_result_shapes[idx] as Dictionary
	var ideal_l: Array = shape_dat.get("ideal", [])
	var player_l: Array = shape_dat.get("player", [])
	if not ideal_l.is_empty() or not player_l.is_empty():
		_stage_renderer.draw_result_thumbnail(thumb_rect, ideal_l, player_l)
	else:
		_game.draw_rect(thumb_rect, Color(1.0, 1.0, 1.0, 0.1 * a))

	# ─── CLEAR TIME / TRY COUNT（ステージクリアカードと同じ2行ラベル） ───
	var t_s: float = _game.stage_session.stage_times[idx] if idx < _game.stage_session.stage_times.size() else 0.0
	var mv: int = _game.stage_session.stage_move_counts[idx] if idx < _game.stage_session.stage_move_counts.size() else 0
	var row_gap: float = pad * 0.5
	var row_top: float = by + bh - rows_h + row_gap
	var row_h: float = (rows_h - row_gap * 2.0 - row_gap) * 0.5
	var stat_label_w: float = cw * 0.40
	_draw_results_stat_row(Rect2(cx + row_gap, row_top, cw - row_gap * 2.0, row_h), ["CLEAR", "TIME"], stat_label_w, t_s, "%.2f", false, a, 0.0, 1.0, 0, 0.0, -1, slot_elapsed, 1.0)
	_draw_results_stat_row(Rect2(cx + row_gap, row_top + row_h + row_gap, cw - row_gap * 2.0, row_h), ["TRY", "COUNT"], stat_label_w, float(mv), "%d", true, a, 0.0, 1.0, 0, 0.0, -1, slot_elapsed, 1.37)

	# ─── 外枠 ───
	_draw_rect_border_with_corners(rect, c_dark, 4.0)


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


func _compute_results_layout(vp: Vector2) -> Dictionary:
	"""Result 画面のブロック位置・NEXT 座標（描画とヒット判定で共通）"""
	# ─── タイトル（画面最上部・全幅、DIN BOLD）───
	var title_fs: int = int(RESULT_SCREEN_TITLE_FS * 1.25)
	var title_top: float = 40.0
	var title_h: float = 150.0
	# ─── 左ダークカード（固定サイズ。下端(970px)は変更前と揃える）───
	var lp_x: float = 40.0
	var lp_y: float = title_top + title_h + 30.0
	var lp_w: float = 1040.0
	var lp_h: float = 970.0 - lp_y
	const CARD_PAD: float = 16.0
	# TOTALバー（CLEAR TIME / TRY COUNT の2段。カード下端から逆算）
	var total_row_h: float = 90.0
	var total_row_gap: float = 12.0
	var total_block_h: float = total_row_h * 2.0 + total_row_gap
	var total_bar_y: float = lp_y + lp_h - CARD_PAD - total_block_h
	var total_bar_y2: float = total_bar_y + total_row_h + total_row_gap
	# グリッド: TOTALブロックの上側に収まる範囲（実サイズそのまま使用。TOTALブロックとの間隔を15px追加）
	var grid_top: float = lp_y + CARD_PAD
	var grid_h: float = (total_bar_y - CARD_PAD - 15.0) - grid_top
	# NEXTボタン（画面右下隅）
	var next_s: float = 88.0
	var next_cx: float = vp.x - 50.0 - next_s * 0.5
	var next_cy: float = vp.y - 50.0 - next_s * 0.5
	return {
		"title_fs": title_fs, "title_top": title_top, "title_h": title_h,
		"lp_x": lp_x, "lp_y": lp_y, "lp_w": lp_w, "lp_h": lp_h,
		"card_pad": CARD_PAD,
		"grid_top": grid_top, "grid_h": grid_h,
		"total_bar_y": total_bar_y, "total_bar_y2": total_bar_y2, "total_row_h": total_row_h,
		"next_cx": next_cx, "next_cy": next_cy, "next_s": next_s,
	}


func get_results_next_button_rect(vp: Vector2) -> Rect2:
	# 描画側と同じ計算: NEXTアイコン右下端を画面右下端から縦100px・横100px（右パネル縮小に伴い30px上へ）
	const NEXT_BTN_S: float = 128.0
	var cx: float = vp.x - 100.0 - NEXT_BTN_S * 0.5 - 26.0
	var cy: float = vp.y - 100.0 - NEXT_BTN_S * 0.5 - 30.0
	return Rect2(cx - NEXT_BTN_S * 0.5, cy - NEXT_BTN_S * 0.5, NEXT_BTN_S, NEXT_BTN_S)


func get_results_camera_button_rect(vp: Vector2) -> Rect2:
	# _draw_results() 内のカメラボタン描画と同じ座標計算
	const NEXT_BTN_S: float = 128.0
	const IG_GAP: float = 120.0
	var ig_size: float = 88.0  # next_s と同値
	var next_cx_new: float = vp.x - 100.0 - NEXT_BTN_S * 0.5 - 26.0
	var ig_cy: float = vp.y - 100.0 - NEXT_BTN_S * 0.5 - 30.0
	var tw_cx: float = next_cx_new - ig_size - IG_GAP
	var cam_cx: float = tw_cx - ig_size - IG_GAP
	var icon_draw_size: float = ig_size * 1.50 * 0.90 * 1.50
	return Rect2(cam_cx - icon_draw_size * 0.5, ig_cy - icon_draw_size * 0.5, icon_draw_size, icon_draw_size)


func get_results_twitter_button_rect(vp: Vector2) -> Rect2:
	# _draw_results() 内のTwitterボタン描画と同じ座標計算
	const NEXT_BTN_S: float = 128.0
	const IG_GAP: float = 120.0
	var ig_size: float = 88.0
	var next_cx_new: float = vp.x - 100.0 - NEXT_BTN_S * 0.5 - 26.0
	var ig_cy: float = vp.y - 100.0 - NEXT_BTN_S * 0.5 - 30.0
	var tw_cx: float = next_cx_new - ig_size - IG_GAP
	var icon_draw_size: float = ig_size * 1.50 * 0.90 * 1.50
	return Rect2(tw_cx - icon_draw_size * 0.5, ig_cy - icon_draw_size * 0.5, icon_draw_size, icon_draw_size)


func get_results_active_focus(vp: Vector2) -> int:
	if get_results_camera_button_rect(vp).has_point(_result_mouse_pos):
		return 0
	if get_results_twitter_button_rect(vp).has_point(_result_mouse_pos):
		return 1
	if get_results_next_button_rect(vp).has_point(_result_mouse_pos):
		return 2
	return results_action_focus_index


# =============================================================================
# 体験版リザルト画面の演出フェーズ管理
#   ① メインタイトル → ② ステージカード(#1〜#10、連鎖ポップイン) →
#   ③ TOTALブロック(2段) → ④ 右パネル → ⑤ アイコングループ(カメラ/Twitter/NEXT)
#   の順に登場させる。各フェーズは個別にボタン押下でスキップ可能（初見から機能）。
# =============================================================================

func _results_phase_schedule() -> Dictionary:
	"""各フェーズの開始・所要時間・終了時刻（秒、リザルト画面表示からの経過時間基準）"""
	var p0_start: float = 0.0                      # ① メインタイトル
	var p0_dur: float = 0.30
	var p0_end: float = p0_start + p0_dur

	var p1_start: float = p0_end + 0.05             # ② ステージカード（10枚、連鎖ポップイン）
	var p1_stagger: float = 0.05
	var p1_dur: float = 0.30
	var p1_count: int = 10
	var p1_end: float = p1_start + float(p1_count - 1) * p1_stagger + p1_dur

	var p2_start: float = p1_end + 0.15             # ③ TOTALブロック（CLEAR TIME → TRY COUNT）
	var p2_stagger: float = 0.10
	var p2_dur: float = 0.30
	var p2_count: int = 2
	var p2_end: float = p2_start + float(p2_count - 1) * p2_stagger + p2_dur

	var p3_start: float = p2_end + 0.10             # ④ 右パネル
	var p3_dur: float = 0.30
	var p3_end: float = p3_start + p3_dur

	var p4_start: float = p3_end + 0.10             # ⑤ アイコングループ（カメラ→Twitter→NEXT）
	var p4_stagger: float = 0.08
	var p4_dur: float = 0.25
	var p4_count: int = 3
	var p4_end: float = p4_start + float(p4_count - 1) * p4_stagger + p4_dur

	return {
		"p0_start": p0_start, "p0_dur": p0_dur, "p0_end": p0_end,
		"p1_start": p1_start, "p1_stagger": p1_stagger, "p1_dur": p1_dur, "p1_end": p1_end,
		"p2_start": p2_start, "p2_stagger": p2_stagger, "p2_dur": p2_dur, "p2_end": p2_end,
		"p3_start": p3_start, "p3_dur": p3_dur, "p3_end": p3_end,
		"p4_start": p4_start, "p4_stagger": p4_stagger, "p4_dur": p4_dur, "p4_end": p4_end,
	}


func _results_effective_elapsed() -> float:
	"""スキップ分を加算した、演出計算用の経過時間"""
	if _results_anim_time < 0.0:
		return 999.0
	return maxf(0.0, Time.get_ticks_msec() / 1000.0 - _results_anim_time) + _results_skip_offset


func _reveal_progress(elapsed: float, start: float, dur: float) -> float:
	"""指定フェーズ内での進行度（0〜1の線形値。イージングは呼び出し側で適用）"""
	if dur <= 0.0:
		return 1.0 if elapsed >= start else 0.0
	return clampf((elapsed - start) / dur, 0.0, 1.0)


func is_results_reveal_done() -> bool:
	"""全フェーズの演出が終わっているか（ボタンの当たり判定を有効にしてよいか）"""
	var sched: Dictionary = _results_phase_schedule()
	return _results_effective_elapsed() >= sched["p4_end"]


const RESULTS_SLOT_DUR: float = 0.5  # _draw_results_stat_row() のスロット演出時間と揃える

func _results_slot_windows() -> Array:
	"""数値スロット演出の開始時刻一覧。ステージカード10件（CLEAR TIME/TRY COUNTは同時開始のため1件にまとめる）
	   + TOTALの2件で計12件。SFX（ui_count.wav / Telop_22.wav）の発火判定に使う"""
	var sched: Dictionary = _results_phase_schedule()
	var starts: Array = []
	for i in range(10):
		starts.append(sched["p1_start"] + float(i) * sched["p1_stagger"])
	starts.append(sched["p2_start"])
	starts.append(sched["p2_start"] + sched["p2_stagger"])
	return starts


func is_results_any_slot_active() -> bool:
	"""数値がスロット演出中（スクランブル表示中）かどうか。ui_count.wav のループ再生管理用"""
	var elapsed: float = _results_effective_elapsed()
	for s in _results_slot_windows():
		if elapsed >= s and elapsed < s + RESULTS_SLOT_DUR:
			return true
	return false


func get_results_slot_completed_count() -> int:
	"""elapsed時点で確定表示に切り替わったスロットの累計件数"""
	var elapsed: float = _results_effective_elapsed()
	var n: int = 0
	for s in _results_slot_windows():
		if elapsed >= s + RESULTS_SLOT_DUR:
			n += 1
	return n


func is_results_all_slots_done() -> bool:
	"""全スロット（12件）が確定表示になったか。呼び出し側でこれが初めてtrueになった瞬間に
	   Telop_22.wav をワンショット再生する（数値が1つ確定するごとではなく、全部止まった後の1回のみ）"""
	return get_results_slot_completed_count() >= _results_slot_windows().size()


func skip_results_phase() -> void:
	"""現在再生中のフェーズを即座に完了させ、次のフェーズへ進める（ボタン押下で呼ぶ）"""
	var sched: Dictionary = _results_phase_schedule()
	var elapsed: float = _results_effective_elapsed()
	var boundaries: Array = [sched["p0_end"], sched["p1_end"], sched["p2_end"], sched["p3_end"], sched["p4_end"]]
	for b in boundaries:
		if elapsed < b:
			_results_skip_offset += (b - elapsed)
			return


func _draw_results_title_justified(block_x: float, top_y: float, span_w: float, fs: int, color: Color) -> void:
	"""画面最上部の見出しを描画する。span_w に自然に収まらない場合のみ縮小し、
	   幅いっぱいへの強制引き伸ばしは行わない（体験版専用画面のためロケール非依存の英語表記で固定）"""
	var font: Font = _game.font_din
	var text: String = "TRIAL MODE RESULT"
	if text.is_empty():
		return
	var use_fs: int = fs
	while use_fs > 20 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, use_fs).x > span_w:
		use_fs -= 2
	var baseline_y: float = top_y + font.get_ascent(use_fs)
	_game.draw_string(font, Vector2(block_x, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, span_w, use_fs, color)


func _draw_results(vp: Vector2) -> void:
	_draw_bg(vp)

	var sched: Dictionary = _results_phase_schedule()
	var elapsed: float = _results_effective_elapsed()

	var lay: Dictionary = _compute_results_layout(vp)
	var lp_x: float    = lay["lp_x"]
	var lp_y: float    = lay["lp_y"]
	var lp_w: float    = lay["lp_w"]
	var title_fs: int     = lay["title_fs"]
	var title_top: float  = lay["title_top"]
	var grid_top: float   = lay["grid_top"]
	var grid_h: float     = lay["grid_h"]
	var total_bar_y: float  = lay["total_bar_y"]
	var total_bar_y2: float = lay["total_bar_y2"]
	var total_row_h: float  = lay["total_row_h"]
	var next_s: float     = lay["next_s"]

	const CARD_BORDER_W: float  = 5.75
	const SHADOW_OFFSET: float  = 12.5

	_game.draw_set_transform_matrix(Transform2D.IDENTITY)

	# ═══ ① メインタイトル ═══
	var p0_t: float = _reveal_progress(elapsed, sched["p0_start"], sched["p0_dur"])
	var p0_a: float = _ease_out_cubic(p0_t)
	if p0_a > 0.0:
		var c_red_title: Color = Color(0.9490, 0.1882, 0.3216, p0_a)
		var title_slide: float = lerp(24.0, 0.0, p0_a)
		_draw_results_title_justified(lp_x + 3.0 + 55.0, title_top + title_slide - 20.0, vp.x - lp_x - 70.0, title_fs, c_red_title)

	# ═══ ④ 右パネル（先に描画 → ②のステージカードより下レイヤー） ═══
	const RP_W: float      = 740.0
	const RP_H: float      = 530.0
	const RP_MARGIN: float = 120.0
	const INNER_PAD:     float = 20.0
	const HASH_BAR_H:    float = 60.0
	var p3_t: float = _reveal_progress(elapsed, sched["p3_start"], sched["p3_dur"])
	var p3_a: float = _ease_out_cubic(p3_t)
	var rp_w: float = RP_W
	var rp_h: float = RP_H
	var rp_x_slide: float = lerp(50.0, 0.0, p3_a)
	var rp_x: float = vp.x - RP_MARGIN - rp_w + rp_x_slide
	var rp_y: float = lp_y + 18.0
	var rp_rect := Rect2(rp_x, rp_y, rp_w, rp_h)
	if p3_a > 0.0:
		var c_white_p3: Color = Color(1.0, 1.0, 1.0, p3_a)
		var c_red_p3:   Color = Color(0.9490, 0.1882, 0.3216, p3_a)
		var c_dark_p3:  Color = Color(LINE_COLOR, p3_a)
		# 1. シャドウ
		_game.draw_rect(Rect2(rp_rect.position + Vector2(SHADOW_OFFSET, SHADOW_OFFSET), rp_rect.size), Color(LINE_COLOR, 0.30 * p3_a))
		# 2. 白塗り
		_game.draw_rect(rp_rect, c_white_p3)
		# 3. ロゴ（上部60%）
		var logo_area_h: float = rp_h * 0.60
		var logo_tex: Texture2D = _game.result_logo_texture if _game.result_logo_texture else _game.title_logo_texture
		if logo_tex:
			var tex_size: Vector2 = logo_tex.get_size()
			var max_w: float = (rp_w - INNER_PAD * 2.0) * 0.85
			var max_h: float = (logo_area_h - INNER_PAD * 2.0) * 0.85
			var sc_logo: float = minf(max_w / tex_size.x, max_h / tex_size.y)
			var dw: float = tex_size.x * sc_logo
			var dh: float = tex_size.y * sc_logo
			_game.draw_texture_rect(logo_tex, Rect2(Vector2(rp_x + (rp_w - dw) * 0.5, rp_y + (logo_area_h - dh) * 0.5), Vector2(dw, dh)), false, Color(1, 1, 1, p3_a))
		# COMING SOON テキスト
		var coming_fs: int = 48
		var coming_mid_y: float = rp_y + logo_area_h + (rp_h * 0.18) * 0.5
		var coming_y: float = coming_mid_y + _game.font_din.get_ascent(coming_fs) * 0.5 - _game.font_din.get_descent(coming_fs) * 0.5
		_game.draw_string(_game.font_din, Vector2(rp_x, coming_y), "COMING SOON", HORIZONTAL_ALIGNMENT_CENTER, rp_w, coming_fs, c_dark_p3)
		# 4. 赤バナー（枠線より下レイヤー・60px上に移動）
		var hash_bar_rect := Rect2(rp_x, rp_y + rp_h - HASH_BAR_H - 60.0, rp_w, HASH_BAR_H)
		_game.draw_rect(hash_bar_rect, c_red_p3)
		var hash_fs: int = 40
		var hash_y: float = hash_bar_rect.position.y + (HASH_BAR_H + _game.font_din.get_ascent(hash_fs) - _game.font_din.get_descent(hash_fs)) * 0.5
		_game.draw_string(_game.font_din, Vector2(rp_x, hash_y), "#KATADRAW", HORIZONTAL_ALIGNMENT_CENTER, rp_w, hash_fs, c_white_p3)
		# 5. 枠線（赤バナーより上レイヤー・製品版ボタンと同じKATA意匠: 四隅に●）
		_draw_rect_border_with_corners(rp_rect, c_dark_p3, CARD_BORDER_W)

	# ═══ ⑤ アイコングループ（カメラ→Twitter→NEXT の順にポップイン、画面右下に横並び） ═══
	var ig_size: float = next_s         # 88px (間隔計算基準)
	const IG_GAP: float = 120.0
	const NEXT_BTN_S: float = 128.0
	var next_cx_new: float = vp.x - 100.0 - NEXT_BTN_S * 0.5 - 26.0
	var ig_cy: float = vp.y - 100.0 - NEXT_BTN_S * 0.5 - 30.0
	var tw_cx: float = next_cx_new - ig_size - IG_GAP
	var cam_cx: float = tw_cx - ig_size - IG_GAP
	var icon_draw_size: float = ig_size * 1.50 * 0.90 * 1.50
	var res_act: int = get_results_active_focus(vp)

	var p4_cam_t: float = _reveal_progress(elapsed, sched["p4_start"], sched["p4_dur"])
	var p4_tw_t: float = _reveal_progress(elapsed, sched["p4_start"] + sched["p4_stagger"], sched["p4_dur"])
	var p4_next_t: float = _reveal_progress(elapsed, sched["p4_start"] + sched["p4_stagger"] * 2.0, sched["p4_dur"])

	if p4_cam_t > 0.0:
		var cam_a: float = _ease_out_cubic(p4_cam_t)
		var cam_sz: float = icon_draw_size * _ease_out_back(p4_cam_t)
		var cam_center := Vector2(cam_cx, ig_cy)
		_draw_result_camera_btn(cam_center - Vector2(cam_sz, cam_sz) * 0.5, cam_sz, cam_a, res_act == 0)
	if p4_tw_t > 0.0:
		var tw_a: float = _ease_out_cubic(p4_tw_t)
		var tw_sz: float = icon_draw_size * _ease_out_back(p4_tw_t)
		var tw_center := Vector2(tw_cx, ig_cy)
		_draw_result_twitter_btn(tw_center - Vector2(tw_sz, tw_sz) * 0.5, tw_sz, tw_a, res_act == 1)

	# ─── ③で使うTOTALブロックの横幅・位置を先に決め、②のグリッドの横幅をこれに合わせる ───
	var total_bar_w: float = lp_w * 0.88
	var total_bar_x: float = lp_x + (lp_w - total_bar_w) * 0.5
	var total_label_w: float = minf(220.0, total_bar_w * 0.24)

	# ═══ ② ステージ結果カード（背景は透明。5列×2行、#1から順に連鎖ポップイン。TOTALブロックと同幅で配置） ═══
	var n_stages: int = _game.stage_session.stage_times.size()
	const GRID_COLS: int = 5
	const GRID_ROWS: int = 2
	var col_gap: float = 14.0
	var row_gap: float = 20.0
	var col_w: float = (total_bar_w - col_gap * float(GRID_COLS - 1)) / float(GRID_COLS)
	var row_h: float = (grid_h - row_gap * float(GRID_ROWS - 1)) / float(GRID_ROWS)
	const CELL_BORDER_W: float = 1.25 * 3.0
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var idx: int = row * GRID_COLS + col
			var cell_x: float = total_bar_x + float(col) * (col_w + col_gap)
			var cell_y: float = grid_top + float(row) * (row_h + row_gap)
			var cell_rect := Rect2(cell_x, cell_y, col_w, row_h)
			if idx >= n_stages:
				_game.draw_rect(cell_rect, Color(1.0, 1.0, 1.0, 0.05))
				_game.draw_rect(cell_rect, Color(1.0, 1.0, 1.0, 0.15), false, CELL_BORDER_W)
				continue
			var card_start: float = sched["p1_start"] + float(idx) * sched["p1_stagger"]
			var card_t: float = _reveal_progress(elapsed, card_start, sched["p1_dur"])
			if card_t <= 0.0:
				continue
			var card_a: float = _ease_out_cubic(card_t)
			var card_scale: float = _ease_out_back(card_t)
			var card_slot_elapsed: float = maxf(0.0, elapsed - card_start)
			var ccx: float = cell_rect.position.x + cell_rect.size.x * 0.5
			var ccy: float = cell_rect.position.y + cell_rect.size.y * 0.5
			var pop_xf := Transform2D(Vector2(card_scale, 0.0), Vector2(0.0, card_scale), Vector2(ccx * (1.0 - card_scale), ccy * (1.0 - card_scale)))
			_game.draw_set_transform_matrix(pop_xf)
			_draw_results_stage_card(cell_rect, idx, card_a, card_slot_elapsed)
			_game.draw_set_transform_matrix(Transform2D.IDENTITY)

	# ═══ ③ TOTAL CLEAR TIME → TOTAL TRY COUNT（ステージクリアカードと同じラベル+値の演出を2段で流用） ═══
	var total_time: float = 0.0
	for t in _game.stage_session.stage_times:
		total_time += t
	var total_moves: int = 0
	for m in _game.stage_session.stage_move_counts:
		total_moves += m

	var p2_time_start: float = sched["p2_start"]
	var p2_moves_start: float = sched["p2_start"] + sched["p2_stagger"]
	var p2_time_t: float = _reveal_progress(elapsed, p2_time_start, sched["p2_dur"])
	var p2_moves_t: float = _reveal_progress(elapsed, p2_moves_start, sched["p2_dur"])

	if p2_time_t > 0.0:
		var p2_time_a: float = _ease_out_cubic(p2_time_t)
		var p2_time_slide: float = lerp(20.0, 0.0, p2_time_a)
		var total_time_rect := Rect2(total_bar_x, total_bar_y + p2_time_slide, total_bar_w, total_row_h)
		_draw_results_stat_row(total_time_rect, ["TOTAL", "CLEAR", "TIME"], total_label_w, total_time, "%.2f", false, p2_time_a, -10.0, 1.1, 97, -5.0, -2, maxf(0.0, elapsed - p2_time_start), 1.0)
	if p2_moves_t > 0.0:
		var p2_moves_a: float = _ease_out_cubic(p2_moves_t)
		var p2_moves_slide: float = lerp(20.0, 0.0, p2_moves_a)
		var total_moves_rect := Rect2(total_bar_x, total_bar_y2 + p2_moves_slide, total_bar_w, total_row_h)
		_draw_results_stat_row(total_moves_rect, ["TOTAL", "TRY", "COUNT"], total_label_w, float(total_moves), "%d", true, p2_moves_a, -10.0, 1.1, 97, -5.0, -2, maxf(0.0, elapsed - p2_moves_start), 1.37)

	# ─── NEXTボタン（アイコングループ右端。⑤の最後にポップイン） ───
	if p4_next_t > 0.0:
		var next_a: float = _ease_out_cubic(p4_next_t)
		var next_side: float = NEXT_BTN_S * _ease_out_back(p4_next_t)
		_draw_results_next_button(Vector2(next_cx_new, ig_cy), tr("RESULT_BTN_NEXT"), 35, next_a, next_side, res_act == 2)

	_game.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_result_camera_btn(pos: Vector2, size: float, alpha: float, pad_focused: bool = false) -> void:
	"""カメラアイコンボタン: ホバー中は result_icon01_on.png、通常は result_icon01_off.png"""
	var hovered: bool = Rect2(pos, Vector2(size, size)).has_point(_result_mouse_pos) or pad_focused
	var tex: Texture2D = _game.result_icon01_on_texture if hovered else _game.result_icon01_off_texture
	if tex:
		_game.draw_texture_rect(tex, Rect2(pos, Vector2(size, size)), false, Color(1, 1, 1, alpha))
	else:
		_game.draw_rect(Rect2(pos, Vector2(size, size)), Color(1.0, 1.0, 1.0, alpha * 0.3))
		_game.draw_rect(Rect2(pos, Vector2(size, size)), Color(LINE_COLOR,alpha), false, 2.5)


func _draw_result_twitter_btn(pos: Vector2, size: float, alpha: float, pad_focused: bool = false) -> void:
	"""Twitterアイコンボタン: ホバー中は result_icon02_on.png、通常は result_icon02_off.png"""
	var hovered: bool = Rect2(pos, Vector2(size, size)).has_point(_result_mouse_pos) or pad_focused
	var tex: Texture2D = _game.result_icon02_on_texture if hovered else _game.result_icon02_off_texture
	if tex:
		_game.draw_texture_rect(tex, Rect2(pos, Vector2(size, size)), false, Color(1, 1, 1, alpha))
	else:
		_game.draw_rect(Rect2(pos, Vector2(size, size)), Color(1.0, 1.0, 1.0, alpha * 0.3))
		_game.draw_rect(Rect2(pos, Vector2(size, size)), Color(LINE_COLOR,alpha), false, 2.5)


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


func _draw_results_next_button(center: Vector2, text: String, fs: int, alpha: float, side: float = 88.0, pad_focused: bool = false) -> void:
	"""Result 専用: 正方形・太枠・枠上を移動する ●。ホバー／フォーカス時は RESULT 画面と同系の赤（c_red）とクリームの反転"""
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
	var hovered: bool = rect.has_point(_result_mouse_pos) or pad_focused
	# _draw_results のタイトル赤・グリッド文字色と揃える
	var c_accent_red: Color = Color(0.9490, 0.1882, 0.3216, alpha)
	var c_cream: Color = Color(1.0, 0.99, 0.97, alpha)
	var c_body_dark: Color = Color(LINE_COLOR,alpha)
	var c_text: Color
	if hovered:
		c_text = c_cream
		# 頂点グラデーション（上: 明るい赤、下: 暗い赤）
		var r_pts := PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
		var r_grad := PackedColorArray([
			Color(1.00, 0.28, 0.40, alpha),
			Color(1.00, 0.28, 0.40, alpha),
			Color(0.50, 0.07, 0.14, alpha),
			Color(0.50, 0.07, 0.14, alpha),
		])
		_game.draw_polygon(r_pts, r_grad)
		# ハイライトストライプ（上部 26%）
		_game.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.26)), Color(1.0, 0.937, 0.89, 0.12 * alpha))
	else:
		c_text = c_body_dark
		var nr_pts := PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
		var nr_grad := PackedColorArray([
			Color(1.00, 0.990, 0.970, alpha),
			Color(1.00, 0.990, 0.970, alpha),
			Color(0.80, 0.792, 0.776, alpha),
			Color(0.80, 0.792, 0.776, alpha),
		])
		_game.draw_polygon(nr_pts, nr_grad)
		# ハイライトストライプ（上部 26%）
		_game.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.26)), Color(1.0, 1.0, 1.0, 0.22 * alpha))
	_draw_rect_border_with_corners(rect, Color(LINE_COLOR, alpha), 5.75)
	var ascent: float = _game.font_bold.get_ascent(fs)
	var descent: float = _game.font_bold.get_descent(fs)
	var baseline_y: float = rect.position.y + (draw_h + ascent - descent) * 0.5
	_game.draw_string(_game.font_bold, Vector2(rect.position.x, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, draw_w, fs, c_text)


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
	_game.draw_rect(play_rect, Color(LINE_COLOR,0.50 * pause_alpha))

	if _game.pause_confirm_title:
		# 確認ダイアログ（白背景、大きめ、ボタン幅広）
		var dlg_w: float = 640.0
		var dlg_h: float = 250.0
		var dlg_rect := Rect2(Vector2(play_cx - dlg_w / 2.0, play_cy - dlg_h / 2.0), Vector2(dlg_w, dlg_h))
		# 白背景で描画
		var dlg_shadow := Vector2(15.0, 15.0)
		_game.draw_rect(Rect2(dlg_rect.position + dlg_shadow, dlg_rect.size), Color(LINE_COLOR,0.25))
		_game.draw_rect(dlg_rect, Color(1.0, 1.0, 1.0))
		_draw_rect_border_with_corners(dlg_rect, LINE_COLOR, 5.75)
		# テキスト（Bold、大きめ）
		var confirm_msg: String = tr("TA_PAUSE_CONFIRM_MSG") if StageSelectManager.time_attack_active else tr("PAUSE_CONFIRM_MSG")
		_game.draw_string(_game.font_bold, Vector2(play_cx - dlg_w / 2.0, play_cy - 45.0), confirm_msg, HORIZONTAL_ALIGNMENT_CENTER, dlg_w, 42, Color(0.95, 0.19, 0.32))
		# ボタン（幅広、間隔広め）
		var cbtn_w: float = 220.0
		var cbtn_gap: float = cbtn_w / 2.0 + 30.0
		var cbtn_cy: float = play_cy + 50.0
		var yes_off: bool = _game.pause_confirm_index != 0
		var no_off: bool = _game.pause_confirm_index != 1
		_draw_auto_button_with_shadow(Vector2(play_cx - cbtn_gap, cbtn_cy), tr("PAUSE_CONFIRM_YES"), BTN_FONT_SIZE, 1.0, yes_off, cbtn_w, 64.0)
		_draw_auto_button_with_shadow(Vector2(play_cx + cbtn_gap, cbtn_cy), tr("PAUSE_CONFIRM_NO"), BTN_FONT_SIZE, 1.0, no_off, cbtn_w, 64.0)
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
		_game.draw_rect(Rect2(panel_rect.position + shadow_offset, panel_rect.size), Color(LINE_COLOR,0.25))
		_game.draw_rect(panel_rect, Color(1.0, 1.0, 1.0))
		_game.draw_rect(panel_rect, LINE_COLOR, false, 3.45)

		# 上部: 操作ガイド（90%スケール）
		var controls_top_y: float = panel_rect.position.y + 40.0 * ps + 50.0 * ps
		var controls_bottom_y: float = _draw_controls_stacked_in_panel(panel_rect, controls_top_y, ps)

		# 下部: [とじる][やりなおす][タイトルへ] — 同一サイズで横並び
		var btn_w: float = panel_w * 0.27
		var btn_gap: float = panel_w * 0.03
		var base_cy: float = panel_rect.end.y - 56.0 * ps - 50.0 * ps
		var labels: Array[String] = _game._pause_menu_labels()
		var n: int = labels.size()
		var total_w: float = btn_w * float(n) + btn_gap * float(n - 1)
		var btn_start_x: float = play_cx - total_w / 2.0 + btn_w / 2.0
		for i in range(n):
			var bcx: float = btn_start_x + i * (btn_w + btn_gap)
			var sel: bool = (i == _game.pause_index)
			var is_off: bool = not sel
			_draw_auto_button_with_shadow(Vector2(bcx, base_cy), labels[i], BTN_FONT_SIZE, 1.0, is_off, btn_w)

	_draw_player_avatar()


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


func _draw_tri_deco(origin: Vector2, w: float, color: Color) -> void:
	var h: float = w * 0.9495  # SVG bbox 475.5 / 500.85
	var shapes: Array = [
		[Vector2(0.2886,0.1754), Vector2(0.2886,0.3510), Vector2(0.1442,0.2633), Vector2(0.0000,0.1754), Vector2(0.1442,0.0877), Vector2(0.2886,0.0000)],
		[Vector2(0.0010,0.3918), Vector2(0.0010,0.2165), Vector2(0.1454,0.3041), Vector2(0.2896,0.3918), Vector2(0.1454,0.4795), Vector2(0.0010,0.5672)],
		[Vector2(0.6101,0.1968), Vector2(0.4659,0.2847), Vector2(0.3218,0.3722), Vector2(0.3216,0.1969), Vector2(0.3216,0.0213), Vector2(0.4659,0.1091)],
		[Vector2(0.3557,0.3918), Vector2(0.5000,0.3040), Vector2(0.6442,0.2163), Vector2(0.6442,0.3918), Vector2(0.6443,0.5673), Vector2(0.4999,0.4794)],
		[Vector2(0.7114,0.6081), Vector2(0.8557,0.5202), Vector2(0.9999,0.4326), Vector2(0.9999,0.6080), Vector2(1.0000,0.7836), Vector2(0.8557,0.6958)],
		[Vector2(0.0010,0.8244), Vector2(0.0010,0.6490), Vector2(0.1454,0.7367), Vector2(0.2896,0.8244), Vector2(0.1454,0.9121), Vector2(0.0010,1.0000)],
	]
	for shape in shapes:
		var pts := PackedVector2Array()
		for p in shape:
			pts.append(origin + Vector2((p as Vector2).x * w, (p as Vector2).y * h))
		_game.draw_colored_polygon(pts, color)
