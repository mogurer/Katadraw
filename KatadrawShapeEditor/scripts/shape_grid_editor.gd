# =============================================================================
# ShapeGridEditor - 目標図形のグリッド編集（スタンドアロン版）
# =============================================================================
# 使い方: プロジェクトを開き、scenes/shape_grid_editor.tscn を開いて F6 で実行。
# 左クリック: ライン上に新規ポイント追加（直線）
# 右クリック: ライン/円弧上に新規ポイント追加（円弧）
# 左ドラッグ: ポイント移動（直線はそのまま、弧は中心角を維持して拡大・縮小・回転）
# 右クリック(ポイント上): 削除
# 右ドラッグ(ポイント上): ポイント移動（3点で円を再計算）
# Eキー: コンソールへGDScript形式で出力
# 画面左3/4: エディタ、右1/4: スクリプト表示。▶:セーブ ◀:ロード

@tool
extends Node2D

const LEFT_RATIO := 0.75
const GRID_CELL_SIZE := 24.0
const GRID_SIZE := 16  # グリッドの半径（-16～16）
const POINT_RADIUS := 8.0
const HOVER_DISTANCE := 28.0  # ポイント検出距離（ドラッグ開始判定）
const EDGE_ADD_DISTANCE := 80.0  # この距離以内のライン上クリックでポイント追加
const RIGHT_CLICK_DRAG_THRESHOLD := 5.0
const ARC_SAMPLE_COUNT := 16

# ポイント（グリッド座標、整数）
var _points: Array[Vector2] = []
# エッジ: { "type": "line" | "arc", "arc_control": Vector2 }
var _edges: Array[Dictionary] = []

var _center: Vector2 = Vector2.ZERO
var _dragging_idx: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _left_drag_on_circle: bool = false  # 片側弧のみの場合の弧上拘束（両側弧では未使用）
var _left_drag_arc_ratio: float = 0.0  # 片側弧の円周比率
var _left_drag_original_center: Vector2 = Vector2.ZERO
var _left_drag_original_point_screen: Vector2 = Vector2.ZERO
var _left_drag_single_arc_angle: float = 0.0  # 片側のみ弧の場合の中心角（ラジアン）
var _left_drag_single_arc_edge: int = -1
var _left_drag_both_arc_edges: Array[int] = []  # 両側弧: [prev_e, curr_e] の中心角をそれぞれ維持
var _left_drag_both_arc_angles: Array[float] = []  # 両側弧: [弧0-1の中心角, 弧1-2の中心角] ラジアン
var _left_drag_both_arc_centers: Array[Vector2] = []  # 両側弧: 弧の向き維持用の元の円中心（画面座標）
var _left_drag_both_arc_last_centers: Array[Vector2] = []  # 両側弧: 前フレームで選んだ円中心（連続ドラッグ時の反転防止）
var _right_down_pos: Vector2 = Vector2.ZERO
var _right_drag_idx: int = -1
var _right_drag_offset: Vector2 = Vector2.ZERO
var _right_drag_committed: bool = false  # 5px動いたらドラッグ確定
var _hover_edge: int = -1

var _script_text_edit: TextEdit = null
var _btn_save: Button = null
var _btn_load: Button = null


func _ready() -> void:
	_init_triangle()
	_setup_script_panel()


func _init_triangle() -> void:
	"""初期3ポイント（三角形）"""
	_points.clear()
	_edges.clear()
	# グリッド座標で三角形
	_points.append(Vector2(-4, 2))
	_points.append(Vector2(4, 2))
	_points.append(Vector2(0, -4))
	_edges.append({"type": "line"})
	_edges.append({"type": "line"})
	_edges.append({"type": "line"})


func _get_left_width() -> float:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 1.0:
		vp = Vector2(640.0, 360.0)
	return vp.x * LEFT_RATIO


func _setup_script_panel() -> void:
	"""右パネル・ボタンを配置。エディタ実行時のみ"""
	if Engine.is_editor_hint():
		return
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 1.0:
		vp = Vector2(640.0, 360.0)
	var left_w: float = vp.x * LEFT_RATIO
	var right_w: float = vp.x - left_w
	var btn_size: float = 36.0
	var gap: float = 8.0

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.12, 0.12, 0.14)
	panel.position = Vector2(left_w, 0)
	panel.size = Vector2(right_w, vp.y)
	layer.add_child(panel)

	_script_text_edit = TextEdit.new()
	_script_text_edit.position = Vector2(left_w + 8, 8)
	_script_text_edit.custom_minimum_size = Vector2(right_w - 16, vp.y - 16)
	_script_text_edit.size = Vector2(right_w - 16, vp.y - 16)
	_script_text_edit.editable = true
	_script_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	layer.add_child(_script_text_edit)

	var boundary_x: float = left_w
	var btn_y_center: float = vp.y / 2.0
	_btn_save = Button.new()
	_btn_save.text = "▶"
	_btn_save.position = Vector2(boundary_x - btn_size / 2 - btn_size - gap, btn_y_center - btn_size - gap)
	_btn_save.custom_minimum_size = Vector2(btn_size, btn_size)
	_btn_save.pressed.connect(_on_save_pressed)
	layer.add_child(_btn_save)

	_btn_load = Button.new()
	_btn_load.text = "◀"
	_btn_load.position = Vector2(boundary_x - btn_size / 2 - btn_size - gap, btn_y_center + gap)
	_btn_load.custom_minimum_size = Vector2(btn_size, btn_size)
	_btn_load.pressed.connect(_on_load_pressed)
	layer.add_child(_btn_load)

	_refresh_script_text()


func _refresh_script_text() -> void:
	"""エディタの現在状態をスクリプト形式でテキストに反映"""
	if _script_text_edit == null:
		return
	var data: Dictionary = _build_polygon_with_arcs_for_export()
	var lines: PackedStringArray = PackedStringArray()
	if data.is_empty():
		lines.append("# 頂点がありません。◀でスクリプトからロード")
	else:
		var verts: Array = data["vertices"]
		var arc_ctrls: Dictionary = data["arc_controls"]
		var max_d: float = data.get("max_d", GRID_SIZE)
		lines.append("# max_d: %.4f  # ロード時のスケール復元用（stage_manager貼り付け時は削除可）" % max_d)
		lines.append("# get_*_polygon_vertices() に貼り付け")
		lines.append("var v: Array = []")
		for i in range(verts.size()):
			var p: Vector2 = verts[i]
			lines.append("\tv.append(Vector2(%.4f, %.4f))" % [p.x, p.y])
		lines.append("\treturn v")
		if not arc_ctrls.is_empty():
			lines.append("")
			lines.append("# get_*_arc_controls() に貼り付け")
			var keys: Array = arc_ctrls.keys()
			keys.sort()
			for idx in keys:
				var ac: Vector2 = arc_ctrls[idx]
				lines.append("\tarc_ctrls[%d] = Vector2(%.4f, %.4f)" % [idx, ac.x, ac.y])
	_script_text_edit.text = "\n".join(lines)


