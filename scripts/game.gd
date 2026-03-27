extends Node2D

# =============================================================================
# KATA-DRAW - Multi-Stage Shape Matching Game
# =============================================================================

# --- Stage / Config (StageData, GameConfig を参照) ---
var stage_manager: StageManager
var input_handler: InputHandler
var ui_renderer: UIRenderer

# --- Constants ---
const CIRCLE_SEGMENTS := 128

# --- Colors ---
const BG_COLOR := Color(1.0, 0.937, 0.89)
const HOVER_COLOR := Color(0.95, 0.19, 0.32)
const DRAG_COLOR := Color(0.98, 0.30, 0.40)
const SELECTED_COLOR := Color(0.95, 0.19, 0.32)
# ポイント位置・つかみ状態のエフェクト用
const POINT_POSITION_EFFECT_COLOR := Color(0.95, 0.40, 0.50)   # 淡赤（拡散エフェクト）
const GRAB_STATE_EFFECT_COLOR := Color(0.95, 0.19, 0.32)       # 赤色（収束エフェクト）
const IDEAL_CIRCLE_COLOR := Color(0.95, 0.19, 0.32, 0.55)
const IDEAL_STAR_COLOR := Color(0.75, 0.15, 0.25, 0.60)
const GUIDE_COLOR := Color(0.95, 0.19, 0.32, 0.75)
const GUIDE_STAR_COLOR := Color(0.75, 0.15, 0.25, 0.75)
const SELECT_RECT_COLOR := Color(0.95, 0.19, 0.32, 0.25)
const SELECT_RECT_BORDER := Color(0.95, 0.19, 0.32, 0.60)
const RULES_DEMO_POINTS := 7

# --- Game State ---
var current_stage: int = 0
var stage_type: String = "circle"
var shape_center: Vector2
var point_positions: Array[Vector2] = []
var hovered_index: int = -1
var game_state: String = "title"
var start_time: float = 0.0
var clear_time: float = 0.0
var min_radius: float = 0.0
var max_radius: float = 0.0
var clear_threshold: float = 5.0
var num_points: int = 12
var display_rate_min_pct: float = 50.0  # 実現率表示の下限（min～目標 を 0～100 にマッピング）
var font: Font
var font_bold: Font
var font_din: Font

# --- Circle Metrics (primary / group 1) ---
var current_centroid: Vector2 = Vector2.ZERO
var current_avg_radius: float = 0.0
var current_circularity_error: float = 100.0
var current_circularity: float = 0.0
var current_smoothness_error: float = 100.0
var current_smoothness: float = 0.0

# --- Two Circles (group 2) ---
var group_split: int = 0
var group1_cleared: bool = false
var group2_cleared: bool = false
var current_centroid_2: Vector2 = Vector2.ZERO
var current_avg_radius_2: float = 0.0
var current_circularity_error_2: float = 100.0
var current_circularity_2: float = 0.0
var current_smoothness_error_2: float = 100.0
var current_smoothness_2: float = 0.0

# --- Star ---
var star_rotation: float = 0.0
var star_outer_r: float = 0.0
var star_inner_r: float = 0.0

# --- Polygon (triangle, square) ---
var polygon_rotation: float = -PI / 2.0

# --- Correspondence (square, cat_face) ---
var ideal_points: Array = []
var ideal_outline_points: Array = []  # cat_face: 描画用（弧をサンプルした頂点）
var correspondence_scale: float = 1.0
var correspondence_rotation: float = 0.0

# --- Guide & Hints ---
var guide_start_time: float = 0.0
var guide_center_1: Vector2 = Vector2.ZERO
var guide_center_2: Vector2 = Vector2.ZERO
var guide_radius_val: float = 0.0
var ideal_display_radius: float = 0.0   # 理想形描画用（triangle/circle）。固定サイズ時は guide_radius_val
var ideal_display_radius_2: float = 0.0  # two_circles 用
var hint_alpha: float = 0.0
var guide_count_played: int = 0  # tracks which count SE ticks have played
var hint_active: bool = false
var hint_end_time: float = 0.0
var hints_triggered: Array[bool] = [false, false]

# --- Stage Results ---
var stage_times: Array[float] = []

# --- Multi-Select & Drag (InputHandler 縺梧峩譁ｰ縲“ame 縺御ｿ晄戟) ---
var selected_indices: Array[int] = []
var is_dragging: bool = false

## 実現率の表示値: min_pct以下→0、min_pct～目標値の範囲で百分率(0-100)にマッピング
## display_rate_min_pct はステージごとに指定可能（例: さかな75%、デフォルト50%）
func get_display_reproduction_rate(current: float) -> float:
	var goal_pct: float = 100.0 - clear_threshold
	var min_pct: float = display_rate_min_pct
	if current <= min_pct:
		return 0.0
	if goal_pct <= min_pct:
		return 0.0
	var pct: float = (current - min_pct) / (goal_pct - min_pct) * 100.0
	return clampf(pct, 0.0, 100.0)


## 表示用に小数点1桁で切り捨て。99.95→99.9 にし、未クリアで100.0%と出るのを防ぐ
func get_display_reproduction_rate_floor(current: float) -> float:
	var raw: float = get_display_reproduction_rate(current)
	return floor(raw * 10.0) / 10.0

# --- Menu / Config ---
var menu_index: int = 0          # 0=Game Start, 1=Config, 2=Quit
var menu_confirm_quit: bool = false
var menu_confirm_index: int = 1  # 0=はい, 1=いいえ
var config_index: int = 0        # 0=Resolution, 1=Window Mode, 2=Language, 3=BGM Vol, 4=SE Vol, 5=Back
var config_sub: String = ""      # "" or "resolution", "window_mode", "language"
var config_sub_index: int = 0    # cursor within sub-menu
var is_fullscreen: bool = false
var current_resolution: int = 1  # 0=720P, 1=1080P
var bgm_volume: int = 5         # 0(ミュート)〜10(最大), デフォルト5
var se_volume: int = 5          # 0(ミュート)〜10(最大), デフォルト5

# --- Rules デモ ---
var rules_focus_button: bool = false  # false=デモ操作, true=[次へ]にフォーカス
var preferred_input_method: String = ""  # "mouse" or "pad" - デモで次へを選んだ操作にロック。""は未設定
var rules_demo_center: Vector2 = Vector2.ZERO
var rules_demo_radius: float = 90.0
# rules_confirm: ゲーム開始前の操作デバイス確認（"mouse" | "pad"）
var rules_confirm_kind: String = ""
var rules_confirm_index: int = 0  # 0=はい 1=いいえ

# --- Stage debug（Godot エディタからの実行時のみ。F2。エクスポート版では無効）---
const STAGE_DEBUG_ROW_H: float = 80.0
const STAGE_DEBUG_HEADER_H: float = 64.0
# タイトル・ガイド文言の下からリスト行を描画（重なり防止）
const STAGE_DEBUG_LIST_TOP_Y: float = 172.0
# 2カラム: 左リスト / 右エディタ。下端余白のみ（旧ボトムパネル廃止）
const STAGE_DEBUG_CONTENT_BOTTOM_MARGIN: float = 16.0
const STAGE_DEBUG_LEFT_COL_RATIO: float = 0.40
const STAGE_DEBUG_TOP_BTN_Y: float = 32.0
const STAGE_DEBUG_ACTION_BTN_H: float = 30.0
const STAGE_DEBUG_ACTION_BTN_GAP: float = 8.0
const STAGE_DEBUG_FIELD_KEYS: Array[String] = [
	"type", "num_points", "min_radius", "max_radius", "variance", "zigzag",
	"display_rate_min_pct", "clear_pct", "group_sizes",
]
var stage_debug_scroll: float = 0.0
var stage_debug_selected: int = 0
var stage_debug_pending: Dictionary = {}  # idx -> partial Dictionary
var stage_debug_field_buffers: Dictionary = {}  # field_key -> String（選択行の編集用）
var stage_debug_field_focus_idx: int = -1  # STAGE_DEBUG_FIELD_KEYS のインデックス、-1=なし
var stage_debug_edit_buffer: String = ""
var stage_debug_last_error: String = ""
var debug_stage_test_mode: bool = false
var debug_stage_test_seed: int = 0
var input_recorder: DebugInputRecorder

# --- Pause Menu ---
var pause_active: bool = false
var pause_index: int = 0          # 0=閉じる, 1=やりなおし, 2=タイトルへ戻る
var pause_confirm_title: bool = false
var pause_confirm_index: int = 0  # 0=はい, 1=いいえ
var pause_elapsed: float = 0.0    # elapsed time saved when pausing
var pause_retry_elapsed: float = -1.0  # やりなおし時、再開時の経過時間を保持（-1=未使用）

# --- Logo ---
var logo_texture: Texture2D
var title_logo_texture: Texture2D
var title_logo02_texture: Texture2D
var bg_texture: Texture2D
var logo_start_time: float = 0.0
var title_start_time: float = 0.0

# --- Audio ---
# 一時: BGM を聞こえないようにする。通常に戻すときは false にして _apply_bgm_volume() の通常分岐を有効にする。
const BGM_TEMPORARILY_SILENT := true
var bgm_title: AudioStreamPlayer
var bgm_game: AudioStreamPlayer
var bgm_result: AudioStreamPlayer
var sfx_count: AudioStreamPlayer
var sfx_clear: AudioStreamPlayer
var sfx_on: AudioStreamPlayer
var sfx_click: AudioStreamPlayer
var sfx_window_open: AudioStreamPlayer
var sfx_window_close: AudioStreamPlayer
var sfx_catch: AudioStreamPlayer
var sfx_move: AudioStreamPlayer
var sfx_stageclear: AudioStreamPlayer
var sfx_point: AudioStreamPlayer
var sfx_motion: AudioStreamPlayer
var _sfx_move_playing: bool = false  # ui_move ループ管理用

# --- Debug ---
var debug_mode: bool = true  # デバッグ用: ヒントガイドを常時表示。false で [K] on title でトグル


