# =============================================================================
# タイトルイントロ用 K キーフレーム編集ツール（5シート・再生・クリップボード出力）
# シート1=最終（編集不可）。プレビューは 5→4→3→2→1 の順（各2秒）。
# 実行: このシーンを開いて F6（またはメインから別ウィンドウで起動）
# =============================================================================
extends Control

const SHEET_COUNT := 5
# 5→4→3→2→1 の区間数（各2秒）
const PREVIEW_SEGMENT_COUNT := SHEET_COUNT - 1

const PREVIEW_STEP_SEC := 2.0
const VERTEX_HIT_PX := 14.0
const CANVAS_PAD := 56.0
# キャンバス内のフィット率（小さいほど全体が小さく収まる）
const VIEW_SCALE_FACTOR := 0.78

var _grid_xs: Array[float] = []
var _grid_ys: Array[float] = []

# title_intro_animation.gd の K_EDGES と同一順
const K_EDGES: Array = [
	[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6],
	[6, 7], [7, 8], [8, 9], [9, 10], [10, 11], [11, 0],
]

const K_WHITE_DOT_IDX := 2

# シート1（最終・編集不可）— title_intro_animation.gd の K_VERTICES と一致。TI_EDITOR_KF3 はシート2。
const SHEET1_FINAL_EDITOR: Array[Vector2] = [
	Vector2(-22.0000, -43.0000),
	Vector2(10.0000, -150.0000),
	Vector2(84.0000, -175.0000),
	Vector2(18.0000, -26.0000),
	Vector2(66.0000, 150.0000),
	Vector2(16.0000, 150.0000),
	Vector2(-11.0000, 39.0000),
	Vector2(-22.0000, 75.0000),
	Vector2(-22.0000, 150.0000),
	Vector2(-66.0000, 150.0000),
	Vector2(-66.0000, -150.0000),
	Vector2(-22.0000, -150.0000),
]

@onready var _btn_done: Button = %BtnDone
@onready var _tab_bar: TabBar = %TabBar
@onready var _canvas: Control = %Canvas

var _sheets: Array = []
var _preview_playing: bool = false
var _preview_elapsed: float = 0.0
var _preview_segment: int = 0
var _preview_from: Array = []
var _preview_to: Array = []
var _dragging_idx: int = -1


func _ready() -> void:
	_cache_grid_axes_from_reference()
	_reset_sheets_from_final()
	_lock_sheet1()
	_btn_done.tooltip_text = "シート5→4→3→2→1を各2秒でプレビュー再生し、終了後に Cursor 用の指示と TI_EDITOR_KF 定義をクリップボードへコピーします。"
	_btn_done.pressed.connect(_on_done_pressed)
	_tab_bar.tab_changed.connect(_on_tab_changed)
	_canvas.gui_input.connect(_on_canvas_gui_input)
	_canvas.tooltip_text = "シート2〜5で頂点をドラッグ。Shift 押しながらでグリッドにスナップしません（微調整）。"
	_tab_bar.tab_count = SHEET_COUNT
	for i in range(SHEET_COUNT):
		_tab_bar.set_tab_title(i, "シート%d" % (i + 1))
	_tab_bar.current_tab = 0
	queue_redraw_canvas()


func _cache_grid_axes_from_reference() -> void:
	var xset: Dictionary = {}
	var yset: Dictionary = {}
	for v in SHEET1_FINAL_EDITOR:
		var p: Vector2 = v as Vector2
		xset[p.x] = true
		yset[p.y] = true
	_grid_xs.clear()
	_grid_ys.clear()
	for k in xset.keys():
		_grid_xs.append(float(k))
	for k in yset.keys():
		_grid_ys.append(float(k))
	_grid_xs.sort()
	_grid_ys.sort()


func _nearest_on_axes(value: float, axes: Array[float]) -> float:
	if axes.is_empty():
		return value
	var best: float = axes[0]
	var best_d: float = absf(value - best)
	for a in axes:
		var d: float = absf(value - a)
		if d < best_d:
			best_d = d
			best = a
	return best


func _snap_to_reference_grid(ev: Vector2) -> Vector2:
	return Vector2(_nearest_on_axes(ev.x, _grid_xs), _nearest_on_axes(ev.y, _grid_ys))


func _editor_visible_bounds(inner: Rect2, origin: Vector2, scale_px: float) -> Rect2:
	var a: Vector2 = _screen_to_editor(inner.position, origin, scale_px)
	var b: Vector2 = _screen_to_editor(inner.position + inner.size, origin, scale_px)
	var minx: float = minf(a.x, b.x)
	var maxx: float = maxf(a.x, b.x)
	var miny: float = minf(a.y, b.y)
	var maxy: float = maxf(a.y, b.y)
	return Rect2(minx, miny, maxx - minx, maxy - miny)