func _on_save_pressed() -> void:
	"""▶: エディタからスクリプトへ出力（テキストエリアに反映）"""
	_refresh_script_text()
	# コンソールにも出力（従来のEキーと同様）
	_export_to_console()


func _on_load_pressed() -> void:
	"""◀: スクリプトからエディタへポイントとラインを反映"""
	var text: String = _script_text_edit.text if _script_text_edit != null else ""
	var data: Dictionary = _parse_script_format(text)
	if data.is_empty():
		return
	_load_from_parsed_data(data)


func _parse_script_format(text: String) -> Dictionary:
	"""スクリプト形式のテキストをパース。{vertices: Array, arc_controls: Dictionary, max_d: float}"""
	var verts: Array = []
	var arc_ctrls: Dictionary = {}
	var max_d: float = GRID_SIZE
	var regex_vert: RegEx = RegEx.new()
	regex_vert.compile("v\\.append\\(Vector2\\s*\\(\\s*([+-]?\\d+\\.?\\d*)\\s*,\\s*([+-]?\\d+\\.?\\d*)\\s*\\)\\)")
	var regex_arc: RegEx = RegEx.new()
	regex_arc.compile("arc_ctrls\\[(\\d+)\\]\\s*=\\s*Vector2\\s*\\(\\s*([+-]?\\d+\\.?\\d*)\\s*,\\s*([+-]?\\d+\\.?\\d*)\\s*\\)")
	var regex_max_d: RegEx = RegEx.new()
	regex_max_d.compile("#\\s*max_d\\s*:\\s*([+-]?\\d+\\.?\\d*)")
	for line in text.split("\n"):
		var m_max: RegExMatch = regex_max_d.search(line.strip_edges())
		if m_max:
			max_d = float(m_max.get_string(1))
			if max_d < 0.001:
				max_d = GRID_SIZE
		var m_vert: RegExMatch = regex_vert.search(line.strip_edges())
		if m_vert:
			var x: float = float(m_vert.get_string(1))
			var y: float = float(m_vert.get_string(2))
			verts.append(Vector2(x, y))
		var m_arc: RegExMatch = regex_arc.search(line.strip_edges())
		if m_arc:
			var idx: int = int(m_arc.get_string(1))
			var x: float = float(m_arc.get_string(2))
			var y: float = float(m_arc.get_string(3))
			arc_ctrls[idx] = Vector2(x, y)
	if verts.size() < 3:
		return {}
	return {"vertices": verts, "arc_controls": arc_ctrls, "max_d": max_d}


func _load_from_parsed_data(data: Dictionary) -> void:
	"""パース済みデータをエディタに反映。正規化座標→グリッド座標に変換し、グリッドへスナップ"""
	var verts: Array = data.get("vertices", [])
	var arc_ctrls: Dictionary = data.get("arc_controls", {})
	var scale: float = data.get("max_d", GRID_SIZE)
	if scale < 0.001:
		scale = GRID_SIZE
	if verts.size() < 3:
		return
	_points.clear()
	_edges.clear()
	for p in verts:
		var g: Vector2 = Vector2(p.x * scale, -p.y * scale)
		_points.append(_snap_to_grid(g))
	for i in range(verts.size()):
		_edges.append({"type": "line"})
	for idx in arc_ctrls.keys():
		if idx >= 0 and idx < _edges.size():
			var ac: Vector2 = arc_ctrls[idx]
			var g_ac: Vector2 = Vector2(ac.x * scale, -ac.y * scale)
			_edges[idx] = {"type": "arc", "arc_control": _snap_to_grid(g_ac)}
	queue_redraw()


func _grid_to_screen(g: Vector2) -> Vector2:
	return _center + Vector2(g.x, -g.y) * GRID_CELL_SIZE


func _screen_to_grid(s: Vector2) -> Vector2:
	var rel: Vector2 = (s - _center) / GRID_CELL_SIZE
	return Vector2(roundf(rel.x), -roundf(rel.y))


func _screen_to_grid_exact(s: Vector2) -> Vector2:
	"""スナップせず正確なグリッド座標を返す（arc_control 用・円上に正確に乗せるため）"""
	var rel: Vector2 = (s - _center) / GRID_CELL_SIZE
	return Vector2(rel.x, -rel.y)


func _snap_to_grid(g: Vector2) -> Vector2:
	return Vector2(roundf(g.x), roundf(g.y))


func _compute_arc_central_angle(pa: Vector2, pb: Vector2, pc: Vector2) -> float:
	"""3点で決まる円の、弧pa→pb（pcを通る方）の中心角（ラジアン）を返す"""
	var center: Vector2 = _circumcenter(pa, pb, pc)
	if center.x != center.x:
		return 0.0
	var r: float = pa.distance_to(center)
	if r < 0.001:
		return 0.0
	var ang_a: float = atan2(pa.y - center.y, pa.x - center.x)
	var ang_b: float = atan2(pb.y - center.y, pb.x - center.x)
	var ang_c: float = atan2(pc.y - center.y, pc.x - center.x)
	var delta: float = ang_b - ang_a
	while delta > PI:
		delta -= TAU
	while delta <= -PI:
		delta += TAU
	var c_on_short: bool = _angle_between(ang_c, ang_a, ang_a + delta)
	var span: float = delta if c_on_short else (TAU - absf(delta))
	return absf(span)


