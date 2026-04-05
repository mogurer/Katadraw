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
## StageConfig.guide_follows_player_radius（ガイドをプレイヤー半径に追従させるか）
var guide_follows_player_radius: bool = false
var hint_alpha: float = 0.0
var guide_count_played: int = 0  # tracks which count SE ticks have played
var hint_active: bool = false
var hint_end_time: float = 0.0
var hints_triggered: Array[bool] = [false, false]

# --- Stage Results ---
var stage_times: Array[float] = []
var stage_move_counts: Array[int] = []
## 各ステージクリア時のガイド／プレイヤー輪郭（リザルト一覧サムネイル用）。要素は capture_result_loops() と同形の Dictionary
var stage_result_shapes: Array = []
## 現在ステージ中の「つかんだあと動かした」回数（閾値距離ごとに加算）
var stage_move_count: int = 0
const STAGE_MOVE_COUNT_PIXEL_THRESHOLD := 22.0
var _move_grab_was_active: bool = false
var _move_count_track_valid: bool = false
var _move_count_track_prev_centroid: Vector2 = Vector2.ZERO
var _move_count_accum: float = 0.0

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
var config_index: int = 0        # 0=Window Mode, 1=Language, 2=BGM Vol, 3=SE Vol, 4=Back
## コンフィグ画面レイアウト（ui_renderer._draw_config とヒット判定で共通）
const CONFIG_MENU_BASE_Y_RATIO := 0.28
const CONFIG_MENU_SPACING := 103.5
const CONFIG_MENU_LX_RATIO := 0.24
const CONFIG_MENU_VX_RATIO := 0.44
const CONFIG_MENU_BOX_W_RATIO := 0.23
const CONFIG_MENU_ARROW_W := 36.0
const CONFIG_MENU_ARROW_PAD := 4.0
## 項目名の右端と ◀ 左端の間の余白（英語ラベル長でも見切れしにくいよう vx を寄せている）
const CONFIG_MENU_LABEL_GAP_TO_ARROW := 20.0
## コンフィグ 0〜3 行のホバー拡大（set_btn_hover / get_btn_scale と同一 ID）
const CONFIG_ROW_BTN_IDS: Array[String] = ["cfg_row_window", "cfg_row_lang", "cfg_row_bgm", "cfg_row_se"]
# UI メニュー: 左スティック / D-pad ハット（ボタン型十字と併用。_process でポーリング）
# JoyAxis の HAT は環境によって JOY_AXIS_LEFT_HAT_* が未定義のため、Enum と同じ番号を直指定する
const _JOY_AXIS_HAT_X := 6
const _JOY_AXIS_HAT_Y := 7
const UI_MENU_STICK_REPEAT_INITIAL := 0.35
const UI_MENU_STICK_REPEAT_RATE := 0.12
## 複数ジョイパッド時: デバイス 0 を優先するが、0 がニュートラルなら別デバイス（実コントローラ）を使う閾値
const UI_MENU_STICK_DEVICE0_ACTIVE_MIN := 0.15
## メニュー／コンフィグ等の UI ナビ: 左スティックのみ（十字ボタンは _input の D-pad）。
## 旧実装は HAT 軸と max(abs) 合成＋広いデッドゾーンで、スティック単独が効きにくかった（process_pad はメニュー中は未実行で競合しない）。
const UI_LEFT_STICK_UI_NAV_DEADZONE := 0.35
## 生の |LY|（スティック＋HAT 合成後）がこれ以上なら、十字「ボタン」で縦を上書きしない。Steam Input 等でスティックが DPAD_* を同時に押すと ly が ±1 固定になり INVERT が無効に見える。
const UI_MENU_STICK_ANALOG_OVERRIDE_DPAD_BUTTONS := 0.12
## Godot 既定は「上で LEFT_Y が負」。true は「上で LY が正」になるデバイス向け（アナログのみ。十字ボタンは合成後に ±1 を上書きするため、invert を後から掛けると十字と両立しない）。
## MENU/コンフィグのパッド移動は _process で左スティックと十字ボタンを同一軸に合成（_input の D-pad は使わない）。
const UI_LEFT_STICK_UI_NAV_INVERT_Y := false
## true にするとコンフィグ中に生の軸を出力（_process 先頭で実行。リリース前は false）
const DEBUG_UI_STICK_NAV := false
var _debug_ui_stick_nav_accum: float = 0.0
# 左スティック UI ナビ: 1 フレームにつき軸は 1 回だけ読む（縦横の二重ポーリングでリピート状態が壊れるのを防ぐ）
var _ui_stick_axes_frame: int = -1
var _ui_stick_lx: float = 0.0
var _ui_stick_ly: float = 0.0
var _ui_stick_ly_raw: float = 0.0
var _ui_stick_ui_device: int = -1
var _ui_menu_stick_v_dir: int = 0
var _ui_menu_stick_v_cd: float = 0.0
var _ui_menu_stick_h_dir: int = 0
var _ui_menu_stick_h_cd: float = 0.0
var is_fullscreen: bool = false
## ウインドウモード時の OS ウィンドウ（クライアント領域）。描画解像度は INTERNAL_VIEWPORT_SIZE のまま stretch。
const FIXED_WINDOW_CLIENT_SIZE := Vector2i(1280, 720)
const INTERNAL_VIEWPORT_SIZE := Vector2i(1920, 1080)
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
## 右パネル: 左は固定ラベル列、右のみ編集（値欄）。列幅は _stage_debug_field_label_column_width() で最長ラベルを測る
const STAGE_DEBUG_FIELD_LABEL_FS: int = 14
const STAGE_DEBUG_FIELD_VALUE_GAP: float = 10.0
## description 欄の表示行数・1行のフォントサイズ（値欄の高さに使用）
const STAGE_DEBUG_DESC_VISIBLE_LINES: int = 3
## 行数が多いときの高さ上限（描画・高さ計算の共通上限）
const STAGE_DEBUG_DESC_MAX_LINES: int = 50
const STAGE_DEBUG_DESC_LINE_FS: int = 14
const STAGE_DEBUG_FIELD_SINGLE_H: float = 22.0
const STAGE_DEBUG_FIELD_ROW_GAP: float = 4.0
## stage_name / description 右側の操作ボタン（カスタム行のみ表示）
const STAGE_DEBUG_TEXT_BTN_W: float = 52.0
const STAGE_DEBUG_TEXT_BTN_H: float = 20.0
const STAGE_DEBUG_TEXT_BTN_GAP: float = 4.0
const STAGE_DEBUG_DESC_PAD_TOP: float = 8.0
const STAGE_DEBUG_DESC_LINE_INNER_GAP: float = 2.0
const STAGE_DEBUG_FIELD_KEYS: Array[String] = [
	"type", "num_points", "min_radius", "max_radius", "variance", "zigzag",
	"display_rate_min_pct", "clear_pct", "guide_follows_player_radius", "group_sizes",
	"stage_name", "description",
]
var stage_debug_scroll: float = 0.0
var stage_debug_selected: int = 0
var stage_debug_pending: Dictionary = {}  # マスタ行 index -> partial（②: インデックスオーバーライド専用）
## ② Edit 産カスタム（ファイル1本=1行）。path -> フィールド編集の差分（config + meta.stage_name / meta.description）
var stage_debug_custom_paths: Array[String] = []
var stage_debug_custom_pending: Dictionary = {}
var stage_debug_field_buffers: Dictionary = {}  # field_key -> String（選択行の編集用）
var stage_debug_field_focus_idx: int = -1  # STAGE_DEBUG_FIELD_KEYS のインデックス、-1=なし
var stage_debug_edit_buffer: String = ""
var stage_debug_last_error: String = ""
# --- Stage edit（カスタム JSON 保存 + fish/cat_face は正規化座標ポリゴンをキャンバス編集）---
const STAGE_EDIT_TYPE_OPTIONS: Array[String] = [
	"fish", "cat_face", "triangle", "square", "circle", "star", "two_circles",
]
const STAGE_EDIT_TOP_BAR: float = 44.0
const STAGE_EDIT_LEFT_RATIO: float = 0.66
const STAGE_EDIT_FOOTER_H: float = 44.0
## キャンバス上のグリッド間隔（ピクセル）。KatadrawShapeEditor の 24px に合わせる
const STAGE_EDIT_GRID_CELL_PX: float = 24.0
const STAGE_EDIT_CANVAS_HANDLE_R: float = 12.0
const STAGE_EDIT_CANVAS_HIT_VERTEX_R: float = 28.0
const STAGE_EDIT_CANVAS_EDGE_ADD_DISTANCE: float = 80.0
const STAGE_EDIT_CANVAS_RIGHT_DRAG_THRESHOLD: float = 5.0
const STAGE_EDIT_MIRROR_BTN_SZ: float = 36.0
const STAGE_EDIT_UNDO_STACK_MAX: int = 80
var stage_edit_stage_id: String = "new_stage"
## meta の JSON 保存時にそのままマージ（stage_name / description は STAGE DEBUG で編集）
var stage_edit_meta_preserve: Dictionary = {}
var stage_edit_type_idx: int = 0
## fish のとき samples の polygon を初期値に使うか（オフ時は組み込み fish 頂点）
var stage_edit_include_fish_shape: bool = true
## 0=Stage ID（テキスト欄はこれのみ）
var stage_edit_text_line: int = 0
var stage_edit_last_error: String = ""
## shape_type が fish / cat_face のときの編集用頂点（正規化座標）と辺（KatadrawShapeEditor と同様）
var stage_edit_canvas_vertices: Array[Vector2] = []
var stage_edit_canvas_edges: Array[Dictionary] = []
var stage_edit_canvas_hover_edge: int = -1
var stage_edit_canvas_drag_idx: int = -1
var stage_edit_canvas_drag_norm_offset: Vector2 = Vector2.ZERO
var stage_edit_canvas_right_drag_idx: int = -1
var stage_edit_canvas_right_down_pos: Vector2 = Vector2.ZERO
var stage_edit_canvas_right_drag_norm_offset: Vector2 = Vector2.ZERO
var stage_edit_canvas_right_drag_committed: bool = false
## Edit キャンバス用 undo / redo（頂点・辺のスナップショット）
var stage_edit_undo_stack: Array = []
var stage_edit_redo_stack: Array = []
## ◀▶▲▼ 鏡像プレビュー（各ボタンでトグル、データは変更しない）
var stage_edit_mirror_preview: Array[bool] = [false, false, false, false]
var _se_ld_single_arc_edge: int = -1
var _se_ld_single_arc_angle: float = 0.0
var _se_ld_both_edges: Array[int] = []
var _se_ld_both_angles: Array[float] = []
var _se_ld_both_centers: Array[Vector2] = []
var _se_ld_both_last_centers: Array[Vector2] = []
var debug_stage_test_mode: bool = false
var debug_stage_test_seed: int = 0
## テストプレイ guide_info の説明行に出す（カスタムの meta.stage_name）
var debug_stage_test_meta_stage_name: String = ""
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
var result_logo_texture: Texture2D
var bg_texture: Texture2D
var logo_start_time: float = 0.0
var title_start_time: float = 0.0

# --- Audio ---
# 一時: BGM を聞こえないようにする。通常に戻すときは false にして _apply_bgm_volume() の通常分岐を有効にする。
const BGM_TEMPORARILY_SILENT := false
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
	_register_translations_from_csv()
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
	result_logo_texture = _load_texture("res://assets/UI/kata-draw_Resultlogo.png")
	bg_texture = _load_texture("res://assets/UI/kata-draw_bg.png")
	_setup_game_cursor()
	get_window().size_changed.connect(_on_window_size_changed)
	_sync_fullscreen_from_os()
	if is_fullscreen:
		call_deferred("_apply_internal_viewport_size")
	else:
		call_deferred("_apply_window_pixel_size_impl", FIXED_WINDOW_CLIENT_SIZE)
	game_state = "logo"
	logo_start_time = Time.get_ticks_msec() / 1000.0


## Translation.csv を直接読み込み、TranslationServer に登録する（.translation バイナリに依存しない）。
func _register_translations_from_csv() -> void:
	var path := "res://Resources/Translation/Translation.csv"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Translation CSV not found: " + path)
		return
	var text: String = f.get_as_text()
	f.close()
	if text.is_empty():
		return
	if text.begins_with("\ufeff"):
		text = text.substr(1)
	var lines: PackedStringArray = text.split("\n")
	if lines.size() < 2:
		return
	var header: PackedStringArray = _split_csv_row(lines[0])
	if header.size() < 2:
		return
	var locales: Array[String] = []
	for c in range(1, header.size()):
		var col: String = header[c].strip_edges()
		if not col.is_empty():
			locales.append(col)
	if locales.is_empty():
		return
	var trans_by_locale: Dictionary = {}
	for loc in locales:
		var t: Translation = Translation.new()
		t.locale = loc
		trans_by_locale[loc] = t
	for li in range(1, lines.size()):
		var line: String = lines[li].strip_edges()
		if line.is_empty():
			continue
		var parts: PackedStringArray = _split_csv_row(line)
		if parts.size() < 2:
			continue
		var key: String = parts[0].strip_edges()
		if key.is_empty():
			continue
		for c in range(min(locales.size(), parts.size() - 1)):
			var msg: String = parts[c + 1]
			var tr_obj: Translation = trans_by_locale[locales[c]]
			tr_obj.add_message(key, msg)
	for loc in trans_by_locale:
		TranslationServer.add_translation(trans_by_locale[loc])


func _split_csv_row(line: String) -> PackedStringArray:
	# 先頭列はキー、以降は ja,en,zh_CN,zh_TW（本文にカンマは含めない前提）
	return line.split(",", true, 4)


