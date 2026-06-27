extends Node2D

# =============================================================================
# Stage Select Screen
# ・自キャラ: マウス追跡（lerp）＋ゲームパッドスティック移動
# ・接近したステージの目標図形を吹き出しで表示
# ・確認ポップアップ: 「このステージをプレイしますか？」[はい][いいえ]
# =============================================================================

const _GAME_SCENE := "res://scenes/game.tscn"

# --- 色 ---
const _BG_COLOR       := Color(1.0, 0.937, 0.89)
const _LINE_COLOR      := Color(0.80, 0.70, 0.67)
const _LOCKED_COLOR    := Color(0.72, 0.62, 0.60)
const _UNLOCKED_COLOR  := Color(0.95, 0.19, 0.32)
const _CLEARED_COLOR   := Color(0.95, 0.19, 0.32, 0.55)
const _HOVER_COLOR     := Color(1.0, 0.10, 0.20)
const _CHAR_COLOR      := Color(0.26, 0.21, 0.28)
const _BUBBLE_BG       := Color(1.0, 0.98, 0.96)
const _BUBBLE_BORDER   := Color(0.95, 0.19, 0.32)
const _POPUP_BG        := Color(1.0, 0.98, 0.96)
const _POPUP_BORDER    := Color(0.95, 0.19, 0.32)
const _BTN_YES_COLOR   := Color(0.95, 0.19, 0.32)
const _BTN_NO_COLOR    := Color(0.26, 0.21, 0.28)

# --- [DEBUG] ゾウステージ起動ドット ---
const _ZOU_DOT_POS := Vector2(40.0, 80.0)
const _ZOU_DOT_R   := 16.0

# --- [DEBUG] SE選択パネル ---
const _DBG_PANEL_X   := 310.0
const _DBG_PANEL_Y   := 12.0
const _DBG_COL_W     := 108.0
const _DBG_COL_GAP   := 16.0
const _DBG_HEADER_H  := 26.0
const _DBG_ITEM_H    := 22.0
const _DBG_PAD       := 10.0
const _DBG_BG        := Color(0.92, 0.97, 0.98, 0.93)
const _DBG_BD        := Color(0.45, 0.72, 0.80)
const _DBG_SEL       := Color(0.18, 0.55, 0.70)
const _DBG_TXT       := Color(0.25, 0.35, 0.40)

# --- サイズ ---
const _DOT_RADIUS      := 20.0
const _LINE_WIDTH      := 2.0
const _CHAR_RADIUS     := 14.0
const _PROX_DIST       := 140.0   # 吹き出し表示する距離（px）
const _BUBBLE_W        := 225.0   # バブル固定幅 (150 × 1.5)
const _BUBBLE_H        := 300.0   # バブル固定高さ (200 × 1.5)
const _BUBBLE_HDR_H    := 78.0    # ヘッダエリア高さ (52 × 1.5)
const _BUBBLE_FIG_H    := 117.0   # 図形エリア高さ (78 × 1.5)
const _BUBBLE_ROW_H    := 52.5    # BESTレコード各行高さ (35 × 1.5)
const _BUBBLE_STRIPE_W := 22.5    # 左縦ストライプ幅 (15 × 1.5)
const _BUBBLE_LABEL_W  := 67.5    # BEST行ラベルセル幅 (45 × 1.5)
const _BUBBLE_DARK     := Color(0.26, 0.21, 0.28)
const _BUBBLE_RED      := Color(0.95, 0.19, 0.32)
const _BUBBLE_VAL_BG   := Color(0.87, 0.85, 0.85)
const _POPUP_W         := 700.0
const _POPUP_H         := 250.0

# --- 自キャラ ---
const _CHAR_LERP       := 10.0    # マウス追跡の平滑化係数
const _PAD_SPEED       := 600.0   # ゲームパッド移動速度（px/sec）

# --- Camera2D スクロール ---
const SCROLL_MARGIN: float = 0.20  # ビューポート端からスクロール開始する割合
const SCROLL_SPEED: float  = 800.0 # スクロール速度（px/sec）

# --- ステージ解放フォーカス演出 ---
const FOCUS_DURATION: float = 0.8  # 1ステージあたりのフォーカス時間（秒）
const FOCUS_LERP: float     = 5.0  # カメラ追従の線形補間係数

# --- BGM 曲名表示 ---
const _BGM_TRACK_KEYS: Array[String] = [
	"BGM_01-05",
	"BGM_01-06",
	"BGM_01-08",
	"BGM_02-03",
	"BGM_02-09",
]
const _BGM_LABEL_FONT_SIZE := 20
const _BGM_LABEL_COLOR     := Color(0.5, 0.3, 0.3)
const _BGM_TYPEWRITER_SEC  := 1.0
const _BGM_HOLD_SEC        := 5.0
const _BGM_DISMISS_SEC     := 2.0

var _camera: Camera2D = null  # コードで生成する Camera2D

var _char_pos: Vector2 = Vector2(960, 540)
var _char_target: Vector2 = Vector2(960, 540)
var _char_moved_by_user: bool = false

# --- ステージ解放フォーカス演出 ---
var _focus_queue: Array = []      # フォーカス対象ステージID配列
var _is_focusing: bool = false    # フォーカス演出中フラグ
var _focus_elapsed: float = 0.0   # 現在フォーカス経過時間
var _focus_return_id: int = -1    # フォーカス演出終了後に戻るステージID

# --- アニメーション ---
var _elapsed: float = 0.0
var _anim_freq:  Array[float] = []
var _anim_phase: Array[float] = []
var _anim_amp:   Array[float] = []

# --- 状態 ---
var _nearest: int = -1        # 最近傍ステージ ID
var _popup_stage: int = -1    # 確認ポップアップ対象（-1 = 非表示）
var _popup_yes_hovered: bool = false
var _popup_no_hovered: bool = false

var _esc_popup: bool = false   # タイトル戻り確認ポップアップ
var _esc_popup_yes_hovered: bool = false
var _esc_popup_no_hovered: bool = false

var _font: Font
var _font_din: Font = null
var _font_din_logo: FontVariation = null  # STAGESELECTロゴ専用（spacing_glyph=-4、net -5px）
var _stage_cfgs: Array = []
var _dbg_preview: AudioStreamPlayer = null
var _sfx_hover: AudioStreamPlayer = null
var _sfx_click: AudioStreamPlayer = null
var _sfx_on: AudioStreamPlayer = null
var _zou_stage_idx: int = -1  # [DEBUG] zou.json の StageData インデックス（-1=未発見）