func _update_arc_control_for_angle(edge_idx: int, angle_rad: float, original_center_screen: Variant = null, previous_center_screen: Variant = null) -> Variant:
	"""エッジの弧の中心角を維持するよう arc_control を更新。previous_center_screen で連続ドラッグ時の反転を防止。選んだ円中心を返す"""
	if edge_idx < 0 or edge_idx >= _edges.size():
		return null
	var edge: Dictionary = _edges[edge_idx]
	if edge.get("type", "line") != "arc":
		return null
	var ga: Vector2 = _points[edge_idx]
	var gb: Vector2 = _points[(edge_idx + 1) % _points.size()]
	var sa: Vector2 = _grid_to_screen(ga)
	var sb: Vector2 = _grid_to_screen(gb)
	var chord: Vector2 = sb - sa
	var L: float = chord.length()
	if L < 0.001 or sin(angle_rad * 0.5) < 0.0001:
		return null
	var r: float = L / (2.0 * sin(angle_rad * 0.5))
	var mid: Vector2 = (sa + sb) * 0.5
	var perp: Vector2 = Vector2(-chord.y, chord.x).normalized()
	var d: float = sqrt(r * r - (L * 0.5) * (L * 0.5))
	if d != d or d < 0.0:
		return null
	var center1: Vector2 = mid + perp * d
	var center2: Vector2 = mid - perp * d
	var old_ctrl_screen: Vector2 = _grid_to_screen(edge["arc_control"])
	var ang_ctrl1: float = atan2(old_ctrl_screen.y - center1.y, old_ctrl_screen.x - center1.x)
	var ang_a1: float = atan2(sa.y - center1.y, sa.x - center1.x)
	var ang_b1: float = atan2(sb.y - center1.y, sb.x - center1.x)
	var ctrl_on_arc1: bool = _angle_on_arc(ang_ctrl1, ang_a1, ang_b1, angle_rad)
	var ang_ctrl2: float = atan2(old_ctrl_screen.y - center2.y, old_ctrl_screen.x - center2.x)
	var ang_a2: float = atan2(sa.y - center2.y, sa.x - center2.x)
	var ang_b2: float = atan2(sb.y - center2.y, sb.x - center2.x)
	var ctrl_on_arc2: bool = _angle_on_arc(ang_ctrl2, ang_a2, ang_b2, angle_rad)
	var center: Vector2
	if ctrl_on_arc1 and not ctrl_on_arc2:
		center = center1
	elif ctrl_on_arc2 and not ctrl_on_arc1:
		center = center2
	elif previous_center_screen != null and previous_center_screen is Vector2:
		# 連続ドラッグ時: 前フレームの中心に近い方を選び、弧の向き反転を防ぐ
		var prev: Vector2 = previous_center_screen
		center = center1 if center1.distance_to(prev) <= center2.distance_to(prev) else center2
	elif original_center_screen != null and original_center_screen is Vector2:
		var orig: Vector2 = original_center_screen
		var to_orig: Vector2 = orig - mid
		var center1_side: float = (center1 - mid).dot(perp)
		var orig_side: float = to_orig.dot(perp)
		center = center1 if (center1_side * orig_side > 0) else center2
	else:
		var mid1: Vector2 = center1 + Vector2(cos(ang_a1 + angle_rad * 0.5), sin(ang_a1 + angle_rad * 0.5)) * r
		var mid2: Vector2 = center2 + Vector2(cos(ang_a2 + angle_rad * 0.5), sin(ang_a2 + angle_rad * 0.5)) * r
		center = center1 if mid1.distance_to(old_ctrl_screen) <= mid2.distance_to(old_ctrl_screen) else center2
	var ang_a: float = atan2(sa.y - center.y, sa.x - center.x)
	var ang_b: float = atan2(sb.y - center.y, sb.x - center.x)
	var delta: float = ang_b - ang_a
	while delta > PI:
		delta -= TAU
	while delta <= -PI:
		delta += TAU
	# _sample_arc_3points は「第3点を通らない方」の弧を描く。描きたい弧(angle_rad)の反対側に arc_control を置く
	# delta>0: 弧は反時計回り ang_a→ang_b。補弧中央は ang_a+angle_rad+comp_span/2
	# delta<0: 弧は時計回り ang_a→ang_b。補弧中央は ang_a+delta-comp_span/2
	var comp_span: float = TAU - angle_rad
	var arc_end: float = ang_a + (angle_rad if delta > 0 else -angle_rad)
	var ang_mid: float = arc_end + (comp_span * 0.5 if delta > 0 else -comp_span * 0.5)
	var mid_screen: Vector2 = center + Vector2(cos(ang_mid), sin(ang_mid)) * r
	var new_ctrl: Vector2 = _screen_to_grid_exact(mid_screen)
	if new_ctrl.distance_to(ga) < 0.5 or new_ctrl.distance_to(gb) < 0.5:
		var ang_third: float = arc_end + (comp_span * 0.33 if delta > 0 else -comp_span * 0.33)
		mid_screen = center + Vector2(cos(ang_third), sin(ang_third)) * r
		new_ctrl = _screen_to_grid_exact(mid_screen)
	_edges[edge_idx]["arc_control"] = new_ctrl
	return center


func _fix_arc_chain_controls(pt_idx: int) -> void:
	"""右ドラッグ後: 隣接2辺を弧に変換し、3点を通る円で arc_control を設定"""
	if pt_idx < 0 or _points.size() < 3:
		return
	var n: int = _points.size()
	var prev_e: int = (pt_idx - 1 + n) % n
	var curr_e: int = pt_idx
	var prev_pt: int = (pt_idx - 1 + n) % n
	var next_pt: int = (pt_idx + 1) % n
	var pa: Vector2 = _grid_to_screen(_points[prev_pt])
	var pb: Vector2 = _grid_to_screen(_points[pt_idx])
	var pc: Vector2 = _grid_to_screen(_points[next_pt])
	var circ: Vector2 = _circumcenter(pa, pb, pc)
	if circ.x != circ.x:
		return
	var r: float = pa.distance_to(circ)
	if r < 0.001:
		return
	_edges[prev_e] = {"type": "arc", "arc_control": _points[next_pt]}
	_edges[curr_e] = {"type": "arc", "arc_control": _points[prev_pt]}


func _apply_left_drag_arc_update() -> void:
	"""左ドラッグ後、弧の中心角維持のため arc_control を更新"""
	if _left_drag_single_arc_edge >= 0 and _left_drag_single_arc_angle > 0.0001:
		_update_arc_control_for_angle(_left_drag_single_arc_edge, _left_drag_single_arc_angle)
	elif _left_drag_both_arc_edges.size() >= 2 and _left_drag_both_arc_angles.size() >= 2:
		var orig0: Variant = _left_drag_both_arc_centers[0] if _left_drag_both_arc_centers.size() > 0 and _left_drag_both_arc_centers[0].x == _left_drag_both_arc_centers[0].x else null
		var orig1: Variant = _left_drag_both_arc_centers[1] if _left_drag_both_arc_centers.size() > 1 and _left_drag_both_arc_centers[1].x == _left_drag_both_arc_centers[1].x else null
		var prev0: Variant = _left_drag_both_arc_last_centers[0] if _left_drag_both_arc_last_centers.size() > 0 else null
		var prev1: Variant = _left_drag_both_arc_last_centers[1] if _left_drag_both_arc_last_centers.size() > 1 else null
		if _left_drag_both_arc_angles[0] > 0.0001:
			var c0: Variant = _update_arc_control_for_angle(_left_drag_both_arc_edges[0], _left_drag_both_arc_angles[0], orig0, prev0)
			if c0 is Vector2:
				if _left_drag_both_arc_last_centers.size() < 1:
					_left_drag_both_arc_last_centers.append(c0)
				else:
					_left_drag_both_arc_last_centers[0] = c0
		if _left_drag_both_arc_angles[1] > 0.0001:
			var c1: Variant = _update_arc_control_for_angle(_left_drag_both_arc_edges[1], _left_drag_both_arc_angles[1], orig1, prev1)
			if c1 is Vector2:
				if _left_drag_both_arc_last_centers.size() < 2:
					_left_drag_both_arc_last_centers.append(c1)
				else:
					_left_drag_both_arc_last_centers[1] = c1