func _on_window_size_changed() -> void:
	_sync_fullscreen_from_os()
	if not is_fullscreen:
		_apply_internal_viewport_size()
	queue_redraw()


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
	bgm_title.stream = _load_audio("res://assets/sounds/k_03_indigo_01.mp3")
	bgm_title.volume_db = -22.5
	bgm_title.autoplay = false
	if bgm_title.stream is AudioStreamMP3:
		bgm_title.stream.loop = true
	add_child(bgm_title)

	bgm_game = AudioStreamPlayer.new()
	bgm_game.stream = _load_audio("res://assets/sounds/audiostock_1544483.mp3")
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


func _selection_centroid() -> Vector2:
	var s := Vector2.ZERO
	for idx in selected_indices:
		if idx >= 0 and idx < point_positions.size():
			s += point_positions[idx]
	return s / selected_indices.size() if selected_indices.size() > 0 else Vector2.ZERO


func _is_move_grab_active_for_count() -> bool:
	return (
		is_dragging
		or input_handler.grab_input_active
		or input_handler.is_bb_dragging()
		or input_handler.is_pad_grabbing_modifier_now()
	)


func _reset_stage_move_track_internal() -> void:
	_move_grab_was_active = false
	_move_count_track_valid = false
	_move_count_accum = 0.0


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
	# プレイ中かつつかみ中のみ、選択重心の移動距離を閾値で「動かした回数」に加算
	if game_state == "playing" and _is_move_grab_active_for_count() and selected_indices.size() > 0:
		if not _move_count_track_valid:
			_move_count_track_prev_centroid = _selection_centroid()
			_move_count_track_valid = true
		else:
			var c: Vector2 = _selection_centroid()
			var leg: float = c.distance_to(_move_count_track_prev_centroid)
			_move_count_track_prev_centroid = c
			_move_count_accum += leg
			while _move_count_accum >= STAGE_MOVE_COUNT_PIXEL_THRESHOLD:
				stage_move_count += 1
				_move_count_accum -= STAGE_MOVE_COUNT_PIXEL_THRESHOLD
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
	guide_follows_player_radius = stage_manager.guide_follows_player_radius


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
	stage_move_count = 0
	_reset_stage_move_track_internal()
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


func _append_stage_result_snapshot() -> void:
	stage_result_shapes.append(ui_renderer.capture_stage_result_shapes())


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
			stage_move_counts.append(stage_move_count)
			_append_stage_result_snapshot()
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
		stage_move_counts.append(stage_move_count)
		_append_stage_result_snapshot()
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
	stage_move_counts.append(stage_move_count)
	_append_stage_result_snapshot()
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

## 左スティックの LX/LY。縦は HAT 軸と max(abs) 合成しない（環境によって HAT_Y と LEFT_Y の「上」の符号が逆になり、スティックだけ常に逆になる原因になる）。
## 十字の上下は _ui_menu_nav_merge_dpad_buttons（ボタン）または HAT 専用デバイスは別途必要なら拡張する。
func _ui_menu_stick_axes_raw(dev: int) -> Vector2:
	var lx: float = Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
	var ly: float = Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
	var hx: float = Input.get_joy_axis(dev, _JOY_AXIS_HAT_X)
	if absf(hx) > absf(lx):
		lx = hx
	return Vector2(lx, ly)


## 十字ボタンをアナログと同じ [-1,1] に載せる（MENU/CONFIG はここ経由のみで縦横移動する）
## lock_analog_vertical/horizontal: アナログが十分動いているときは仮想十字ボタンで上書きしない（スティック操作が十字扱いになる環境向け）
func _ui_menu_nav_merge_dpad_buttons(dev: int, lx: float, ly: float, lock_analog_vertical: bool = false, lock_analog_horizontal: bool = false) -> Vector2:
	if dev < 0:
		return Vector2(lx, ly)
	var up: bool = Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP)
	var down: bool = Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN)
	var left: bool = Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT)
	var right: bool = Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT)
	if not lock_analog_vertical and up != down:
		ly = -1.0 if up else 1.0
	if not lock_analog_horizontal and left != right:
		lx = -1.0 if left else 1.0
	return Vector2(lx, ly)


func _ui_menu_stick_pick_device_for_ui() -> int:
	var pads = Input.get_connected_joypads()
	if pads.is_empty():
		return -1
	if pads.size() == 1:
		return int(pads[0])
	# 全デバイスで最大変位のスティックを基準にしつつ、同値に近いときはデバイス 0 を優先（process_pad と同じ 0 を読む）。
	# 以前の「毎フレームグローバル最大のみ」は、ニュートラル時の先頭 ID と操作時の別 ID で軸が切り替わり、上下が逆／INVERT が効かない原因になる。
	var best_dev: int = int(pads[0])
	var best_score: float = -1.0
	for p in pads:
		var d: int = int(p)
		var axes: Vector2 = _ui_menu_stick_axes_raw(d)
		var s: float = maxf(absf(axes.x), absf(axes.y))
		if s > best_score:
			best_score = s
			best_dev = d
	var d0_in_list: bool = false
	var d0_score: float = 0.0
	for p in pads:
		if int(p) == 0:
			d0_in_list = true
			var a0: Vector2 = _ui_menu_stick_axes_raw(0)
			d0_score = maxf(absf(a0.x), absf(a0.y))
			break
	if d0_in_list and d0_score >= UI_MENU_STICK_DEVICE0_ACTIVE_MIN and d0_score >= best_score - 0.02:
		return 0
	return best_dev


func _ui_menu_stick_update_axes_cache() -> void:
	var f: int = Engine.get_process_frames()
	if _ui_stick_axes_frame == f:
		return
	_ui_stick_axes_frame = f
	_ui_stick_ui_device = _ui_menu_stick_pick_device_for_ui()
	if _ui_stick_ui_device < 0:
		_ui_stick_lx = 0.0
		_ui_stick_ly = 0.0
		_ui_stick_ly_raw = 0.0
		return
	var axes: Vector2 = _ui_menu_stick_axes_raw(_ui_stick_ui_device)
	_ui_stick_ly_raw = axes.y
	# invert はアナログ（スティック＋HAT 軸）のみ。十字ボタンは merge 側で既にメニュー論理（上=-1）なので、merge の後に invert すると ±1 が反転して十字とスティックが食い違う。
	var ly_analog: float = (-axes.y) if UI_LEFT_STICK_UI_NAV_INVERT_Y else axes.y
	var lock_v: bool = absf(axes.y) > UI_MENU_STICK_ANALOG_OVERRIDE_DPAD_BUTTONS
	var lock_h: bool = absf(axes.x) > UI_MENU_STICK_ANALOG_OVERRIDE_DPAD_BUTTONS
	axes = _ui_menu_nav_merge_dpad_buttons(_ui_stick_ui_device, axes.x, ly_analog, lock_v, lock_h)
	_ui_stick_lx = axes.x
	_ui_stick_ly = axes.y


func _reset_ui_menu_stick_navigation() -> void:
	_ui_stick_axes_frame = -1
	_ui_menu_stick_v_dir = 0
	_ui_menu_stick_v_cd = 0.0
	_ui_menu_stick_h_dir = 0
	_ui_menu_stick_h_cd = 0.0


func _ui_menu_stick_vertical_step(delta: float, ly: float) -> int:
	var dz: float = UI_LEFT_STICK_UI_NAV_DEADZONE
	var dir: int = 0
	# 戻り値 vy は「index に加える量」: 上＝-1（index を減らす）、下＝+1。キーボード ↑↓・D-pad と同じ。
	if ly < -dz:
		dir = -1
	elif ly > dz:
		dir = 1
	if dir == 0:
		_ui_menu_stick_v_dir = 0
		_ui_menu_stick_v_cd = 0.0
		return 0
	if dir != _ui_menu_stick_v_dir:
		_ui_menu_stick_v_dir = dir
		_ui_menu_stick_v_cd = UI_MENU_STICK_REPEAT_INITIAL
		return dir
	_ui_menu_stick_v_cd -= delta
	if _ui_menu_stick_v_cd <= 0.0:
		_ui_menu_stick_v_cd = UI_MENU_STICK_REPEAT_RATE
		return dir
	return 0


func _ui_menu_stick_horizontal_step(delta: float, lx: float) -> int:
	var dz: float = UI_LEFT_STICK_UI_NAV_DEADZONE
	var dir: int = 0
	if lx < -dz:
		dir = -1
	elif lx > dz:
		dir = 1
	if dir == 0:
		_ui_menu_stick_h_dir = 0
		_ui_menu_stick_h_cd = 0.0
		return 0
	if dir != _ui_menu_stick_h_dir:
		_ui_menu_stick_h_dir = dir
		_ui_menu_stick_h_cd = UI_MENU_STICK_REPEAT_INITIAL
		return dir
	_ui_menu_stick_h_cd -= delta
	if _ui_menu_stick_h_cd <= 0.0:
		_ui_menu_stick_h_cd = UI_MENU_STICK_REPEAT_RATE
		return dir
	return 0


func _ui_menu_stick_nav_vertical_or_horizontal(delta: float) -> Vector2i:
	var vy: int = _ui_menu_stick_vertical_step(delta, _ui_stick_ly)
	if vy != 0:
		return Vector2i(0, vy)
	var hx: int = _ui_menu_stick_horizontal_step(delta, _ui_stick_lx)
	if hx != 0:
		return Vector2i(hx, 0)
	return Vector2i(0, 0)


## はい/いいえなど「左右のみ」の UI 用（縦入力より横を優先。十字と左スティックが同じ論理）
func _ui_menu_stick_nav_horizontal_first(delta: float) -> Vector2i:
	var hx: int = _ui_menu_stick_horizontal_step(delta, _ui_stick_lx)
	if hx != 0:
		return Vector2i(hx, 0)
	var vy: int = _ui_menu_stick_vertical_step(delta, _ui_stick_ly)
	if vy != 0:
		return Vector2i(0, vy)
	return Vector2i(0, 0)


func _process_config_stick_navigation(delta: float) -> void:
	# 上下＝行移動、左右＝値変更（全項目で同じ優先: 縦を先に処理）
	var items_count: int = 5
	var ly: float = _ui_stick_ly
	var lx: float = _ui_stick_lx
	var vy: int = _ui_menu_stick_vertical_step(delta, ly)
	if vy != 0:
		config_index = (config_index + vy + items_count) % items_count
		queue_redraw()
		return
	var hx: int = _ui_menu_stick_horizontal_step(delta, lx)
	if hx != 0 and config_index < 4:
		_config_apply_main_horizontal(hx)
		queue_redraw()


func _debug_ui_stick_nav_poll_config(delta: float) -> void:
	if not DEBUG_UI_STICK_NAV:
		return
	_ui_menu_stick_update_axes_cache()
	_debug_ui_stick_nav_accum += delta
	if _debug_ui_stick_nav_accum < 0.12:
		return
	_debug_ui_stick_nav_accum = 0.0
	if _ui_stick_ui_device < 0:
		print("[UIStickNav] no joypad")
		return
	var vy_probe: int = 0
	if _ui_stick_ly < -UI_LEFT_STICK_UI_NAV_DEADZONE:
		vy_probe = -1
	elif _ui_stick_ly > UI_LEFT_STICK_UI_NAV_DEADZONE:
		vy_probe = 1
	var msg: String = (
		"[UIStickNav] dev=%s raw(LY=%.3f LX=%.3f) logical_ly=%.3f invert_y=%s deadzone=%.2f vy_probe=%s cfg_idx=%s"
		% [_ui_stick_ui_device, _ui_stick_ly_raw, _ui_stick_lx, _ui_stick_ly, UI_LEFT_STICK_UI_NAV_INVERT_Y, UI_LEFT_STICK_UI_NAV_DEADZONE, vy_probe, config_index]
	)
	print(msg)
	push_warning(msg)