func _ready() -> void:
	stage_manager = StageManager.new()
	ui_renderer = UIRenderer.new(self)
	input_handler = InputHandler.new(self)
	input_handler.on_points_changed = _on_input_points_changed
	input_handler.on_selection_changed = _on_selection_changed
	TranslationServer.set_locale("ja")
	var mplus_font: Font = load("res://assets/fonts/Mplus2-Medium.otf")
	if mplus_font:
		mplus_font.fallbacks = [ThemeDB.fallback_font]
		font = mplus_font
	else:
		font = ThemeDB.fallback_font
	var bold_font: Font = load("res://assets/fonts/Mplus2-Bold.otf")
	if bold_font:
		bold_font.fallbacks = [font]
		font_bold = bold_font
	else:
		font_bold = font
	var din_font: FontFile = load("res://assets/fonts/D-DIN-PRO-700-Bold.otf")
	if din_font:
		din_font.fallbacks = [font]
		din_font.set_extra_spacing(0, TextServer.SPACING_GLYPH, 5)
		font_din = din_font
	else:
		font_din = font
	var vp: Vector2 = get_viewport_rect().size
	# Center shape in right 3/4 area (UI zone is left 1/4)
	shape_center = Vector2(vp.x * GameConfig.UI_WIDTH_RATIO + (vp.x - vp.x * GameConfig.UI_WIDTH_RATIO) * 0.5, vp.y * 0.5)
	_setup_audio()
	# Load logo texture
	logo_texture = _load_texture("res://assets/UI/messed_logo.png")
	title_logo_texture = _load_texture("res://assets/UI/kata-draw_logo.png")
	title_logo02_texture = _load_texture("res://assets/UI/kata-draw_logo02.png")
	bg_texture = _load_texture("res://assets/UI/kata-draw_bg.png")
	_setup_game_cursor()
	game_state = "logo"
	logo_start_time = Time.get_ticks_msec() / 1000.0


# =============================================================================
# Mouse cursor（ゲームウィンドウ内のみ、OS のデフォルト矢印を差し替え）
# =============================================================================

func _setup_game_cursor() -> void:
	# res://assets/UI/katacursor.png（エディタでインポート後に利用）
	var tex_path := "res://assets/UI/katacursor.png"
	var tex_src: Texture2D = _load_texture(tex_path)
	if tex_src == null:
		push_warning("Game cursor texture missing: " + tex_path)
		return
	var img: Image = tex_src.get_image()
	if img == null:
		img = Image.new()
		img.load_from_file(tex_path)
		# load_from_file の戻り値と OK の比較は型推論でエラーになる環境があるため、サイズで判定
		if img.get_width() < 1 or img.get_height() < 1:
			push_warning("Game cursor: could not read image data")
			return
	img = img.duplicate()
	var nw: int = maxi(1, img.get_width() / 4)
	var nh: int = maxi(1, img.get_height() / 4)
	img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	var tex: Texture2D = ImageTexture.create_from_image(img)
	# 左上をクリック基準（ホットスポットは縮小後テクスチャの左上）
	var hotspot := Vector2.ZERO
	# CursorShape は通常 0〜16（HELP）。Input.CURSOR_MAX は GDScript から見えない環境がある
	const CURSOR_SHAPE_COUNT := 17
	for shape in range(CURSOR_SHAPE_COUNT):
		Input.set_custom_mouse_cursor(tex, shape as Input.CursorShape, hotspot)


# =============================================================================
# Audio
# =============================================================================

func _setup_audio() -> void:
	bgm_title = AudioStreamPlayer.new()
	bgm_title.stream = _load_audio("res://assets/sounds/maintheme_image_01.mp3")
	bgm_title.volume_db = -22.5
	bgm_title.autoplay = false
	if bgm_title.stream is AudioStreamMP3:
		bgm_title.stream.loop = true
	add_child(bgm_title)

	bgm_game = AudioStreamPlayer.new()
	bgm_game.stream = _load_audio("res://assets/sounds/audiostock_1544483_sample.mp3")
	bgm_game.volume_db = -16.5
	bgm_game.autoplay = false
	if bgm_game.stream is AudioStreamMP3:
		bgm_game.stream.loop = true
	add_child(bgm_game)

	bgm_result = AudioStreamPlayer.new()
	bgm_result.stream = _load_audio("res://assets/sounds/maou_bgm_cyber13.mp3")
	bgm_result.volume_db = -16.5
	bgm_result.autoplay = false
	if bgm_result.stream is AudioStreamMP3:
		bgm_result.stream.loop = true
	add_child(bgm_result)

	sfx_count = AudioStreamPlayer.new()
	sfx_count.stream = _load_audio("res://assets/sounds/count.wav")
	sfx_count.volume_db = -14.5
	add_child(sfx_count)

	sfx_clear = AudioStreamPlayer.new()
	sfx_clear.stream = _load_audio("res://assets/sounds/match.mp3")
	sfx_clear.volume_db = -14.5
	add_child(sfx_clear)

	sfx_on = AudioStreamPlayer.new()
	sfx_on.stream = _load_audio("res://assets/sounds/ui_on.wav")
	sfx_on.volume_db = -14.5
	add_child(sfx_on)

	sfx_point = AudioStreamPlayer.new()
	sfx_point.stream = _load_audio("res://assets/sounds/ui_point.wav")
	sfx_point.volume_db = -14.5
	add_child(sfx_point)

	sfx_motion = AudioStreamPlayer.new()
	sfx_motion.stream = _load_audio("res://assets/sounds/motion.mp3")
	sfx_motion.volume_db = -14.5
	add_child(sfx_motion)

	sfx_click = AudioStreamPlayer.new()
	sfx_click.stream = _load_audio("res://assets/sounds/ui_click.wav")
	sfx_click.volume_db = -14.5
	add_child(sfx_click)

	sfx_window_open = AudioStreamPlayer.new()
	sfx_window_open.stream = _load_audio("res://assets/sounds/ui_window_open.wav")
	sfx_window_open.volume_db = -14.5
	add_child(sfx_window_open)

	sfx_window_close = AudioStreamPlayer.new()
	sfx_window_close.stream = _load_audio("res://assets/sounds/ui_window_close.wav")
	sfx_window_close.volume_db = -14.5
	add_child(sfx_window_close)

	sfx_catch = AudioStreamPlayer.new()
	sfx_catch.stream = _load_audio("res://assets/sounds/ui_catch.wav")
	sfx_catch.volume_db = -14.5
	add_child(sfx_catch)

	sfx_move = AudioStreamPlayer.new()
	sfx_move.stream = _load_audio("res://assets/sounds/ui_move.wav")
	sfx_move.volume_db = -14.5
	add_child(sfx_move)

	sfx_stageclear = AudioStreamPlayer.new()
	sfx_stageclear.stream = _load_audio("res://assets/sounds/ui_stageclear.wav")
	sfx_stageclear.volume_db = -14.5
	add_child(sfx_stageclear)

	_apply_bgm_volume()
	_apply_se_volume()


func _play_bgm(player: AudioStreamPlayer) -> void:
	if player and player.stream and not player.playing:
		player.play()

func _stop_bgm(player: AudioStreamPlayer) -> void:
	if player and player.playing:
		player.stop()