func _ensure_not_on_adjacent(grid_pos: Vector2, dragging_idx: int) -> Vector2:
	"""隣接点と同じ位置にスナップしないよう補正（ポイント消失を防ぐ）"""
	if dragging_idx < 0 or _points.size() < 3:
		return grid_pos
	var n: int = _points.size()
	var prev_idx: int = (dragging_idx - 1 + n) % n
	var next_idx: int = (dragging_idx + 1) % n
	var prev_pos: Vector2 = _points[prev_idx]
	var next_pos: Vector2 = _points[next_idx]
	if grid_pos.distance_to(prev_pos) < 0.001 or grid_pos.distance_to(next_pos) < 0.001:
		if _left_drag_on_circle and _left_drag_arc_ratio > 0.0001:
			return _nudge_along_arc(dragging_idx, grid_pos, prev_idx, next_idx)
		var orig: Vector2 = _points[dragging_idx]
		var cands: Array[Vector2] = [
			Vector2(grid_pos.x + 1, grid_pos.y), Vector2(grid_pos.x - 1, grid_pos.y),
			Vector2(grid_pos.x, grid_pos.y + 1), Vector2(grid_pos.x, grid_pos.y - 1),
			Vector2(grid_pos.x + 1, grid_pos.y + 1), Vector2(grid_pos.x - 1, grid_pos.y - 1),
		]
		var best: Vector2 = orig
		var best_d: float = INF
		for c in cands:
			if c.distance_to(prev_pos) < 0.001 or c.distance_to(next_pos) < 0.001:
				continue
			var d: float = c.distance_to(grid_pos)
			if d < best_d:
				best_d = d
				best = c
		return best
	return grid_pos


func _nudge_along_arc(dragging_idx: int, grid_pos: Vector2, prev_idx: int, next_idx: int) -> Vector2:
	"""弧上に沿って隣接点を避ける位置を探す"""
	var pa: Vector2 = _grid_to_screen(_points[prev_idx])
	var pb: Vector2 = _grid_to_screen(_points[next_idx])
	var chord: Vector2 = pb - pa
	var L: float = chord.length()
	if L < 0.001:
		return grid_pos
	var arc_angle: float = _left_drag_arc_ratio * TAU
	var half_angle: float = arc_angle * 0.5
	if sin(half_angle) < 0.0001:
		return grid_pos
	var r: float = L / (2.0 * sin(half_angle))
	var mid: Vector2 = (pa + pb) * 0.5
	var perp: Vector2 = Vector2(-chord.y, chord.x).normalized()
	var d: float = sqrt(r * r - (L * 0.5) * (L * 0.5))
	if d != d or d < 0.0:
		return grid_pos
	var to_orig: Vector2 = _left_drag_original_center - mid
	var center: Vector2 = mid + perp * d if perp.dot(to_orig) > 0 else mid - perp * d
	var pos_screen: Vector2 = _grid_to_screen(grid_pos)
	var ang_p: float = atan2(pa.y - center.y, pa.x - center.x)
	var ang_pos: float = atan2(pos_screen.y - center.y, pos_screen.x - center.x)
	var ang_orig: float = atan2(_left_drag_original_point_screen.y - center.y, _left_drag_original_point_screen.x - center.x)
	var delta: float = atan2(pb.y - center.y, pb.x - center.x) - ang_p
	while delta > PI:
		delta -= TAU
	while delta <= -PI:
		delta += TAU
	var use_neg: bool = not _angle_between(ang_orig, ang_p, ang_p + arc_angle)
	var ang_end: float = ang_p + (arc_angle if not use_neg else -arc_angle)
	var ang_start: float = ang_p
	for sign in [1.0, -1.0]:
		for step in range(1, 12):
			var da: float = sign * step * 0.08
			var ang_new: float = _clamp_angle_to_arc(ang_pos + da, ang_start, ang_end)
			var pt: Vector2 = center + Vector2(cos(ang_new), sin(ang_new)) * r
			var cand: Vector2 = _snap_to_grid(_screen_to_grid(pt))
			if cand.distance_to(_points[prev_idx]) >= 0.01 and cand.distance_to(_points[next_idx]) >= 0.01:
				return cand
	return grid_pos


func _get_left_drag_grid_pos(mouse: Vector2) -> Vector2:
	"""左ドラッグ時の新規グリッド座標。弧の点なら円周比率を維持して拡大・縮小・回転"""
	var result: Vector2
	if _left_drag_on_circle and _dragging_idx >= 0 and _left_drag_arc_ratio > 0.0001:
		var n: int = _points.size()
		var prev_idx: int = (_dragging_idx - 1 + n) % n
		var next_idx: int = (_dragging_idx + 1) % n
		var pa: Vector2 = _grid_to_screen(_points[prev_idx])
		var pb: Vector2 = _grid_to_screen(_points[next_idx])
		var chord: Vector2 = pb - pa
		var L: float = chord.length()
		if L < 0.001:
			result = _snap_to_grid(_screen_to_grid(mouse) + _drag_offset)
		else:
			var arc_angle: float = _left_drag_arc_ratio * TAU
			var half_angle: float = arc_angle * 0.5
			if sin(half_angle) < 0.0001:
				result = _snap_to_grid(_screen_to_grid(mouse) + _drag_offset)
			else:
				var r: float = L / (2.0 * sin(half_angle))
				var mid: Vector2 = (pa + pb) * 0.5
				var perp: Vector2 = Vector2(-chord.y, chord.x).normalized()
				var d: float = sqrt(r * r - (L * 0.5) * (L * 0.5))
				if d != d or d < 0.0:
					result = _snap_to_grid(_screen_to_grid(mouse) + _drag_offset)
				else:
					var center1: Vector2 = mid + perp * d
					var center2: Vector2 = mid - perp * d
					var to_orig: Vector2 = _left_drag_original_center - mid
					var center: Vector2 = center1 if (perp.dot(to_orig) > 0) else center2
					var on_arc: Vector2 = _project_mouse_to_arc(mouse, center, r, pa, pb, arc_angle)
					result = _snap_to_grid(_screen_to_grid(on_arc))
	else:
		result = _snap_to_grid(_screen_to_grid(mouse) + _drag_offset)
	return _ensure_not_on_adjacent(result, _dragging_idx)


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 1.0 or vp.y < 1.0:
		vp = Vector2(640.0, 360.0)
	var left_w: float = vp.x * LEFT_RATIO
	_center = Vector2(left_w / 2.0, vp.y / 2.0)

	# グリッド線（左エリア内）
	_draw_grid(left_w)

	# エッジ（ライン・円弧）
	_draw_edges()

	# ポイント
	_draw_points()

	# デバッグ: 弧をドラッグ中は円の中心を表示
	if _dragging_idx >= 0:
		_draw_debug_arc_centers()

	# 境界線
	draw_line(Vector2(left_w, 0), Vector2(left_w, vp.y), Color(0.3, 0.3, 0.35), 2.0)

	# ヒント
	if not Engine.is_editor_hint():
		_draw_hint(left_w)


