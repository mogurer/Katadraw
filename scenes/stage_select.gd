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
const _BUBBLE_R        := 60.0    # 吹き出し内の図形半径
const _BUBBLE_PAD      := 18.0
const _BUBBLE_NAME_H   := 34.0    # ステージ名ラベルの高さ
const _POPUP_W         := 520.0
const _POPUP_H         := 260.0

# --- 自キャラ ---
const _CHAR_LERP       := 10.0    # マウス追跡の平滑化係数
const _PAD_SPEED       := 600.0   # ゲームパッド移動速度（px/sec）

var _char_pos: Vector2 = Vector2(960, 540)
var _char_target: Vector2 = Vector2(960, 540)
var _char_moved_by_user: bool = false

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
var _dbg_preview: AudioStreamPlayer = null
var _zou_stage_idx: int = -1  # [DEBUG] zou.json の StageData インデックス（-1=未発見）


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_char_pos = get_viewport_rect().size * 0.5
	_char_target = _char_pos
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


func _process(delta: float) -> void:
	_elapsed += delta

	# ゲームパッドスティック
	var sx: float = Input.get_axis("ui_left", "ui_right")
	var sy: float = Input.get_axis("ui_up", "ui_down")
	var pad_active: bool = absf(sx) > 0.1 or absf(sy) > 0.1
	if pad_active:
		_char_pos += Vector2(sx, sy).normalized() * _PAD_SPEED * delta
		_char_pos = _char_pos.clamp(Vector2.ZERO, get_viewport_rect().size)
		_char_target = _char_pos
		_char_moved_by_user = true
	else:
		# マウス追跡
		var new_pos: Vector2 = _char_pos.lerp(_char_target, _CHAR_LERP * delta)
		if new_pos.distance_to(_char_pos) > 0.5:
			_char_moved_by_user = true
		_char_pos = new_pos

	# 最近傍ステージ更新（ユーザー操作で動いたときのみ）
	if _char_moved_by_user and _popup_stage < 0:
		_char_moved_by_user = false
		_nearest = _find_nearest_accessible()

	queue_redraw()


func _input(event: InputEvent) -> void:
	# マウス位置 → 自キャラターゲット更新
	if event is InputEventMouseMotion:
		_char_target = event.position
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
			get_tree().change_scene_to_file(_GAME_SCENE)
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
		queue_redraw()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_esc_popup = true
		_esc_popup_yes_hovered = false
		_esc_popup_no_hovered = false
		queue_redraw()

	# L/R ボタンでBGM切り替え（ポップアップ非表示中のみ）
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			BGMManager.select_prev_bgm()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			BGMManager.select_next_bgm()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), _BG_COLOR)

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
		var is_near: bool = (i == _nearest and _popup_stage < 0)
		match state:
			StageSelectManager.StageState.LOCKED:
				draw_circle(pos, _DOT_RADIUS, _LOCKED_COLOR)
			StageSelectManager.StageState.UNLOCKED:
				draw_circle(pos, _DOT_RADIUS, _HOVER_COLOR if is_near else _UNLOCKED_COLOR)
			StageSelectManager.StageState.CLEARED:
				draw_circle(pos, _DOT_RADIUS, _HOVER_COLOR if is_near else _CLEARED_COLOR)
				draw_circle(pos, _DOT_RADIUS * 0.35, Color.WHITE)

	# 吹き出し（最近傍ステージ・ポップアップ非表示時のみ）
	if _nearest >= 0 and _popup_stage < 0:
		_draw_bubble(_nearest)

	# ラベル
	draw_string(_font, Vector2(40, 48), "STAGE SELECT", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.3, 0.1, 0.1))
	draw_string(_font, Vector2(40, vp.y - 32), "ESC: タイトルへ戻る", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.5, 0.3, 0.3))

	# 確認ポップアップ
	if _popup_stage >= 0:
		_draw_popup(vp)

	# タイトル戻り確認ポップアップ
	if _esc_popup:
		_draw_esc_popup(vp)

	# [DEBUG] ゾウステージ起動ドット
	if _is_debug() and _zou_stage_idx >= 0:
		draw_circle(_ZOU_DOT_POS, _ZOU_DOT_R, Color(0.15, 0.10, 0.20))

	# [DEBUG] SE選択パネル
	if _is_debug() and (DebugSFXConfig.in_count > 0 or DebugSFXConfig.out_count > 0):
		_draw_dbg_sfx_panel()

	# 自キャラ（ポップアップより前面）
	draw_circle(_char_pos, _CHAR_RADIUS, _CHAR_COLOR)
	draw_circle(_char_pos, _CHAR_RADIUS * 0.55, _BG_COLOR)