# --- BGM 曲名表示 ---
var _bgm_canvas: CanvasLayer = null
var _bgm_container: HBoxContainer = null
var _btn_prev: Button = null
var _btn_next: Button = null
var _bgm_label: Label = null
var _bgm_text: String = ""
var _bgm_tween: Tween = null


func _ready() -> void:
	var mplus: Font = load("res://assets/fonts/Mplus2-Medium.otf")
	if mplus != null:
		mplus.fallbacks = [ThemeDB.fallback_font]
		_font = mplus
	else:
		_font = ThemeDB.fallback_font
	var din_res: FontFile = load("res://assets/fonts/D-DIN-PRO-700-Bold.otf")
	if din_res != null:
		din_res.fallbacks = [_font]
		din_res.set_extra_spacing(0, TextServer.SPACING_GLYPH, -1)
		_font_din_logo = FontVariation.new()
		_font_din_logo.base_font = din_res
		_font_din_logo.set_spacing(TextServer.SPACING_GLYPH, -4)  # base(-1) + (-4) = net -5px
	_font_din = din_res if din_res != null else _font
	_stage_cfgs = StageData.get_stages()

	# Camera2D をコードで生成してワールド座標追従を有効化
	_camera = Camera2D.new()
	_camera.zoom = Vector2(1.0, 1.0)
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera.make_current()

	# アバター初期位置: 最後にプレイしたステージがあればそこへ、なければステージ0
	var _focus_id: int = StageSelectManager.last_played_stage_id
	if _focus_id < 0 or _focus_id >= StageSelectManager.STAGE_COUNT:
		_focus_id = 0
	var _start: Vector2 = StageSelectManager.get_world_pos(_focus_id)
	_char_pos = _start
	_char_target = _start
	_camera.position = _start

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(StageSelectManager.STAGE_COUNT):
		_anim_freq.append(rng.randf_range(0.5, 1.2))
		_anim_phase.append(rng.randf_range(0.0, TAU))
		_anim_amp.append(rng.randf_range(4.0, 9.0))
	if _is_debug():
		DebugSFXConfig.ensure_counted()
		_dbg_preview = AudioStreamPlayer.new()
		add_child(_dbg_preview)
		_zou_stage_idx = _find_zou_stage_idx()
	_bgm_canvas = $BgmUI
	_setup_bgm_ui()
	_sfx_hover = AudioStreamPlayer.new()
	_sfx_hover.stream = load("res://assets/sounds/pinon.wav")
	_sfx_hover.volume_db = -10.0
	add_child(_sfx_hover)
	_sfx_click = AudioStreamPlayer.new()
	_sfx_click.stream = load("res://assets/sounds/se_click.wav")
	_sfx_click.volume_db = -14.5
	add_child(_sfx_click)
	_sfx_on = AudioStreamPlayer.new()
	_sfx_on.stream = load("res://assets/sounds/se_on.wav")
	_sfx_on.volume_db = -14.5
	add_child(_sfx_on)
	_start_bgm_label_anim.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta

	# フォーカス演出中は通常の入力・描画更新をスキップ
	if _is_focusing:
		_process_focus(delta)
		queue_redraw()
		return

	# ゲームパッドスティック
	var sx: float = Input.get_axis("ui_left", "ui_right")
	var sy: float = Input.get_axis("ui_up", "ui_down")
	var pad_active: bool = absf(sx) > 0.1 or absf(sy) > 0.1
	if pad_active:
		_char_pos += Vector2(sx, sy).normalized() * _PAD_SPEED * delta
		# クランプをワールド座標範囲に変更
		var bounds: Rect2 = _calc_world_bounds()
		_char_pos = _char_pos.clamp(bounds.position, bounds.position + bounds.size)
		_char_target = _char_pos
		_char_moved_by_user = true
	else:
		# マウス追跡
		var new_pos: Vector2 = _char_pos.lerp(_char_target, _CHAR_LERP * delta)
		if new_pos.distance_to(_char_pos) > 0.5:
			_char_moved_by_user = true
		_char_pos = new_pos

	# 最近傍ステージ更新（ユーザー操作で動いたとき・ポップアップ非表示時のみ）
	if _char_moved_by_user and _popup_stage < 0 and not _esc_popup:
		_char_moved_by_user = false
		var prev_nearest: int = _nearest
		_nearest = _find_nearest_accessible()
		if _nearest >= 0 and _nearest != prev_nearest:
			_sfx_hover.play()

	# BGM ボタンはポップアップ表示中に無効化
	if _btn_prev:
		var popup_open := _popup_stage >= 0 or _esc_popup
		_btn_prev.disabled = popup_open
		_btn_next.disabled = popup_open

	_update_camera(delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	# マウス位置 → 自キャラターゲット更新
	if event is InputEventMouseMotion:
		_char_target = get_canvas_transform().affine_inverse() * event.position
		_char_moved_by_user = true
		if _esc_popup:
			_update_esc_popup_hover(event.position)
		elif _popup_stage >= 0:
			_update_popup_hover(event.position)

	# [DEBUG] デバッグクリック処理（他のUIより先に処理）
	if _is_debug() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _handle_dbg_sfx_click(event.position):
			return
		if _zou_stage_idx >= 0 and event.position.distance_to(_ZOU_DOT_POS) <= _ZOU_DOT_R:
			StageSelectManager.pending_stage_id = _zou_stage_idx
			TransitionManager.play_triangle(func(): get_tree().change_scene_to_file(_GAME_SCENE))
			return

	# タイトル戻り確認ポップアップ
	if _esc_popup:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_esc_popup_click(event.position)
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_esc_popup = false
				queue_redraw()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_handle_esc_popup_confirm(_esc_popup_yes_hovered)
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_B:
				_esc_popup = false
				queue_redraw()
			elif event.button_index == JOY_BUTTON_A:
				_handle_esc_popup_confirm(_esc_popup_yes_hovered)
		return

	# ステージ選択確認ポップアップ
	if _popup_stage >= 0:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_popup_click(event.position)
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_popup_stage = -1
				_nearest = _find_nearest_accessible()
				queue_redraw()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				if _popup_yes_hovered or _popup_no_hovered:
					_handle_popup_confirm(_popup_yes_hovered)
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_B:
				_popup_stage = -1
				_nearest = _find_nearest_accessible()
				queue_redraw()
			elif event.button_index == JOY_BUTTON_A:
				_handle_popup_confirm(_popup_yes_hovered)
		return

	# 決定: マウス左クリック or ゲームパッドA or Enter
	var is_confirm: bool = (
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)
		or (event is InputEventKey and event.pressed and not event.echo
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER))
	)
	if is_confirm and _nearest >= 0:
		_popup_stage = _nearest
		_popup_yes_hovered = true
		_popup_no_hovered = false
		_sfx_click.play()
		queue_redraw()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_esc_popup = true
		_esc_popup_yes_hovered = false
		_esc_popup_no_hovered = false
		_sfx_click.play()
		queue_redraw()

	# L/R ボタンでBGM切り替え（ポップアップ非表示中のみ）
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			BGMManager.select_prev_bgm()
			_start_bgm_label_anim()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			BGMManager.select_next_bgm()
			_start_bgm_label_anim()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size

	# ─── 画面固定レイヤー ───
	# get_canvas_transform() は world→screen。逆変換を draw_set_transform_matrix に
	# 与えることで「draw座標 = screen座標」になる。
	var screen_xform := get_canvas_transform().affine_inverse()
	draw_set_transform_matrix(screen_xform)

	draw_rect(Rect2(Vector2.ZERO, vp), _BG_COLOR)

	# STAGE / SELECT ロゴ（画面固定）
	if _font_din_logo:
		var logo_fs: int = 400
		var logo_x: float = -20.0
		var logo_asc: float = _font_din_logo.get_ascent(logo_fs)
		var logo_dsc: float = _font_din_logo.get_descent(logo_fs)
		var stage_y: float  = logo_asc - 170.0
		var select_y: float = stage_y + logo_dsc + 10.0 + logo_asc - 300.0
		var logo_col := Color(0.26, 0.21, 0.28, 0.2)
		draw_string(_font_din_logo, Vector2(logo_x, stage_y),  "STAGE",  HORIZONTAL_ALIGNMENT_LEFT, -1, logo_fs, logo_col)
		draw_string(_font_din_logo, Vector2(logo_x, select_y), "SELECT", HORIZONTAL_ALIGNMENT_LEFT, -1, logo_fs, logo_col)

	# ─── ワールド座標レイヤー ───
	# Identity = ノードのローカル（=ワールド）座標。Camera2D が自動でスクリーンに変換する。
	draw_set_transform_matrix(Transform2D())

	# 接続ライン
	for conn in StageSelectManager.get_connections():
		var a: int = conn[0]
		var b: int = conn[1]
		if StageSelectManager.get_state(a) == StageSelectManager.StageState.LOCKED:
			continue
		if StageSelectManager.get_state(b) == StageSelectManager.StageState.LOCKED:
			continue
		draw_line(_dot_pos(a), _dot_pos(b), _LINE_COLOR, _LINE_WIDTH)

	# ステージドット
	for i in range(StageSelectManager.STAGE_COUNT):
		var state: int = StageSelectManager.get_state(i)
		var pos: Vector2 = _dot_pos(i)
		var is_near: bool = (i == _nearest and _popup_stage < 0 and not _esc_popup)
		match state:
			StageSelectManager.StageState.LOCKED:
				draw_circle(pos, _DOT_RADIUS, _LOCKED_COLOR)
			StageSelectManager.StageState.UNLOCKED:
				draw_circle(pos, _DOT_RADIUS, _HOVER_COLOR if is_near else _UNLOCKED_COLOR)
			StageSelectManager.StageState.CLEARED:
				draw_circle(pos, _DOT_RADIUS, _HOVER_COLOR if is_near else _CLEARED_COLOR)
				draw_circle(pos, _DOT_RADIUS * 0.35, Color.WHITE)

	# 自キャラ（ワールド座標・最前面）
	draw_circle(_char_pos, _CHAR_RADIUS, _CHAR_COLOR)
	draw_circle(_char_pos, _CHAR_RADIUS * 0.55, _BG_COLOR)

	# ─── 再び画面固定レイヤーへ戻してUI要素を描画 ───
	draw_set_transform_matrix(get_canvas_transform().affine_inverse())

	# 吹き出し（スクリーン座標で描画。dot位置はcanvas_transformで変換済み）
	if _nearest >= 0 and _popup_stage < 0 and not _esc_popup:
		_draw_bubble(_nearest)

	# ラベル
	draw_string(_font, Vector2(40, vp.y - 32), "ESC: タイトルへ戻る", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.5, 0.3, 0.3))

	# 確認ポップアップ
	if _popup_stage >= 0:
		_draw_popup(vp)

	# タイトル戻り確認ポップアップ
	if _esc_popup:
		_draw_esc_popup(vp)

	# [DEBUG] ゾウステージ起動ドット（画面固定）
	if _is_debug() and _zou_stage_idx >= 0:
		draw_circle(_ZOU_DOT_POS, _ZOU_DOT_R, Color(0.15, 0.10, 0.20))

	# [DEBUG] SE選択パネル（画面固定）
	if _is_debug() and (DebugSFXConfig.in_count > 0 or DebugSFXConfig.out_count > 0):
		_draw_dbg_sfx_panel()