func _draw_grid(left_width: float = -1.0) -> void:
	if left_width < 0:
		left_width = _get_left_width()
	var dot_col: Color = Color(0.25, 0.25, 0.30)
	var solid_col: Color = Color(0.22, 0.22, 0.27)
	var axis_col: Color = Color(0.15, 0.15, 0.15)
	for i in range(-GRID_SIZE, GRID_SIZE + 1):
		var x: float = _center.x + i * GRID_CELL_SIZE
		var y: float = _center.y - i * GRID_CELL_SIZE
		if x < 0 or x > left_width:
			continue
		var is_major: bool = (i % 5) == 0
		var is_axis: bool = i == 0
		var col: Color = axis_col if is_axis else (solid_col if is_major else dot_col)
		var width: float = 1.5 if is_axis else (1.2 if is_major else 1.0)
		# 縦線
		_draw_grid_line(Vector2(x, 0), Vector2(x, _center.y * 2), col, width, is_axis or is_major)
		# 横線（左エリア内で切り詰め）
		_draw_grid_line(Vector2(0, y), Vector2(left_width, y), col, width, is_axis or is_major)


func _draw_grid_line(from: Vector2, to: Vector2, col: Color, width: float, solid: bool) -> void:
	if solid:
		draw_line(from, to, col, width, true)
	else:
		var seg_len: float = 4.0
		var gap: float = 4.0
		var dir: Vector2 = (to - from).normalized()
		var total: float = from.distance_to(to)
		var pos: float = 0.0
		while pos < total:
			var seg_end: float = minf(pos + seg_len, total)
			draw_line(from + dir * pos, from + dir * seg_end, col, width, true)
			pos = seg_end + gap


func _draw_edges() -> void:
	var line_col: Color = Color(0.35, 0.35, 0.45)
	var line_hover_col: Color = Color(0.50, 0.55, 0.70)
	var arc_col: Color = Color(0.40, 0.45, 0.55)
	for i in range(_edges.size()):
		var p0: Vector2 = _grid_to_screen(_points[i])
		var p1: Vector2 = _grid_to_screen(_points[(i + 1) % _points.size()])
		var edge: Dictionary = _edges[i]
		var is_arc: bool = edge.get("type", "line") == "arc" and edge.has("arc_control")
		var ac: Vector2 = _grid_to_screen(edge["arc_control"]) if is_arc else Vector2.ZERO
		if is_arc:
			var arc_pts: Array = _sample_arc_3points(p0, p1, ac)
			if arc_pts.size() >= 2:
				for j in range(arc_pts.size() - 1):
					draw_line(arc_pts[j], arc_pts[j + 1], arc_col, 2.5, true)
		else:
			var col: Color = line_hover_col if _hover_edge == i else line_col
			draw_line(p0, p1, col, 2.5, true)


func _draw_debug_arc_centers() -> void:
	"""弧をドラッグ中、その弧を延長した円の中心をデバッグ表示"""
	if _dragging_idx < 0 or _edges.size() == 0:
		return
	var n: int = _points.size()
	var prev_e: int = (_dragging_idx - 1 + n) % n
	var curr_e: int = _dragging_idx
	var center_col: Color = Color(1.0, 0.85, 0.2, 0.9)
	var radius_col: Color = Color(1.0, 0.85, 0.2, 0.25)
	for ei in [prev_e, curr_e]:
		if ei < 0 or ei >= _edges.size():
			continue
		var edge: Dictionary = _edges[ei]
		if edge.get("type", "line") != "arc" or not edge.has("arc_control"):
			continue
		var p0: Vector2 = _grid_to_screen(_points[ei])
		var p1: Vector2 = _grid_to_screen(_points[(ei + 1) % n])
		var ac: Vector2 = _grid_to_screen(edge["arc_control"])
		var center: Vector2 = _circumcenter(p0, p1, ac)
		if center.x != center.x:
			continue
		var r: float = p0.distance_to(center)
		if r < 0.001:
			continue
		draw_arc(center, r, 0, TAU, 32, radius_col, 1.0)
		draw_circle(center, 6, center_col)
		draw_arc(center, 6, 0, TAU, 16, Color(0.2, 0.2, 0.2, 0.8), 1.5)


func _sample_arc_3points(a: Vector2, b: Vector2, c: Vector2) -> Array:
	"""3点を通る円の弧をサンプル。A→Bの弧で、第3点cを通らない方（3-4-5の部分だけ）を描く"""
	var center: Vector2 = _circumcenter(a, b, c)
	if center.x != center.x:  # NaN check
		return [a, b]
	var r: float = a.distance_to(center)
	if r < 0.001:
		return [a, b]
	var ang_a: float = atan2(a.y - center.y, a.x - center.x)
	var ang_b: float = atan2(b.y - center.y, b.x - center.x)
	var ang_c: float = atan2(c.y - center.y, c.x - center.x)
	# 常に短い弧（角距離 < PI）を選び、第3点cがその弧上にあれば長い弧に切り替え
	var delta: float = ang_b - ang_a
	while delta > PI:
		delta -= TAU
	while delta <= -PI:
		delta += TAU
	var c_on_short_arc: bool = _angle_between(ang_c, ang_a, ang_a + delta)
	if c_on_short_arc:
		delta = delta - TAU if delta > 0 else delta + TAU
	var result: Array = []
	for k in range(ARC_SAMPLE_COUNT + 1):
		var t: float = float(k) / float(ARC_SAMPLE_COUNT)
		var ang: float = ang_a + delta * t
		result.append(center + Vector2(cos(ang), sin(ang)) * r)
	return result


func _angle_on_arc(ang_ctrl: float, ang_a: float, ang_b: float, arc_span: float) -> bool:
	"""ang_ctrl が弧 ang_a→ang_b（中心角 arc_span）上にあるか"""
	var delta: float = ang_b - ang_a
	while delta > PI:
		delta -= TAU
	while delta <= -PI:
		delta += TAU
	if absf(delta - arc_span) < 0.01:
		return _angle_between(ang_ctrl, ang_a, ang_a + arc_span)
	if absf(delta + arc_span) < 0.01:
		return _angle_between(ang_ctrl, ang_a - arc_span, ang_a)
	return false


func _angle_between(ang: float, from_a: float, to_b: float) -> bool:
	"""ang が from_a から to_b への弧上にあるか（角のラップを考慮）"""
	var span: float = to_b - from_a
	if absf(span) >= TAU:
		return true
	var d: float = ang - from_a
	while d > PI:
		d -= TAU
	while d <= -PI:
		d += TAU
	return (span > 0 and d >= 0 and d <= span) or (span < 0 and d <= 0 and d >= span)