func _process_ui_menu_stick_navigation(delta: float) -> void:
	if ui_renderer._btn_press_pending:
		return
	_ui_menu_stick_update_axes_cache()
	if pause_active:
		if pause_confirm_title:
			var nav_pc: Vector2i = _ui_menu_stick_nav_horizontal_first(delta)
			if nav_pc.x < 0 or nav_pc.y < 0:
				pause_confirm_index = (pause_confirm_index - 1 + 2) % 2
				queue_redraw()
			elif nav_pc.x > 0 or nav_pc.y > 0:
				pause_confirm_index = (pause_confirm_index + 1) % 2
				queue_redraw()
		else:
			var nav_p: Vector2i = _ui_menu_stick_nav_vertical_or_horizontal(delta)
			if nav_p.x < 0 or nav_p.y < 0:
				pause_index = (pause_index - 1 + 3) % 3
				queue_redraw()
			elif nav_p.x > 0 or nav_p.y > 0:
				pause_index = (pause_index + 1) % 3
				queue_redraw()
		return
	match game_state:
		"menu":
			if menu_confirm_quit:
				var nav_q: Vector2i = _ui_menu_stick_nav_horizontal_first(delta)
				if nav_q.x < 0 or nav_q.y < 0:
					menu_confirm_index = (menu_confirm_index - 1 + 2) % 2
					queue_redraw()
				elif nav_q.x > 0 or nav_q.y > 0:
					menu_confirm_index = (menu_confirm_index + 1) % 2
					queue_redraw()
			else:
				var vy_m: int = _ui_menu_stick_vertical_step(delta, _ui_stick_ly)
				if vy_m != 0:
					var menu_count: int = 3
					menu_index = (menu_index + vy_m + menu_count) % menu_count
					queue_redraw()
		"config":
			_process_config_stick_navigation(delta)
		"rules_confirm":
			var nav_rc: Vector2i = _ui_menu_stick_nav_horizontal_first(delta)
			if nav_rc.x < 0 or nav_rc.y < 0:
				rules_confirm_index = (rules_confirm_index - 1 + 2) % 2
				queue_redraw()
			elif nav_rc.x > 0 or nav_rc.y > 0:
				rules_confirm_index = (rules_confirm_index + 1) % 2
				queue_redraw()


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
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S and _debug_tools_enabled():
			_enter_results_screen_debug()
		elif is_confirm:
			ui_renderer.set_btn_press_with_callback(tr("TITLE_START"), func():
				game_state = "menu"
				menu_index = 0
				menu_confirm_quit = false
				_reset_ui_menu_stick_navigation()
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

	if game_state == "stage_edit":
		_input_stage_edit(event)
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
		var is_start_pad: bool = (
			event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
		)
		if is_confirm_key or is_confirm_pad or is_start_pad:
			ui_renderer.set_btn_press_with_callback(tr("RESULT_BTN_NEXT"), func():
				_stop_bgm(bgm_result)
				_return_to_title_or_stage_debug_from_test()
				queue_redraw()
			)
			queue_redraw()
		elif is_confirm_click and _hit_results_button(event.position):
			ui_renderer.set_btn_press_with_callback(tr("RESULT_BTN_NEXT"), func():
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
	# 十字の上下移動は _process_ui_menu_stick_navigation（左スティックと同一経路）
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B:
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
				_sync_fullscreen_from_os()
				game_state = "config"
				config_index = 0
				_reset_ui_menu_stick_navigation()
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
	# 十字の左右は _process_ui_menu_stick_navigation（左スティックと同一経路）
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
	var items_count: int = 5  # window_mode, language, bgm_vol, se_vol, back
	var moved: bool = false

	# ESC / B: メニューへ戻る
	var is_back: bool = (
		(event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE)
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	)
	if is_back:
		game_state = "menu"
		_reset_ui_menu_stick_navigation()
		queue_redraw()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			config_index = (config_index - 1 + items_count) % items_count
			moved = true
		elif event.keycode == KEY_DOWN:
			config_index = (config_index + 1) % items_count
			moved = true
		elif event.keycode == KEY_LEFT:
			if config_index < 4:
				_config_apply_main_horizontal(-1)
				moved = true
		elif event.keycode == KEY_RIGHT:
			if config_index < 4:
				_config_apply_main_horizontal(1)
				moved = true

	if event is InputEventMouseMotion:
		var vp: Vector2 = get_viewport_rect().size
		var base_y: float = vp.y * CONFIG_MENU_BASE_Y_RATIO
		var spacing: float = CONFIG_MENU_SPACING
		var box_h: float = (font.get_ascent(34) + font.get_descent(34)) * 1.5
		var mouse_pos: Vector2 = event.position
		for i in range(items_count):
			if i < 4:
				var geom: Dictionary = config_row_scaled_layout(vp, i)
				var bh: float = geom["bh"]
				var top: float = geom["Lp"].y - bh * 0.5
				var bottom: float = top + bh
				if mouse_pos.y >= top - 5.0 and mouse_pos.y <= bottom + 5.0:
					config_index = i
			else:
				var item_y: float = base_y + i * spacing
				var extra_y: float = vp.y * 0.15 - 35.0
				if mouse_pos.y >= item_y - 20.0 + extra_y and mouse_pos.y <= item_y - 16.0 + box_h + extra_y:
					config_index = i

	if is_confirm_click:
		var adj: Dictionary = _hit_config_value_arrows(event.position)
		if adj.get("ok", false):
			config_index = int(adj["item"])
			_config_apply_main_horizontal(int(adj["delta"]))
			queue_redraw()
			return

	var do_confirm: bool = false
	if is_confirm_key or is_confirm_pad:
		do_confirm = true
	elif is_confirm_click:
		var hit: Dictionary = _hit_config_item(event.position)
		if hit.get("ok", false):
			config_index = int(hit["main"])
			do_confirm = true
	if do_confirm and config_index == 4:
		ui_renderer.set_btn_press_with_callback(tr("CONFIG_BACK"), func():
			game_state = "menu"
			_reset_ui_menu_stick_navigation()
			queue_redraw()
		)
		queue_redraw()
	if moved:
		queue_redraw()


## コンフィグ: 0〜3 行の左右（±1）。画面モードは [フルスクリーン, ウインドウ] を循環。
func _config_apply_main_horizontal(delta: int) -> void:
	match config_index:
		0:
			_config_apply_window_mode_delta(delta)
			_play_sfx(sfx_click)
		1:
			_config_apply_language_delta(delta)
			_play_sfx(sfx_click)
		2:
			bgm_volume = clampi(bgm_volume + delta, 0, 10)
			_apply_bgm_volume()
			_play_sfx(sfx_click)
		3:
			se_volume = clampi(se_volume + delta, 0, 10)
			_apply_se_volume()
			_play_sfx(sfx_click)


func _config_apply_window_mode_delta(delta: int) -> void:
	var idx: int = 0 if is_fullscreen else 1
	idx = (idx + delta + 2) % 2
	_config_apply_window_mode_index(idx)


func _config_apply_window_mode_index(idx: int) -> void:
	is_fullscreen = (idx == 0)
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		call_deferred("_apply_internal_viewport_size")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		call_deferred("_apply_window_pixel_size_impl", FIXED_WINDOW_CLIENT_SIZE)


func _config_apply_language_delta(delta: int) -> void:
	var idx: int = _config_language_ui_index_from_locale()
	idx = (idx + delta + 2) % 2
	TranslationServer.set_locale("ja" if idx == 0 else "en")


## コンフィグで切り替えるのは日本語・英語のみ（zh 系は UI 上は ja スロットに寄せる）
func _config_language_ui_index_from_locale() -> int:
	var loc: String = TranslationServer.get_locale()
	if loc == "en":
		return 1
	return 0


## コンフィグの値表示用（CONFIG_LANG_JA / CONFIG_LANG_EN のみ）
func config_language_ui_label() -> String:
	return tr("CONFIG_LANG_JA") if _config_language_ui_index_from_locale() == 0 else tr("CONFIG_LANG_EN")


func _center_window() -> void:
	var screen_rect: Rect2i = DisplayServer.screen_get_usable_rect(0)
	var win_size: Vector2i = get_window().get_size_with_decorations()
	get_window().position = screen_rect.position + (screen_rect.size / 2 - win_size / 2)


func _sync_fullscreen_from_os() -> void:
	var win: Window = get_window()
	var wid: int = win.get_window_id()
	var m := DisplayServer.window_get_mode(wid)
	is_fullscreen = (
		m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		or m == DisplayServer.WINDOW_MODE_FULLSCREEN
	)


## ウインドウのクライアントサイズのみ変更する。内部解像度は常に INTERNAL_VIEWPORT_SIZE（stretch で縮小表示）。
func _apply_window_pixel_size_impl(new_size: Vector2i) -> void:
	_sync_fullscreen_from_os()
	if is_fullscreen:
		_apply_internal_viewport_size()
		return
	var win: Window = get_window()
	var wid: int = win.get_window_id()
	DisplayServer.window_set_size(new_size, wid)
	win.size = new_size
	_apply_internal_viewport_size()
	call_deferred("_center_window")


func _apply_internal_viewport_size() -> void:
	var vp: Viewport = get_viewport()
	if vp:
		vp.size = INTERNAL_VIEWPORT_SIZE


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
		_reset_ui_menu_stick_navigation()
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
	return ui_renderer.get_results_next_button_rect(vp).has_point(pos)


func _hit_menu_item(pos: Vector2) -> int:
	var vp: Vector2 = get_viewport_rect().size
	var menu_count: int = 3
	for i in range(menu_count):
		var btn_cy: float = ui_renderer.get_menu_btn_cy(vp, i, menu_count)
		if pos.y >= btn_cy - 35.0 and pos.y <= btn_cy + 35.0:
			return i
	return -1


func _hit_config_item(pos: Vector2) -> Dictionary:
	# 「タイトルに戻る」ボタン（行4）の決定用。値行は ◀▶ は _hit_config_value_arrows。
	var vp: Vector2 = get_viewport_rect().size
	var base_y: float = vp.y * CONFIG_MENU_BASE_Y_RATIO
	var spacing: float = CONFIG_MENU_SPACING
	var box_w: float = vp.x * CONFIG_MENU_BOX_W_RATIO
	var box_h: float = (font.get_ascent(34) + font.get_descent(34)) * 1.5
	var i: int = 4
	var item_y: float = base_y + i * spacing
	var extra_y: float = vp.y * 0.15 - 35.0
	var btn_half_w: float = box_w / 2.0
	var btn_cx: float = vp.x / 2.0
	if pos.y >= item_y - 20.0 + extra_y and pos.y <= item_y - 16.0 + box_h + extra_y and pos.x >= btn_cx - btn_half_w and pos.x <= btn_cx + btn_half_w:
		return { "ok": true, "main": i }
	return {}


## 画面モード・言語・BGM/SE の ◀▲ クリック。戻り値: ok, item(0〜3), delta(±1)
func _hit_config_value_arrows(pos: Vector2) -> Dictionary:
	var vp: Vector2 = get_viewport_rect().size
	for item_idx in range(4):
		var geom: Dictionary = config_row_scaled_layout(vp, item_idx)
		var Lp: Vector2 = geom["Lp"]
		var Rp: Vector2 = geom["Rp"]
		var aw: float = geom["aw"]
		var bh: float = geom["bh"]
		var top: float = Lp.y - bh * 0.5
		var bottom: float = top + bh
		if pos.y < top or pos.y > bottom:
			continue
		var left_enabled: bool = true
		var right_enabled: bool = true
		match item_idx:
			2:
				left_enabled = bgm_volume > 0
				right_enabled = bgm_volume < 10
			3:
				left_enabled = se_volume > 0
				right_enabled = se_volume < 10
		var left_edge: float = Lp.x - aw * 0.5
		if left_enabled and pos.x >= left_edge and pos.x <= left_edge + aw:
			return { "ok": true, "item": item_idx, "delta": -1 }
		var right_edge: float = Rp.x - aw * 0.5
		if right_enabled and pos.x >= right_edge and pos.x <= right_edge + aw:
			return { "ok": true, "item": item_idx, "delta": 1 }
	return {}


## コンフィグ 0〜3 行の値ボックス中心・矢印位置（get_btn_scale 適用後）。描画とヒット判定で共通。
func config_row_scaled_layout(vp: Vector2, item_idx: int) -> Dictionary:
	var base_y: float = vp.y * CONFIG_MENU_BASE_Y_RATIO
	var spacing: float = CONFIG_MENU_SPACING
	var vx: float = vp.x * CONFIG_MENU_VX_RATIO
	var box_w: float = vp.x * CONFIG_MENU_BOX_W_RATIO
	var box_h: float = (font.get_ascent(34) + font.get_descent(34)) * 1.5
	var arrow_w: float = CONFIG_MENU_ARROW_W
	var pad: float = CONFIG_MENU_ARROW_PAD
	var item_y: float = base_y + item_idx * spacing
	var gy: float = item_y - 16.0 + box_h * 0.5
	var gx: float = vx + box_w * 0.5
	var G: Vector2 = Vector2(gx, gy)
	var sc: float = ui_renderer.get_btn_scale(CONFIG_ROW_BTN_IDS[item_idx])
	var Lcen: Vector2 = Vector2(vx - arrow_w - pad + arrow_w * 0.5, gy)
	var Rcen: Vector2 = Vector2(vx + box_w + pad + arrow_w * 0.5, gy)
	var Lp: Vector2 = G + (Lcen - G) * sc
	var Rp: Vector2 = G + (Rcen - G) * sc
	return {
		"G": G,
		"Lp": Lp,
		"Rp": Rp,
		"bw": box_w * sc,
		"bh": box_h * sc,
		"aw": arrow_w * sc,
	}


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
	# 十字の上下左右は _process_ui_menu_stick_navigation（左スティック＋D-pad をアナログ合成と同一経路）。ここで JoypadButton を重ねると _input→_process の順で二重に進む／左右が逆に感じる原因になる。

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
	stage_move_count = 0
	_reset_stage_move_track_internal()
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
	# 十字は _process_ui_menu_stick_navigation のみ（メインのポーズメニューと同じく二重処理しない）

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
	debug_stage_test_meta_stage_name = ""
	input_recorder = null
	_stop_bgm(bgm_title)
	stage_times.clear()
	stage_move_counts.clear()
	stage_result_shapes.clear()
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
# Stage debug（エディタからの実行時のみ。F2）
# =============================================================================

func _debug_tools_enabled() -> bool:
	# エディタから F5 実行時、Engine.is_editor_hint() は false になることがある。
	# OS.has_feature("editor") がエディタ経由の実行を表す。エクスポート版では両方 false。
	return OS.has_feature("editor") or Engine.is_editor_hint()


func _enter_results_screen_debug() -> void:
	"""タイトルで [S]：リザルト画面のみを検証（秒・回はランダム、合計は配列の合算）"""
	if not _debug_tools_enabled():
		return
	const SLOT_COUNT: int = 10
	stage_times.clear()
	stage_move_counts.clear()
	stage_result_shapes.clear()
	for i in range(SLOT_COUNT):
		stage_times.append(randf_range(1.0, 999.0))
		stage_move_counts.append(randi_range(10, 500))
		stage_result_shapes.append({})
	_stop_bgm(bgm_title)
	game_state = "results"
	_play_bgm(bgm_result)
	queue_redraw()


func _return_to_title_or_stage_debug_from_test() -> void:
	var back_to_stage_debug: bool = debug_stage_test_mode and _debug_tools_enabled()
	debug_stage_test_mode = false
	debug_stage_test_meta_stage_name = ""
	input_recorder = null
	if back_to_stage_debug:
		_refresh_stage_debug_custom_paths()
		_clamp_stage_debug_selection()
		game_state = "stage_debug"
		_sync_stage_debug_field_buffers()
		stage_debug_last_error = ""
	else:
		game_state = "title"
	preferred_input_method = ""
	title_start_time = Time.get_ticks_msec() / 1000.0
	_play_bgm(bgm_title)


func _enter_stage_debug_screen() -> void:
	_refresh_stage_debug_custom_paths()
	stage_debug_scroll = 0.0
	stage_debug_selected = 0
	stage_debug_field_focus_idx = -1
	stage_debug_edit_buffer = ""
	stage_debug_last_error = ""
	_clamp_stage_debug_selection()
	_sync_stage_debug_field_buffers()
	game_state = "stage_debug"
	_stage_debug_sync_ime_for_field_focus()
	queue_redraw()


## STAGE DEBUG: 日本語 IME 用（カスタム描画の値欄で stage_name / description のときのみ有効化）
func _stage_debug_sync_ime_for_field_focus() -> void:
	if not _debug_tools_enabled():
		return
	if game_state != "stage_debug":
		DisplayServer.window_set_ime_active(false)
		return
	var want_ime: bool = false
	if stage_debug_field_focus_idx >= 0 and stage_debug_field_focus_idx < STAGE_DEBUG_FIELD_KEYS.size():
		var fk: String = STAGE_DEBUG_FIELD_KEYS[stage_debug_field_focus_idx]
		want_ime = fk == "stage_name" or fk == "description"
	DisplayServer.window_set_ime_active(want_ime)


func _refresh_stage_debug_custom_paths() -> void:
	if not _debug_tools_enabled():
		stage_debug_custom_paths.clear()
		return
	stage_debug_custom_paths = CustomStageFile.list_custom_stage_paths()


func _stage_debug_master_count() -> int:
	return StageData.get_stages().size()


func _stage_debug_total_rows() -> int:
	return _stage_debug_master_count() + stage_debug_custom_paths.size()


func _stage_debug_is_custom_row(row: int) -> bool:
	return row >= _stage_debug_master_count() and row < _stage_debug_total_rows()


func _stage_debug_custom_path_at(row: int) -> String:
	return stage_debug_custom_paths[row - _stage_debug_master_count()]


func _clamp_stage_debug_selection() -> void:
	var n: int = _stage_debug_total_rows()
	if n <= 0:
		stage_debug_selected = 0
		return
	if stage_debug_selected >= n:
		stage_debug_selected = n - 1
	if stage_debug_selected < 0:
		stage_debug_selected = 0


## カスタム行: ファイル + custom_pending をマージした raw（effective 前）
func _stage_debug_custom_raw_merged(path: String) -> Dictionary:
	var pr: Dictionary = CustomStageFile.parse_file(path)
	if not pr.get("ok", false):
		return {}
	var raw: Dictionary = (pr["raw"] as Dictionary).duplicate(true)
	var pend: Dictionary = stage_debug_custom_pending.get(path, {})
	if pend.is_empty():
		return raw
	var cfg_partial: Dictionary = (raw["config"] as Dictionary).duplicate(true)
	var meta_partial: Dictionary = {}
	if raw.has("meta") and typeof(raw["meta"]) == TYPE_DICTIONARY:
		meta_partial = (raw["meta"] as Dictionary).duplicate(true)
	for k in pend:
		if k == "stage_name" or k == "description":
			var vs: String = str(pend[k]).strip_edges()
			if vs == "":
				meta_partial.erase(k)
			else:
				meta_partial[k] = vs
		else:
			cfg_partial[k] = pend[k]
	raw["config"] = cfg_partial
	if not meta_partial.is_empty():
		raw["meta"] = meta_partial
	elif raw.has("meta"):
		raw.erase("meta")
	return raw


func _sync_stage_debug_field_buffers() -> void:
	var cfg: Dictionary = {}
	var row: int = stage_debug_selected
	var raw_cfg: Dictionary = {}
	var meta_view: Dictionary = {}
	if _stage_debug_is_custom_row(row):
		var path: String = _stage_debug_custom_path_at(row)
		var raw: Dictionary = _stage_debug_custom_raw_merged(path)
		if not raw.is_empty():
			cfg = CustomStageFile.effective_config_with_shape(raw)
			raw_cfg = raw["config"] as Dictionary
			if raw.has("meta") and typeof(raw["meta"]) == TYPE_DICTIONARY:
				meta_view = raw["meta"] as Dictionary
	else:
		cfg = StageDebugOverrides.build_config_for_index(
			row, stage_debug_pending.get(row, {})
		)
	stage_debug_field_buffers.clear()
	for key in STAGE_DEBUG_FIELD_KEYS:
		if key == "stage_name":
			if _stage_debug_is_custom_row(row):
				stage_debug_field_buffers[key] = str(meta_view.get("stage_name", ""))
			else:
				stage_debug_field_buffers[key] = ""
			continue
		if key == "description":
			if _stage_debug_is_custom_row(row):
				stage_debug_field_buffers[key] = str(meta_view.get("description", ""))
			else:
				stage_debug_field_buffers[key] = ""
			continue
		if key == "group_sizes" and cfg.has("group_sizes"):
			var gs: Array = cfg["group_sizes"] as Array
			stage_debug_field_buffers[key] = "%d,%d" % [int(gs[0]), int(gs[1])]
		elif _stage_debug_is_custom_row(row) and key == "type":
			stage_debug_field_buffers[key] = str(raw_cfg.get("type", ""))
		elif cfg.has(key):
			stage_debug_field_buffers[key] = _stage_debug_config_value_str_for_buffer(key, cfg[key])
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


func _validate_custom_stage_pending(path: String, partial: Dictionary) -> String:
	var pr: Dictionary = CustomStageFile.parse_file(path)
	if not pr.get("ok", false):
		return str(pr.get("error", "読み込み失敗"))
	var raw: Dictionary = (pr["raw"] as Dictionary).duplicate(true)
	var cfg_partial: Dictionary = (raw["config"] as Dictionary).duplicate(true)
	var meta_partial: Dictionary = {}
	if raw.has("meta") and typeof(raw["meta"]) == TYPE_DICTIONARY:
		meta_partial = (raw["meta"] as Dictionary).duplicate(true)
	for k in partial:
		if k == "stage_name" or k == "description":
			var vs: String = str(partial[k]).strip_edges()
			if vs == "":
				meta_partial.erase(k)
			else:
				meta_partial[k] = vs
		else:
			cfg_partial[k] = partial[k]
	raw["config"] = cfg_partial
	if not meta_partial.is_empty():
		raw["meta"] = meta_partial
	elif raw.has("meta"):
		raw.erase("meta")
	var vroot: String = CustomStageFile.validate_root(raw)
	if vroot != "":
		return vroot
	var cfg: Dictionary = CustomStageFile.effective_config_with_shape(raw)
	return StageDebugOverrides.validate_effective_config(cfg)


func _apply_field_string_to_pending(key: String, text: String) -> String:
	var s: String = text.strip_edges()
	var row: int = stage_debug_selected
	if (key == "stage_name" or key == "description") and not _stage_debug_is_custom_row(row):
		if s == "":
			return ""
		return "stage_name / description はカスタムステージ行のみ編集できます"
	if _stage_debug_is_custom_row(row):
		var path: String = _stage_debug_custom_path_at(row)
		var p: Dictionary = stage_debug_custom_pending.get(path, {}).duplicate(true)
		if s == "":
			# stage_name / description は空文字を pending に残す（erase だと未編集扱いでファイルの meta に戻る）
			if key == "stage_name" or key == "description":
				p[key] = ""
			else:
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
				"guide_follows_player_radius":
					if s != "0" and s != "1":
						return "guide_follows_player_radius は 0 または 1"
					p[key] = int(s)
				"group_sizes":
					var parts: PackedStringArray = s.split(",")
					if parts.size() < 2:
						return "group_sizes は 12,12 の形式にしてください"
					if not parts[0].strip_edges().is_valid_int() or not parts[1].strip_edges().is_valid_int():
						return "group_sizes が不正です"
					p["group_sizes"] = [int(parts[0].strip_edges()), int(parts[1].strip_edges())]
				"stage_name", "description":
					p[key] = s
				_:
					p[key] = s
		var verr: String = _validate_custom_stage_pending(path, p)
		if verr != "":
			return verr
		if p.is_empty():
			stage_debug_custom_pending.erase(path)
		else:
			stage_debug_custom_pending[path] = p
		return ""

	var idx: int = row
	var p2: Dictionary = stage_debug_pending.get(idx, {}).duplicate(true)
	if s == "":
		p2.erase(key)
	else:
		match key:
			"type":
				p2["type"] = s
			"num_points":
				if not s.is_valid_int():
					return "num_points が整数ではありません"
				p2["num_points"] = int(s)
			"min_radius", "max_radius", "variance", "zigzag", "display_rate_min_pct", "clear_pct":
				if not s.is_valid_float():
					return "%s が数値ではありません" % key
				p2[key] = float(s)
			"guide_follows_player_radius":
				if s != "0" and s != "1":
					return "guide_follows_player_radius は 0 または 1"
				p2[key] = int(s)
			"group_sizes":
				var parts: PackedStringArray = s.split(",")
				if parts.size() < 2:
					return "group_sizes は 12,12 の形式にしてください"
				if not parts[0].strip_edges().is_valid_int() or not parts[1].strip_edges().is_valid_int():
					return "group_sizes が不正です"
				p2["group_sizes"] = [int(parts[0].strip_edges()), int(parts[1].strip_edges())]
			_:
				p2[key] = s
	var verr: String = StageDebugOverrides.validate_partial_with_master(idx, p2)
	if verr != "":
		return verr
	if p2.is_empty():
		stage_debug_pending.erase(idx)
	else:
		stage_debug_pending[idx] = p2
	return ""


func _stage_debug_split_x(vp: Vector2) -> float:
	return clampf(vp.x * STAGE_DEBUG_LEFT_COL_RATIO, 260.0, 520.0)


func _stage_debug_action_row_y() -> float:
	return STAGE_DEBUG_LIST_TOP_Y + 6.0


func _stage_debug_fields_start_y() -> float:
	return _stage_debug_action_row_y() + STAGE_DEBUG_ACTION_BTN_H + 12.0


func _stage_debug_config_value_str_for_buffer(key: String, v: Variant) -> String:
	match key:
		"num_points", "guide_follows_player_radius":
			return str(int(v))
		_:
			return str(v)


func _stage_debug_description_line_count() -> int:
	var dfi: int = STAGE_DEBUG_FIELD_KEYS.find("description")
	var txt: String = ""
	if dfi >= 0 and stage_debug_field_focus_idx == dfi:
		txt = stage_debug_edit_buffer
	else:
		txt = str(stage_debug_field_buffers.get("description", ""))
	var n: int = max(1, txt.split("\n").size())
	return max(STAGE_DEBUG_DESC_VISIBLE_LINES, min(n, STAGE_DEBUG_DESC_MAX_LINES))


func _stage_debug_description_field_height() -> float:
	var n: int = _stage_debug_description_line_count()
	var line_h: float = font.get_height(STAGE_DEBUG_DESC_LINE_FS) + STAGE_DEBUG_DESC_LINE_INNER_GAP
	return STAGE_DEBUG_DESC_PAD_TOP + line_h * float(n) + 4.0


func _stage_debug_field_value_height(fi: int) -> float:
	if fi >= 0 and fi < STAGE_DEBUG_FIELD_KEYS.size() and STAGE_DEBUG_FIELD_KEYS[fi] == "description":
		return _stage_debug_description_field_height()
	return STAGE_DEBUG_FIELD_SINGLE_H


func _stage_debug_field_row_top_y(_vp: Vector2, fi: int) -> float:
	var y: float = _stage_debug_fields_start_y()
	for i in range(fi):
		y += _stage_debug_field_value_height(i) + STAGE_DEBUG_FIELD_ROW_GAP
	return y


func _stage_debug_scroll_max(vp: Vector2) -> float:
	var n: int = _stage_debug_total_rows()
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
	var bw4: float = minf(100.0, (right_w - 3.0 * gap) / 4.0)
	bw4 = maxf(48.0, bw4)
	var rx: float = split + 12.0
	for k in range(4):
		out.append(Rect2(rx + float(k) * (bw4 + gap), y_actions, bw4, bh))
	var tw: float = minf(96.0, (vp.x - split - 48.0) / 2.0 - gap * 0.5)
	tw = maxf(72.0, tw)
	var tr_x: float = vp.x - 12.0 - 2.0 * tw - gap
	out.append(Rect2(tr_x, y_top, tw, bh))
	out.append(Rect2(tr_x + tw + gap, y_top, tw, bh))
	return out


## 全フィールドの「名前:」のうち最長のピクセル幅 + 余白（右寄せで値欄の左端に揃える）
func _stage_debug_field_label_column_width() -> float:
	var max_w: float = 0.0
	for k in STAGE_DEBUG_FIELD_KEYS:
		var lbl: String = "%s:" % k
		var sz: Vector2 = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, STAGE_DEBUG_FIELD_LABEL_FS)
		max_w = maxf(max_w, sz.x)
	return max_w + 12.0


## 値入力欄のみ（クリック・編集対象）。ラベル列は含まない。
func _stage_debug_field_value_rect(vp: Vector2, fi: int) -> Rect2:
	var split: float = _stage_debug_split_x(vp)
	var margin: float = 12.0
	var y: float = _stage_debug_field_row_top_y(vp, fi)
	var label_w: float = _stage_debug_field_label_column_width()
	var x0: float = split + margin + label_w + STAGE_DEBUG_FIELD_VALUE_GAP
	var full_vw: float = vp.x - x0 - margin
	full_vw = maxf(64.0, full_vw)
	var vw: float = full_vw
	if fi >= 0 and fi < STAGE_DEBUG_FIELD_KEYS.size():
		var fk: String = STAGE_DEBUG_FIELD_KEYS[fi]
		if fk == "stage_name":
			var sn_actions_w: float = STAGE_DEBUG_TEXT_BTN_W * 3.0 + STAGE_DEBUG_TEXT_BTN_GAP * 2.0
			vw = maxf(64.0, full_vw - sn_actions_w - STAGE_DEBUG_TEXT_BTN_GAP)
		elif fk == "description":
			var actions_w: float = STAGE_DEBUG_TEXT_BTN_W * 3.0 + STAGE_DEBUG_TEXT_BTN_GAP * 2.0
			vw = maxf(64.0, full_vw - actions_w - STAGE_DEBUG_TEXT_BTN_GAP)
	var h: float = _stage_debug_field_value_height(fi)
	return Rect2(x0, y, vw, h)


## action_idx: 0=コピー 1=消去 2=貼り付け（description と同順）
func _stage_debug_stage_name_action_button_rect(vp: Vector2, action_idx: int) -> Rect2:
	var fi: int = STAGE_DEBUG_FIELD_KEYS.find("stage_name")
	if fi < 0 or action_idx < 0 or action_idx > 2:
		return Rect2()
	var fr: Rect2 = _stage_debug_field_value_rect(vp, fi)
	var bx: float = fr.position.x + fr.size.x + STAGE_DEBUG_TEXT_BTN_GAP + float(action_idx) * (STAGE_DEBUG_TEXT_BTN_W + STAGE_DEBUG_TEXT_BTN_GAP)
	var by: float = fr.position.y + (fr.size.y - STAGE_DEBUG_TEXT_BTN_H) * 0.5
	return Rect2(bx, by, STAGE_DEBUG_TEXT_BTN_W, STAGE_DEBUG_TEXT_BTN_H)


## action_idx: 0=コピー 1=消去 2=貼り付け
func _stage_debug_description_action_button_rect(vp: Vector2, action_idx: int) -> Rect2:
	var fi: int = STAGE_DEBUG_FIELD_KEYS.find("description")
	if fi < 0 or action_idx < 0 or action_idx > 2:
		return Rect2()
	var fr: Rect2 = _stage_debug_field_value_rect(vp, fi)
	var bx: float = fr.position.x + fr.size.x + STAGE_DEBUG_TEXT_BTN_GAP + float(action_idx) * (STAGE_DEBUG_TEXT_BTN_W + STAGE_DEBUG_TEXT_BTN_GAP)
	var by: float = fr.position.y + (fr.size.y - STAGE_DEBUG_TEXT_BTN_H) * 0.5
	return Rect2(bx, by, STAGE_DEBUG_TEXT_BTN_W, STAGE_DEBUG_TEXT_BTN_H)


func _stage_debug_paste_into_field(field_key: String) -> void:
	if not _stage_debug_is_custom_row(stage_debug_selected):
		return
	var fi: int = STAGE_DEBUG_FIELD_KEYS.find(field_key)
	if fi < 0:
		return
	stage_debug_field_focus_idx = fi
	stage_debug_edit_buffer = _filter_stage_debug_paste_for_field(field_key, DisplayServer.clipboard_get())
	stage_debug_last_error = _apply_field_string_to_pending(field_key, stage_debug_edit_buffer)
	_sync_stage_debug_field_buffers()
	_stage_debug_sync_ime_for_field_focus()


func _stage_debug_description_copy_to_clipboard() -> void:
	var dfi: int = STAGE_DEBUG_FIELD_KEYS.find("description")
	var txt: String
	if stage_debug_field_focus_idx == dfi:
		txt = stage_debug_edit_buffer
	else:
		txt = str(stage_debug_field_buffers.get("description", ""))
	DisplayServer.clipboard_set(txt)


func _stage_debug_stage_name_copy_to_clipboard() -> void:
	var sfi: int = STAGE_DEBUG_FIELD_KEYS.find("stage_name")
	var txt: String
	if stage_debug_field_focus_idx == sfi:
		txt = stage_debug_edit_buffer
	else:
		txt = str(stage_debug_field_buffers.get("stage_name", ""))
	DisplayServer.clipboard_set(txt)


func _stage_debug_stage_name_clear() -> void:
	var sfi: int = STAGE_DEBUG_FIELD_KEYS.find("stage_name")
	if sfi < 0:
		return
	stage_debug_field_focus_idx = sfi
	stage_debug_edit_buffer = ""
	stage_debug_last_error = _apply_field_string_to_pending("stage_name", "")
	_sync_stage_debug_field_buffers()
	_stage_debug_sync_ime_for_field_focus()


func _stage_debug_description_clear() -> void:
	var dfi: int = STAGE_DEBUG_FIELD_KEYS.find("description")
	if dfi < 0:
		return
	stage_debug_field_focus_idx = dfi
	stage_debug_edit_buffer = ""
	stage_debug_last_error = _apply_field_string_to_pending("description", "")
	_sync_stage_debug_field_buffers()
	_stage_debug_sync_ime_for_field_focus()


func _filter_stage_debug_digits_only_char(ch: String) -> String:
	if ch.length() != 1:
		return ""
	var c: int = ch.unicode_at(0)
	if c >= 48 and c <= 57:
		return ch
	return ""


func _filter_stage_debug_digits_only_string(s: String) -> String:
	var out: String = ""
	for i in range(s.length()):
		var c: int = s.unicode_at(i)
		if c >= 48 and c <= 57:
			out += s[i]
	return out


func _filter_stage_debug_float_chars_string(s: String) -> String:
	var out: String = ""
	for i in range(s.length()):
		var c: int = s.unicode_at(i)
		if (c >= 48 and c <= 57) or c == 46 or c == 45:
			out += s[i]
	return out


func _filter_stage_debug_float_char(ch: String) -> String:
	if ch.length() != 1:
		return ""
	var c: int = ch.unicode_at(0)
	if (c >= 48 and c <= 57) or c == 46 or c == 45:
		return ch
	return ""


func _filter_stage_debug_group_sizes_char(ch: String) -> String:
	if ch.length() != 1:
		return ""
	var c: int = ch.unicode_at(0)
	if (c >= 48 and c <= 57) or c == 44:
		return ch
	return ""


func _filter_stage_debug_group_sizes_string(s: String) -> String:
	var out: String = ""
	for i in range(s.length()):
		var c: int = s.unicode_at(i)
		if (c >= 48 and c <= 57) or c == 44:
			out += s[i]
	return out


func _filter_stage_debug_guide_follow_char(ch: String) -> String:
	if ch.length() != 1:
		return ""
	var c: int = ch.unicode_at(0)
	if c == 48 or c == 49:
		return ch
	return ""


func _filter_stage_debug_guide_follow_string(s: String) -> String:
	var out: String = ""
	for i in range(s.length()):
		var c: int = s.unicode_at(i)
		if c == 48 or c == 49:
			out += s[i]
	return out


func _filter_stage_debug_char_for_field(key: String, ch: String) -> String:
	match key:
		"type":
			return _filter_stage_id_allowed_only(ch)
		"group_sizes":
			return _filter_stage_debug_group_sizes_char(ch)
		"num_points":
			return _filter_stage_debug_digits_only_char(ch)
		"guide_follows_player_radius":
			return _filter_stage_debug_guide_follow_char(ch)
		"stage_name":
			if ch.length() != 1:
				return ""
			var cs: int = ch.unicode_at(0)
			if cs < 32:
				return ""
			return ch
		"description":
			if ch.length() != 1:
				return ""
			var cd: int = ch.unicode_at(0)
			if cd < 32 and cd != 10:
				return ""
			return ch
		_:
			return _filter_stage_debug_float_char(ch)


func _filter_stage_debug_paste_for_field(key: String, clip: String) -> String:
	match key:
		"type":
			return _filter_stage_id_allowed_only(clip)
		"group_sizes":
			return _filter_stage_debug_group_sizes_string(clip)
		"num_points":
			return _filter_stage_debug_digits_only_string(clip)
		"guide_follows_player_radius":
			return _filter_stage_debug_guide_follow_string(clip)
		"stage_name", "description":
			return clip
		_:
			return _filter_stage_debug_float_chars_string(clip)


func _stage_debug_new_custom_button_rect(vp: Vector2) -> Rect2:
	return Rect2(24.0, 132.0, 76.0, 30.0)


## Stage ID 用: 小文字 a-z / 数字 / _ のみ（それ以外は除去）
func _filter_stage_id_allowed_only(s: String) -> String:
	var out: String = ""
	for i in range(s.length()):
		var c: int = s.unicode_at(i)
		if (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95:
			out += s[i]
	return out


func _sanitized_stage_edit_filename(s: String) -> String:
	var t: String = _filter_stage_id_allowed_only(s.strip_edges())
	if t.length() > 48:
		t = t.left(48)
	return t


func _stage_edit_type_idx_from_saved_config(cfg: Dictionary) -> int:
	var st: String = str(cfg.get("shape_type", ""))
	if st.is_empty():
		var tid: String = str(cfg.get("type", ""))
		if StageConfig.TYPE_DEFAULTS.has(tid):
			st = tid
		else:
			st = "fish"
	for i in range(STAGE_EDIT_TYPE_OPTIONS.size()):
		if STAGE_EDIT_TYPE_OPTIONS[i] == st:
			return i
	return 0


func _shape_block_has_polygon(shape_block: Dictionary) -> bool:
	var pv: Variant = shape_block.get("polygon_vertices", [])
	return typeof(pv) == TYPE_ARRAY and (pv as Array).size() >= 3


func _stage_edit_snap_current_canvas_to_grid() -> void:
	if not _stage_edit_shape_has_canvas():
		return
	if stage_edit_canvas_vertices.is_empty():
		return
	var vp: Vector2 = get_viewport_rect().size
	_stage_edit_snap_canvas_state_to_grid(_stage_edit_canvas_rect(vp))


func _enter_stage_edit_screen() -> void:
	if not _debug_tools_enabled():
		return
	DisplayServer.window_set_ime_active(false)
	stage_edit_stage_id = "new_stage"
	stage_edit_meta_preserve = {}
	stage_edit_type_idx = 0
	stage_edit_include_fish_shape = true
	stage_edit_text_line = 0
	stage_edit_last_error = ""
	stage_edit_canvas_drag_idx = -1
	stage_edit_canvas_right_drag_idx = -1
	stage_edit_canvas_right_drag_committed = false
	stage_edit_undo_stack.clear()
	stage_edit_redo_stack.clear()
	stage_edit_mirror_preview = [false, false, false, false]
	_init_stage_edit_canvas()
	_stage_edit_snap_current_canvas_to_grid()
	game_state = "stage_edit"
	queue_redraw()


func _enter_stage_edit_from_path(path: String) -> void:
	if not _debug_tools_enabled():
		return
	DisplayServer.window_set_ime_active(false)
	var pr: Dictionary = CustomStageFile.parse_file(path)
	if not pr.get("ok", false):
		stage_debug_last_error = str(pr.get("error", "読めません"))
		queue_redraw()
		return
	stage_debug_last_error = ""
	var raw: Dictionary = pr["raw"] as Dictionary
	var cfg: Dictionary = raw["config"] as Dictionary
	stage_edit_stage_id = str(cfg.get("type", "new_stage"))
	stage_edit_meta_preserve = {}
	if raw.has("meta") and typeof(raw["meta"]) == TYPE_DICTIONARY:
		stage_edit_meta_preserve = (raw["meta"] as Dictionary).duplicate(true)
	stage_edit_type_idx = _stage_edit_type_idx_from_saved_config(cfg)
	stage_edit_include_fish_shape = true
	stage_edit_text_line = 0
	stage_edit_last_error = ""
	stage_edit_canvas_drag_idx = -1
	stage_edit_canvas_right_drag_idx = -1
	stage_edit_canvas_right_drag_committed = false
	stage_edit_undo_stack.clear()
	stage_edit_redo_stack.clear()
	stage_edit_mirror_preview = [false, false, false, false]
	_init_stage_edit_canvas(raw)
	_stage_edit_snap_current_canvas_to_grid()
	game_state = "stage_edit"
	queue_redraw()


func _exit_stage_edit_to_debug() -> void:
	stage_edit_last_error = ""
	game_state = "stage_debug"
	queue_redraw()


func _exit_stage_edit_after_save(saved_path: String) -> void:
	stage_debug_custom_pending.erase(saved_path)
	_refresh_stage_debug_custom_paths()
	var idx: int = stage_debug_custom_paths.find(saved_path)
	if idx < 0:
		for i in range(stage_debug_custom_paths.size()):
			if stage_debug_custom_paths[i].get_file() == saved_path.get_file():
				idx = i
				break
	if idx >= 0:
		stage_debug_selected = _stage_debug_master_count() + idx
	else:
		_clamp_stage_debug_selection()
	stage_edit_last_error = ""
	game_state = "stage_debug"
	_sync_stage_debug_field_buffers()
	stage_debug_last_error = "保存しました: %s" % saved_path.get_file()
	queue_redraw()


func _stage_edit_split_x(vp: Vector2) -> float:
	return vp.x * STAGE_EDIT_LEFT_RATIO


func _stage_edit_right_panel_rect(vp: Vector2) -> Rect2:
	var top: float = STAGE_EDIT_TOP_BAR + 8.0
	var split_x: float = _stage_edit_split_x(vp)
	var gap: float = 14.0
	var right_pad: float = 20.0
	var x: float = split_x + gap * 0.5
	var w: float = vp.x - x - right_pad
	var h: float = vp.y - top - STAGE_EDIT_FOOTER_H
	return Rect2(x, top, maxf(200.0, w), maxf(120.0, h))


func _stage_edit_canvas_rect(vp: Vector2) -> Rect2:
	var top: float = STAGE_EDIT_TOP_BAR + 8.0
	var left_pad: float = 20.0
	var split_x: float = _stage_edit_split_x(vp)
	var gap: float = 14.0
	var w: float = split_x - left_pad - gap * 0.5
	var h: float = vp.y - top - STAGE_EDIT_FOOTER_H
	return Rect2(left_pad, top, maxf(200.0, w), maxf(160.0, h))


func _stage_edit_text_rect_filename(vp: Vector2) -> Rect2:
	var pr: Rect2 = _stage_edit_right_panel_rect(vp)
	var y: float = pr.position.y + 76.0
	return Rect2(pr.position.x, y, pr.size.x, 28.0)


func _stage_edit_type_chip_rect(vp: Vector2, i: int) -> Rect2:
	var pr: Rect2 = _stage_edit_right_panel_rect(vp)
	var fr: Rect2 = _stage_edit_text_rect_filename(vp)
	var col: int = i % 4
	var row: int = i / 4
	var chip_w: float = minf(104.0, (pr.size.x - 32.0) / 4.0 - 6.0)
	var x0: float = pr.position.x
	var y0: float = fr.position.y + fr.size.y + 28.0
	var x: float = x0 + float(col) * (chip_w + 8.0)
	var y: float = y0 + float(row) * 32.0
	return Rect2(x, y, chip_w, 28.0)


func _stage_edit_fish_shape_toggle_rect(vp: Vector2) -> Rect2:
	var pr: Rect2 = _stage_edit_right_panel_rect(vp)
	var n: int = STAGE_EDIT_TYPE_OPTIONS.size()
	var rows: int = (n + 3) / 4
	var fr: Rect2 = _stage_edit_text_rect_filename(vp)
	var y_chips: float = fr.position.y + fr.size.y + 28.0
	var y: float = y_chips + float(rows) * 32.0 + 12.0
	return Rect2(pr.position.x, y, 28.0, 28.0)


func _stage_edit_shape_has_canvas() -> bool:
	var tidx: int = clampi(stage_edit_type_idx, 0, STAGE_EDIT_TYPE_OPTIONS.size() - 1)
	var t: String = STAGE_EDIT_TYPE_OPTIONS[tidx]
	return t == "fish" or t == "cat_face"


func _init_stage_edit_canvas(merged_raw: Dictionary = {}) -> void:
	stage_edit_canvas_vertices.clear()
	stage_edit_canvas_edges.clear()
	stage_edit_canvas_hover_edge = -1
	stage_edit_canvas_right_drag_idx = -1
	stage_edit_canvas_right_drag_committed = false
	var tidx: int = clampi(stage_edit_type_idx, 0, STAGE_EDIT_TYPE_OPTIONS.size() - 1)
	var t: String = STAGE_EDIT_TYPE_OPTIONS[tidx]
	var shape_block: Dictionary = {}
	if not merged_raw.is_empty() and merged_raw.has("shape") and typeof(merged_raw["shape"]) == TYPE_DICTIONARY:
		shape_block = merged_raw["shape"] as Dictionary
	match t:
		"fish":
			if _shape_block_has_polygon(shape_block):
				_stage_edit_vertices_from_shape_dict(shape_block)
				if stage_edit_canvas_vertices.size() >= 3:
					_stage_edit_sync_edges_from_shape_dict(shape_block)
				else:
					_stage_edit_vertices_from_builtin_fish()
					_stage_edit_reset_edges_all_lines()
			elif stage_edit_include_fish_shape:
				var sh: Dictionary = CustomStageFile.load_sample_fish_shape_from_res()
				_stage_edit_vertices_from_shape_dict(sh)
				if stage_edit_canvas_vertices.size() < 3:
					_stage_edit_vertices_from_builtin_fish()
					_stage_edit_reset_edges_all_lines()
				else:
					_stage_edit_sync_edges_from_shape_dict(sh)
			else:
				_stage_edit_vertices_from_builtin_fish()
				_stage_edit_reset_edges_all_lines()
		"cat_face":
			if _shape_block_has_polygon(shape_block):
				_stage_edit_vertices_from_shape_dict(shape_block)
				if stage_edit_canvas_vertices.size() >= 3:
					_stage_edit_sync_edges_from_shape_dict(shape_block)
				else:
					_stage_edit_vertices_from_builtin_cat_face()
					_stage_edit_set_edges_from_arc_dict(StageManager.get_cat_face_arc_controls())
			else:
				_stage_edit_vertices_from_builtin_cat_face()
				_stage_edit_set_edges_from_arc_dict(StageManager.get_cat_face_arc_controls())
		_:
			pass


func _stage_edit_reset_edges_all_lines() -> void:
	var n: int = stage_edit_canvas_vertices.size()
	stage_edit_canvas_edges.clear()
	for i in range(n):
		stage_edit_canvas_edges.append({"type": "line"})


func _stage_edit_sync_edges_from_shape_dict(sh: Dictionary) -> void:
	var n: int = stage_edit_canvas_vertices.size()
	stage_edit_canvas_edges.clear()
	for i in range(n):
		stage_edit_canvas_edges.append({"type": "line"})
	var ac: Variant = sh.get("arc_controls", {})
	if typeof(ac) != TYPE_DICTIONARY:
		return
	for ks in ac as Dictionary:
		var ei: int = int(str(ks))
		var v2: Variant = CustomStageFile._parse_vec2((ac as Dictionary)[ks])
		if v2 != null and ei >= 0 and ei < n:
			stage_edit_canvas_edges[ei] = {"type": "arc", "arc_control": v2 as Vector2}


func _stage_edit_set_edges_from_arc_dict(ac: Dictionary) -> void:
	var n: int = stage_edit_canvas_vertices.size()
	stage_edit_canvas_edges.clear()
	for i in range(n):
		stage_edit_canvas_edges.append({"type": "line"})
	for k in ac:
		var ei: int = int(k)
		var pt: Vector2 = ac[k]
		if ei >= 0 and ei < n:
			stage_edit_canvas_edges[ei] = {"type": "arc", "arc_control": pt}


func _stage_edit_vertices_from_shape_dict(sh: Dictionary) -> void:
	stage_edit_canvas_vertices.clear()
	var pv: Variant = sh.get("polygon_vertices", [])
	if typeof(pv) != TYPE_ARRAY:
		return
	for p in pv as Array:
		var v2: Variant = CustomStageFile._parse_vec2(p)
		if v2 != null:
			stage_edit_canvas_vertices.append(v2 as Vector2)


func _stage_edit_vertices_from_builtin_fish() -> void:
	stage_edit_canvas_vertices.clear()
	var a: Array = StageManager.get_fish_polygon_vertices()
	for p in a:
		if p is Vector2:
			stage_edit_canvas_vertices.append(p as Vector2)


func _stage_edit_vertices_from_builtin_cat_face() -> void:
	stage_edit_canvas_vertices.clear()
	var a: Array = StageManager.get_cat_face_polygon_vertices()
	for p in a:
		if p is Vector2:
			stage_edit_canvas_vertices.append(p as Vector2)


func _stage_edit_clear_left_drag_arc_state() -> void:
	_se_ld_single_arc_edge = -1
	_se_ld_single_arc_angle = 0.0
	_se_ld_both_edges.clear()
	_se_ld_both_angles.clear()
	_se_ld_both_centers.clear()
	_se_ld_both_last_centers.clear()


func _stage_edit_begin_left_drag_vertex(pt_idx: int, screen_pos: Vector2, rect: Rect2) -> void:
	stage_edit_canvas_drag_idx = pt_idx
	stage_edit_canvas_drag_norm_offset = stage_edit_canvas_vertices[pt_idx] - StageEditPolygonTools.screen_to_norm_exact(screen_pos, rect)
	_stage_edit_clear_left_drag_arc_state()
	var n: int = stage_edit_canvas_vertices.size()
	if n < 3:
		return
	var prev_e: int = (pt_idx - 1 + n) % n
	var curr_e: int = pt_idx
	var prev_arc: bool = stage_edit_canvas_edges[prev_e].get("type", "line") == "arc"
	var curr_arc: bool = stage_edit_canvas_edges[curr_e].get("type", "line") == "arc"
	if prev_arc and curr_arc:
		var pa: Vector2 = _stage_edit_canvas_norm_to_screen(stage_edit_canvas_vertices[prev_e], rect)
		var pc: Vector2 = _stage_edit_canvas_norm_to_screen(stage_edit_canvas_vertices[pt_idx], rect)
		var pb: Vector2 = _stage_edit_canvas_norm_to_screen(stage_edit_canvas_vertices[(pt_idx + 1) % n], rect)
		var ac_prev: Vector2 = _stage_edit_canvas_norm_to_screen(stage_edit_canvas_edges[prev_e]["arc_control"], rect)
		var ac_curr: Vector2 = _stage_edit_canvas_norm_to_screen(stage_edit_canvas_edges[curr_e]["arc_control"], rect)
		var ang_pc: float = StageEditPolygonTools.compute_arc_central_angle(pa, pc, ac_prev)
		var ang_cp: float = StageEditPolygonTools.compute_arc_central_angle(pc, pb, ac_curr)
		var circ_prev: Vector2 = StageEditPolygonTools.circumcenter(pa, pc, ac_prev)
		var circ_curr: Vector2 = StageEditPolygonTools.circumcenter(pc, pb, ac_curr)
		_se_ld_both_edges = [prev_e, curr_e]
		_se_ld_both_angles = [ang_pc, ang_cp]
		_se_ld_both_centers = [circ_prev, circ_curr]
		_se_ld_both_last_centers = [circ_prev, circ_curr]
	elif prev_arc and not curr_arc:
		var pa: Vector2 = _stage_edit_canvas_norm_to_screen(stage_edit_canvas_vertices[prev_e], rect)
		var pb: Vector2 = _stage_edit_canvas_norm_to_screen(stage_edit_canvas_vertices[pt_idx], rect)
		var pc: Vector2 = _stage_edit_canvas_norm_to_screen(stage_edit_canvas_edges[prev_e]["arc_control"], rect)
		_se_ld_single_arc_angle = StageEditPolygonTools.compute_arc_central_angle(pa, pb, pc)
		_se_ld_single_arc_edge = prev_e
	elif curr_arc and not prev_arc:
		var pa: Vector2 = _stage_edit_canvas_norm_to_screen(stage_edit_canvas_vertices[pt_idx], rect)
		var pb: Vector2 = _stage_edit_canvas_norm_to_screen(stage_edit_canvas_vertices[(pt_idx + 1) % n], rect)
		var pc: Vector2 = _stage_edit_canvas_norm_to_screen(stage_edit_canvas_edges[curr_e]["arc_control"], rect)
		_se_ld_single_arc_angle = StageEditPolygonTools.compute_arc_central_angle(pa, pb, pc)
		_se_ld_single_arc_edge = curr_e


func _stage_edit_grid_cell_px(rect: Rect2) -> float:
	var m: float = minf(rect.size.x, rect.size.y)
	return clampf(STAGE_EDIT_GRID_CELL_PX, 10.0, minf(24.0, m / 28.0))


func _stage_edit_snap_norm_to_grid(norm: Vector2, rect: Rect2) -> Vector2:
	var cell: float = _stage_edit_grid_cell_px(rect)
	var c: Vector2 = rect.position + rect.size * 0.5
	var rad: float = minf(rect.size.x, rect.size.y) * 0.42
	var sp: Vector2 = c + Vector2(norm.x * rad, norm.y * rad)
	var rel: Vector2 = sp - c
	var qx: float = roundf(rel.x / cell) * cell
	var qy: float = roundf(rel.y / cell) * cell
	var sp2: Vector2 = c + Vector2(qx, qy)
	var nn: Vector2 = StageEditPolygonTools.screen_to_norm_exact(sp2, rect)
	nn.x = clampf(nn.x, -1.35, 1.35)
	nn.y = clampf(nn.y, -1.35, 1.35)
	return nn


func _stage_edit_snap_canvas_state_to_grid(rect: Rect2) -> void:
	for i in range(stage_edit_canvas_vertices.size()):
		stage_edit_canvas_vertices[i] = _stage_edit_snap_norm_to_grid(stage_edit_canvas_vertices[i], rect)
	for i in range(stage_edit_canvas_edges.size()):
		var e: Dictionary = stage_edit_canvas_edges[i]
		if e.get("type", "line") == "arc" and e.has("arc_control"):
			var ac: Vector2 = e["arc_control"]
			stage_edit_canvas_edges[i]["arc_control"] = _stage_edit_snap_norm_to_grid(ac, rect)


func _stage_edit_canvas_norm_to_screen(norm: Vector2, rect: Rect2) -> Vector2:
	var c: Vector2 = rect.position + rect.size * 0.5
	var rad: float = minf(rect.size.x, rect.size.y) * 0.42
	return c + Vector2(norm.x * rad, norm.y * rad)


func _stage_edit_canvas_screen_to_norm(screen: Vector2, rect: Rect2) -> Vector2:
	var c: Vector2 = rect.position + rect.size * 0.5
	var rad: float = minf(rect.size.x, rect.size.y) * 0.42
	if rad < 0.001:
		return Vector2.ZERO
	var d: Vector2 = screen - c
	return Vector2(d.x / rad, d.y / rad)


func _stage_edit_canvas_vertex_hit_at_screen(pos: Vector2, rect: Rect2) -> int:
	var hr: float = STAGE_EDIT_CANVAS_HIT_VERTEX_R
	for i in range(stage_edit_canvas_vertices.size()):
		var sp: Vector2 = _stage_edit_canvas_norm_to_screen(stage_edit_canvas_vertices[i], rect)
		if pos.distance_to(sp) <= hr:
			return i
	return -1


func _stage_edit_bottom_button_layout(vp: Vector2) -> Array[Rect2]:
	var btn_w: float = 168.0
	var btn_h: float = 36.0
	var gap: float = 12.0
	var pad_r: float = 20.0
	var pad_bottom: float = 16.0
	var y: float = vp.y - STAGE_EDIT_FOOTER_H - pad_bottom - btn_h
	var cancel_x: float = vp.x - pad_r - btn_w
	var save_x: float = cancel_x - gap - btn_w
	return [Rect2(save_x, y, btn_w, btn_h), Rect2(cancel_x, y, btn_w, btn_h)]


func _stage_edit_save_button_rect(vp: Vector2) -> Rect2:
	return _stage_edit_bottom_button_layout(vp)[0]


func _stage_edit_cancel_button_rect(vp: Vector2) -> Rect2:
	return _stage_edit_bottom_button_layout(vp)[1]


func _stage_edit_snapshot_state() -> Dictionary:
	var ed: Array = []
	for e in stage_edit_canvas_edges:
		ed.append((e as Dictionary).duplicate())
	return {"verts": stage_edit_canvas_vertices.duplicate(), "edges": ed}


func _stage_edit_restore_snapshot(snap: Dictionary) -> void:
	stage_edit_canvas_vertices.clear()
	for v in snap["verts"] as Array:
		if v is Vector2:
			stage_edit_canvas_vertices.append(v as Vector2)
	stage_edit_canvas_edges.clear()
	for e in snap["edges"] as Array:
		stage_edit_canvas_edges.append((e as Dictionary).duplicate())


func _stage_edit_push_undo() -> void:
	if not _stage_edit_shape_has_canvas():
		return
	stage_edit_undo_stack.append(_stage_edit_snapshot_state())
	if stage_edit_undo_stack.size() > STAGE_EDIT_UNDO_STACK_MAX:
		stage_edit_undo_stack.pop_front()
	stage_edit_redo_stack.clear()


func _stage_edit_apply_undo() -> void:
	if not _stage_edit_shape_has_canvas() or stage_edit_undo_stack.is_empty():
		return
	stage_edit_redo_stack.append(_stage_edit_snapshot_state())
	var snap: Dictionary = stage_edit_undo_stack.pop_back() as Dictionary
	_stage_edit_restore_snapshot(snap)
	stage_edit_canvas_hover_edge = -1
	stage_edit_canvas_drag_idx = -1
	stage_edit_canvas_right_drag_idx = -1
	_stage_edit_clear_left_drag_arc_state()


func _stage_edit_apply_redo() -> void:
	if not _stage_edit_shape_has_canvas() or stage_edit_redo_stack.is_empty():
		return
	stage_edit_undo_stack.append(_stage_edit_snapshot_state())
	var snap: Dictionary = stage_edit_redo_stack.pop_back() as Dictionary
	_stage_edit_restore_snapshot(snap)
	stage_edit_canvas_hover_edge = -1
	stage_edit_canvas_drag_idx = -1
	stage_edit_canvas_right_drag_idx = -1
	_stage_edit_clear_left_drag_arc_state()


## 順に ◀ ▶ ▲ ▼（キャンバス上端中央・右縦並び）。鏡像プレビューのトグル（データは変更しない）
func _stage_edit_mirror_button_rects(vp: Vector2) -> Array[Rect2]:
	var w: float = STAGE_EDIT_MIRROR_BTN_SZ
	var g: float = 6.0
	var cr: Rect2 = _stage_edit_canvas_rect(vp)
	var cx: float = cr.position.x + cr.size.x * 0.5
	var y_top: float = cr.position.y + 4.0
	var rx: float = cr.position.x + cr.size.x - w - 4.0
	var cy: float = cr.position.y + cr.size.y * 0.5
	var out: Array[Rect2] = []
	out.append(Rect2(cx - w - g * 0.5, y_top, w, w))
	out.append(Rect2(cx + g * 0.5, y_top, w, w))
	out.append(Rect2(rx, cy - w - g * 0.5, w, w))
	out.append(Rect2(rx, cy + g * 0.5, w, w))
	return out


func _stage_edit_toggle_mirror_preview(mi: int) -> void:
	if mi < 0 or mi > 3:
		return
	stage_edit_mirror_preview[mi] = not stage_edit_mirror_preview[mi]


func _stage_edit_save() -> void:
	var base: String = _sanitized_stage_edit_filename(stage_edit_stage_id)
	if base.is_empty():
		stage_edit_last_error = "Stage ID は小文字・数字・_ のみで指定してください"
		queue_redraw()
		return
	CustomStageFile.ensure_custom_stage_dir()
	var path: String = "%s/%s.json" % [CustomStageFile.CUSTOM_STAGE_DIR, base]
	var tidx: int = clampi(stage_edit_type_idx, 0, STAGE_EDIT_TYPE_OPTIONS.size() - 1)
	var shape_kind: String = STAGE_EDIT_TYPE_OPTIONS[tidx]
	var partial: Dictionary = {"type": base, "shape_type": shape_kind}
	if StageConfig.TYPE_DEFAULTS.has(shape_kind):
		var defs: Dictionary = StageConfig.TYPE_DEFAULTS[shape_kind] as Dictionary
		for k in defs:
			partial[k] = defs[k]
	var np: int
	if (shape_kind == "fish" or shape_kind == "cat_face") and stage_edit_canvas_edges.size() > 0:
		np = StageEditPolygonTools.compute_num_points_from_edges(stage_edit_canvas_edges)
	else:
		np = int((StageConfig.TYPE_DEFAULTS.get(shape_kind, {}) as Dictionary).get("num_points", 12))
	partial["num_points"] = np
	partial["min_radius"] = 200.0
	partial["max_radius"] = 400.0
	partial["display_rate_min_pct"] = 80.0
	partial["clear_pct"] = 99.0
	partial["guide_follows_player_radius"] = 0
	var shape: Dictionary = {}
	if shape_kind == "fish" or shape_kind == "cat_face":
		if stage_edit_canvas_vertices.size() >= 3:
			var pv: Array = []
			for v in stage_edit_canvas_vertices:
				pv.append([v.x, v.y])
			shape["polygon_vertices"] = pv
			var built: Dictionary = StageEditPolygonTools.build_arc_controls_for_save(stage_edit_canvas_edges)
			if not built.is_empty():
				var ac_out: Dictionary = {}
				for k in built:
					var pt: Vector2 = built[k] as Vector2
					ac_out[str(k)] = [pt.x, pt.y]
				shape["arc_controls"] = ac_out
	var meta: Dictionary = stage_edit_meta_preserve.duplicate(true)
	var payload: Dictionary = CustomStageFile.build_payload(partial, shape, meta)
	var err: String = CustomStageFile.save_to_path(path, payload)
	if err != "":
		stage_edit_last_error = err
		queue_redraw()
		return
	_exit_stage_edit_after_save(path)


func _input_stage_edit(event: InputEvent) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var crect: Rect2 = _stage_edit_canvas_rect(vp)
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.ctrl_pressed or event.meta_pressed) and (event.keycode == KEY_Z or event.keycode == KEY_Y):
			if _stage_edit_shape_has_canvas():
				if event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed):
					_stage_edit_apply_redo()
				elif event.keycode == KEY_Z:
					_stage_edit_apply_undo()
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion:
		if _stage_edit_shape_has_canvas():
			if stage_edit_canvas_drag_idx >= 0:
				stage_edit_canvas_vertices[stage_edit_canvas_drag_idx] = StageEditPolygonTools.get_left_drag_norm(
					stage_edit_canvas_vertices, stage_edit_canvas_edges, crect, stage_edit_canvas_drag_idx, event.position, stage_edit_canvas_drag_norm_offset
				)
				StageEditPolygonTools.apply_left_drag_arc_update(
					stage_edit_canvas_vertices, stage_edit_canvas_edges, crect,
					_se_ld_single_arc_edge, _se_ld_single_arc_angle, _se_ld_both_edges, _se_ld_both_angles, _se_ld_both_centers, _se_ld_both_last_centers
				)
				_stage_edit_snap_canvas_state_to_grid(crect)
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif stage_edit_canvas_right_drag_idx >= 0:
				stage_edit_canvas_right_drag_committed = stage_edit_canvas_right_drag_committed or (event.position.distance_to(stage_edit_canvas_right_down_pos) >= STAGE_EDIT_CANVAS_RIGHT_DRAG_THRESHOLD)
				if stage_edit_canvas_right_drag_committed:
					var nn: Vector2 = StageEditPolygonTools.screen_to_norm_exact(event.position, crect) + stage_edit_canvas_right_drag_norm_offset
					nn.x = clampf(nn.x, -1.35, 1.35)
					nn.y = clampf(nn.y, -1.35, 1.35)
					nn = _stage_edit_snap_norm_to_grid(nn, crect)
					stage_edit_canvas_vertices[stage_edit_canvas_right_drag_idx] = nn
					StageEditPolygonTools.fix_arc_chain_controls(stage_edit_canvas_vertices, stage_edit_canvas_edges, stage_edit_canvas_right_drag_idx)
					_stage_edit_snap_canvas_state_to_grid(crect)
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif crect.has_point(event.position):
				var ne: int = StageEditPolygonTools.find_nearest_edge_screen(
					stage_edit_canvas_vertices, stage_edit_canvas_edges, event.position, crect, STAGE_EDIT_CANVAS_EDGE_ADD_DISTANCE
				)
				if ne != stage_edit_canvas_hover_edge:
					stage_edit_canvas_hover_edge = ne
					queue_redraw()
			elif stage_edit_canvas_hover_edge >= 0:
				stage_edit_canvas_hover_edge = -1
				queue_redraw()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if stage_edit_canvas_drag_idx >= 0:
			stage_edit_canvas_vertices[stage_edit_canvas_drag_idx] = StageEditPolygonTools.get_left_drag_norm(
				stage_edit_canvas_vertices, stage_edit_canvas_edges, crect, stage_edit_canvas_drag_idx, event.position, stage_edit_canvas_drag_norm_offset
			)
			StageEditPolygonTools.apply_left_drag_arc_update(
				stage_edit_canvas_vertices, stage_edit_canvas_edges, crect,
				_se_ld_single_arc_edge, _se_ld_single_arc_angle, _se_ld_both_edges, _se_ld_both_angles, _se_ld_both_centers, _se_ld_both_last_centers
			)
			_stage_edit_snap_canvas_state_to_grid(crect)
			stage_edit_canvas_drag_idx = -1
			_stage_edit_clear_left_drag_arc_state()
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		if stage_edit_canvas_right_drag_idx >= 0:
			if not stage_edit_canvas_right_drag_committed:
				StageEditPolygonTools.delete_point(stage_edit_canvas_vertices, stage_edit_canvas_edges, stage_edit_canvas_right_drag_idx)
			stage_edit_canvas_right_drag_idx = -1
			stage_edit_canvas_right_drag_committed = false
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_exit_stage_edit_to_debug()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACKSPACE:
			if stage_edit_text_line == 0 and stage_edit_stage_id.length() > 0:
				stage_edit_stage_id = stage_edit_stage_id.left(stage_edit_stage_id.length() - 1)
			queue_redraw()
			return
		if event.keycode == KEY_V and (event.ctrl_pressed or event.meta_pressed):
			if stage_edit_text_line == 0:
				stage_edit_stage_id += _filter_stage_id_allowed_only(DisplayServer.clipboard_get())
				if stage_edit_stage_id.length() > 48:
					stage_edit_stage_id = stage_edit_stage_id.left(48)
			queue_redraw()
			return
		if event.unicode >= 32 and event.unicode != 127:
			var ch_str: String = String.chr(event.unicode)
			if stage_edit_text_line == 0:
				var ok: String = _filter_stage_id_allowed_only(ch_str)
				if ok.length() > 0:
					stage_edit_stage_id += ok
					if stage_edit_stage_id.length() > 48:
						stage_edit_stage_id = stage_edit_stage_id.left(48)
			queue_redraw()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var pos_r: Vector2 = event.position
		if _stage_edit_shape_has_canvas() and crect.has_point(pos_r):
			var vhr: int = _stage_edit_canvas_vertex_hit_at_screen(pos_r, crect)
			if vhr >= 0:
				_stage_edit_push_undo()
				stage_edit_canvas_right_drag_idx = vhr
				stage_edit_canvas_right_down_pos = pos_r
				stage_edit_canvas_right_drag_committed = false
				stage_edit_canvas_right_drag_norm_offset = stage_edit_canvas_vertices[vhr] - StageEditPolygonTools.screen_to_norm_exact(pos_r, crect)
				get_viewport().set_input_as_handled()
				queue_redraw()
				return
			var eir: int = StageEditPolygonTools.find_nearest_edge_screen(
				stage_edit_canvas_vertices, stage_edit_canvas_edges, pos_r, crect, STAGE_EDIT_CANVAS_EDGE_ADD_DISTANCE
			)
			if eir >= 0:
				_stage_edit_push_undo()
				StageEditPolygonTools.add_point_on_edge(stage_edit_canvas_vertices, stage_edit_canvas_edges, eir, pos_r, crect, true)
				get_viewport().set_input_as_handled()
				queue_redraw()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos: Vector2 = event.position
		var mrs: Array[Rect2] = _stage_edit_mirror_button_rects(vp)
		for mii in range(mrs.size()):
			if mrs[mii].has_point(pos):
				_stage_edit_toggle_mirror_preview(mii)
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
		if _stage_edit_shape_has_canvas() and crect.has_point(pos):
			var hi: int = _stage_edit_canvas_vertex_hit_at_screen(pos, crect)
			if hi >= 0:
				_stage_edit_push_undo()
				_stage_edit_begin_left_drag_vertex(hi, pos, crect)
				get_viewport().set_input_as_handled()
				queue_redraw()
				return
			var eil: int = StageEditPolygonTools.find_nearest_edge_screen(
				stage_edit_canvas_vertices, stage_edit_canvas_edges, pos, crect, STAGE_EDIT_CANVAS_EDGE_ADD_DISTANCE
			)
			if eil >= 0:
				_stage_edit_push_undo()
				StageEditPolygonTools.add_point_on_edge(stage_edit_canvas_vertices, stage_edit_canvas_edges, eil, pos, crect, false)
				get_viewport().set_input_as_handled()
				queue_redraw()
				return
		if _stage_edit_save_button_rect(vp).has_point(pos):
			_stage_edit_save()
			return
		if _stage_edit_cancel_button_rect(vp).has_point(pos):
			_exit_stage_edit_to_debug()
			return
		if _stage_edit_text_rect_filename(vp).has_point(pos):
			stage_edit_text_line = 0
			queue_redraw()
			return
		if _stage_edit_fish_shape_toggle_rect(vp).has_point(pos) and STAGE_EDIT_TYPE_OPTIONS[clampi(stage_edit_type_idx, 0, STAGE_EDIT_TYPE_OPTIONS.size() - 1)] == "fish":
			stage_edit_include_fish_shape = not stage_edit_include_fish_shape
			_init_stage_edit_canvas()
			_stage_edit_snap_current_canvas_to_grid()
			queue_redraw()
			return
		for ti in range(STAGE_EDIT_TYPE_OPTIONS.size()):
			if _stage_edit_type_chip_rect(vp, ti).has_point(pos):
				stage_edit_type_idx = ti
				_init_stage_edit_canvas()
				_stage_edit_snap_current_canvas_to_grid()
				queue_redraw()
				return