func _play_sfx(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()

func _start_sfx_move() -> void:
	if sfx_move and sfx_move.stream:
		if not sfx_move.playing:
			sfx_move.play()
		_sfx_move_playing = true

func _stop_sfx_move() -> void:
	# _sfx_move_playing と実再生がずれた場合でも確実に止める（クリア直後など）
	if sfx_move and sfx_move.playing:
		sfx_move.stop()
	_sfx_move_playing = false


func _load_texture(path: String) -> Texture2D:
	var tex = load(path)
	if tex:
		return tex
	if not FileAccess.file_exists(path):
		push_warning("Texture not found: " + path)
		return null
	var img := Image.load_from_file(path)
	if img:
		return ImageTexture.create_from_image(img)
	return null


func _load_audio(path: String) -> AudioStream:
	# Try resource load first (works when imported by editor)
	var stream = load(path)
	if stream:
		return stream

	# Fallback: load raw file for formats that support it
	if not FileAccess.file_exists(path):
		push_warning("Audio file not found: " + path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var data := file.get_buffer(file.get_length())
	file.close()

	if path.ends_with(".mp3"):
		var mp3 := AudioStreamMP3.new()
		mp3.data = data
		mp3.loop = false
		return mp3
	elif path.ends_with(".ogg"):
		var ogg := AudioStreamOggVorbis.load_from_buffer(data)
		return ogg

	push_warning("Unsupported audio format: " + path)
	return null


# =============================================================================
# Stage Management (StageManager 縺ｫ蟋碑ｭｲ)
# =============================================================================

func _on_selection_changed() -> void:
	"""左スティック・十字キー・LB/RBで選択ポイントが変更された時に胞子バースト"""
	if selected_indices.size() > 0:
		var positions: Array[Vector2] = []
		for idx in selected_indices:
			if idx >= 0 and idx < point_positions.size():
				positions.append(point_positions[idx])
		if positions.size() > 0:
			ui_renderer.spawn_spore_burst(positions)


func _on_input_points_changed() -> void:
	# InputHandler のコールバック: メトリクス計算とクリア判定を呼ぶ
	# つかんで移動時は胞子増量なし（処理は残し、量は0）
	if selected_indices.size() > 0:
		var positions: Array[Vector2] = []
		for idx in selected_indices:
			if idx >= 0 and idx < point_positions.size():
				positions.append(point_positions[idx])
		if positions.size() > 0:
			ui_renderer.spawn_spore_burst(positions, 0)
	if game_state == "rules":
		queue_redraw()
		return
	_calculate_metrics()
	_check_clear()


func _sync_stage_vars() -> void:
	"""StageManager 縺ｮ迥ｶ諷九ｒ game 縺ｮ陦ｨ遉ｺ逕ｨ螟画焚縺ｫ蜷梧悄縺吶ｋ"""
	current_stage = stage_manager.current_stage
	stage_type = stage_manager.stage_type
	min_radius = stage_manager.min_radius
	max_radius = stage_manager.max_radius
	clear_threshold = stage_manager.clear_threshold
	num_points = stage_manager.num_points
	display_rate_min_pct = stage_manager.display_rate_min_pct
	current_centroid = stage_manager.current_centroid
	current_avg_radius = stage_manager.current_avg_radius
	current_circularity_error = stage_manager.current_circularity_error
	current_circularity = stage_manager.current_circularity
	current_smoothness_error = stage_manager.current_smoothness_error
	current_smoothness = stage_manager.current_smoothness
	group_split = stage_manager.group_split
	group1_cleared = stage_manager.group1_cleared
	group2_cleared = stage_manager.group2_cleared
	current_centroid_2 = stage_manager.current_centroid_2
	current_avg_radius_2 = stage_manager.current_avg_radius_2
	current_circularity_error_2 = stage_manager.current_circularity_error_2
	current_circularity_2 = stage_manager.current_circularity_2
	current_smoothness_error_2 = stage_manager.current_smoothness_error_2
	current_smoothness_2 = stage_manager.current_smoothness_2
	star_rotation = stage_manager.star_rotation
	star_outer_r = stage_manager.star_outer_r
	star_inner_r = stage_manager.star_inner_r
	polygon_rotation = stage_manager.polygon_rotation
	ideal_points = stage_manager.ideal_points.duplicate()
	ideal_outline_points = stage_manager.ideal_outline_points.duplicate()
	correspondence_scale = stage_manager.correspondence_scale
	correspondence_rotation = stage_manager.correspondence_rotation
	guide_center_1 = stage_manager.guide_center_1
	guide_center_2 = stage_manager.guide_center_2
	guide_radius_val = stage_manager.guide_radius_val
	ideal_display_radius = stage_manager.ideal_display_radius
	ideal_display_radius_2 = stage_manager.ideal_display_radius_2


func _start_stage(idx: int) -> void:
	var vp: Vector2 = get_viewport_rect().size
	# 左1/4がUIのため、右3/4領域の中央に図形を配置
	shape_center = Vector2(vp.x * GameConfig.UI_WIDTH_RATIO + (vp.x - vp.x * GameConfig.UI_WIDTH_RATIO) * 0.5, vp.y * 0.5)
	stage_manager.start_stage(idx, shape_center, vp, point_positions)
	_sync_stage_vars()

	game_state = "guide_info"
	guide_start_time = 0.0
	hovered_index = -1
	is_dragging = false
	selected_indices.clear()
	input_handler.reset_for_stage()
	ui_renderer.clear_spore_particles()
	hint_alpha = 0.0
	hint_active = false
	hints_triggered = [false, false]
	guide_count_played = 0
	queue_redraw()


func _calculate_metrics() -> void:
	stage_manager.calculate_metrics(point_positions)
	_sync_stage_vars()


func _point_accuracy_alpha(idx: int) -> float:
	return stage_manager.get_point_accuracy_alpha(idx, point_positions)


func _is_locked(idx: int) -> bool:
	return stage_manager.is_locked(idx)


func _is_selected(idx: int) -> bool:
	return idx in selected_indices


func _check_clear() -> void:
	if game_state != "playing":
		return
	# For two_circles: check per-group clear and lock
	if stage_manager.stage_type == "two_circles":
		var changed: bool = false
		if not stage_manager.group1_cleared and stage_manager.is_group_clear(1):
			stage_manager.set_group1_cleared()
			_sync_stage_vars()
			_play_sfx(sfx_clear)
			input_handler.release_mouse_grab()
			changed = true
		if not stage_manager.group2_cleared and stage_manager.is_group_clear(2):
			stage_manager.set_group2_cleared()
			_sync_stage_vars()
			_play_sfx(sfx_clear)
			input_handler.release_mouse_grab()
			changed = true
		if changed and stage_manager.group1_cleared and stage_manager.group2_cleared:
			is_dragging = false
			game_state = "cleared"
			input_handler.release_mouse_grab()
			_stop_sfx_move()
			clear_time = Time.get_ticks_msec() / 1000.0 - start_time
			stage_times.append(clear_time)
			ui_renderer.clear_spore_particles()
			var mid: Vector2 = (current_centroid + current_centroid_2) * 0.5
			ui_renderer.spawn_particles(mid)
			_play_sfx(sfx_stageclear)
		return

	if stage_manager.is_clear():
		is_dragging = false
		game_state = "cleared"
		input_handler.release_mouse_grab()
		_stop_sfx_move()
		clear_time = Time.get_ticks_msec() / 1000.0 - start_time
		stage_times.append(clear_time)
		ui_renderer.clear_spore_particles()
		ui_renderer.spawn_particles(current_centroid)
		_play_sfx(sfx_clear)
		_play_sfx(sfx_stageclear)


func _force_clear_for_debug() -> void:
	"""デバッグ用: 実現率を無視してステージクリア扱いにする"""
	if stage_manager.stage_type == "two_circles":
		stage_manager.set_group1_cleared()
		stage_manager.set_group2_cleared()
		_sync_stage_vars()
	is_dragging = false
	game_state = "cleared"
	input_handler.release_mouse_grab()
	_stop_sfx_move()
	clear_time = Time.get_ticks_msec() / 1000.0 - start_time
	stage_times.append(clear_time)
	ui_renderer.clear_spore_particles()
	if stage_manager.stage_type == "two_circles":
		ui_renderer.spawn_particles((current_centroid + current_centroid_2) * 0.5)
	else:
		ui_renderer.spawn_particles(current_centroid)
	_play_sfx(sfx_clear)
	_play_sfx(sfx_stageclear)


# =============================================================================
# Input
# =============================================================================

func _input(event: InputEvent) -> void:
	# Helper: 決定操作（Enter/Space/A のみ。Any key は無効）
	var is_confirm_key: bool = (
		event is InputEventKey and event.pressed and not event.echo
		and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)
	)
	var is_confirm_pad: bool = (
		event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A
	)
	var is_confirm_click: bool = (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	)
	var is_confirm: bool = is_confirm_key or is_confirm_pad or is_confirm_click

	# 押下アニメーション待機中は入力を無視
	if ui_renderer._btn_press_pending:
		return

	if game_state == "logo":
		if is_confirm:
			game_state = "title_intro"
			queue_redraw()
		return

	if game_state == "title_intro":
		if is_confirm:
			ui_renderer.start_title_intro_skip()
			queue_redraw()
		return

	if game_state == "title":
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
			debug_mode = not debug_mode
			queue_redraw()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2 and _debug_tools_enabled():
			_enter_stage_debug_screen()
		elif is_confirm:
			ui_renderer.set_btn_press_with_callback(tr("TITLE_START"), func():
				game_state = "menu"
				menu_index = 0
				menu_confirm_quit = false
				queue_redraw()
			)
			queue_redraw()
		return

	if game_state == "menu":
		_input_menu(event, is_confirm_key, is_confirm_pad, is_confirm_click)
		return

	if game_state == "config":
		_input_config(event, is_confirm_key, is_confirm_pad, is_confirm_click)
		return

	if game_state == "stage_debug":
		_input_stage_debug(event)
		return

	if game_state == "rules_confirm":
		_input_rules_confirm(event, is_confirm_key, is_confirm_pad, is_confirm_click)
		return

	if game_state == "rules":
		_input_rules(event, is_confirm_key, is_confirm_pad, is_confirm_click)
		return

	if game_state == "guide_info":
		# ボタンなし: 任意の箇所で クリック / Enter / A で次へ（目標図形を隠さない）
		if is_confirm:
			game_state = "guide_countdown"
			guide_start_time = Time.get_ticks_msec() / 1000.0
			guide_count_played = 0
			queue_redraw()
		return

	if game_state == "guide_countdown":
		return

	if game_state == "results":
		if is_confirm_key or is_confirm_pad:
			ui_renderer.set_btn_press_with_callback(tr("BTN_TO_TITLE"), func():
				_stop_bgm(bgm_result)
				_return_to_title_or_stage_debug_from_test()
				queue_redraw()
			)
			queue_redraw()
		elif is_confirm_click and _hit_results_button(event.position):
			ui_renderer.set_btn_press_with_callback(tr("BTN_TO_TITLE"), func():
				_stop_bgm(bgm_result)
				_return_to_title_or_stage_debug_from_test()
				queue_redraw()
			)
			queue_redraw()
		return

	if game_state == "cleared":
		if debug_stage_test_mode:
			if is_confirm_key or is_confirm_pad:
				ui_renderer.set_btn_press_with_callback(tr("BTN_NEXT"), func():
					_stop_bgm(bgm_game)
					_return_to_title_or_stage_debug_from_test()
					queue_redraw()
				, false)
				queue_redraw()
			elif is_confirm_click and _hit_cleared_button(event.position):
				ui_renderer.set_btn_press_with_callback(tr("BTN_NEXT"), func():
					_stop_bgm(bgm_game)
					_return_to_title_or_stage_debug_from_test()
					queue_redraw()
				, false)
				queue_redraw()
			return
		if is_confirm_key or is_confirm_pad:
			ui_renderer.set_btn_press_with_callback(tr("BTN_NEXT"), func():
				_advance_stage()
			, false)
			queue_redraw()
		elif is_confirm_click and _hit_cleared_button(event.position):
			ui_renderer.set_btn_press_with_callback(tr("BTN_NEXT"), func():
				_advance_stage()
			, false)
			queue_redraw()
		return

	# --- Pause Menu ---
	var is_pause_key: bool = (
		(event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE)
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)
	)

	if pause_active:
		_input_pause(event, is_confirm, is_pause_key)
		return

	# デバッグ用: [S] で実現率無視の強制クリア
	if game_state == "playing" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S:
		_force_clear_for_debug()
		return

	if game_state == "playing" and is_pause_key:
		pause_active = true
		pause_index = 0
		pause_elapsed = Time.get_ticks_msec() / 1000.0 - start_time
		ui_renderer._pause_anim_time = Time.get_ticks_msec() / 1000.0
		ui_renderer._pause_closing = false
		_play_sfx(sfx_window_open)
		_stop_sfx_move()
		queue_redraw()
		return

	# --- Playing: InputHandler に委譲（デモで選んだ操作にロック）---
	if game_state != "playing":
		return
	# イントロ演出中は入力を受け付けない（ポーズ除く）
	if not ui_renderer.is_stage_intro_done():
		return
	if debug_stage_test_mode and input_recorder and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _hit_debug_log_button(event.position):
			_flush_debug_input_log()
			return
	var allow_mouse: bool = preferred_input_method != "pad"
	var allow_pad: bool = preferred_input_method != "mouse"
	if allow_mouse and event is InputEventMouseMotion:
		input_handler.handle_mouse_motion(event.position)
	if allow_mouse and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var prev_dragging: bool = is_dragging
			input_handler.handle_mouse_press(event.position)
			if not prev_dragging and is_dragging:
				_play_sfx(sfx_catch)
		else:
			input_handler.handle_mouse_release(event.position)
			_stop_sfx_move()
	if allow_pad and event is InputEventJoypadButton:
		input_handler.handle_pad_button(event.button_index, event.pressed)
	if debug_stage_test_mode and input_recorder:
		input_recorder.record_event(event)