func _circumcenter(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var d: float = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 0.0001:
		return Vector2(NAN, NAN)
	var ux: float = ((a.x * a.x + a.y * a.y) * (b.y - c.y) + (b.x * b.x + b.y * b.y) * (c.y - a.y) + (c.x * c.x + c.y * c.y) * (a.y - b.y)) / d
	var uy: float = ((a.x * a.x + a.y * a.y) * (c.x - b.x) + (b.x * b.x + b.y * b.y) * (a.x - c.x) + (c.x * c.x + c.y * c.y) * (b.x - a.x)) / d
	return Vector2(ux, uy)


func _project_mouse_to_arc(mouse: Vector2, center: Vector2, r: float, pa: Vector2, pb: Vector2, arc_angle: float) -> Vector2:
	"""マウス位置を弧上に投影。弧は pa→pb で円周の arc_angle ラジアン分。元の点を含む弧を選択"""
	if r < 0.001:
		return pa
	var ang_p: float = atan2(pa.y - center.y, pa.x - center.x)
	var ang_n: float = atan2(pb.y - center.y, pb.x - center.x)
	var ang_orig: float = atan2(_left_drag_original_point_screen.y - center.y, _left_drag_original_point_screen.x - center.x)
	var delta: float = ang_n - ang_p
	while delta > PI:
		delta -= TAU
	while delta <= -PI:
		delta += TAU
	var use_neg: bool
	if absf(delta - arc_angle) < 0.001 or absf(delta + arc_angle) < 0.001:
		var in_pos: bool = _angle_between(ang_orig, ang_p, ang_p + arc_angle)
		use_neg = not in_pos
	else:
		use_neg = absf(delta + arc_angle) < absf(delta - arc_angle)
	var ang_end: float = ang_p + (arc_angle if not use_neg else -arc_angle)
	var ang_start: float = ang_p
	var to_mouse: Vector2 = mouse - center
	var ang_m: float = atan2(to_mouse.y, to_mouse.x) if to_mouse.length() > 0.001 else ang_start
	var ang_clamped: float = _clamp_angle_to_arc(ang_m, ang_start, ang_end)
	return center + Vector2(cos(ang_clamped), sin(ang_clamped)) * r


func _clamp_angle_to_arc(ang: float, ang_start: float, ang_end: float) -> float:
	"""角度 ang を弧 [ang_start, ang_end] の範囲にクランプ（ラップ考慮）"""
	var span: float = ang_end - ang_start
	if span >= 0:
		if ang >= ang_start and ang <= ang_end:
			return ang
		if ang < ang_start:
			return ang_start
		return ang_end
	else:
		if ang <= ang_start and ang >= ang_end:
			return ang
		var d_start: float = absf(ang - ang_start)
		if d_start > PI:
			d_start = TAU - d_start
		var d_end: float = absf(ang - ang_end)
		if d_end > PI:
			d_end = TAU - d_end
		return ang_start if d_start <= d_end else ang_end


func _draw_points() -> void:
	var font: Font = ThemeDB.fallback_font
	for i in range(_points.size()):
		var p: Vector2 = _grid_to_screen(_points[i])
		var c: Color = Color(0.25, 0.55, 0.85)
		if _dragging_idx == i:
			c = Color(0.20, 0.50, 0.95)
		elif _right_drag_idx == i:
			c = Color(0.85, 0.60, 0.25)
		draw_arc(p, POINT_RADIUS, 0, TAU, 24, Color(0.15, 0.15, 0.2), 1.5)
		draw_circle(p, POINT_RADIUS - 2, c)
		var label: String = str(i)
		var ls: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_string(font, p - ls / 2.0 + Vector2(0, POINT_RADIUS + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 1.0, 1.0))


func _draw_hint(left_width: float = -1.0) -> void:
	var font: Font = ThemeDB.fallback_font
	var vp: Vector2 = get_viewport_rect().size
	if left_width < 0:
		left_width = vp.x * LEFT_RATIO
	var hint: String = "左:直線 右:円弧 左ドラッグ:移動 右:削除/移動 E:出力  ▶:セーブ ◀:ロード"
	draw_string(font, Vector2(20, vp.y - 20), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.4, 0.45))


func _get_local_mouse() -> Vector2:
	return get_local_mouse_position()


func _find_point_at(screen_pos: Vector2) -> int:
	var best: int = -1
	var best_d: float = HOVER_DISTANCE
	for i in range(_points.size()):
		var p: Vector2 = _grid_to_screen(_points[i])
		var d: float = screen_pos.distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func _find_nearest_edge(screen_pos: Vector2) -> int:
	var best: int = -1
	var best_d: float = EDGE_ADD_DISTANCE
	for i in range(_edges.size()):
		var p0: Vector2 = _grid_to_screen(_points[i])
		var p1: Vector2 = _grid_to_screen(_points[(i + 1) % _points.size()])
		var edge: Dictionary = _edges[i]
		var d: float
		if edge.get("type", "line") == "arc" and edge.has("arc_control"):
			var ac: Vector2 = _grid_to_screen(edge["arc_control"])
			var arc_pts: Array = _sample_arc_3points(p0, p1, ac)
			d = INF
			for k in range(arc_pts.size() - 1):
				var seg_d: float = _point_to_segment_distance(screen_pos, arc_pts[k], arc_pts[k + 1])
				d = minf(d, seg_d)
		else:
			d = _point_to_segment_distance(screen_pos, p0, p1)
		if d < best_d:
			best_d = d
			best = i
	return best