func _input_stage_debug(event: InputEvent) -> void:
	var vp: Vector2 = get_viewport_rect().size
	if _debug_tools_enabled() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _stage_debug_new_custom_button_rect(vp).has_point(event.position):
			_enter_stage_edit_screen()
			queue_redraw()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		stage_debug_field_focus_idx = -1
		_stage_debug_sync_ime_for_field_focus()
		game_state = "title"
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
	if _debug_tools_enabled() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var pos_r: Vector2 = event.position
		var split_r: float = _stage_debug_split_x(vp)
		var n_r: int = _stage_debug_total_rows()
		var y0_r: float = STAGE_DEBUG_LIST_TOP_Y - stage_debug_scroll
		var list_bottom_r: float = vp.y - STAGE_DEBUG_CONTENT_BOTTOM_MARGIN
		for i_r in range(n_r):
			var y1_r: float = y0_r + float(i_r) * STAGE_DEBUG_ROW_H
			if pos_r.y >= y1_r and pos_r.y < y1_r + STAGE_DEBUG_ROW_H and pos_r.y < list_bottom_r and pos_r.y >= STAGE_DEBUG_LIST_TOP_Y - 4.0:
				if pos_r.x >= 8.0 and pos_r.x < split_r - 8.0:
					if _stage_debug_is_custom_row(i_r):
						_enter_stage_edit_from_path(_stage_debug_custom_path_at(i_r))
						get_viewport().set_input_as_handled()
					queue_redraw()
				return
	if stage_debug_field_focus_idx >= 0 and event is InputEventKey and event.pressed:
		var fk_in: String = STAGE_DEBUG_FIELD_KEYS[stage_debug_field_focus_idx]
		var ime_comp: String = DisplayServer.ime_get_text()
		if event.keycode == KEY_TAB:
			if not event.echo:
				_commit_focused_field_to_pending()
				if stage_debug_last_error != "":
					queue_redraw()
					return
				_stage_debug_write_selected_row_to_disk(false)
				if stage_debug_last_error != "":
					queue_redraw()
					return
				_sync_stage_debug_field_buffers()
				var n_keys: int = STAGE_DEBUG_FIELD_KEYS.size()
				if event.shift_pressed:
					stage_debug_field_focus_idx = (stage_debug_field_focus_idx - 1 + n_keys) % n_keys
				else:
					stage_debug_field_focus_idx = (stage_debug_field_focus_idx + 1) % n_keys
				var fk_tab: String = STAGE_DEBUG_FIELD_KEYS[stage_debug_field_focus_idx]
				stage_debug_edit_buffer = str(stage_debug_field_buffers.get(fk_tab, ""))
				_stage_debug_sync_ime_for_field_focus()
				queue_redraw()
			return
		if event.keycode == KEY_ENTER:
			if ime_comp != "":
				queue_redraw()
				return
			if fk_in == "description":
				stage_debug_edit_buffer += "\n"
				queue_redraw()
				return
			if not event.echo:
				_commit_focused_field_to_pending()
				queue_redraw()
			return
		if event.keycode == KEY_BACKSPACE:
			if stage_debug_edit_buffer.length() > 0:
				stage_debug_edit_buffer = stage_debug_edit_buffer.left(stage_debug_edit_buffer.length() - 1)
			queue_redraw()
			return
		if event.keycode == KEY_V and (event.ctrl_pressed or event.meta_pressed):
			if not event.echo:
				var fk_paste: String = STAGE_DEBUG_FIELD_KEYS[stage_debug_field_focus_idx]
				if fk_paste == "stage_name" or fk_paste == "description":
					stage_debug_edit_buffer = _filter_stage_debug_paste_for_field(fk_paste, DisplayServer.clipboard_get())
					stage_debug_last_error = _apply_field_string_to_pending(fk_paste, stage_debug_edit_buffer)
					_sync_stage_debug_field_buffers()
				else:
					stage_debug_edit_buffer += _filter_stage_debug_paste_for_field(fk_paste, DisplayServer.clipboard_get())
				queue_redraw()
			return
		if fk_in == "stage_name" or fk_in == "description":
			if event.unicode != 0:
				var ch_u: String = String.chr(event.unicode)
				var ok_u: String = _filter_stage_debug_char_for_field(fk_in, ch_u)
				if ok_u.length() > 0:
					stage_debug_edit_buffer += ok_u
			queue_redraw()
			return
		if not event.echo and event.unicode >= 32 and event.unicode < 128:
			var ch_in: String = PackedByteArray([event.unicode]).get_string_from_utf8()
			var ok_in: String = _filter_stage_debug_char_for_field(fk_in, ch_in)
			if ok_in.length() > 0:
				stage_debug_edit_buffer += ok_in
			queue_redraw()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos: Vector2 = event.position
		var rects: Array[Rect2] = _stage_debug_button_rects(vp)
		for bi in range(rects.size()):
			if rects[bi].has_point(pos):
				match bi:
					0:
						_start_stage_debug_test()
					1:
						_stage_debug_save_selected()
					2:
						_stage_debug_open_shape_edit_for_selected()
					3:
						_stage_debug_reset_selected_row()
					4:
						_stage_debug_reset_all_files()
					5:
						stage_debug_field_focus_idx = -1
						_stage_debug_sync_ime_for_field_focus()
						game_state = "title"
				queue_redraw()
				return
		if _stage_debug_is_custom_row(stage_debug_selected):
			for sni in range(3):
				if _stage_debug_stage_name_action_button_rect(vp, sni).has_point(pos):
					match sni:
						0:
							_stage_debug_stage_name_copy_to_clipboard()
						1:
							_stage_debug_stage_name_clear()
						2:
							_stage_debug_paste_into_field("stage_name")
					queue_redraw()
					return
			for ai in range(3):
				if _stage_debug_description_action_button_rect(vp, ai).has_point(pos):
					match ai:
						0:
							_stage_debug_description_copy_to_clipboard()
						1:
							_stage_debug_description_clear()
						2:
							_stage_debug_paste_into_field("description")
					queue_redraw()
					return
		for fi in range(STAGE_DEBUG_FIELD_KEYS.size()):
			if _stage_debug_field_value_rect(vp, fi).has_point(pos):
				if fi == stage_debug_field_focus_idx:
					queue_redraw()
					return
				if stage_debug_field_focus_idx >= 0:
					_commit_focused_field_to_pending()
					if stage_debug_last_error != "":
						queue_redraw()
						return
					_stage_debug_write_selected_row_to_disk(false)
					if stage_debug_last_error != "":
						queue_redraw()
						return
					_sync_stage_debug_field_buffers()
				stage_debug_field_focus_idx = fi
				var fk: String = STAGE_DEBUG_FIELD_KEYS[fi]
				stage_debug_edit_buffer = str(stage_debug_field_buffers.get(fk, ""))
				_stage_debug_sync_ime_for_field_focus()
				queue_redraw()
				return
		var split: float = _stage_debug_split_x(vp)
		var n: int = _stage_debug_total_rows()
		var y0: float = STAGE_DEBUG_LIST_TOP_Y - stage_debug_scroll
		var list_bottom: float = vp.y - STAGE_DEBUG_CONTENT_BOTTOM_MARGIN
		for i in range(n):
			var y1: float = y0 + float(i) * STAGE_DEBUG_ROW_H
			if pos.y >= y1 and pos.y < y1 + STAGE_DEBUG_ROW_H and pos.y < list_bottom and pos.y >= STAGE_DEBUG_LIST_TOP_Y - 4.0:
				if pos.x >= 8.0 and pos.x < split - 8.0:
					if i != stage_debug_selected:
						_commit_focused_field_to_pending()
						if stage_debug_last_error != "":
							queue_redraw()
							return
						_stage_debug_write_selected_row_to_disk(false)
						if stage_debug_last_error != "":
							queue_redraw()
							return
					stage_debug_selected = i
					_sync_stage_debug_field_buffers()
					queue_redraw()
				return