# ---------- 吹き出し ----------

func _draw_bubble(stage_id: int, fixed_bx: float = NAN, fixed_by: float = NAN) -> void:
	# _draw_bubble はスクリーン座標セクションで呼ばれる。ワールド座標を画面座標へ変換する。
	var dot: Vector2 = get_canvas_transform() * _dot_pos(stage_id)
	var bw: float = _BUBBLE_W
	var bh: float = _BUBBLE_H
	var vp: Vector2 = get_viewport_rect().size
	var bx: float
	var by: float
	var draw_tail: bool
	if is_nan(fixed_bx):
		bx = dot.x + _DOT_RADIUS + 12.0
		by = dot.y - bh - _DOT_RADIUS
		bx = clampf(bx, 6.0, vp.x - bw - 6.0)
		by = clampf(by, 6.0, vp.y - bh - 6.0)
		draw_tail = true
	else:
		bx = fixed_bx
		by = fixed_by
		draw_tail = false

	var bd: float    = 4.5
	var str_w: float = _BUBBLE_STRIPE_W   # 縦ストライプ幅 = 15px
	var ix: float    = bx + bd
	var iy: float    = by + bd
	var iw: float    = bw - bd * 2.0      # 144px
	var ih: float    = bh - bd * 2.0      # 194px

	# ─── ドロップシャドウ ───
	draw_rect(Rect2(bx + 12.5, by + 12.5, bw, bh), Color(0.26, 0.21, 0.28, 0.30))

	# ─── 外枠 ───
	draw_rect(Rect2(bx, by, bw, bh), _BUBBLE_DARK)

	# ─── 右コンテンツ背景（白・全高） ───
	var cx: float = ix + str_w    # bx + 18
	var cw: float = iw - str_w    # 129px
	draw_rect(Rect2(cx, iy, cw, ih), _BUBBLE_BG)

	# ─── 左縦ストライプ（全高）: 上部赤 + 下部ダーク ───
	var red_h: float = ih * 0.38 - 20.0   # 下部を20pxカット
	draw_rect(Rect2(ix, iy,         str_w, red_h),      _BUBBLE_RED)
	draw_rect(Rect2(ix, iy + red_h, str_w, ih - red_h), _BUBBLE_DARK)

	# ─── ストライプ内 平行四辺形（ダーク部・間隔を1/3に縮小して中央揃え） ───
	var para_zone_top: float = iy + red_h
	var para_zone_bot: float = iy + _BUBBLE_HDR_H + _BUBBLE_FIG_H
	var para_count: int = 5
	var para_full_step: float = (para_zone_bot - para_zone_top) / 4.0   # 元の3個分の間隔基準を維持
	var para_step: float = para_full_step / 3.0 * 2.0   # 間隔は既存と同じ
	var para_h: float    = para_full_step * 0.50        # 高さは元のままを維持
	var para_skew: float = str_w * 0.55
	var cluster_h: float = para_step * float(para_count - 1) + para_skew + para_h
	var cluster_y: float = (para_zone_top + para_zone_bot) * 0.5 - cluster_h * 0.5 + 90.0   # 90px下に移動
	for pi in range(para_count):
		var py: float = cluster_y + float(pi) * para_step
		draw_colored_polygon(PackedVector2Array([
			Vector2(ix + str_w, py),
			Vector2(ix,         py + para_skew),
			Vector2(ix,         py + para_skew + para_h),
			Vector2(ix + str_w, py + para_h),
		]), _BUBBLE_RED)

	# ─── プレイ済み（クリア済み）判定 ───
	var has_rec: bool = StageSelectManager.get_best_time(stage_id) >= 0.0

	# ─── ヘッダ: #N ───
	var num_fs: int = 39
	draw_string(_font_din, Vector2(cx + 7.5, iy - 6.0 + _font_din.get_ascent(num_fs)),
		"#%d" % (stage_id + 1), HORIZONTAL_ALIGNMENT_LEFT, cw - 12.0, num_fs, _BUBBLE_DARK)

	# ─── ヘッダ: ステージ名（未プレイは ???） ───
	var name_str: String = StageSelectManager.get_stage_name(stage_id) if has_rec else "???"
	if not name_str.is_empty():
		var name_fs: int = 20
		draw_string(_font, Vector2(cx + 7.5, iy + 47.5 + _font.get_ascent(name_fs)),
			name_str, HORIZONTAL_ALIGNMENT_LEFT, cw - 12.0, name_fs, _BUBBLE_DARK)

	# ─── 図形エリア（未プレイは大きな ? をグレーで表示） ───
	var hdr_fig_h: float = _BUBBLE_HDR_H + _BUBBLE_FIG_H
	var fig_cx: float = cx + cw * 0.5
	var fig_cy: float = iy + _BUBBLE_HDR_H + _BUBBLE_FIG_H * 0.5
	if has_rec:
		var shape_r: float = 52.5 if stage_id >= 4 else 42.0
		_draw_mini_shape(stage_id, Vector2(fig_cx, fig_cy), shape_r)
	else:
		var q_fs: int = 66
		var q_c: Color = Color(0.72, 0.68, 0.66)
		var q_asc: float = _font_din.get_ascent(q_fs)
		var q_dsc: float = _font_din.get_descent(q_fs)
		draw_string(_font_din, Vector2(cx, fig_cy + (q_asc - q_dsc) * 0.5), "?",
			HORIZONTAL_ALIGNMENT_CENTER, cw, q_fs, q_c)

	# ─── BEST 枠 2 本 ───
	var box_pad: float  = 7.5
	var box_gap: float  = 4.5
	var rows_top: float = iy + hdr_fig_h
	var rows_bot: float = iy + ih - box_pad
	var row_h: float    = (rows_bot - rows_top - box_gap) * 0.5
	var box_x: float    = ix + box_pad + 20.0
	var box_w: float    = iw - box_pad * 2.0 - 20.0
	var label_w: float  = _BUBBLE_LABEL_W   # 67.5px

	var bt_str: String = "%.2f" % StageSelectManager.get_best_time(stage_id) if has_rec else "---"
	var bm_str: String = "%d"   % StageSelectManager.get_best_move_count(stage_id) if has_rec else "---"

	_draw_bubble_best_row(box_x, rows_top,                   box_w, row_h, label_w, "BEST", "CLEAR", "TIME",  bt_str)
	_draw_bubble_best_row(box_x, rows_top + row_h + box_gap, box_w, row_h, label_w, "BEST", "TRY",   "COUNT", bm_str)

	# ─── しっぽ ───
	if draw_tail:
		var tail_tip: Vector2 = dot + Vector2(-_DOT_RADIUS * 0.5, -_DOT_RADIUS * 0.5)
		var tail_base_x: float = clampf(tail_tip.x, bx + 12.0, bx + bw - 12.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tail_base_x - 9.0, by + bh),
			Vector2(tail_base_x + 9.0, by + bh),
			tail_tip,
		]), _BUBBLE_DARK)

	# ─── 四隅サークル（ボタン・リザルトと同じデザイン言語） ───
	var corner_r: float = bd * 1.25   # ≈ 5.6px
	draw_circle(Vector2(bx + 1.0,      by + 1.0),      corner_r, _BUBBLE_DARK)
	draw_circle(Vector2(bx + bw - 1.0, by + 1.0),      corner_r, _BUBBLE_DARK)
	draw_circle(Vector2(bx + 1.0,      by + bh - 1.0), corner_r, _BUBBLE_DARK)
	draw_circle(Vector2(bx + bw - 1.0, by + bh - 1.0), corner_r, _BUBBLE_DARK)