# ---------- 吹き出し ----------

func _draw_bubble(stage_id: int) -> void:
	var dot: Vector2 = _dot_pos(stage_id)
	var bw: float = (_BUBBLE_R + _BUBBLE_PAD) * 2.0
	var bh: float = bw + _BUBBLE_NAME_H
	# 吹き出し位置: ドットの右上（画面端に応じて調整）
	var vp: Vector2 = get_viewport_rect().size
	var bx: float = dot.x + _DOT_RADIUS + 8.0
	var by: float = dot.y - bh - _DOT_RADIUS
	bx = clampf(bx, 4.0, vp.x - bw - 4.0)
	by = clampf(by, 4.0, vp.y - bh - 4.0)
	var br := Rect2(bx, by, bw, bh)
	# 背景
	draw_rect(br, _BUBBLE_BORDER)
	draw_rect(br.grow(-3.0), _BUBBLE_BG)
	# ミニ図形（上部 bw×bw エリアの中央）
	var center := Vector2(bx + bw * 0.5, by + bw * 0.5)
	_draw_mini_shape(stage_id, center, _BUBBLE_R - _BUBBLE_PAD)
	# ステージ名（下部ラベルエリア）
	var name_str: String = StageSelectManager.get_stage_name(stage_id)
	if not name_str.is_empty():
		var name_y: float = by + bw + _BUBBLE_NAME_H * 0.72
		draw_string(_font, Vector2(bx, name_y), name_str,
			HORIZONTAL_ALIGNMENT_CENTER, bw, 18, _BUBBLE_BORDER)
	# しっぽ（ドットへ向かう小三角）
	var tail_tip: Vector2 = dot + Vector2(-_DOT_RADIUS * 0.5, -_DOT_RADIUS * 0.5)
	var tail_base_x: float = clampf(tail_tip.x, bx + 8.0, bx + bw - 8.0)
	var tail_base_y: float = by + bh
	draw_colored_polygon(PackedVector2Array([
		Vector2(tail_base_x - 6, tail_base_y),
		Vector2(tail_base_x + 6, tail_base_y),
		tail_tip,
	]), _BUBBLE_BORDER)


func _draw_mini_shape(stage_id: int, center: Vector2, r: float) -> void:
	# スケルトン段階: ステージ番号を円とともに表示（実データ接続後に形状別描画へ置き換え）
	var segments: int = 48
	var pts := PackedVector2Array()
	for i in range(segments):
		var a: float = i * TAU / segments
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color(_BUBBLE_BORDER, 0.18))
	draw_polyline(pts + PackedVector2Array([pts[0]]), _BUBBLE_BORDER, 1.5)
	var label: String = str(stage_id + 1)
	draw_string(_font, center - Vector2(r * 0.25, -r * 0.22), label, HORIZONTAL_ALIGNMENT_CENTER, r * 0.7, int(r * 0.5), _BUBBLE_BORDER)


# ---------- ポップアップ ----------

func _popup_rects(vp: Vector2) -> Dictionary:
	var px: float = (vp.x - _POPUP_W) * 0.5
	var py: float = (vp.y - _POPUP_H) * 0.5
	var popup_rect := Rect2(px, py, _POPUP_W, _POPUP_H)
	var btn_w: float = _POPUP_W * 0.3
	var btn_h: float = 52.0
	var btn_y: float = py + _POPUP_H - btn_h - 28.0
	var yes_rect := Rect2(px + _POPUP_W * 0.18, btn_y, btn_w, btn_h)
	var no_rect  := Rect2(px + _POPUP_W * 0.52, btn_y, btn_w, btn_h)
	return { "popup": popup_rect, "yes": yes_rect, "no": no_rect }