func _start_stage_debug_test() -> void:
	_commit_focused_field_to_pending()
	var idx: int = stage_debug_selected
	if _stage_debug_is_custom_row(idx):
		var path: String = _stage_debug_custom_path_at(idx)
		var raw: Dictionary = _stage_debug_custom_raw_merged(path)
		if raw.is_empty():
			stage_debug_last_error = "カスタムファイルを読めません: %s" % path
			queue_redraw()
			return
		var cfg: Dictionary = CustomStageFile.effective_config_with_shape(raw)
		var err: String = StageDebugOverrides.validate_effective_config(cfg)
		if err != "":
			stage_debug_last_error = err
			queue_redraw()
			return
		stage_debug_last_error = ""
		debug_stage_test_seed = randi()
		seed(debug_stage_test_seed)
		debug_stage_test_meta_stage_name = ""
		if raw.has("meta") and typeof(raw["meta"]) == TYPE_DICTIONARY:
			debug_stage_test_meta_stage_name = str((raw["meta"] as Dictionary).get("stage_name", ""))
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
		return

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
	debug_stage_test_meta_stage_name = ""
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


## 現在選択行の pending をファイル／オーバーライドに書き出す（保存ボタンと同一ロジック）
func _stage_debug_write_selected_row_to_disk(show_success_message: bool = true) -> void:
	var idx: int = stage_debug_selected
	if _stage_debug_is_custom_row(idx):
		var path: String = _stage_debug_custom_path_at(idx)
		var raw: Dictionary = _stage_debug_custom_raw_merged(path)
		if raw.is_empty():
			stage_debug_last_error = "保存できません（ファイルを読めません）"
			return
		var err: String = CustomStageFile.save_to_path(path, raw)
		if err != "":
			stage_debug_last_error = err
		else:
			stage_debug_custom_pending.erase(path)
			if show_success_message:
				stage_debug_last_error = "保存しました: %s" % path
			else:
				stage_debug_last_error = ""
		return
	var p: Dictionary = stage_debug_pending.get(idx, {})
	var err2: String = StageDebugOverrides.save_stage_override(idx, p)
	if err2 != "":
		stage_debug_last_error = err2
	else:
		if show_success_message:
			stage_debug_last_error = "保存しました: %s" % StageDebugOverrides.path_for_index(idx)
		else:
			stage_debug_last_error = ""