func _input_menu(event: InputEvent, is_confirm_key: bool, is_confirm_pad: bool, is_confirm_click: bool) -> void:
	# 終了確認ダイアログ表示中
	if menu_confirm_quit:
		_input_menu_quit_confirm(event, is_confirm_key or is_confirm_pad, is_confirm_click)
		return
	var menu_count: int = 3
	var moved: bool = false
	# Keyboard / Pad up/down
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			menu_index = (menu_index - 1 + menu_count) % menu_count
			moved = true
		elif event.keycode == KEY_DOWN:
			menu_index = (menu_index + 1) % menu_count
			moved = true
		elif event.keycode == KEY_ESCAPE:
			game_state = "title"
			preferred_input_method = ""
			title_start_time = Time.get_ticks_msec() / 1000.0
			queue_redraw()
			return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_UP:
			menu_index = (menu_index - 1 + menu_count) % menu_count
			moved = true
		elif event.button_index == JOY_BUTTON_DPAD_DOWN:
			menu_index = (menu_index + 1) % menu_count
			moved = true
		elif event.button_index == JOY_BUTTON_B:
			game_state = "title"
			preferred_input_method = ""
			title_start_time = Time.get_ticks_msec() / 1000.0
			queue_redraw()
			return
	# Mouse hover detection
	if event is InputEventMouseMotion:
		var vp: Vector2 = get_viewport_rect().size
		var mouse_y: float = event.position.y
		for i in range(menu_count):
			var btn_cy: float = ui_renderer.get_menu_btn_cy(vp, i, menu_count)
			if mouse_y >= btn_cy - 35.0 and mouse_y <= btn_cy + 35.0:
				menu_index = i
	# Confirm: キー/パッドは選択項目を実行。マウスは項目上クリックのみ有効
	var do_confirm: bool = false
	if is_confirm_key or is_confirm_pad:
		do_confirm = true
	elif is_confirm_click:
		var clicked_item: int = _hit_menu_item(event.position)
		if clicked_item >= 0:
			menu_index = clicked_item
			do_confirm = true
	if do_confirm:
		var menu_labels: Array[String] = [tr("MENU_GAME_START"), tr("MENU_CONFIG"), tr("MENU_QUIT")]
		var idx: int = menu_index
		ui_renderer.set_btn_press_with_callback(menu_labels[idx], func():
			if idx == 0:
				_enter_rules()
			elif idx == 1:
				game_state = "config"
				config_index = 0
				config_sub = ""
			elif idx == 2:
				menu_confirm_quit = true
				menu_confirm_index = 1  # デフォルト「いいえ」
			queue_redraw()
		)
		queue_redraw()
	if moved:
		queue_redraw()


func _input_menu_quit_confirm(event: InputEvent, is_confirm: bool, is_confirm_click: bool) -> void:
	# ESC / B で閉じる
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		menu_confirm_quit = false
		queue_redraw()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		menu_confirm_quit = false
		queue_redraw()
		return
	# 左右でカーソル移動
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			menu_confirm_index = (menu_confirm_index - 1 + 2) % 2
			queue_redraw()
		elif event.keycode == KEY_RIGHT:
			menu_confirm_index = (menu_confirm_index + 1) % 2
			queue_redraw()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_LEFT:
			menu_confirm_index = (menu_confirm_index - 1 + 2) % 2
			queue_redraw()
		elif event.button_index == JOY_BUTTON_DPAD_RIGHT:
			menu_confirm_index = (menu_confirm_index + 1) % 2
			queue_redraw()
	# マウスホバー
	if event is InputEventMouseMotion:
		var vp: Vector2 = get_viewport_rect().size
		var cx: float = vp.x / 2.0
		var dlg_w: float = 640.0
		var cbtn_w: float = 220.0
		var cbtn_gap: float = cbtn_w / 2.0 + 30.0
		var cbtn_cy: float = vp.y / 2.0 + 50.0
		var mouse: Vector2 = event.position
		if mouse.y >= cbtn_cy - 35.0 and mouse.y <= cbtn_cy + 35.0:
			if mouse.x >= cx - cbtn_gap - cbtn_w / 2.0 and mouse.x <= cx - cbtn_gap + cbtn_w / 2.0:
				menu_confirm_index = 0
			elif mouse.x >= cx + cbtn_gap - cbtn_w / 2.0 and mouse.x <= cx + cbtn_gap + cbtn_w / 2.0:
				menu_confirm_index = 1
	# 決定
	if is_confirm or is_confirm_click:
		var do_action: bool = false
		if is_confirm:
			do_action = true
		elif is_confirm_click:
			var vp: Vector2 = get_viewport_rect().size
			var cx: float = vp.x / 2.0
			var cbtn_w: float = 220.0
			var cbtn_gap: float = cbtn_w / 2.0 + 30.0
			var cbtn_cy: float = vp.y / 2.0 + 50.0
			var mouse: Vector2 = event.position
			if mouse.y >= cbtn_cy - 35.0 and mouse.y <= cbtn_cy + 35.0:
				if mouse.x >= cx - cbtn_gap - cbtn_w / 2.0 and mouse.x <= cx - cbtn_gap + cbtn_w / 2.0:
					menu_confirm_index = 0
					do_action = true
				elif mouse.x >= cx + cbtn_gap - cbtn_w / 2.0 and mouse.x <= cx + cbtn_gap + cbtn_w / 2.0:
					menu_confirm_index = 1
					do_action = true
		if do_action:
			var confirm_label: String = tr("PAUSE_CONFIRM_YES") if menu_confirm_index == 0 else tr("PAUSE_CONFIRM_NO")
			var cidx: int = menu_confirm_index
			ui_renderer.set_btn_press_with_callback(confirm_label, func():
				if cidx == 0:
					get_tree().quit()
				else:
					menu_confirm_quit = false
				queue_redraw()
			)
			queue_redraw()