func _draw_bubble_best_row(bx: float, by: float, bw: float, bh: float, lw: float,
		l1: String, l2: String, l3: String, value_str: String) -> void:
	# ラベルセル（ダーク）
	draw_rect(Rect2(bx, by, lw, bh), _BUBBLE_DARK)
	# ラベルテキスト（白・行間を半分に詰める）
	var lfs: int = 12
	var lasc: float = _font.get_ascent(lfs)
	var ldsc: float = _font.get_descent(lfs)
	var lh: float   = (lasc + ldsc + 1.0) * 0.5 + 3.0   # 行間 +3px (2 × 1.5)
	var block_h: float = lh * 2.0 + lasc + ldsc
	var ty: float = by + (bh - block_h) * 0.5 + lasc
	var tx: float = bx + 4.5
	var tw: float = lw - 6.0
	draw_string(_font, Vector2(tx, ty),            l1, HORIZONTAL_ALIGNMENT_LEFT, tw, lfs, _BUBBLE_BG)
	draw_string(_font, Vector2(tx, ty + lh),       l2, HORIZONTAL_ALIGNMENT_LEFT, tw, lfs, _BUBBLE_BG)
	draw_string(_font, Vector2(tx, ty + lh * 2.0), l3, HORIZONTAL_ALIGNMENT_LEFT, tw, lfs, _BUBBLE_BG)
	# 値テキスト（DIN Bold・右寄せ・グレー背景）
	var vx: float  = bx + lw
	var vw: float  = bw - lw
	var vfs: int   = 34
	var vasc: float = _font_din.get_ascent(vfs)
	var vdsc: float = _font_din.get_descent(vfs)
	draw_rect(Rect2(vx, by, vw, bh), _BUBBLE_VAL_BG)
	draw_string(_font_din, Vector2(vx, by + (bh + vasc - vdsc) * 0.5),
		value_str, HORIZONTAL_ALIGNMENT_RIGHT, vw - 7.5, vfs, _BUBBLE_DARK)