func _stage_debug_save_selected() -> void:
	_commit_focused_field_to_pending()
	_stage_debug_write_selected_row_to_disk(true)
	queue_redraw()


func _stage_debug_open_shape_edit_for_selected() -> void:
	if not _debug_tools_enabled():
		return
	var idx: int = stage_debug_selected
	if not _stage_debug_is_custom_row(idx):
		stage_debug_last_error = "図形編集は [C] カスタム行を選択したときのみ使えます"
		queue_redraw()
		return
	var path: String = _stage_debug_custom_path_at(idx)
	_enter_stage_edit_from_path(path)


func _stage_debug_reset_selected_row() -> void:
	var idx: int = stage_debug_selected
	if _stage_debug_is_custom_row(idx):
		var path: String = _stage_debug_custom_path_at(idx)
		stage_debug_custom_pending.erase(path)
		_sync_stage_debug_field_buffers()
		stage_debug_last_error = "カスタムの未保存編集を破棄しました（ファイル本体は変更しません）"
		queue_redraw()
		return
	stage_debug_pending.erase(idx)
	StageDebugOverrides.delete_stage_override(idx)
	_sync_stage_debug_field_buffers()
	stage_debug_last_error = "ステージ %d をマスターに戻しました" % idx
	queue_redraw()


func _stage_debug_reset_all_files() -> void:
	stage_debug_pending.clear()
	stage_debug_custom_pending.clear()
	StageDebugOverrides.delete_all_overrides()
	_sync_stage_debug_field_buffers()
	stage_debug_last_error = "マスタのオーバーライドを削除し、カスタム行の未保存編集も破棄しました（user://custom_stages の JSON は削除していません）"
	queue_redraw()