func _input_config(event: InputEvent, is_confirm_key: bool, is_confirm_pad: bool, is_confirm_click: bool) -> void:
	var items_count: int = 6  # resolution, window_mode, language, bgm_vol, se_vol, back
	var moved: bool = false

	# ESC / B: back
	var is_back: bool = (
		(event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE)
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	)
	if is_back:
		if config_sub != "":
			config_sub = ""
		else:
			game_state = "menu"
		queue_redraw()
		return

	# 音量項目（3=BGM, 4=SE）の左右キー直接増減
	var is_volume_item: bool = config_sub == "" and (config_index == 3 or config_index == 4)
	var vol_delta: int = 0

	# Up/Down navigation (サブメニューは横並びなのでLeft/Rightも対応)
	if event is InputEventKey and event.pressed and not event.echo:
		if config_sub == "":
			if event.keycode == KEY_UP:
				config_index = (config_index - 1 + items_count) % items_count
				moved = true
			elif event.keycode == KEY_DOWN:
				config_index = (config_index + 1) % items_count
				moved = true
			elif is_volume_item and event.keycode == KEY_LEFT:
				vol_delta = -1
			elif is_volume_item and event.keycode == KEY_RIGHT:
				vol_delta = 1
		else:
			var sub_count: int = _config_sub_count()
			if event.keycode == KEY_LEFT or event.keycode == KEY_UP:
				config_sub_index = (config_sub_index - 1 + sub_count) % sub_count
				moved = true
			elif event.keycode == KEY_RIGHT or event.keycode == KEY_DOWN:
				config_sub_index = (config_sub_index + 1) % sub_count
				moved = true
	if event is InputEventJoypadButton and event.pressed:
		if config_sub == "":
			if event.button_index == JOY_BUTTON_DPAD_UP:
				config_index = (config_index - 1 + items_count) % items_count
				moved = true
			elif event.button_index == JOY_BUTTON_DPAD_DOWN:
				config_index = (config_index + 1) % items_count
				moved = true
			elif is_volume_item and event.button_index == JOY_BUTTON_DPAD_LEFT:
				vol_delta = -1
			elif is_volume_item and event.button_index == JOY_BUTTON_DPAD_RIGHT:
				vol_delta = 1
		else:
			var sub_count: int = _config_sub_count()
			if event.button_index == JOY_BUTTON_DPAD_LEFT or event.button_index == JOY_BUTTON_DPAD_UP:
				config_sub_index = (config_sub_index - 1 + sub_count) % sub_count
				moved = true
			elif event.button_index == JOY_BUTTON_DPAD_RIGHT or event.button_index == JOY_BUTTON_DPAD_DOWN:
				config_sub_index = (config_sub_index + 1) % sub_count
				moved = true

	# 音量増減の適用
	if vol_delta != 0:
		if config_index == 3:
			bgm_volume = clampi(bgm_volume + vol_delta, 0, 10)
			_apply_bgm_volume()
			_play_sfx(sfx_click)
		elif config_index == 4:
			se_volume = clampi(se_volume + vol_delta, 0, 10)
			_apply_se_volume()
			_play_sfx(sfx_click)
		queue_redraw()

	# Mouse hover
	if event is InputEventMouseMotion:
		var vp: Vector2 = get_viewport_rect().size
		var base_y: float = vp.y * 0.28
		var spacing: float = 103.5
		var box_h: float = (font.get_ascent(34) + font.get_descent(34)) * 1.5
		var mouse_pos: Vector2 = event.position
		if config_sub == "":
			for i in range(items_count):
				var item_y: float = base_y + i * spacing
				var extra_y: float = (vp.y * 0.15 - 35.0) if i == 5 else 0.0
				if mouse_pos.y >= item_y - 20.0 + extra_y and mouse_pos.y <= item_y - 16.0 + box_h + extra_y:
					config_index = i
		else:
			# サブメニュー（横並び）のホバー — テキスト幅に基づく判定
			var vx: float = vp.x * 0.42
			var box_w: float = vp.x * 0.24
			var item_y: float = base_y + config_index * spacing
			var sub_x: float = vx + box_w + 30.0
			if mouse_pos.y >= item_y - 20.0 and mouse_pos.y <= item_y - 16.0 + box_h:
				var sub_labels: Array[String] = _get_config_sub_labels_for_hit(config_index)
				var sx_cursor: float = sub_x
				for i in range(sub_labels.size()):
					var tw: float = font.get_string_size(sub_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x + 30.0
					if mouse_pos.x >= sx_cursor and mouse_pos.x <= sx_cursor + tw:
						config_sub_index = i
					sx_cursor += tw

	# マウスで▼▲ボタンクリック
	if is_confirm_click:
		var vol_hit: Dictionary = _hit_config_volume_btn(event.position)
		if vol_hit.get("ok", false):
			config_index = vol_hit["item"]
			var vd: int = vol_hit["delta"]
			if config_index == 3:
				bgm_volume = clampi(bgm_volume + vd, 0, 10)
				_apply_bgm_volume()
				_play_sfx(sfx_click)
			elif config_index == 4:
				se_volume = clampi(se_volume + vd, 0, 10)
				_apply_se_volume()
				_play_sfx(sfx_click)
			queue_redraw()
			return

	# Confirm: キー/パッドは選択項目を実行。マウスは項目上クリックのみ有効
	var do_confirm: bool = false
	if is_confirm_key or is_confirm_pad:
		do_confirm = true
	elif is_confirm_click:
		var hit: Dictionary = _hit_config_item(event.position)
		if hit.get("ok", false):
			config_index = hit["main"]
			if hit.get("sub", -1) >= 0:
				config_sub_index = hit["sub"]
			do_confirm = true
	if do_confirm:
		if config_sub == "":
			match config_index:
				0:
					config_sub = "resolution"
					config_sub_index = current_resolution
				1:
					config_sub = "window_mode"
					config_sub_index = 0 if is_fullscreen else 1
				2:
					config_sub = "language"
					var _loc: String = TranslationServer.get_locale()
					if _loc == "ja":
						config_sub_index = 0
					elif _loc == "en":
						config_sub_index = 1
					elif _loc == "zh_CN":
						config_sub_index = 2
					elif _loc == "zh_TW":
						config_sub_index = 3
					else:
						config_sub_index = 0
				5:
					ui_renderer.set_btn_press_with_callback(tr("CONFIG_BACK"), func():
						game_state = "menu"
						queue_redraw()
					)
					queue_redraw()
		else:
			_apply_config_selection()
			config_sub = ""
		queue_redraw()
	if moved:
		queue_redraw()


func _config_sub_count() -> int:
	match config_sub:
		"resolution": return 2
		"window_mode": return 2
		"language": return 4
	return 0


func _get_config_sub_labels_for_hit(item_index: int) -> Array[String]:
	match item_index:
		0: return [tr("CONFIG_720P"), tr("CONFIG_1080P")]
		1: return [tr("CONFIG_FULLSCREEN"), tr("CONFIG_WINDOW")]
		2: return [tr("CONFIG_LANG_JA"), tr("CONFIG_LANG_EN"), tr("CONFIG_LANG_ZH_CN"), tr("CONFIG_LANG_ZH_TW")]
	return []


func _apply_config_selection() -> void:
	match config_sub:
		"resolution":
			current_resolution = config_sub_index
			var new_size: Vector2i = Vector2i(1920, 1080) if config_sub_index == 1 else Vector2i(1280, 720)
			if not is_fullscreen:
				DisplayServer.window_set_size(new_size)
				_center_window()
			get_viewport().size = new_size
		"window_mode":
			is_fullscreen = (config_sub_index == 0)
			if is_fullscreen:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				var res_size: Vector2i = Vector2i(1920, 1080) if current_resolution == 1 else Vector2i(1280, 720)
				DisplayServer.window_set_size(res_size)
				_center_window()
		"language":
			var locale: String
			match config_sub_index:
				0: locale = "ja"
				1: locale = "en"
				2: locale = "zh_CN"
				3: locale = "zh_TW"
				_: locale = "ja"
			TranslationServer.set_locale(locale)


func _center_window() -> void:
	var screen_rect: Rect2i = DisplayServer.screen_get_usable_rect(0)
	var win_size: Vector2i = get_window().get_size_with_decorations()
	get_window().position = screen_rect.position + (screen_rect.size / 2 - win_size / 2)


func _apply_bgm_volume() -> void:
	if BGM_TEMPORARILY_SILENT:
		bgm_title.volume_db = -80.0
		bgm_game.volume_db = -80.0
		bgm_result.volume_db = -80.0
		return
	# レベル5を基準(0dB補正)とし、0=ミュート, 10=最大
	# BGM基準音量: title=-22.5, game/result=-16.5
	var offset_db: float = _volume_offset_db(bgm_volume)
	bgm_title.volume_db = -22.5 + offset_db
	bgm_game.volume_db = -16.5 + offset_db
	bgm_result.volume_db = -16.5 + offset_db


func _apply_se_volume() -> void:
	var offset_db: float = _volume_offset_db(se_volume)
	sfx_count.volume_db = -14.5 + offset_db
	sfx_clear.volume_db = -14.5 + offset_db
	sfx_on.volume_db = -14.5 + offset_db
	sfx_click.volume_db = -14.5 + offset_db
	sfx_window_open.volume_db = -14.5 + offset_db
	sfx_window_close.volume_db = -14.5 + offset_db
	sfx_catch.volume_db = -14.5 + offset_db
	sfx_move.volume_db = -14.5 + offset_db
	sfx_stageclear.volume_db = -14.5 + offset_db
	sfx_point.volume_db = -14.5 + offset_db
	sfx_motion.volume_db = -14.5 + offset_db


func _volume_offset_db(level: int) -> float:
	# 0=ミュート(-80dB), 1〜10: -20dB 〜 +10dB（5で0dB）
	if level <= 0:
		return -80.0
	return (level - 5) * 3.0


# --- Rules デモ ---

func _enter_rules() -> void:
	game_state = "rules"
	rules_focus_button = false
	rules_confirm_kind = ""
	rules_confirm_index = 0
	var vp: Vector2 = get_viewport_rect().size
	var guide_h: float = 270.0
	var btn_h: float = 100.0
	var shift_down: float = vp.y * 0.15
	rules_demo_center = Vector2(vp.x / 2.0, guide_h + shift_down + (vp.y - guide_h - shift_down - btn_h) / 2.0)
	rules_demo_radius = minf(vp.x, vp.y) * 0.12
	point_positions.clear()
	var demo_points: int = RULES_DEMO_POINTS
	for i in range(demo_points):
		var angle: float = TAU * i / float(demo_points)
		point_positions.append(rules_demo_center + Vector2(cos(angle), sin(angle)) * rules_demo_radius)
	stage_type = "circle"
	stage_manager.stage_type = "circle"
	stage_manager.group_split = 0
	stage_manager.num_points = demo_points
	stage_manager.current_centroid = rules_demo_center
	shape_center = rules_demo_center
	selected_indices.clear()
	hovered_index = -1
	is_dragging = false
	input_handler.reset_for_stage()
	ui_renderer.clear_spore_particles()
	queue_redraw()


func _input_rules(event: InputEvent, is_confirm_key: bool, is_confirm_pad: bool, is_confirm_click: bool) -> void:
	var is_start: bool = (
		event is InputEventJoypadButton and event.pressed
		and event.button_index == JOY_BUTTON_START
	)

	# ESC / パッドBボタンでメニューへ戻る
	var is_back: bool = (
		(event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE)
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	)
	if is_back:
		game_state = "menu"
		queue_redraw()
		return

	# Start → コントローラ確認ダイアログ
	if is_start:
		_open_rules_confirm("pad")
		queue_redraw()
		return

	# Enter / Space（キーボード）→ マウス確認ダイアログ（Space はマウス扱い）
	if is_confirm_key:
		_open_rules_confirm("mouse")
		queue_redraw()
		return

	# デモ操作: マウス/コントローラを input_handler へ
	if event is InputEventMouseMotion:
		input_handler.handle_mouse_motion(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _hit_rules_button(event.position):
				ui_renderer.set_btn_press_with_callback(tr("BTN_NEXT"), func():
					_open_rules_confirm("mouse")
				)
				queue_redraw()
				return
			var prev_dragging: bool = is_dragging
			input_handler.handle_mouse_press(event.position)
			if not prev_dragging and is_dragging:
				_play_sfx(sfx_catch)
		else:
			input_handler.handle_mouse_release(event.position)
			_stop_sfx_move()
	if event is InputEventJoypadButton:
		input_handler.handle_pad_button(event.button_index, event.pressed)
	queue_redraw()


func _open_rules_confirm(kind: String) -> void:
	game_state = "rules_confirm"
	rules_confirm_kind = kind
	rules_confirm_index = 0
	queue_redraw()


func _close_rules_confirm_no() -> void:
	game_state = "rules"
	rules_confirm_kind = ""
	queue_redraw()


func _apply_rules_confirm_yes() -> void:
	var k: String = rules_confirm_kind
	rules_confirm_kind = ""
	preferred_input_method = "mouse" if k == "mouse" else "pad"
	_start_game()


func _input_rules_confirm(event: InputEvent, is_confirm_key: bool, is_confirm_pad: bool, is_confirm_click: bool) -> void:
	var is_confirm: bool = is_confirm_key or is_confirm_pad
	# ESC / B → いいえ（ルール画面に戻る）
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_rules_confirm_no()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		_close_rules_confirm_no()
		return
	# 左右でフォーカス
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			rules_confirm_index = (rules_confirm_index - 1 + 2) % 2
			queue_redraw()
		elif event.keycode == KEY_RIGHT:
			rules_confirm_index = (rules_confirm_index + 1) % 2
			queue_redraw()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_LEFT:
			rules_confirm_index = (rules_confirm_index - 1 + 2) % 2
			queue_redraw()
		elif event.button_index == JOY_BUTTON_DPAD_RIGHT:
			rules_confirm_index = (rules_confirm_index + 1) % 2
			queue_redraw()
	# マウスホバー
	if event is InputEventMouseMotion:
		var vp: Vector2 = get_viewport_rect().size
		var cx: float = vp.x / 2.0
		var dlg_cy: float = vp.y / 2.0
		var cbtn_w: float = 220.0
		var cbtn_gap: float = cbtn_w / 2.0 + 30.0
		var cbtn_cy: float = dlg_cy + 50.0
		var mouse: Vector2 = event.position
		if mouse.y >= cbtn_cy - 35.0 and mouse.y <= cbtn_cy + 35.0:
			if mouse.x >= cx - cbtn_gap - cbtn_w / 2.0 and mouse.x <= cx - cbtn_gap + cbtn_w / 2.0:
				rules_confirm_index = 0
			elif mouse.x >= cx + cbtn_gap - cbtn_w / 2.0 and mouse.x <= cx + cbtn_gap + cbtn_w / 2.0:
				rules_confirm_index = 1
	# 決定
	if is_confirm or is_confirm_click:
		var do_action: bool = false
		if is_confirm:
			do_action = true
		elif is_confirm_click:
			var vp2: Vector2 = get_viewport_rect().size
			var cx2: float = vp2.x / 2.0
			var dlg_cy2: float = vp2.y / 2.0
			var cbtn_w2: float = 220.0
			var cbtn_gap2: float = cbtn_w2 / 2.0 + 30.0
			var cbtn_cy2: float = dlg_cy2 + 50.0
			var mouse2: Vector2 = event.position
			if mouse2.y >= cbtn_cy2 - 35.0 and mouse2.y <= cbtn_cy2 + 35.0:
				if mouse2.x >= cx2 - cbtn_gap2 - cbtn_w2 / 2.0 and mouse2.x <= cx2 - cbtn_gap2 + cbtn_w2 / 2.0:
					rules_confirm_index = 0
					do_action = true
				elif mouse2.x >= cx2 + cbtn_gap2 - cbtn_w2 / 2.0 and mouse2.x <= cx2 + cbtn_gap2 + cbtn_w2 / 2.0:
					rules_confirm_index = 1
					do_action = true
		if do_action:
			var confirm_label: String = tr("PAUSE_CONFIRM_YES") if rules_confirm_index == 0 else tr("PAUSE_CONFIRM_NO")
			var cidx: int = rules_confirm_index
			ui_renderer.set_btn_press_with_callback(confirm_label, func():
				if cidx == 0:
					_apply_rules_confirm_yes()
				else:
					_close_rules_confirm_no()
				queue_redraw()
			)
			queue_redraw()


# --- ボタン/メニュー項目のヒット判定（意図しない遷移防止） ---

func _hit_rules_button(pos: Vector2) -> bool:
	var vp: Vector2 = get_viewport_rect().size
	var btn_w: float = vp.x * 0.35
	var btn_h: float = (font.get_ascent(40) + font.get_descent(40)) * 1.5
	var center_y: float = vp.y - 48.0 - vp.y * 0.05
	var rect := Rect2(vp.x / 2.0 - btn_w / 2.0, center_y - btn_h / 2.0, btn_w, btn_h)
	return rect.has_point(pos)


func _hit_cleared_button(pos: Vector2) -> bool:
	var vp: Vector2 = get_viewport_rect().size
	var cx: float = vp.x / 2.0
	var cy: float = vp.y / 2.0
	var w: float = 850.0 * 1.2
	var h: float = 520.0 * 1.2
	var x: float = cx - w / 2.0
	var y: float = cy - h / 2.0
	var btn_w: float = w * 0.6
	var btn_h: float = (font.get_ascent(40) + font.get_descent(40)) * 1.5
	var btn_cx: float = x + w / 2.0
	var btn_cy: float = y + h - btn_h / 2.0 - 24.0
	var rect := Rect2(btn_cx - btn_w / 2.0, btn_cy - btn_h / 2.0, btn_w, btn_h)
	return rect.has_point(pos)


func _hit_results_button(pos: Vector2) -> bool:
	var vp: Vector2 = get_viewport_rect().size
	var cx: float = vp.x / 2.0
	var cy: float = vp.y / 2.0
	var w: float = 780.0
	var h: float = 710.0
	var x: float = cx - w / 2.0
	var y: float = cy - h / 2.0
	var btn_w: float = w * 0.6
	var btn_h: float = (font.get_ascent(40) + font.get_descent(40)) * 1.5
	var btn_cx: float = x + w / 2.0
	var btn_cy: float = y + h - btn_h / 2.0 - 40.0
	var rect := Rect2(btn_cx - btn_w / 2.0, btn_cy - btn_h / 2.0, btn_w, btn_h)
	return rect.has_point(pos)


func _hit_menu_item(pos: Vector2) -> int:
	var vp: Vector2 = get_viewport_rect().size
	var menu_count: int = 3
	for i in range(menu_count):
		var btn_cy: float = ui_renderer.get_menu_btn_cy(vp, i, menu_count)
		if pos.y >= btn_cy - 35.0 and pos.y <= btn_cy + 35.0:
			return i
	return -1


func _hit_config_item(pos: Vector2) -> Dictionary:
	var vp: Vector2 = get_viewport_rect().size
	var base_y: float = vp.y * 0.28
	var spacing: float = 103.5
	var lx: float = vp.x * 0.28
	var vx: float = vp.x * 0.42
	var box_w: float = vp.x * 0.24
	var box_h: float = (font.get_ascent(34) + font.get_descent(34)) * 1.5

	if config_sub == "":
		for i in range(6):
			# 音量項目(3,4)はボックスクリックではなく▼▲で操作
			if i == 3 or i == 4:
				continue
			var item_y: float = base_y + i * spacing
			var extra_y: float = (vp.y * 0.15 - 35.0) if i == 5 else 0.0
			if i == 5:
				# 中央配置ボタン: 画面中央基準でヒット判定
				var btn_half_w: float = box_w / 2.0
				var btn_cx: float = vp.x / 2.0
				if pos.y >= item_y - 20.0 + extra_y and pos.y <= item_y - 16.0 + box_h + extra_y and pos.x >= btn_cx - btn_half_w and pos.x <= btn_cx + btn_half_w:
					return { "ok": true, "main": i }
				continue
			if pos.y >= item_y - 20.0 + extra_y and pos.y <= item_y - 16.0 + box_h + extra_y and pos.x >= lx and pos.x <= vx + box_w:
				return { "ok": true, "main": i }
		return {}
	else:
		# サブメニュー（横並び）のクリック判定 — テキスト幅に基づく
		var item_y: float = base_y + config_index * spacing
		var sub_x: float = vx + box_w + 30.0
		if pos.y >= item_y - 20.0 and pos.y <= item_y - 16.0 + box_h:
			var sub_labels: Array[String] = _get_config_sub_labels_for_hit(config_index)
			var sx_cursor: float = sub_x
			for j in range(sub_labels.size()):
				var tw: float = font.get_string_size(sub_labels[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x + 30.0
				if pos.x >= sx_cursor and pos.x <= sx_cursor + tw:
					return { "ok": true, "main": config_index, "sub": j }
				sx_cursor += tw
		return {}


func _hit_config_volume_btn(pos: Vector2) -> Dictionary:
	"""音量項目の▼▲ボタンのヒットテスト。戻り値: {ok, item, delta}"""
	var vp: Vector2 = get_viewport_rect().size
	var base_y: float = vp.y * 0.28
	var spacing: float = 103.5
	var vx: float = vp.x * 0.42
	var box_w: float = vp.x * 0.24
	var box_h: float = (font.get_ascent(34) + font.get_descent(34)) * 1.5
	var arrow_w: float = 36.0
	var arrow_h: float = box_h
	for item_idx in [3, 4]:
		var item_y: float = base_y + item_idx * spacing
		var btn_top: float = item_y - 16.0
		if pos.y < btn_top or pos.y > btn_top + arrow_h:
			continue
		# ▼ボタン（ボックス左端の左）
		var down_x: float = vx - arrow_w - 4.0
		if pos.x >= down_x and pos.x <= down_x + arrow_w:
			return { "ok": true, "item": item_idx, "delta": -1 }
		# ▲ボタン（ボックス右端の右）
		var up_x: float = vx + box_w + 4.0
		if pos.x >= up_x and pos.x <= up_x + arrow_w:
			return { "ok": true, "item": item_idx, "delta": 1 }
	return {}


func _input_pause(event: InputEvent, is_confirm: bool, is_pause_key: bool) -> void:
	# If showing title confirm dialog
	if pause_confirm_title:
		_input_pause_confirm(event, is_confirm, is_pause_key)
		return

	# ESC / Start: close pause and resume
	if is_pause_key:
		_resume_from_pause()
		return

	# Up/Down / Left/Right navigation for 3 buttons
	var moved: bool = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP or event.keycode == KEY_LEFT:
			pause_index = (pause_index - 1 + 3) % 3
			moved = true
		elif event.keycode == KEY_DOWN or event.keycode == KEY_RIGHT:
			pause_index = (pause_index + 1) % 3
			moved = true
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_UP or event.button_index == JOY_BUTTON_DPAD_LEFT:
			pause_index = (pause_index - 1 + 3) % 3
			moved = true
		elif event.button_index == JOY_BUTTON_DPAD_DOWN or event.button_index == JOY_BUTTON_DPAD_RIGHT:
			pause_index = (pause_index + 1) % 3
			moved = true

	# Mouse hover (button hit test is in ui_renderer)
	if event is InputEventMouseMotion:
		var vp: Vector2 = get_viewport_rect().size
		var hit: int = _hit_pause_button(event.position, vp)
		if hit >= 0:
			pause_index = hit

	# Confirm
	if is_confirm:
		var pause_labels: Array[String] = [tr("PAUSE_CLOSE"), tr("PAUSE_RETRY"), tr("PAUSE_TITLE")]
		var pidx: int = pause_index
		ui_renderer.set_btn_press_with_callback(pause_labels[pidx], func():
			match pidx:
				0:  # 閉じる
					_resume_from_pause()
				1:  # やりなおし
					_do_pause_retry()
				2:  # タイトルへ戻る
					pause_confirm_title = true
					pause_confirm_index = 1  # Default to "いいえ"
					_play_sfx(sfx_window_open)
			queue_redraw()
		)
		queue_redraw()
		return

	if moved:
		queue_redraw()


func _hit_pause_button(pos: Vector2, vp: Vector2) -> int:
	"""ポーズ下部ボタンのヒットテスト。0=閉じる, 1=やりなおし, 2=タイトルへ戻る, -1=なし"""
	var ui_w: float = vp.x * GameConfig.UI_WIDTH_RATIO
	var play_w: float = vp.x - ui_w
	var play_cx: float = ui_w + play_w / 2.0
	var ps: float = 0.9
	var full_w: float = play_w - 48.0
	var full_h: float = vp.y - 48.0
	var panel_w: float = full_w * ps
	var panel_h: float = full_h * ps
	var panel_y: float = (vp.y - panel_h) / 2.0
	var panel_end_y: float = panel_y + panel_h
	var btn_w: float = panel_w * 0.27
	var btn_gap: float = panel_w * 0.03
	var base_cy: float = panel_end_y - 56.0 * ps - 50.0 * ps
	var btn_h: float = (font.get_ascent(40) + font.get_descent(40)) * 1.5
	if pos.y < base_cy - btn_h / 2.0 or pos.y > base_cy + btn_h / 2.0:
		return -1
	var total_w: float = btn_w * 3.0 + btn_gap * 2.0
	var btn_start_x: float = play_cx - total_w / 2.0 + btn_w / 2.0
	for i in range(3):
		var bcx: float = btn_start_x + i * (btn_w + btn_gap)
		if pos.x >= bcx - btn_w / 2.0 and pos.x <= bcx + btn_w / 2.0:
			return i
	return -1


func _do_pause_retry() -> void:
	"""やりなおし: guide_info へ戻す。タイマーはリセットしない"""
	pause_retry_elapsed = pause_elapsed
	pause_active = false
	var vp: Vector2 = get_viewport_rect().size
	shape_center = Vector2(vp.x * GameConfig.UI_WIDTH_RATIO + (vp.x - vp.x * GameConfig.UI_WIDTH_RATIO) * 0.5, vp.y * 0.5)
	stage_manager.start_stage(current_stage, shape_center, vp, point_positions)
	_sync_stage_vars()
	game_state = "guide_info"
	guide_start_time = 0.0
	hovered_index = -1
	is_dragging = false
	selected_indices.clear()
	input_handler.reset_for_stage()
	ui_renderer.clear_spore_particles()
	hint_alpha = 0.0
	hint_active = false
	hints_triggered = [false, false]
	guide_count_played = 0
	queue_redraw()


func _input_pause_confirm(event: InputEvent, is_confirm: bool, is_pause_key: bool) -> void:
	# ESC / Start: cancel back to pause menu
	if is_pause_key:
		pause_confirm_title = false
		_play_sfx(sfx_window_close)
		queue_redraw()
		return

	var moved: bool = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP or event.keycode == KEY_LEFT:
			pause_confirm_index = (pause_confirm_index - 1 + 2) % 2
			moved = true
		elif event.keycode == KEY_DOWN or event.keycode == KEY_RIGHT:
			pause_confirm_index = (pause_confirm_index + 1) % 2
			moved = true
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_UP or event.button_index == JOY_BUTTON_DPAD_LEFT:
			pause_confirm_index = (pause_confirm_index - 1 + 2) % 2
			moved = true
		elif event.button_index == JOY_BUTTON_DPAD_DOWN or event.button_index == JOY_BUTTON_DPAD_RIGHT:
			pause_confirm_index = (pause_confirm_index + 1) % 2
			moved = true

	# Mouse hover / click position（インゲーム領域の中央基準）
	var vp: Vector2 = get_viewport_rect().size
	var play_cx: float = vp.x * GameConfig.UI_WIDTH_RATIO + (vp.x - vp.x * GameConfig.UI_WIDTH_RATIO) / 2.0
	var cbtn_cy: float = vp.y / 2.0 + 50.0
	var cbtn_w: float = 220.0
	var cbtn_gap: float = cbtn_w / 2.0 + 30.0
	var btn_h: float = (font.get_ascent(40) + font.get_descent(40)) * 1.5
	if event is InputEventMouseMotion:
		if event.position.y >= cbtn_cy - btn_h / 2.0 and event.position.y <= cbtn_cy + btn_h / 2.0:
			if event.position.x >= play_cx - cbtn_gap - cbtn_w / 2.0 and event.position.x <= play_cx - cbtn_gap + cbtn_w / 2.0:
				pause_confirm_index = 0
				moved = true
			elif event.position.x >= play_cx + cbtn_gap - cbtn_w / 2.0 and event.position.x <= play_cx + cbtn_gap + cbtn_w / 2.0:
				pause_confirm_index = 1
				moved = true
	elif is_confirm and event is InputEventMouseButton:
		if event.position.y >= cbtn_cy - btn_h / 2.0 and event.position.y <= cbtn_cy + btn_h / 2.0:
			if event.position.x >= play_cx - cbtn_gap - cbtn_w / 2.0 and event.position.x <= play_cx - cbtn_gap + cbtn_w / 2.0:
				pause_confirm_index = 0
			elif event.position.x >= play_cx + cbtn_gap - cbtn_w / 2.0 and event.position.x <= play_cx + cbtn_gap + cbtn_w / 2.0:
				pause_confirm_index = 1

	if is_confirm:
		var confirm_label: String = tr("PAUSE_CONFIRM_YES") if pause_confirm_index == 0 else tr("PAUSE_CONFIRM_NO")
		var cidx: int = pause_confirm_index
		ui_renderer.set_btn_press_with_callback(confirm_label, func():
			if cidx == 0:  # はい
				pause_active = false
				pause_confirm_title = false
				pause_retry_elapsed = -1.0
				_stop_bgm(bgm_game)
				_play_sfx(sfx_window_close)
				_return_to_title_or_stage_debug_from_test()
			else:  # いいえ
				pause_confirm_title = false
				_play_sfx(sfx_window_close)
			queue_redraw()
		)
		queue_redraw()
		return

	if moved:
		queue_redraw()


func _resume_from_pause() -> void:
	pause_active = false
	# Restore timer: adjust start_time so elapsed stays the same
	start_time = Time.get_ticks_msec() / 1000.0 - pause_elapsed
	_play_sfx(sfx_window_close)
	queue_redraw()


func _start_game() -> void:
	debug_stage_test_mode = false
	input_recorder = null
	_stop_bgm(bgm_title)
	stage_times.clear()
	pause_retry_elapsed = -1.0
	_start_stage(0)


func _advance_stage() -> void:
	if current_stage < GameConfig.get_max_stage_index():
		_start_stage(current_stage + 1)
	else:
		_stop_bgm(bgm_game)
		game_state = "results"
		_play_bgm(bgm_result)
		queue_redraw()


# =============================================================================
# Stage debug（editor / debug ビルド）
# =============================================================================

func _debug_tools_enabled() -> bool:
	# エディタ必須: エクスポートした .exe / .pck では常に false（デバッグビルドでも同様）
	return Engine.is_editor_hint()


func _return_to_title_or_stage_debug_from_test() -> void:
	var back_to_stage_debug: bool = debug_stage_test_mode and _debug_tools_enabled()
	debug_stage_test_mode = false
	input_recorder = null
	if back_to_stage_debug:
		game_state = "stage_debug"
		_sync_stage_debug_field_buffers()
		stage_debug_last_error = ""
	else:
		game_state = "title"
	preferred_input_method = ""
	title_start_time = Time.get_ticks_msec() / 1000.0
	_play_bgm(bgm_title)


func _enter_stage_debug_screen() -> void:
	stage_debug_scroll = 0.0
	stage_debug_selected = 0
	stage_debug_field_focus_idx = -1
	stage_debug_edit_buffer = ""
	stage_debug_last_error = ""
	_sync_stage_debug_field_buffers()
	game_state = "stage_debug"
	queue_redraw()


func _sync_stage_debug_field_buffers() -> void:
	var cfg: Dictionary = StageDebugOverrides.build_config_for_index(
		stage_debug_selected, stage_debug_pending.get(stage_debug_selected, {})
	)
	stage_debug_field_buffers.clear()
	for key in STAGE_DEBUG_FIELD_KEYS:
		if key == "group_sizes" and cfg.has("group_sizes"):
			var gs: Array = cfg["group_sizes"] as Array
			stage_debug_field_buffers[key] = "%d,%d" % [int(gs[0]), int(gs[1])]
		elif cfg.has(key):
			stage_debug_field_buffers[key] = str(cfg[key])
		else:
			stage_debug_field_buffers[key] = ""
	if stage_debug_field_focus_idx >= 0 and stage_debug_field_focus_idx < STAGE_DEBUG_FIELD_KEYS.size():
		var fk: String = STAGE_DEBUG_FIELD_KEYS[stage_debug_field_focus_idx]
		stage_debug_edit_buffer = str(stage_debug_field_buffers.get(fk, ""))


func _commit_focused_field_to_pending() -> void:
	if stage_debug_field_focus_idx < 0 or stage_debug_field_focus_idx >= STAGE_DEBUG_FIELD_KEYS.size():
		return
	var fk: String = STAGE_DEBUG_FIELD_KEYS[stage_debug_field_focus_idx]
	var err: String = _apply_field_string_to_pending(fk, stage_debug_edit_buffer)
	stage_debug_last_error = err
	_sync_stage_debug_field_buffers()


func _apply_field_string_to_pending(key: String, text: String) -> String:
	var s: String = text.strip_edges()
	var idx: int = stage_debug_selected
	var p: Dictionary = stage_debug_pending.get(idx, {}).duplicate(true)
	if s == "":
		p.erase(key)
	else:
		match key:
			"type":
				p["type"] = s
			"num_points":
				if not s.is_valid_int():
					return "num_points が整数ではありません"
				p["num_points"] = int(s)
			"min_radius", "max_radius", "variance", "zigzag", "display_rate_min_pct", "clear_pct":
				if not s.is_valid_float():
					return "%s が数値ではありません" % key
				p[key] = float(s)
			"group_sizes":
				var parts: PackedStringArray = s.split(",")
				if parts.size() < 2:
					return "group_sizes は 12,12 の形式にしてください"
				if not parts[0].strip_edges().is_valid_int() or not parts[1].strip_edges().is_valid_int():
					return "group_sizes が不正です"
				p["group_sizes"] = [int(parts[0].strip_edges()), int(parts[1].strip_edges())]
			_:
				p[key] = s
	var verr: String = StageDebugOverrides.validate_partial_with_master(idx, p)
	if verr != "":
		return verr
	if p.is_empty():
		stage_debug_pending.erase(idx)
	else:
		stage_debug_pending[idx] = p
	return ""


func _stage_debug_split_x(vp: Vector2) -> float:
	return clampf(vp.x * STAGE_DEBUG_LEFT_COL_RATIO, 260.0, 520.0)


func _stage_debug_action_row_y() -> float:
	return STAGE_DEBUG_LIST_TOP_Y + 6.0


func _stage_debug_fields_start_y() -> float:
	return _stage_debug_action_row_y() + STAGE_DEBUG_ACTION_BTN_H + 12.0


func _stage_debug_scroll_max(vp: Vector2) -> float:
	var n: int = StageData.get_stages().size()
	var list_bottom: float = vp.y - STAGE_DEBUG_CONTENT_BOTTOM_MARGIN
	var list_region_h: float = list_bottom - STAGE_DEBUG_LIST_TOP_Y
	var total_list_h: float = float(n) * STAGE_DEBUG_ROW_H
	return maxf(0.0, total_list_h - list_region_h)


func _stage_debug_button_rects(vp: Vector2) -> Array[Rect2]:
	var split: float = _stage_debug_split_x(vp)
	var bh: float = STAGE_DEBUG_ACTION_BTN_H
	var gap: float = STAGE_DEBUG_ACTION_BTN_GAP
	var y_actions: float = _stage_debug_action_row_y()
	var y_top: float = STAGE_DEBUG_TOP_BTN_Y
	var out: Array[Rect2] = []
	var right_w: float = vp.x - split - 24.0
	var bw3: float = minf(100.0, (right_w - 2.0 * gap) / 3.0)
	bw3 = maxf(56.0, bw3)
	var rx: float = split + 12.0
	out.append(Rect2(rx, y_actions, bw3, bh))
	out.append(Rect2(rx + bw3 + gap, y_actions, bw3, bh))
	out.append(Rect2(rx + 2.0 * (bw3 + gap), y_actions, bw3, bh))
	var tw: float = minf(96.0, (vp.x - split - 48.0) / 2.0 - gap * 0.5)
	tw = maxf(72.0, tw)
	var tr_x: float = vp.x - 12.0 - 2.0 * tw - gap
	out.append(Rect2(tr_x, y_top, tw, bh))
	out.append(Rect2(tr_x + tw + gap, y_top, tw, bh))
	return out


func _stage_debug_field_rect(vp: Vector2, fi: int) -> Rect2:
	var split: float = _stage_debug_split_x(vp)
	var margin: float = 12.0
	var y0: float = _stage_debug_fields_start_y()
	var fw: float = vp.x - split - margin * 2
	var fh: float = 22.0
	var y: float = y0 + float(fi) * (fh + 4.0)
	return Rect2(split + margin, y, fw, fh)


func _input_stage_debug(event: InputEvent) -> void:
	var vp: Vector2 = get_viewport_rect().size
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		game_state = "title"
		stage_debug_field_focus_idx = -1
		queue_redraw()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		stage_debug_scroll = maxf(0.0, stage_debug_scroll - 40.0)
		queue_redraw()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		stage_debug_scroll = minf(_stage_debug_scroll_max(vp), stage_debug_scroll + 40.0)
		queue_redraw()
		return
	if stage_debug_field_focus_idx >= 0 and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_commit_focused_field_to_pending()
			stage_debug_field_focus_idx = (stage_debug_field_focus_idx + 1) % STAGE_DEBUG_FIELD_KEYS.size()
			var fk: String = STAGE_DEBUG_FIELD_KEYS[stage_debug_field_focus_idx]
			stage_debug_edit_buffer = str(stage_debug_field_buffers.get(fk, ""))
			queue_redraw()
			return
		if event.keycode == KEY_ENTER:
			_commit_focused_field_to_pending()
			queue_redraw()
			return
		if event.keycode == KEY_BACKSPACE:
			if stage_debug_edit_buffer.length() > 0:
				stage_debug_edit_buffer = stage_debug_edit_buffer.left(stage_debug_edit_buffer.length() - 1)
			queue_redraw()
			return
		if event.unicode >= 32 and event.unicode < 128:
			stage_debug_edit_buffer += PackedByteArray([event.unicode]).get_string_from_utf8()
			queue_redraw()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos: Vector2 = event.position
		var rects: Array[Rect2] = _stage_debug_button_rects(vp)
		var labels: Array[String] = ["テスト", "保存", "行リセット", "全リセット", "戻る"]
		for bi in range(rects.size()):
			if rects[bi].has_point(pos):
				match bi:
					0:
						_start_stage_debug_test()
					1:
						_stage_debug_save_selected()
					2:
						_stage_debug_reset_selected_row()
					3:
						_stage_debug_reset_all_files()
					4:
						game_state = "title"
						stage_debug_field_focus_idx = -1
				queue_redraw()
				return
		for fi in range(STAGE_DEBUG_FIELD_KEYS.size()):
			if _stage_debug_field_rect(vp, fi).has_point(pos):
				stage_debug_field_focus_idx = fi
				var fk: String = STAGE_DEBUG_FIELD_KEYS[fi]
				stage_debug_edit_buffer = str(stage_debug_field_buffers.get(fk, ""))
				queue_redraw()
				return
		var split: float = _stage_debug_split_x(vp)
		var n: int = StageData.get_stages().size()
		var y0: float = STAGE_DEBUG_LIST_TOP_Y - stage_debug_scroll
		var list_bottom: float = vp.y - STAGE_DEBUG_CONTENT_BOTTOM_MARGIN
		for i in range(n):
			var y1: float = y0 + float(i) * STAGE_DEBUG_ROW_H
			if pos.y >= y1 and pos.y < y1 + STAGE_DEBUG_ROW_H and pos.y < list_bottom and pos.y >= STAGE_DEBUG_LIST_TOP_Y - 4.0:
				if pos.x >= 8.0 and pos.x < split - 8.0:
					stage_debug_selected = i
					_sync_stage_debug_field_buffers()
					queue_redraw()
				return


func _start_stage_debug_test() -> void:
	_commit_focused_field_to_pending()
	var idx: int = stage_debug_selected
	var p: Dictionary = stage_debug_pending.get(idx, {})
	var err: String = StageDebugOverrides.validate_partial_with_master(idx, p)
	if err != "":
		stage_debug_last_error = err
		queue_redraw()
		return
	var cfg: Dictionary = StageDebugOverrides.build_config_for_index(idx, p)
	err = StageDebugOverrides.validate_effective_config(cfg)
	if err != "":
		stage_debug_last_error = err
		queue_redraw()
		return
	stage_debug_last_error = ""
	debug_stage_test_seed = randi()
	seed(debug_stage_test_seed)
	var vp: Vector2 = get_viewport_rect().size
	shape_center = Vector2(
		vp.x * GameConfig.UI_WIDTH_RATIO + (vp.x - vp.x * GameConfig.UI_WIDTH_RATIO) * 0.5, vp.y * 0.5
	)
	current_stage = idx
	debug_stage_test_mode = true
	input_recorder = DebugInputRecorder.new()
	stage_manager.start_stage(idx, shape_center, vp, point_positions, cfg)
	_sync_stage_vars()
	input_recorder.start_recording(debug_stage_test_seed, point_positions.duplicate() as Array[Vector2])
	game_state = "guide_info"
	guide_start_time = 0.0
	hovered_index = -1
	is_dragging = false
	selected_indices.clear()
	input_handler.reset_for_stage()
	ui_renderer.clear_spore_particles()
	hint_alpha = 0.0
	hint_active = false
	hints_triggered = [false, false]
	guide_count_played = 0
	queue_redraw()


func _stage_debug_save_selected() -> void:
	_commit_focused_field_to_pending()
	var idx: int = stage_debug_selected
	var p: Dictionary = stage_debug_pending.get(idx, {})
	var err: String = StageDebugOverrides.save_stage_override(idx, p)
	if err != "":
		stage_debug_last_error = err
	else:
		stage_debug_last_error = "保存しました: %s" % StageDebugOverrides.path_for_index(idx)
	queue_redraw()


func _stage_debug_reset_selected_row() -> void:
	var idx: int = stage_debug_selected
	stage_debug_pending.erase(idx)
	StageDebugOverrides.delete_stage_override(idx)
	_sync_stage_debug_field_buffers()
	stage_debug_last_error = "ステージ %d をマスターに戻しました" % idx
	queue_redraw()


func _stage_debug_reset_all_files() -> void:
	stage_debug_pending.clear()
	StageDebugOverrides.delete_all_overrides()
	_sync_stage_debug_field_buffers()
	stage_debug_last_error = "全ステージの調整ファイルを削除しました"
	queue_redraw()


func _hit_debug_log_button(pos: Vector2) -> bool:
	var vp: Vector2 = get_viewport_rect().size
	var w: float = 140.0
	var h: float = 36.0
	var r := Rect2(vp.x - w - 12.0, vp.y - h - 12.0, w, h)
	return r.has_point(pos)


func _flush_debug_input_log() -> void:
	if input_recorder == null:
		return
	var path: String = input_recorder.save_to_user_file()
	if path != "":
		stage_debug_last_error = "ログ保存: %s" % path
		print("debug log: ", path)
	else:
		stage_debug_last_error = "ログ保存に失敗しました"
	queue_redraw()


# =============================================================================
# Rendering
# =============================================================================

func _process_pad(delta: float) -> void:
	# イントロ演出中はパッド処理もスキップ
	if game_state == "playing" and not ui_renderer.is_stage_intro_done():
		return
	if game_state == "playing" and preferred_input_method == "mouse":
		# マウス利用時も grab_input_active を更新（つかみ中の実現率表示用）
		input_handler.update_grab_state_for_mouse()
		return
	var prev_grab: bool = input_handler.grab_input_active
	input_handler.process_pad(delta)
	# パッドでポイントをつかんだ瞬間にキャッチSE
	if not prev_grab and input_handler.grab_input_active:
		_play_sfx(sfx_catch)


func _process(delta: float) -> void:
	ui_renderer.update_animations(delta)
	if pause_active:
		queue_redraw()
		return
	_process_pad(delta)
	if debug_stage_test_mode and input_recorder and game_state == "playing" and ui_renderer.is_stage_intro_done():
		input_recorder.record_pad_stick_if_needed()
	# ポイント移動中のループSE管理（is_dragging ではなく grab_input_active）
	# 左スティックのみの選択切替はつかみではないため鳴らさない。A/右スティック＋マウスドラッグがつかみ。
	# title_intro中はui_renderer側でsfx_moveを管理するため、ここでは停止しない
	if (game_state == "playing" or game_state == "rules") and input_handler.grab_input_active:
		_start_sfx_move()
	elif _sfx_move_playing and game_state != "title_intro":
		_stop_sfx_move()
	if game_state == "logo":
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - logo_start_time
		if elapsed >= GameConfig.LOGO_TOTAL:
			game_state = "title_intro"
		queue_redraw()
		return

	if game_state == "title_intro":
		if ui_renderer.is_title_intro_skip_done():
			ui_renderer.suppress_hover_sfx(1.0)
			game_state = "title"
			title_start_time = Time.get_ticks_msec() / 1000.0
			_play_bgm(bgm_title)
			_play_sfx(sfx_stageclear)
		elif ui_renderer.is_title_intro_done():
			ui_renderer.suppress_hover_sfx(1.0)
			game_state = "title"
			title_start_time = Time.get_ticks_msec() / 1000.0
			_play_bgm(bgm_title)
			_play_sfx(sfx_stageclear)
		queue_redraw()
		return

	if game_state == "title" or game_state == "rules" or game_state == "rules_confirm" or game_state == "menu" or game_state == "config":
		if game_state == "rules" or game_state == "rules_confirm":
			ui_renderer.update_spore_particles(delta)
		queue_redraw()

	elif game_state == "stage_debug":
		queue_redraw()

	elif game_state == "guide_info":
		queue_redraw()

	elif game_state == "guide_countdown":
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - guide_start_time
		# Play count SE at each second tick (at 0s, 1s, 2s)
		var count_tick: int = int(elapsed) + 1  # 1 at 0-1s, 2 at 1-2s, 3 at 2-3s
		if count_tick > guide_count_played and guide_count_played < 3 and not sfx_count.playing:
			guide_count_played = count_tick
			_play_sfx(sfx_count)
		if elapsed >= 3.0:
			game_state = "playing"
			if pause_retry_elapsed >= 0.0:
				start_time = Time.get_ticks_msec() / 1000.0 + ui_renderer.STAGE_INTRO_DURATION - pause_retry_elapsed
				pause_retry_elapsed = -1.0
			else:
				start_time = Time.get_ticks_msec() / 1000.0 + ui_renderer.STAGE_INTRO_DURATION
			_play_bgm(bgm_game)
		queue_redraw()

	elif game_state == "playing":
		var now: float = Time.get_ticks_msec() / 1000.0
		var elapsed: float = maxf(0.0, now - start_time)
		hint_alpha = 0.0

		if debug_mode:
			hint_alpha = 0.8
		elif elapsed >= GameConfig.HINT_LOOP_START:
			# Repeating loop: 1s crossfade visible 竊・3s hidden 竊・repeat
			var cycle_t: float = fmod(elapsed - GameConfig.HINT_LOOP_START, GameConfig.HINT_LOOP_FADE + GameConfig.HINT_LOOP_HIDE)
			if cycle_t < GameConfig.HINT_LOOP_FADE:
				hint_alpha = sin(cycle_t / GameConfig.HINT_LOOP_FADE * PI)
		else:
			# One-shot hints at 60s and 90s
			if hint_active:
				if now >= hint_end_time:
					hint_active = false
				else:
					hint_alpha = 0.8
			else:
				for i in range(GameConfig.HINT_TIMES.size()):
					if not hints_triggered[i] and elapsed >= GameConfig.HINT_TIMES[i]:
						hints_triggered[i] = true
						hint_active = true
						hint_end_time = now + GameConfig.HINT_DURATIONS[i]
						hint_alpha = 0.8
						break
		ui_renderer.update_spore_particles(delta)
		queue_redraw()

	elif game_state == "cleared":
		ui_renderer.update_particles(delta)
		queue_redraw()

	elif game_state == "results":
		queue_redraw()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	ui_renderer.draw(game_state, vp)
	if pause_active:
		ui_renderer.draw_pause_overlay(vp)