func _draw_mini_shape(stage_id: int, center: Vector2, r: float) -> void:
	var cfg: Dictionary = {}
	if stage_id < _stage_cfgs.size():
		cfg = _stage_cfgs[stage_id] as Dictionary
	var stype: String = str(cfg.get("shape_type", cfg.get("type", "circle")))
	var fill_c := Color(_BUBBLE_RED.r, _BUBBLE_RED.g, _BUBBLE_RED.b, 0.22)
	var line_c := _BUBBLE_DARK
	var pts := PackedVector2Array()

	# カスタム形状: shape_polygon_vertices が存在する場合はそちらを優先
	if cfg.has("shape_polygon_vertices"):
		var raw: Array = cfg["shape_polygon_vertices"] as Array
		if not raw.is_empty():
			var raw_pts := PackedVector2Array()
			var max_dist: float = 0.01
			for v in raw:
				var arr: Array = v as Array
				var p := Vector2(float(arr[0]), float(arr[1]))
				raw_pts.append(p)
				max_dist = maxf(max_dist, p.length())
			var sc: float = r / max_dist
			for p in raw_pts:
				pts.append(center + p * sc)
	else:
		match stype:
			"triangle":
				for i in range(3):
					var a: float = -PI * 0.5 + float(i) * TAU / 3.0
					pts.append(center + Vector2(cos(a), sin(a)) * r)
			"square":
				var h: float = r * 0.707
				pts = PackedVector2Array([
					center + Vector2(-h, -h), center + Vector2(h, -h),
					center + Vector2(h,  h),  center + Vector2(-h, h),
				])
			"rhombus":
				pts = PackedVector2Array([
					center + Vector2(0, -r),        center + Vector2(r * 0.72, 0),
					center + Vector2(0,  r),        center + Vector2(-r * 0.72, 0),
				])
			"hexagon":
				for i in range(6):
					var a: float = float(i) * TAU / 6.0 - PI / 6.0
					pts.append(center + Vector2(cos(a), sin(a)) * r)
			_:  # circle やその他
				draw_circle(center, r, fill_c)
				var cp := PackedVector2Array()
				for i in range(32):
					cp.append(center + Vector2(cos(float(i) * TAU / 32.0), sin(float(i) * TAU / 32.0)) * r)
				draw_polyline(cp + PackedVector2Array([cp[0]]), line_c, 2.25)
				return

	if pts.size() < 3:
		return
	draw_colored_polygon(pts, fill_c)
	draw_polyline(pts + PackedVector2Array([pts[0]]), line_c, 2.25)
	for p in pts:
		draw_circle(p, 3.0, line_c)


# ---------- ポップアップ ----------

func _popup_rects(vp: Vector2) -> Dictionary:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5
	var popup_rect := Rect2(cx - _POPUP_W * 0.5, cy - _POPUP_H * 0.5, _POPUP_W, _POPUP_H)
	var btn_w: float  = 220.0
	var btn_h: float  = 64.0
	var cbtn_gap: float = btn_w * 0.5 + 30.0   # = 140
	var btn_cy: float = cy + 40.0
	var yes_rect := Rect2(cx - cbtn_gap - btn_w * 0.5, btn_cy - btn_h * 0.5, btn_w, btn_h)
	var no_rect  := Rect2(cx + cbtn_gap - btn_w * 0.5, btn_cy - btn_h * 0.5, btn_w, btn_h)
	return { "popup": popup_rect, "yes": yes_rect, "no": no_rect }


func _stage_popup_rects(vp: Vector2) -> Dictionary:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5
	var pw: float = _POPUP_W
	var ph: float = _POPUP_H
	# バブル(300) + ギャップ(20) + ダイアログ(280) = 600px を縦中央配置
	var bubble_gap: float = 20.0
	var popup_top: float = cy + (_BUBBLE_H + bubble_gap - ph) * 0.5
	var popup_rect := Rect2(cx - pw * 0.5, popup_top, pw, ph)
	var btn_w: float  = 220.0
	var btn_h: float  = 64.0
	var cbtn_gap: float = btn_w * 0.5 + 30.0
	var btn_cy: float = popup_top + ph * 0.5 + 40.0
	var yes_rect := Rect2(cx - cbtn_gap - btn_w * 0.5, btn_cy - btn_h * 0.5, btn_w, btn_h)
	var no_rect  := Rect2(cx + cbtn_gap - btn_w * 0.5, btn_cy - btn_h * 0.5, btn_w, btn_h)
	return { "popup": popup_rect, "yes": yes_rect, "no": no_rect }


func _draw_popup(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.26, 0.21, 0.28, 0.50))
	var r: Dictionary = _stage_popup_rects(vp)
	var pr: Rect2 = r["popup"]
	var yr: Rect2 = r["yes"]
	var nr: Rect2 = r["no"]

	# バブルをダイアログ上辺から20px上に離して水平中央配置（ダイアログより先に描画）
	var bubble_bx: float = pr.position.x + (pr.size.x - _BUBBLE_W) * 0.5
	var bubble_by: float = pr.position.y - _BUBBLE_H - 20.0
	_draw_bubble(_popup_stage, bubble_bx, bubble_by)

	draw_rect(Rect2(pr.position + Vector2(15.0, 15.0), pr.size), Color(0.26, 0.21, 0.28, 0.25))
	draw_rect(pr, Color(1.0, 1.0, 1.0))
	_draw_rect_border_with_corners_local(pr, Color(0.26, 0.21, 0.28), 5.75)

	# 問いかけ文（ESCダイアログと同一レイアウト）
	var q_fs: int = 42
	var dialog_cy: float = pr.position.y + pr.size.y * 0.5
	draw_string(_font_din, Vector2(pr.position.x, dialog_cy - 45.0), "このステージをプレイしますか？",
		HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, q_fs, Color(0.95, 0.19, 0.32))

	_draw_popup_btn(yr, "はい",   _popup_yes_hovered)
	_draw_popup_btn(nr, "いいえ", _popup_no_hovered)