func _draw_reference_grid(
	canvas: Control, origin: Vector2, scale_px: float, inner: Rect2
) -> void:
	if _grid_xs.is_empty() or _grid_ys.is_empty():
		return
	var vb: Rect2 = _editor_visible_bounds(inner, origin, scale_px)
	var col := Color(0.28, 0.29, 0.34, 0.55)
	var col_h := Color(0.24, 0.25, 0.3, 0.35)
	for gx in _grid_xs:
		var p1: Vector2 = _editor_to_screen(Vector2(gx, vb.position.y), origin, scale_px)
		var p2: Vector2 = _editor_to_screen(Vector2(gx, vb.position.y + vb.size.y), origin, scale_px)
		canvas.draw_line(p1, p2, col, 1.0, true)
	for gy in _grid_ys:
		var q1: Vector2 = _editor_to_screen(Vector2(vb.position.x, gy), origin, scale_px)
		var q2: Vector2 = _editor_to_screen(Vector2(vb.position.x + vb.size.x, gy), origin, scale_px)
		canvas.draw_line(q1, q2, col_h, 1.0, true)


func _reset_sheets_from_final() -> void:
	var base: Array = SHEET1_FINAL_EDITOR.duplicate()
	_sheets.clear()
	for i in range(SHEET_COUNT):
		var copy: Array = []
		for v in base:
			copy.append(v as Vector2)
		_sheets.append(copy)


func _lock_sheet1() -> void:
	_sheets[0] = SHEET1_FINAL_EDITOR.duplicate()


func _on_tab_changed(tab: int) -> void:
	_lock_sheet1()
	queue_redraw_canvas()


func _sheet_editable(sheet_index: int) -> bool:
	return sheet_index >= 1 and sheet_index <= SHEET_COUNT - 1


func _current_vertices() -> Array:
	if _preview_playing:
		var t: float = clampf(_preview_elapsed / PREVIEW_STEP_SEC, 0.0, 1.0)
		t = ease_out_cubic(t)
		return _vertices_lerp(_preview_from, _preview_to, t)
	return _sheets[_tab_bar.current_tab] as Array


func _vertices_lerp(a: Array, b: Array, t: float) -> Array:
	var out: Array = []
	for i in range(mini(a.size(), b.size())):
		out.append((a[i] as Vector2).lerp(b[i] as Vector2, t))
	return out


func ease_out_cubic(t: float) -> float:
	var t1: float = 1.0 - t
	return 1.0 - t1 * t1 * t1


func queue_redraw_canvas() -> void:
	_canvas.queue_redraw()


func draw_canvas(canvas: Control) -> void:
	var verts: Array = _current_vertices()
	if verts.is_empty():
		return
	var rect: Rect2 = canvas.get_rect()
	var inner: Rect2 = rect.grow(-CANVAS_PAD)
	var scale_px: float = _compute_scale(verts, inner.size)
	var origin: Vector2 = inner.position + inner.size / 2.0

	canvas.draw_rect(rect, Color(0.12, 0.12, 0.14))
	canvas.draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.18, 0.18, 0.22), false, 2.0)

	_draw_reference_grid(canvas, origin, scale_px, inner)

	var screen_pts: PackedVector2Array = PackedVector2Array()
	for v in verts:
		screen_pts.append(_editor_to_screen(v as Vector2, origin, scale_px))

	if screen_pts.size() >= 3:
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(screen_pts)
		var fill_col := Color(0.95, 0.19, 0.32, 0.12)
		for ti in range(0, tris.size(), 3):
			var tri: PackedVector2Array = PackedVector2Array([
				screen_pts[tris[ti]],
				screen_pts[tris[ti + 1]],
				screen_pts[tris[ti + 2]],
			])
			canvas.draw_colored_polygon(tri, fill_col)

	for edge in K_EDGES:
		var a: int = edge[0]
		var b: int = edge[1]
		canvas.draw_line(screen_pts[a], screen_pts[b], Color(0.92, 0.88, 0.9), 2.5, true)

	for i in range(screen_pts.size()):
		var col := Color(0.45, 0.75, 1.0) if i == K_WHITE_DOT_IDX else Color(0.95, 0.92, 1.0)
		canvas.draw_circle(screen_pts[i], 6.0, col)
		canvas.draw_arc(screen_pts[i], 6.0, 0.0, TAU, 32, Color(0.1, 0.1, 0.12), 1.5, true)

	if _preview_playing:
		canvas.draw_string(ThemeDB.fallback_font, Vector2(16, 28), "プレビュー再生中…", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.85, 0.9))


func _compute_scale(verts: Array, inner_size: Vector2) -> float:
	var xmin: float = 1e9
	var xmax: float = -1e9
	var ymin: float = 1e9
	var ymax: float = -1e9
	for v in verts:
		var p: Vector2 = v as Vector2
		xmin = minf(xmin, p.x)
		xmax = maxf(xmax, p.x)
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	var w: float = maxf(xmax - xmin, 0.001)
	var h: float = maxf(ymax - ymin, 0.001)
	return minf(inner_size.x / w, inner_size.y / h) * VIEW_SCALE_FACTOR


# エディタ座標はゲーム（Godot 2D・Y 下向き正）と同じ向きでスクリーンへ写す
func _editor_to_screen(v: Vector2, origin: Vector2, scale_px: float) -> Vector2:
	return origin + v * scale_px