func _point_to_segment_distance(pt: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.0001:
		return pt.distance_to(a)
	var ap: Vector2 = pt - a
	var t: float = clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return pt.distance_to(proj)


func _find_closest_on_arc(ga: Vector2, gb: Vector2, gctrl: Vector2, screen_pos: Vector2) -> Vector2:
	"""円弧上の最も近い点を求め、グリッドにスナップして返す"""
	var sa: Vector2 = _grid_to_screen(ga)
	var sb: Vector2 = _grid_to_screen(gb)
	var sctrl: Vector2 = _grid_to_screen(gctrl)
	var arc_pts: Array = _sample_arc_3points(sa, sb, sctrl)
	var best_idx: int = 0
	var best_d: float = screen_pos.distance_to(arc_pts[0])
	for k in range(1, arc_pts.size()):
		var d: float = screen_pos.distance_to(arc_pts[k])
		if d < best_d:
			best_d = d
			best_idx = k
	var closest_screen: Vector2 = arc_pts[best_idx]
	return _snap_to_grid(_screen_to_grid(closest_screen))


func _add_point_on_edge(edge_idx: int, screen_pos: Vector2, as_arc: bool) -> void:
	var grid_pos: Vector2
	var p0: Vector2 = _points[edge_idx]
	var p1: Vector2 = _points[(edge_idx + 1) % _points.size()]
	if as_arc and _edges[edge_idx].get("type", "line") == "arc" and _edges[edge_idx].has("arc_control"):
		# 円弧上: 弧上の最も近い点を求め、グリッドにスナップ
		grid_pos = _find_closest_on_arc(p0, p1, _edges[edge_idx]["arc_control"], screen_pos)
	else:
		grid_pos = _screen_to_grid(screen_pos)
		grid_pos = _snap_to_grid(grid_pos)
	# 既存ポイントと重複、または端点と同じなら追加しない
	if grid_pos.distance_to(p0) < 0.01 or grid_pos.distance_to(p1) < 0.01:
		return
	var idx: int = edge_idx + 1
	_points.insert(idx, grid_pos)
	if as_arc:
		# 円弧: A→C→B の最小弧。arc_control は他端（ACのcontrol=B, BCのcontrol=A）
		_edges.insert(idx, {"type": "arc", "arc_control": p0})
		_edges[edge_idx] = {"type": "arc", "arc_control": p1}
	else:
		_edges.insert(idx, {"type": "line"})
		_edges[edge_idx] = {"type": "line"}


func _delete_point(idx: int) -> void:
	if _points.size() <= 3:
		return
	var prev_idx: int = (idx - 1 + _points.size()) % _points.size()
	# 削除: points[idx] と edges[idx] を除去。prev_idx のエッジを両隣直線に
	_points.remove_at(idx)
	_edges.remove_at(idx)
	# remove_at(idx) により、prev_idx > idx のときはインデックスが1つずれる
	var update_idx: int = prev_idx if prev_idx < idx else prev_idx - 1
	_edges[update_idx] = {"type": "line"}
	queue_redraw()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	var mouse: Vector2 = _get_local_mouse()
	var left_w: float = _get_left_width()

	# Eキー: 出力
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_export_to_console()
		if _script_text_edit != null:
			_refresh_script_text()
		get_viewport().set_input_as_handled()
		return

	# マウス操作は左エリアのみ（右パネルではエディタ操作しない）
	if event is InputEventMouse:
		if mouse.x >= left_w:
			return

	# 右クリック
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_down_pos = mouse
				_right_drag_idx = _find_point_at(mouse)
				_right_drag_committed = false
				if _right_drag_idx >= 0:
					_right_drag_offset = _points[_right_drag_idx] - _screen_to_grid(mouse)
				else:
					var edge_idx: int = _find_nearest_edge(mouse)
					if edge_idx >= 0:
						_add_point_on_edge(edge_idx, mouse, true)
						_hover_edge = -1
			else:
				if _right_drag_idx >= 0:
					# 5px以上動いていたらドラッグ（移動）、そうでなければクリック（削除）
					if _right_drag_committed:
						var new_grid: Vector2 = _screen_to_grid(mouse) + _right_drag_offset
						_points[_right_drag_idx] = _snap_to_grid(new_grid)
						_fix_arc_chain_controls(_right_drag_idx)
					else:
						_delete_point(_right_drag_idx)
					_right_drag_idx = -1
					_right_drag_committed = false
				queue_redraw()
			get_viewport().set_input_as_handled()
			return

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var pt_idx: int = _find_point_at(mouse)
				if pt_idx >= 0:
					_dragging_idx = pt_idx
					_drag_offset = _points[pt_idx] - _screen_to_grid(mouse)
					_left_drag_on_circle = false
					_left_drag_single_arc_edge = -1
					_left_drag_both_arc_edges = []
					_left_drag_both_arc_angles = []
					_left_drag_both_arc_centers = []
					_left_drag_both_arc_last_centers = []
					var prev_e: int = (pt_idx - 1 + _points.size()) % _points.size()
					var curr_e: int = pt_idx
					var prev_arc: bool = _edges[prev_e].get("type", "line") == "arc"
					var curr_arc: bool = _edges[curr_e].get("type", "line") == "arc"
					if prev_arc and curr_arc:
						# 両側弧: 弧0-1と弧1-2のそれぞれの中心角を維持（自由移動＋arc_control更新）
						var pa: Vector2 = _grid_to_screen(_points[prev_e])
						var pc: Vector2 = _grid_to_screen(_points[pt_idx])
						var pb: Vector2 = _grid_to_screen(_points[(pt_idx + 1) % _points.size()])
						var ac_prev: Vector2 = _grid_to_screen(_edges[prev_e]["arc_control"])
						var ac_curr: Vector2 = _grid_to_screen(_edges[curr_e]["arc_control"])
						var ang_pc: float = _compute_arc_central_angle(pa, pc, ac_prev)
						var ang_cp: float = _compute_arc_central_angle(pc, pb, ac_curr)
						var circ_prev: Vector2 = _circumcenter(pa, pc, ac_prev)
						var circ_curr: Vector2 = _circumcenter(pc, pb, ac_curr)
						_left_drag_both_arc_edges = [prev_e, curr_e]
						_left_drag_both_arc_angles = [ang_pc, ang_cp]
						_left_drag_both_arc_centers = [circ_prev, circ_curr]
						_left_drag_both_arc_last_centers = [circ_prev, circ_curr]
						_left_drag_on_circle = false
					elif prev_arc and not curr_arc:
						# 片側のみ弧: 弧の中心角を維持（arc_control を更新）
						var pa: Vector2 = _grid_to_screen(_points[prev_e])
						var pb: Vector2 = _grid_to_screen(_points[pt_idx])
						var pc: Vector2 = _grid_to_screen(_edges[prev_e]["arc_control"])
						_left_drag_single_arc_angle = _compute_arc_central_angle(pa, pb, pc)
						_left_drag_single_arc_edge = prev_e
					elif curr_arc and not prev_arc:
						# 片側のみ弧: 弧の中心角を維持
						var pa: Vector2 = _grid_to_screen(_points[pt_idx])
						var pb: Vector2 = _grid_to_screen(_points[(pt_idx + 1) % _points.size()])
						var pc: Vector2 = _grid_to_screen(_edges[curr_e]["arc_control"])
						_left_drag_single_arc_angle = _compute_arc_central_angle(pa, pb, pc)
						_left_drag_single_arc_edge = curr_e
					_hover_edge = -1
				else:
					var edge_idx: int = _find_nearest_edge(mouse)
					if edge_idx >= 0:
						_add_point_on_edge(edge_idx, mouse, false)
						_hover_edge = -1
				queue_redraw()
			else:
				if _dragging_idx >= 0:
					_points[_dragging_idx] = _get_left_drag_grid_pos(mouse)
					_apply_left_drag_arc_update()
				_dragging_idx = -1
				_left_drag_on_circle = false
				_left_drag_single_arc_edge = -1
				_left_drag_both_arc_edges = []
				_left_drag_both_arc_angles = []
				_left_drag_both_arc_centers = []
				_left_drag_both_arc_last_centers = []
				queue_redraw()

	elif event is InputEventMouseMotion:
		if _dragging_idx >= 0:
			var new_grid: Vector2 = _get_left_drag_grid_pos(mouse)
			_points[_dragging_idx] = new_grid
			_apply_left_drag_arc_update()
			queue_redraw()
		elif _right_drag_idx >= 0:
			var moved: float = mouse.distance_to(_right_down_pos)
			if moved >= RIGHT_CLICK_DRAG_THRESHOLD:
				_right_drag_committed = true
			if _right_drag_committed:
				# 5px動いたらドラッグ確定、ポイント移動
				var new_grid: Vector2 = _screen_to_grid(mouse) + _right_drag_offset
				_points[_right_drag_idx] = _snap_to_grid(new_grid)
				_fix_arc_chain_controls(_right_drag_idx)
			queue_redraw()
		else:
			var prev: int = _hover_edge
			_hover_edge = _find_nearest_edge(mouse)
			if _hover_edge != prev:
				queue_redraw()


func _export_to_console() -> void:
	"""ポリゴン頂点をGDScript形式でコンソール出力。直線と弧を分離して出力"""
	var data: Dictionary = _build_polygon_with_arcs_for_export()
	if data.is_empty():
		print("// 頂点がありません")
		return
	var verts: Array = data["vertices"]
	var arc_ctrls: Dictionary = data["arc_controls"]
	print("")
	print("# stage_manager.gd の get_*_polygon_vertices() と get_*_arc_controls() に貼り付け")
	print("var v: Array = []")
	for i in range(verts.size()):
		var p: Vector2 = verts[i]
		print("\tv.append(Vector2(%.4f, %.4f))" % [p.x, p.y])
	print("\treturn v")
	if not arc_ctrls.is_empty():
		print("")
		print("# get_*_arc_controls() の arc_ctrls に貼り付け（コメント行を置換）")
		var keys: Array = arc_ctrls.keys()
		keys.sort()
		for idx in keys:
			var ac: Vector2 = arc_ctrls[idx]
			print("\tarc_ctrls[%d] = Vector2(%.4f, %.4f)" % [idx, ac.x, ac.y])
	print("")


func _build_polygon_with_arcs_for_export() -> Dictionary:
	"""頂点と弧情報を分離して返す。{vertices: Array, arc_controls: Dictionary, max_d: float}"""
	if _points.size() < 3:
		return {}
	var verts: Array = []
	var arc_ctrls: Dictionary = {}
	for p in _points:
		verts.append(p)
	for i in range(_edges.size()):
		var edge: Dictionary = _edges[i]
		if edge.get("type", "line") == "arc" and edge.has("arc_control"):
			arc_ctrls[i] = edge["arc_control"]
	# 正規化: 重心で中心化、max_dist でスケール
	var all_pts: Array = verts.duplicate()
	for k in arc_ctrls.keys():
		all_pts.append(arc_ctrls[k])
	var c := Vector2.ZERO
	for p in all_pts:
		c += p
	c /= all_pts.size()
	var max_d: float = 0.001
	for p in all_pts:
		max_d = maxf(max_d, (p - c).length())
	# グリッドは Y+ が上、Godot は Y+ が下なので、エクスポート時に Y を反転
	var result_verts: Array = []
	for p in verts:
		var n: Vector2 = (p - c) / max_d
		result_verts.append(Vector2(n.x, -n.y))
	var result_arcs: Dictionary = {}
	for k in arc_ctrls.keys():
		var n: Vector2 = (arc_ctrls[k] - c) / max_d
		result_arcs[k] = Vector2(n.x, -n.y)
	return {"vertices": result_verts, "arc_controls": result_arcs, "max_d": max_d}


func _build_polygon_for_export() -> Array:
	"""エッジ（線・円弧）をたどってポリゴン頂点の配列を構築。正規化済み（max_dist=1）で返す。
	重複頂点を除去。エディタでの点の並び順（外周順）をそのまま保持する（後方互換用）"""
	var raw: Array = []
	if _points.is_empty():
		return []
	raw.append(_points[0])
	for i in range(_edges.size()):
		var p0: Vector2 = _points[i]
		var p1: Vector2 = _points[(i + 1) % _points.size()]
		var edge: Dictionary = _edges[i]
		if edge.get("type", "line") == "arc" and edge.has("arc_control"):
			var arc_pts: Array = _sample_arc_grid(p0, p1, edge["arc_control"])
			for j in range(1, arc_pts.size()):
				raw.append(arc_pts[j])
		else:
			raw.append(p1)
	# 重複頂点を除去（連続する同一点・近接点）
	raw = _deduplicate_polygon_vertices(raw)
	if raw.size() < 3:
		return []
	# 正規化: 重心で中心化し、max_dist でスケール
	var c := Vector2.ZERO
	for p in raw:
		c += p
	c /= raw.size()
	var max_d: float = 0.001
	for p in raw:
		max_d = maxf(max_d, (p - c).length())
	var result: Array = []
	for p in raw:
		result.append((p - c) / max_d)
	return result


func _deduplicate_polygon_vertices(raw: Array) -> Array:
	"""連続する同一点・近接点を除去"""
	const EPS: float = 0.001
	if raw.size() < 2:
		return raw
	var result: Array = [raw[0]]
	for i in range(1, raw.size()):
		var p: Vector2 = raw[i]
		var prev: Vector2 = result[result.size() - 1]
		if p.distance_to(prev) > EPS:
			result.append(p)
	# 先頭と末尾が重複していたら末尾を削除
	if result.size() >= 2 and result[0].distance_to(result[result.size() - 1]) <= EPS:
		result.pop_back()
	return result


func _sample_arc_grid(ga: Vector2, gb: Vector2, gc: Vector2) -> Array:
	"""グリッド座標の3点を通る円弧をサンプル（ga→gbでgcを通らない弧、3-4-5の部分だけ、グリッド座標で返す）"""
	var sa: Vector2 = _grid_to_screen(ga)
	var sb: Vector2 = _grid_to_screen(gb)
	var sc: Vector2 = _grid_to_screen(gc)
	var center: Vector2 = _circumcenter(sa, sb, sc)
	if center.x != center.x:
		return [ga, gb]
	var r: float = sa.distance_to(center)
	if r < 0.001:
		return [ga, gb]
	var ang_a: float = atan2(sa.y - center.y, sa.x - center.x)
	var ang_b: float = atan2(sb.y - center.y, sb.x - center.x)
	var ang_c: float = atan2(sc.y - center.y, sc.x - center.x)
	var delta: float = ang_b - ang_a
	while delta > PI:
		delta -= TAU
	while delta <= -PI:
		delta += TAU
	var c_on_short_arc: bool = _angle_between(ang_c, ang_a, ang_a + delta)
	if c_on_short_arc:
		delta = delta - TAU if delta > 0 else delta + TAU
	var result: Array = [ga]
	for k in range(1, ARC_SAMPLE_COUNT):
		var t: float = float(k) / float(ARC_SAMPLE_COUNT)
		var ang: float = ang_a + delta * t
		var sp: Vector2 = center + Vector2(cos(ang), sin(ang)) * r
		result.append(_screen_to_grid(sp))
	result.append(gb)
	return result