func _stage_debug_list_row_label(row: int) -> String:
	if row < 0 or row >= _stage_debug_total_rows():
		return "?"
	if row < _stage_debug_master_count():
		var cfg: Dictionary = StageDebugOverrides.build_config_for_index(row, stage_debug_pending.get(row, {}))
		return str(cfg.get("type", "?"))
	var path: String = _stage_debug_custom_path_at(row)
	var fn: String = path.get_file().get_basename()
	var raw: Dictionary = _stage_debug_custom_raw_merged(path)
	if raw.is_empty():
		return "[C] %s" % fn
	var cfg_part: Dictionary = raw["config"] as Dictionary
	return "[C] %s" % str(cfg_part.get("type", fn))


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
	# ボタン押下アニメ待ちで _process_ui_menu_stick_navigation が return してもログが出るように先に実行
	if DEBUG_UI_STICK_NAV and game_state == "config":
		_debug_ui_stick_nav_poll_config(delta)
	_process_ui_menu_stick_navigation(delta)
	if pause_active:
		queue_redraw()
		return
	_process_pad(delta)
	# つかみ終了時に移動距離の累積リセット（次のつかみで基準を取り直す）
	if game_state == "playing":
		var cur_move_grab: bool = _is_move_grab_active_for_count()
		if _move_grab_was_active and not cur_move_grab:
			_move_count_track_valid = false
			_move_count_accum = 0.0
		_move_grab_was_active = cur_move_grab
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