func _draw_popup(vp: Vector2) -> void:
	# 暗幕
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.35))
	var r: Dictionary = _popup_rects(vp)
	var pr: Rect2 = r["popup"]
	var yr: Rect2 = r["yes"]
	var nr: Rect2 = r["no"]

	# パネル
	draw_rect(pr.grow(4.0), _POPUP_BORDER)
	draw_rect(pr, _POPUP_BG)

	# テキスト
	var text_y: float = pr.position.y + pr.size.y * 0.38
	draw_string(_font, Vector2(pr.position.x, text_y), "このステージをプレイしますか？",
		HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 28, Color(0.26, 0.21, 0.28))
	var sub_y: float = text_y + 40.0
	var stage_label: String = "ステージ %d" % (_popup_stage + 1)
	var stage_name: String = StageSelectManager.get_stage_name(_popup_stage)
	if not stage_name.is_empty():
		stage_label += "　" + stage_name
	draw_string(_font, Vector2(pr.position.x, sub_y), stage_label,
		HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 22, Color(0.50, 0.30, 0.30))

	# [はい] ボタン
	var yes_col: Color = _BTN_YES_COLOR if _popup_yes_hovered else Color(_BTN_YES_COLOR, 0.5)
	draw_rect(yr, yes_col)
	draw_string(_font, Vector2(yr.position.x, yr.position.y + yr.size.y * 0.72),
		"はい", HORIZONTAL_ALIGNMENT_CENTER, yr.size.x, 26, Color.WHITE)

	# [いいえ] ボタン
	var no_col: Color = _BTN_NO_COLOR if _popup_no_hovered else Color(_BTN_NO_COLOR, 0.5)
	draw_rect(nr, no_col)
	draw_string(_font, Vector2(nr.position.x, nr.position.y + nr.size.y * 0.72),
		"いいえ", HORIZONTAL_ALIGNMENT_CENTER, nr.size.x, 26, Color.WHITE)


func _update_popup_hover(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _popup_rects(vp)
	_popup_yes_hovered = (r["yes"] as Rect2).has_point(pos)
	_popup_no_hovered  = (r["no"]  as Rect2).has_point(pos)


func _handle_popup_click(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _popup_rects(vp)
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
	if yes:
		StageSelectManager.pending_stage_id = _popup_stage
		get_tree().change_scene_to_file(_GAME_SCENE)
	else:
		_popup_stage = -1
		_nearest = _find_nearest_accessible()
		queue_redraw()


# ---------- ヘルパー ----------

func _dot_pos(i: int) -> Vector2:
	var base: Vector2 = StageSelectManager.STAGE_POSITIONS[i]
	var oy: float = sin(_elapsed * _anim_freq[i] + _anim_phase[i]) * _anim_amp[i]
	return base + Vector2(0.0, oy)


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
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.35))
	var r: Dictionary = _popup_rects(vp)
	var pr: Rect2 = r["popup"]
	var yr: Rect2 = r["yes"]
	var nr: Rect2 = r["no"]

	draw_rect(pr.grow(4.0), _POPUP_BORDER)
	draw_rect(pr, _POPUP_BG)

	var text_y: float = pr.position.y + pr.size.y * 0.42
	draw_string(_font, Vector2(pr.position.x, text_y), "タイトル画面へ戻りますか？",
		HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 28, Color(0.26, 0.21, 0.28))

	var yes_col: Color = _BTN_YES_COLOR if _esc_popup_yes_hovered else Color(_BTN_YES_COLOR, 0.5)
	draw_rect(yr, yes_col)
	draw_string(_font, Vector2(yr.position.x, yr.position.y + yr.size.y * 0.72),
		"はい", HORIZONTAL_ALIGNMENT_CENTER, yr.size.x, 26, Color.WHITE)

	var no_col: Color = _BTN_NO_COLOR if _esc_popup_no_hovered else Color(_BTN_NO_COLOR, 0.5)
	draw_rect(nr, no_col)
	draw_string(_font, Vector2(nr.position.x, nr.position.y + nr.size.y * 0.72),
		"いいえ", HORIZONTAL_ALIGNMENT_CENTER, nr.size.x, 26, Color.WHITE)


func _update_esc_popup_hover(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _popup_rects(vp)
	_esc_popup_yes_hovered = (r["yes"] as Rect2).has_point(pos)
	_esc_popup_no_hovered  = (r["no"]  as Rect2).has_point(pos)


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
	if yes:
		BGMManager.stop()
		get_tree().change_scene_to_file(_GAME_SCENE)
	else:
		_esc_popup = false
		queue_redraw()


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