func _screen_to_editor(screen_pos: Vector2, origin: Vector2, scale_px: float) -> Vector2:
	return (screen_pos - origin) / scale_px


func _on_canvas_gui_input(event: InputEvent) -> void:
	if _preview_playing:
		return
	var idx: int = _tab_bar.current_tab
	if not _sheet_editable(idx):
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var rect: Rect2 = _canvas.get_rect()
		var inner: Rect2 = rect.grow(-CANVAS_PAD)
		var verts: Array = _sheets[idx]
		var scale_px: float = _compute_scale(verts, inner.size)
		var origin: Vector2 = inner.position + inner.size / 2.0
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit: int = _hit_vertex(mb.position, verts, origin, scale_px)
				_dragging_idx = hit
			else:
				_dragging_idx = -1
	elif event is InputEventMouseMotion and _dragging_idx >= 0:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var rect2: Rect2 = _canvas.get_rect()
		var inner2: Rect2 = rect2.grow(-CANVAS_PAD)
		var verts2: Array = _sheets[idx]
		var sc: float = _compute_scale(verts2, inner2.size)
		var org2: Vector2 = inner2.position + inner2.size / 2.0
		var ev: Vector2 = _screen_to_editor(mm.position, org2, sc)
		if not Input.is_key_pressed(KEY_SHIFT):
			ev = _snap_to_reference_grid(ev)
		(_sheets[idx] as Array)[_dragging_idx] = ev
		queue_redraw_canvas()


func _hit_vertex(screen_pos: Vector2, verts: Array, origin: Vector2, scale_px: float) -> int:
	var best: int = -1
	var best_d: float = VERTEX_HIT_PX + 1.0
	for i in range(verts.size()):
		var sp: Vector2 = _editor_to_screen(verts[i] as Vector2, origin, scale_px)
		var d: float = sp.distance_to(screen_pos)
		if d < VERTEX_HIT_PX and d < best_d:
			best_d = d
			best = i
	return best


func _process(delta: float) -> void:
	if not _preview_playing:
		return
	_preview_elapsed += delta
	if _preview_elapsed >= PREVIEW_STEP_SEC:
		_preview_elapsed = 0.0
		_preview_segment += 1
		if _preview_segment >= PREVIEW_SEGMENT_COUNT:
			_preview_playing = false
			_btn_done.disabled = false
			_tab_bar.mouse_filter = Control.MOUSE_FILTER_STOP
			_copy_clipboard_and_notify()
			queue_redraw_canvas()
			return
		# 5→4→3→2→1: from = SHEET_COUNT-1 - seg, to = SHEET_COUNT-2 - seg
		var hi: int = SHEET_COUNT - 1 - _preview_segment
		var lo: int = SHEET_COUNT - 2 - _preview_segment
		_preview_from = (_sheets[hi] as Array).duplicate()
		_preview_to = (_sheets[lo] as Array).duplicate()
	queue_redraw_canvas()


func _on_done_pressed() -> void:
	if _preview_playing:
		return
	_preview_playing = true
	_preview_segment = 0
	_preview_elapsed = 0.0
	_preview_from = (_sheets[SHEET_COUNT - 1] as Array).duplicate()
	_preview_to = (_sheets[SHEET_COUNT - 2] as Array).duplicate()
	_btn_done.disabled = true
	_tab_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw_canvas()


func _copy_clipboard_and_notify() -> void:
	var text: String = _build_cursor_instruction()
	DisplayServer.clipboard_set(text)
	print("[TitleIntroKAnimEditor] クリップボードに指示文をコピーしました。")


func _build_cursor_instruction() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# title_intro_animation.gd への反映（Cursor 用指示）")
	lines.append("#")
	lines.append("# 次の const TI_EDITOR_KF0〜TI_EDITOR_KF3 を、scripts/title_intro_animation.gd 内の同名定義と置き換えてください。")
	lines.append("# 対応: TI_EDITOR_KF0=シート5、KF1=シート4、KF2=シート3、KF3=シート2（その後 K_VERTICES＝シート1 へモーフ）")
	lines.append("# アニメーションの流れは title_intro_animation.gd の Phase 0〜3 と一致（KF0→KF1→KF2→KF3→最終Kモーフ）。")
	lines.append("")
	lines.append(_format_kf_const("TI_EDITOR_KF0", _sheets[4]))
	lines.append("")
	lines.append(_format_kf_const("TI_EDITOR_KF1", _sheets[3]))
	lines.append("")
	lines.append(_format_kf_const("TI_EDITOR_KF2", _sheets[2]))
	lines.append("")
	lines.append(_format_kf_const("TI_EDITOR_KF3", _sheets[1]))
	lines.append("")
	return "\n".join(lines)


func _format_kf_const(name: String, verts: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("const %s: Array[Vector2] = [" % name)
	for i in range(verts.size()):
		var v: Vector2 = verts[i] as Vector2
		var comma: String = "," if i < verts.size() - 1 else ""
		parts.append("\tVector2(%s, %s)%s" % [_fmt(v.x), _fmt(v.y), comma])
	parts.append("]")
	return "\n".join(parts)


func _fmt(x: float) -> String:
	return "%.4f" % x