func _update_popup_hover(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _stage_popup_rects(vp)
	var new_yes: bool = (r["yes"] as Rect2).has_point(pos)
	var new_no: bool  = (r["no"]  as Rect2).has_point(pos)
	if (new_yes and not _popup_yes_hovered) or (new_no and not _popup_no_hovered):
		_sfx_on.play()
	_popup_yes_hovered = new_yes
	_popup_no_hovered  = new_no


func _handle_popup_click(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _stage_popup_rects(vp)
	if (r["yes"] as Rect2).has_point(pos):
		_handle_popup_confirm(true)
	elif (r["no"] as Rect2).has_point(pos):
		_handle_popup_confirm(false)
	elif not (r["popup"] as Rect2).has_point(pos):
		# パネル外クリックで閉じる
		_popup_stage = -1
		_nearest = _find_nearest_accessible()
		queue_redraw()


func _handle_popup_confirm(yes: bool) -> void:
	_sfx_click.play()
	if yes:
		StageSelectManager.pending_stage_id = _popup_stage
		TransitionManager.play_triangle(func(): get_tree().change_scene_to_file(_GAME_SCENE))
	else:
		_popup_stage = -1
		_nearest = _find_nearest_accessible()
		queue_redraw()


# ---------- ヘルパー ----------

func _dot_pos(i: int) -> Vector2:
	var base: Vector2 = StageSelectManager.get_world_pos(i)
	var oy: float = sin(_elapsed * _anim_freq[i] + _anim_phase[i]) * _anim_amp[i]
	return base + Vector2(0.0, oy)


func _calc_world_bounds() -> Rect2:
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	for i in range(StageSelectManager.STAGE_COUNT):
		var pos: Vector2 = StageSelectManager.get_world_pos(i)
		min_x = minf(min_x, pos.x)
		min_y = minf(min_y, pos.y)
		max_x = maxf(max_x, pos.x)
		max_y = maxf(max_y, pos.y)
	var margin: float = 200.0
	return Rect2(min_x - margin, min_y - margin,
				 max_x - min_x + margin * 2.0,
				 max_y - min_y + margin * 2.0)


func _update_camera(delta: float) -> void:
	if _camera == null or _is_focusing:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_view: Vector2 = viewport_size / 2.0 / _camera.zoom
	var margin: Vector2 = half_view * 2.0 * SCROLL_MARGIN
	var rel: Vector2 = _char_pos - _camera.position
	var scroll: Vector2 = Vector2.ZERO
	if rel.x < -half_view.x + margin.x:
		scroll.x = -1.0
	elif rel.x > half_view.x - margin.x:
		scroll.x = 1.0
	if rel.y < -half_view.y + margin.y:
		scroll.y = -1.0
	elif rel.y > half_view.y - margin.y:
		scroll.y = 1.0
	if scroll != Vector2.ZERO:
		_camera.position += scroll.normalized() * SCROLL_SPEED * delta


func start_unlock_focus(unlocked_ids: Array, return_stage_id: int = -1) -> void:
	_focus_return_id = return_stage_id
	if unlocked_ids.is_empty():
		if return_stage_id >= 0:
			_camera.position = StageSelectManager.get_world_pos(return_stage_id)
			_char_pos = _camera.position
			_char_target = _camera.position
		return
	# 時計回りにソート（直前ステージを中心とした角度順）
	var center: Vector2 = Vector2.ZERO
	if return_stage_id >= 0:
		center = StageSelectManager.get_world_pos(return_stage_id)
	var sorted_ids: Array = unlocked_ids.duplicate()
	sorted_ids.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector2 = StageSelectManager.get_world_pos(a) - center
		var pb: Vector2 = StageSelectManager.get_world_pos(b) - center
		return -pa.angle() < -pb.angle()
	)
	_focus_queue = sorted_ids
	_is_focusing = true
	_focus_elapsed = 0.0


func _process_focus(delta: float) -> void:
	if not _is_focusing or _focus_queue.is_empty():
		_is_focusing = false
		# 全ノードを巡り終えたら直前ステージへ戻る
		if _focus_return_id >= 0:
			var return_pos: Vector2 = StageSelectManager.get_world_pos(_focus_return_id)
			_camera.position = return_pos
			_char_pos = return_pos
			_char_target = return_pos
			_focus_return_id = -1
		return
	_focus_elapsed += delta
	var target_pos: Vector2 = StageSelectManager.get_world_pos(_focus_queue[0])
	_camera.position = _camera.position.lerp(target_pos, FOCUS_LERP * delta)
	if _focus_elapsed >= FOCUS_DURATION or _camera.position.distance_to(target_pos) < 5.0:
		_focus_queue.pop_front()
		_focus_elapsed = 0.0
		if _focus_queue.is_empty():
			_is_focusing = false


func _find_nearest_accessible() -> int:
	var best: int = -1
	var best_d: float = _PROX_DIST
	for i in range(StageSelectManager.STAGE_COUNT):
		var state: int = StageSelectManager.get_state(i)
		if state == StageSelectManager.StageState.LOCKED:
			continue
		var d: float = _char_pos.distance_to(_dot_pos(i))
		if d < best_d:
			best_d = d
			best = i
	return best


# ---------- タイトル戻りポップアップ ----------

func _draw_esc_popup(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.26, 0.21, 0.28, 0.50))
	var r: Dictionary = _popup_rects(vp)
	var pr: Rect2 = r["popup"]
	var yr: Rect2 = r["yes"]
	var nr: Rect2 = r["no"]
	var cy: float  = pr.position.y + pr.size.y * 0.5

	draw_rect(Rect2(pr.position + Vector2(15.0, 15.0), pr.size), Color(0.26, 0.21, 0.28, 0.25))
	draw_rect(pr, Color(1.0, 1.0, 1.0))
	_draw_rect_border_with_corners_local(pr, Color(0.26, 0.21, 0.28), 5.75)

	draw_string(_font_din, Vector2(pr.position.x, cy - 45.0), "タイトル画面へ戻りますか？",
		HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 42, Color(0.95, 0.19, 0.32))

	_draw_popup_btn(yr, "はい",   _esc_popup_yes_hovered)
	_draw_popup_btn(nr, "いいえ", _esc_popup_no_hovered)


func _update_esc_popup_hover(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _popup_rects(vp)
	var new_yes: bool = (r["yes"] as Rect2).has_point(pos)
	var new_no: bool  = (r["no"]  as Rect2).has_point(pos)
	if (new_yes and not _esc_popup_yes_hovered) or (new_no and not _esc_popup_no_hovered):
		_sfx_on.play()
	_esc_popup_yes_hovered = new_yes
	_esc_popup_no_hovered  = new_no


func _handle_esc_popup_click(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _popup_rects(vp)
	if (r["yes"] as Rect2).has_point(pos):
		_handle_esc_popup_confirm(true)
	elif (r["no"] as Rect2).has_point(pos):
		_handle_esc_popup_confirm(false)
	elif not (r["popup"] as Rect2).has_point(pos):
		_esc_popup = false
		queue_redraw()


func _handle_esc_popup_confirm(yes: bool) -> void:
	_sfx_click.play()
	if yes:
		BGMManager.stop()
		TransitionManager.play_diagonal(func(): get_tree().change_scene_to_file(_GAME_SCENE))
	else:
		_esc_popup = false
		queue_redraw()


# ---------- ポップアップ共通ヘルパー ----------

func _draw_rect_border_with_corners_local(rect: Rect2, color: Color, bw: float) -> void:
	var dot_r: float = bw * 1.25
	draw_rect(rect, color, false, bw)
	draw_circle(rect.position,                        dot_r, color)
	draw_circle(Vector2(rect.end.x, rect.position.y), dot_r, color)
	draw_circle(Vector2(rect.position.x, rect.end.y), dot_r, color)
	draw_circle(rect.end,                             dot_r, color)


func _draw_popup_btn(rect: Rect2, label: String, hovered: bool) -> void:
	const BTN_BW: float = 5.75
	var dot_r: float = BTN_BW * 1.25
	var fs: int = 40
	var baseline_y: float = rect.position.y + (rect.size.y + _font.get_ascent(fs) - _font.get_descent(fs)) * 0.5
	if hovered:
		# アニメーション形状変化（ui_renderer の ON ボタンと同仕様）
		var t: float = Time.get_ticks_msec() / 500.0
		var mo: float = minf(5.0, minf(rect.size.x, rect.size.y) * 0.45)
		var pts := PackedVector2Array([
			Vector2(rect.position.x + sin(t * 0.71 + 0.00) * mo, rect.position.y + sin(t * 0.53 + 1.10) * mo),
			Vector2(rect.end.x      + sin(t * 0.63 + 2.30) * mo, rect.position.y + sin(t * 0.79 + 3.50) * mo),
			Vector2(rect.end.x      + sin(t * 0.58 + 4.70) * mo, rect.end.y      + sin(t * 0.67 + 5.90) * mo),
			Vector2(rect.position.x + sin(t * 0.82 + 7.10) * mo, rect.end.y      + sin(t * 0.61 + 8.30) * mo),
		])
		var so := Vector2(12.5, 12.5)
		draw_colored_polygon(PackedVector2Array([pts[0]+so, pts[1]+so, pts[2]+so, pts[3]+so]),
			Color(0.26, 0.21, 0.28, 0.30))
		draw_colored_polygon(pts, Color(0.95, 0.19, 0.32, 0.9))
		for i in range(4):
			draw_line(pts[i], pts[(i + 1) % 4], Color(0.26, 0.21, 0.28), BTN_BW, true)
		for c in pts:
			draw_circle(c, dot_r, Color(0.26, 0.21, 0.28))
		draw_string(_font, Vector2(rect.position.x, baseline_y), label,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, Color(1.0, 0.937, 0.89))
	else:
		draw_rect(Rect2(rect.position + Vector2(12.5, 12.5), rect.size), Color(0.26, 0.21, 0.28, 0.30))
		draw_rect(rect, Color(1.0, 0.937, 0.89))
		_draw_rect_border_with_corners_local(rect, Color(0.26, 0.21, 0.28), BTN_BW)
		draw_string(_font, Vector2(rect.position.x, baseline_y), label,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, Color(0.26, 0.21, 0.28))


# ---------- [DEBUG] SE選択パネル ----------

func _is_debug() -> bool:
	return OS.has_feature("editor") or Engine.is_editor_hint()


func _find_zou_stage_idx() -> int:
	# [DEBUG] キャッシュを強制リセットしてマニフェスト変更を反映させる
	StageData._stages_cache_ready = false
	var stages: Array = StageData.get_stages()
	for i in range(stages.size()):
		if str(stages[i].get("_source_file", "")) == "zou.json":
			return i
	return -1


func _dbg_panel_rect() -> Rect2:
	var rows: int = maxi(DebugSFXConfig.in_count, DebugSFXConfig.out_count)
	var pw: float = _DBG_COL_W * 2.0 + _DBG_COL_GAP + _DBG_PAD * 2.0
	var ph: float = _DBG_HEADER_H + rows * _DBG_ITEM_H + _DBG_PAD
	return Rect2(_DBG_PANEL_X, _DBG_PANEL_Y, pw, ph)


func _dbg_item_rect(col: int, row: int) -> Rect2:
	var pr: Rect2 = _dbg_panel_rect()
	var cx: float = pr.position.x + _DBG_PAD + col * (_DBG_COL_W + _DBG_COL_GAP)
	var cy: float = pr.position.y + _DBG_HEADER_H + row * _DBG_ITEM_H
	return Rect2(cx, cy, _DBG_COL_W, _DBG_ITEM_H)


func _draw_dbg_sfx_panel() -> void:
	var pr: Rect2 = _dbg_panel_rect()
	draw_rect(pr.grow(2.0), _DBG_BD)
	draw_rect(pr, _DBG_BG)
	var in_x: float = pr.position.x + _DBG_PAD
	var out_x: float = in_x + _DBG_COL_W + _DBG_COL_GAP
	var hy: float = pr.position.y + _DBG_HEADER_H * 0.78
	draw_string(_font, Vector2(in_x, hy), "in",
		HORIZONTAL_ALIGNMENT_CENTER, _DBG_COL_W, 15, _DBG_SEL)
	draw_string(_font, Vector2(out_x, hy), "out",
		HORIZONTAL_ALIGNMENT_CENTER, _DBG_COL_W, 15, _DBG_TXT)
	for row in range(DebugSFXConfig.in_count):
		_draw_dbg_item(0, row, row == DebugSFXConfig.in_idx)
	for row in range(DebugSFXConfig.out_count):
		_draw_dbg_item(1, row, row == DebugSFXConfig.out_idx)


func _draw_dbg_item(col: int, row: int, selected: bool) -> void:
	var r: Rect2 = _dbg_item_rect(col, row)
	var cy: float = r.position.y + r.size.y * 0.5
	var cx: float = r.position.x + 10.0
	var cr: float = 5.5
	var c: Color = _DBG_SEL if selected else _DBG_TXT
	if selected:
		draw_circle(Vector2(cx, cy), cr, c)
		draw_circle(Vector2(cx, cy), cr * 0.38, _DBG_BG)
	else:
		draw_circle(Vector2(cx, cy), cr, Color(c, 0.20))
		draw_arc(Vector2(cx, cy), cr, 0.0, TAU, 16, c, 1.2)
	draw_string(_font, Vector2(cx + cr + 5.0, r.position.y + r.size.y * 0.78),
		"%02d" % (row + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)


func _handle_dbg_sfx_click(pos: Vector2) -> bool:
	if DebugSFXConfig.in_count == 0 and DebugSFXConfig.out_count == 0:
		return false
	for row in range(DebugSFXConfig.in_count):
		if _dbg_item_rect(0, row).has_point(pos):
			DebugSFXConfig.in_idx = row
			if _dbg_preview:
				_dbg_preview.stream = load(DebugSFXConfig.in_path(row))
				_dbg_preview.play()
			queue_redraw()
			return true
	for row in range(DebugSFXConfig.out_count):
		if _dbg_item_rect(1, row).has_point(pos):
			DebugSFXConfig.out_idx = row
			if _dbg_preview:
				_dbg_preview.stream = load(DebugSFXConfig.out_path(row))
				_dbg_preview.play()
			queue_redraw()
			return true
	return false


# ---------- BGM 曲名表示 ----------

func _mk_bgm_btn(label_text: String) -> Button:
	var b := Button.new()
	b.text = label_text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", _BGM_LABEL_FONT_SIZE)
	b.add_theme_color_override("font_color", _BGM_LABEL_COLOR)
	b.add_theme_color_override("font_hover_color", _BGM_LABEL_COLOR.lightened(0.25))
	b.add_theme_color_override("font_pressed_color", _BGM_LABEL_COLOR.darkened(0.20))
	b.add_theme_color_override("font_disabled_color",
		Color(_BGM_LABEL_COLOR.r, _BGM_LABEL_COLOR.g, _BGM_LABEL_COLOR.b, 0.35))
	return b


func _mk_note_label() -> Label:
	var l := Label.new()
	l.text = "♪"
	l.add_theme_font_size_override("font_size", _BGM_LABEL_FONT_SIZE)
	l.add_theme_color_override("font_color", _BGM_LABEL_COLOR)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _setup_bgm_ui() -> void:
	# フルスクリーン基準コントロール（CanvasLayer 内でアンカー基準を確保）
	var anchor := Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bgm_canvas.add_child(anchor)

	# HBoxContainer: 右下アンカー・コンテンツ量に合わせて左方向へ伸張
	_bgm_container = HBoxContainer.new()
	_bgm_container.anchor_left   = 1.0
	_bgm_container.anchor_right  = 1.0
	_bgm_container.anchor_top    = 1.0
	_bgm_container.anchor_bottom = 1.0
	_bgm_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_bgm_container.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	_bgm_container.offset_right  = -20.0
	_bgm_container.offset_bottom = -14.0
	_bgm_container.add_theme_constant_override("separation", 8)
	anchor.add_child(_bgm_container)

	_btn_prev = _mk_bgm_btn("◀[L]")
	_bgm_container.add_child(_btn_prev)
	_bgm_container.add_child(_mk_note_label())

	_bgm_label = Label.new()
	_bgm_label.name = "BgmNameLabel"
	_bgm_label.visible_characters = 0
	_bgm_label.add_theme_font_size_override("font_size", _BGM_LABEL_FONT_SIZE)
	_bgm_label.add_theme_color_override("font_color", _BGM_LABEL_COLOR)
	_bgm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bgm_label.hide()
	_bgm_container.add_child(_bgm_label)

	_bgm_container.add_child(_mk_note_label())

	_btn_next = _mk_bgm_btn("[R]▶")
	_bgm_container.add_child(_btn_next)

	_btn_prev.pressed.connect(_on_bgm_btn_prev)
	_btn_next.pressed.connect(_on_bgm_btn_next)


func _start_bgm_label_anim() -> void:
	if _bgm_tween:
		_bgm_tween.kill()
		_bgm_tween = null

	var idx := BGMManager.get_ingame_track_idx()
	if idx < 0 or idx >= _BGM_TRACK_KEYS.size():
		return

	_bgm_text = tr(_BGM_TRACK_KEYS[idx])
	_bgm_label.text = _bgm_text
	_bgm_label.visible_characters = 0
	_bgm_label.show()

	_bgm_tween = create_tween()
	(_bgm_tween
		.tween_property(_bgm_label, "visible_characters", len(_bgm_text), _BGM_TYPEWRITER_SEC)
		.set_trans(Tween.TRANS_LINEAR))
	_bgm_tween.tween_interval(_BGM_HOLD_SEC)
	_bgm_tween.tween_callback(_begin_dismiss)


func _begin_dismiss() -> void:
	if _bgm_tween:
		_bgm_tween.kill()
		_bgm_tween = null

	var n := len(_bgm_text)
	if n == 0:
		_bgm_label.hide()
		return

	_bgm_tween = create_tween()
	var step := _BGM_DISMISS_SEC / float(n)
	for i in range(n):
		_bgm_tween.tween_interval(step)
		_bgm_tween.tween_callback(_dismiss_step.bind(i + 1))
	_bgm_tween.tween_callback(func() -> void:
		_bgm_label.hide()
		_bgm_text = ""
	)


func _dismiss_step(skip: int) -> void:
	var rect := _bgm_label.get_global_rect()
	_spawn_bgm_particle(Vector2(rect.position.x + 2.0, rect.get_center().y))
	_bgm_label.text = _bgm_text.substr(skip)


func _spawn_bgm_particle(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	_bgm_canvas.add_child(p)
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 6
	p.lifetime = 0.6
	p.spread = 180.0
	p.gravity = Vector2(0.0, 150.0)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 100.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.8, 0.5, 0.5, 1.0)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)


func _on_bgm_btn_prev() -> void:
	BGMManager.select_prev_bgm()
	_start_bgm_label_anim()


func _on_bgm_btn_next() -> void:
	BGMManager.select_next_bgm()
	_start_bgm_label_anim()
