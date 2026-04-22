# =============================================================================
# StageRenderer - 図形タイプごとの描画
# =============================================================================
# ガイド、ヒント、理想形、線、HUD、クリア表示など、図形タイプに依存する描画を担当。
# 新規図形追加時はこのファイルの match に分岐を追加する。

class_name StageRenderer
extends RefCounted

var _game: Node2D
var _renderer: UIRenderer


func _init(game: Node2D, renderer: UIRenderer) -> void:
	_game = game
	_renderer = renderer


# --- 線・ポイント色 ---

func draw_stage_lines() -> void:
	var n: int = _game.point_positions.size()
	if _game.is_polygon_walk_order_active():
		var ord: PackedInt32Array = _game.polygon_walk_order
		for k in range(n):
			var a: int = ord[k]
			var b: int = ord[(k + 1) % n]
			_game.draw_line(_game.point_positions[a], _game.point_positions[b], _renderer.LINE_COLOR, _renderer.LINE_WIDTH, true)
		return
	match _game.stage_type:
		"triangle", "square", "rhombus", "hexagon", "circle", "star", "cat_face", "fish", "heptagram", "heptagram_silhouette", "rugby_ball":
			for i in range(n):
				_game.draw_line(_game.point_positions[i], _game.point_positions[(i + 1) % n], _renderer.LINE_COLOR, _renderer.LINE_WIDTH, true)
		_:
			for i in range(n):
				_game.draw_line(_game.point_positions[i], _game.point_positions[(i + 1) % n], _renderer.LINE_COLOR, _renderer.LINE_WIDTH, true)


func get_point_base_color(_idx: int) -> Color:
	return _renderer.POINT_COLOR


# --- 理想形（クリア時） ---

func draw_ideal_shape() -> void:
	match _game.stage_type:
		"triangle":
			_draw_polygon_outline(_game.current_centroid, _game.ideal_display_radius, 3, _game.polygon_rotation, _game.IDEAL_CIRCLE_COLOR, 2.5)
		"square":
			_draw_ideal_points_outline(_game.current_centroid, _game.ideal_points, _game.correspondence_scale, _game.correspondence_rotation, _game.IDEAL_CIRCLE_COLOR, 2.5)
		"rhombus":
			_draw_ideal_points_outline(_game.current_centroid, _game.ideal_points, _game.correspondence_scale, _game.correspondence_rotation, _game.IDEAL_CIRCLE_COLOR, 2.5)
		"hexagon":
			_draw_ideal_points_outline(_game.current_centroid, _game.ideal_points, _game.correspondence_scale, _game.correspondence_rotation, _game.IDEAL_CIRCLE_COLOR, 2.5)
		"cat_face", "fish", "rugby_ball":
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			_draw_ideal_points_outline(_game.current_centroid, pts, _game.correspondence_scale, _game.correspondence_rotation, _game.IDEAL_CIRCLE_COLOR, 2.5)
		"circle":
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			_draw_ideal_points_outline(_game.current_centroid, pts, _game.correspondence_scale, _game.correspondence_rotation, _game.IDEAL_CIRCLE_COLOR, 2.5)
		"star", "heptagram", "heptagram_silhouette":
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			_draw_ideal_points_outline(_game.current_centroid, pts, _game.correspondence_scale, _game.correspondence_rotation, _game.IDEAL_STAR_COLOR, 2.5)
		_:
			_draw_ring(_game.current_centroid, _game.ideal_display_radius, _game.IDEAL_CIRCLE_COLOR, 2.5)


# --- ガイド・ヒント ---

func draw_guide_shape(alpha: float, width_scale: float = 1.0) -> void:
	var width: float = 3.5 * width_scale
	var loops: Array = _game.stage_manager.get_fixed_guide_loops_world()
	match _game.stage_type:
		"star", "heptagram", "heptagram_silhouette":
			var col_star := Color(_game.GUIDE_STAR_COLOR.r, _game.GUIDE_STAR_COLOR.g, _game.GUIDE_STAR_COLOR.b, _game.GUIDE_STAR_COLOR.a * alpha)
			for loop in loops:
				_draw_world_loop(loop as Array, col_star, width)
		_:
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			for loop in loops:
				_draw_world_loop(loop as Array, col, width)


func draw_guide_shape_at(center: Vector2, alpha: float, width_scale: float = 1.0, size_scale: float = 1.0) -> void:
	"""指定位置を中心にお手本を描画（size_scale で図形全体を拡縮）"""
	var width: float = 3.5 * width_scale
	var offset1: Vector2 = (_game.guide_center_1 - _game.shape_center) * size_scale
	var r_scaled: float = _game.guide_radius_val * size_scale
	match _game.stage_type:
		"triangle":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			_draw_polygon_outline(center + offset1, r_scaled, 3, _game.polygon_rotation, col, width)
		"square":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var base_sq: float = _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, _game.ideal_points, base_sq * size_scale, _game.correspondence_rotation, col, width)
		"hexagon":
			var col_h := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var base_h: float = _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, _game.ideal_points, base_h * size_scale, _game.correspondence_rotation, col_h, width)
		"rhombus":
			var col_rh := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var base_rh: float = _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, _game.ideal_points, base_rh * size_scale, _game.correspondence_rotation, col_rh, width)
		"circle":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			var base_ci: float = _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, pts, base_ci * size_scale, _game.correspondence_rotation, col, width)
		"star":
			var col := Color(_game.GUIDE_STAR_COLOR.r, _game.GUIDE_STAR_COLOR.g, _game.GUIDE_STAR_COLOR.b, _game.GUIDE_STAR_COLOR.a * alpha)
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			var base_st: float = _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, pts, base_st * size_scale, _game.correspondence_rotation, col, width)
		"heptagram", "heptagram_silhouette":
			var col := Color(_game.GUIDE_STAR_COLOR.r, _game.GUIDE_STAR_COLOR.g, _game.GUIDE_STAR_COLOR.b, _game.GUIDE_STAR_COLOR.a * alpha)
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			var base_hp: float = _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, pts, base_hp * size_scale, _game.correspondence_rotation, col, width)
		"cat_face":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var pts_cf: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			var base_cf: float = _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, pts_cf, base_cf * size_scale, _game.correspondence_rotation, col, width)
		"fish":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var pts_f: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			_draw_ideal_points_outline(center + offset1, pts_f, _game.guide_radius_val * size_scale, _game.correspondence_rotation, col, width)
		"rugby_ball":
			var col_rb := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var pts_rb: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			var base_rb: float = _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, pts_rb, base_rb * size_scale, _game.correspondence_rotation, col_rb, width)
		_:
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			_draw_ring(center + offset1, r_scaled, col, width)


## Playing: fixed HUD outline. Uses the same `hud_guide_outline_world` data as scoring.
func draw_hud_overlay_guide(alpha: float) -> void:
	if not GameConfig.USE_SCREEN_HUD_GUIDE:
		return
	var sm = _game.stage_manager
	var width: float = 3.5
	match _game.stage_type:
		"star", "heptagram", "heptagram_silhouette":
			var col_s := Color(_game.GUIDE_STAR_COLOR.r, _game.GUIDE_STAR_COLOR.g, _game.GUIDE_STAR_COLOR.b, _game.GUIDE_STAR_COLOR.a * alpha)
			_draw_hud_polyline_world(sm.hud_guide_outline_world, col_s, width)
		_:
			var col_g := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			_draw_hud_polyline_world(sm.hud_guide_outline_world, col_g, width)


func _draw_hud_polyline_world(verts: Array, color: Color, width: float) -> void:
	if verts.size() < 2:
		return
	var n: int = verts.size()
	var offsets: Array[float] = [0.0, 5.0, 11.0, 19.0]
	var alphas: Array[float] = [1.0, 0.48, 0.22, 0.07]
	for li in range(offsets.size()):
		var off: float = offsets[li]
		var am: float = alphas[li]
		var w: float = width if li == 0 else width * (1.0 - li * 0.18)
		var sides: Array = [0.0]
		if off > 0.0:
			sides = [-1.0, 1.0]
		var line_c: Color = Color(color.r, color.g, color.b, color.a * am)
		for side in sides:
			var orth_mul: float = off * side
			for i in range(n):
				var a: Vector2 = verts[i] as Vector2
				var b: Vector2 = verts[(i + 1) % n] as Vector2
				var seg: Vector2 = b - a
				var el: float = seg.length()
				if el < 0.001:
					continue
				var orth: Vector2 = Vector2(-seg.y, seg.x) / el * orth_mul
				_game.draw_line(a + orth, b + orth, line_c, w, true)


func get_object_count() -> int:
	"""このステージのオブジェクト数を返す"""
	return 1


func _get_size_ratio(obj_count: int) -> float:
	"""オブジェクト数に応じたサイズ比率"""
	match obj_count:
		1: return 0.80
		2: return 0.65
		3: return 0.50
		4: return 0.35
		_: return maxf(0.80 - (obj_count - 1) * 0.15, 0.20)


func draw_guide_shape_side_by_side(center: Vector2, available_w: float, available_h: float, alpha: float, width_scale: float = 1.0) -> void:
	"""複数オブジェクトを横並び・中心揃え・重複なし・画面内に収めて描画"""
	var ratio: float = _get_size_ratio(get_object_count())

	var desired_r: float = minf(available_w, available_h) * ratio / 2.0
	var sc: float = desired_r / maxf(_game.guide_radius_val, 1.0)
	draw_guide_shape_at(center, alpha, width_scale, sc)


func draw_guide_shape_fit_max(center: Vector2, available_w: float, available_h: float, alpha: float, width_scale: float = 1.0) -> void:
	"""指定枠いっぱいまで使って最大限フィットさせて描画"""
	var desired_r: float = minf(available_w, available_h) / 2.0
	var sc: float = desired_r / maxf(_game.guide_radius_val, 1.0)
	draw_guide_shape_at(center, alpha, width_scale, sc)


func draw_hint_shape(alpha: float) -> void:
	draw_guide_shape(alpha)


func get_type_description() -> String:
	var gtl: String = str(_game.stage_effective_cfg.get("guide_type_label", "")).strip_edges()
	if gtl != "":
		return gtl
	match _game.stage_type:
		"triangle":
			return _game.tr("GUIDE_TYPE_TRIANGLE")
		"square":
			return _game.tr("GUIDE_TYPE_SQUARE")
		"rhombus":
			return _game.tr("GUIDE_TYPE_RHOMBUS")
		"hexagon":
			return _game.tr("GUIDE_TYPE_HEXAGON")
		"cat_face":
			return _game.tr("GUIDE_TYPE_CAT_FACE")
		"fish":
			return _game.tr("GUIDE_TYPE_FISH")
		"circle":
			return _game.tr("GUIDE_TYPE_CIRCLE")
		"star":
			return _game.tr("GUIDE_TYPE_STAR")
		"heptagram":
			return _game.tr("GUIDE_TYPE_HEPTAGRAM")
		"heptagram_silhouette":
			return _game.tr("GUIDE_TYPE_HEPTAGRAM_SILHOUETTE")
		"rugby_ball":
			return _game.tr("GUIDE_TYPE_RUGBY_BALL")
		_:
			return ""


# --- HUD メトリクス ---

func draw_hud_metrics(hx: float, hw: float, goal_pct: float, draw_string_fit: Callable) -> void:
	match _game.stage_type:
		"triangle", "square", "rhombus", "hexagon", "circle", "star", "cat_face", "fish", "heptagram", "heptagram_silhouette", "rugby_ball":
			var smooth_color: Color = _metric_color(_game.current_smoothness_error)
			draw_string_fit.call(Vector2(hx, 240), _game.tr("HUD_SMOOTHNESS") % _game.current_smoothness, hw, 66, smooth_color)
			draw_string_fit.call(Vector2(hx, 330), _game.tr("HUD_GOAL_BOTH") % goal_pct, hw, 45, Color(0.45, 0.38, 0.45))
		_:
			var smooth_color2: Color = _metric_color(_game.current_smoothness_error)
			draw_string_fit.call(Vector2(hx, 240), _game.tr("HUD_SMOOTHNESS") % _game.current_smoothness, hw, 66, smooth_color2)
			draw_string_fit.call(Vector2(hx, 330), _game.tr("HUD_GOAL_BOTH") % goal_pct, hw, 45, Color(0.45, 0.38, 0.45))


# --- クリアオーバーレイ ---

func draw_clear_metrics(tx: float, y: float, tw: float) -> void:
	# 実現率（表示値）をクリア画面にも表示。切り捨てで100.0%と未クリアの不整合を防ぐ
	var circ_display: float = _game.get_display_reproduction_rate_floor(_game.current_circularity)
	match _game.stage_type:
		"triangle", "square", "rhombus", "hexagon", "circle", "star", "cat_face", "fish", "heptagram", "heptagram_silhouette", "rugby_ball":
			_game.draw_string(_game.font, Vector2(tx, y + 196), _game.tr("CLEAR_CIRC_SMOOTH") % [circ_display, _game.current_smoothness], HORIZONTAL_ALIGNMENT_CENTER, tw, 34, Color(0.26, 0.21, 0.28))
		_:
			_game.draw_string(_game.font, Vector2(tx, y + 196), _game.tr("CLEAR_CIRC_SMOOTH") % [circ_display, _game.current_smoothness], HORIZONTAL_ALIGNMENT_CENTER, tw, 34, Color(0.26, 0.21, 0.28))


# --- ユーティリティ ---

func _metric_color(error: float) -> Color:
	if error >= _game.clear_threshold * 2.0:
		return Color(0.95, 0.19, 0.32)
	elif error >= _game.clear_threshold:
		return Color(0.85, 0.45, 0.50)
	else:
		return Color(0.55, 0.75, 0.55)

## 表示用実現率(0-100)から色を取得（赤→黄→緑のグラデーション）
func get_metric_color_for_display_rate(rate: float) -> Color:
	var red_c: Color = Color(0.95, 0.19, 0.32)
	var yellow_c: Color = Color(0.85, 0.45, 0.50)
	var green_c: Color = Color(0.55, 0.75, 0.55)
	var t: float = clampf(rate / 100.0, 0.0, 1.0)
	if t <= 0.5:
		return red_c.lerp(yellow_c, t * 2.0)
	else:
		return yellow_c.lerp(green_c, (t - 0.5) * 2.0)


func _draw_ring(pos: Vector2, radius: float, color: Color, width: float = 1.0) -> void:
	var prev: Vector2 = pos + Vector2(radius, 0)
	for i in range(1, _game.CIRCLE_SEGMENTS + 1):
		var a: float = TAU * i / _game.CIRCLE_SEGMENTS
		var next: Vector2 = pos + Vector2(cos(a), sin(a)) * radius
		_game.draw_line(prev, next, color, width, true)
		prev = next


func _draw_world_loop(points: Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	for i in range(points.size()):
		var a: Vector2 = points[i] as Vector2
		var b: Vector2 = points[(i + 1) % points.size()] as Vector2
		_game.draw_line(a, b, color, width, true)


func _draw_ideal_points_outline(center: Vector2, points: Array, scale: float, rotation: float, color: Color, width: float) -> void:
	"""理想点を回転・スケール・平行移動して多角形として描画"""
	if points.size() < 2:
		return
	var draw_scale: float = scale
	if draw_scale < 10.0:
		draw_scale = _game.guide_radius_val
	var cos_r: float = cos(rotation)
	var sin_r: float = sin(rotation)
	var verts: Array = []
	for p in points:
		var tx: float = (p.x * cos_r - p.y * sin_r) * draw_scale
		var ty: float = (p.x * sin_r + p.y * cos_r) * draw_scale
		verts.append(center + Vector2(tx, ty))
	for i in range(verts.size()):
		_game.draw_line(verts[i], verts[(i + 1) % verts.size()], color, width, true)


func _draw_polygon_outline(center: Vector2, radius: float, n_sides: int, rotation: float, color: Color, width: float) -> void:
	var verts: Array = []
	for k in range(n_sides):
		var a: float = rotation + TAU * k / float(n_sides)
		verts.append(center + Vector2(cos(a), sin(a)) * radius)
	for i in range(n_sides):
		_game.draw_line(verts[i], verts[(i + 1) % n_sides], color, width, true)


func _draw_star_outline(center: Vector2, rotation: float, outer_r: float, inner_r: float, color: Color, width: float) -> void:
	var verts: Array[Vector2] = []
	for k in range(5):
		verts.append(center + Vector2(cos(rotation + k * TAU / 5.0), sin(rotation + k * TAU / 5.0)) * outer_r)
		verts.append(center + Vector2(cos(rotation + TAU / 10.0 + k * TAU / 5.0), sin(rotation + TAU / 10.0 + k * TAU / 5.0)) * inner_r)
	for i in range(10):
		_game.draw_line(verts[i], verts[(i + 1) % 10], color, width, true)


# --- ステージクリア画面用: 目標ガイドと実現図形を指定矩形内にスケールして重ねて描画 ---

func _duplicate_vertex_loops(loops: Array) -> Array:
	var out: Array = []
	for loop in loops:
		var loop_arr: Array = loop
		var inner: Array[Vector2] = []
		for v in loop_arr:
			inner.append(v as Vector2)
		out.append(inner)
	return out


## クリア直後に呼び、リザルト一覧用にガイド／プレイヤー輪郭をコピーして返す
func capture_result_loops() -> Dictionary:
	return {
		"ideal": _duplicate_vertex_loops(_get_ideal_vertex_loops()),
		"player": _duplicate_vertex_loops(_get_player_vertex_loops()),
	}


func draw_clear_shapes(rect: Rect2) -> void:
	"""ステージクリア画面に目標ガイドと最終形を rect 内に収めて重ねて描画"""
	draw_result_thumbnail(rect, _get_ideal_vertex_loops(), _get_player_vertex_loops())


## 保存済みループを rect 内にスケールして重ね描き（リザルト一覧サムネイル用）
func draw_result_thumbnail(rect: Rect2, ideal_loops: Array, player_loops: Array) -> void:
	if ideal_loops.is_empty() and player_loops.is_empty():
		return
	var all: Array[Vector2] = []
	for loop in ideal_loops:
		all.append_array(loop)
	for loop in player_loops:
		all.append_array(loop)
	if all.is_empty():
		return
	var min_p: Vector2 = all[0]
	var max_p: Vector2 = all[0]
	for p in all:
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)
	var size: Vector2 = max_p - min_p
	var center_src: Vector2 = (min_p + max_p) * 0.5
	if size.x < 1.0:
		size.x = 1.0
	if size.y < 1.0:
		size.y = 1.0
	var margin: float = 8.0
	var avail_w: float = rect.size.x - margin * 2.0
	var avail_h: float = rect.size.y - margin * 2.0
	if avail_w < 1.0 or avail_h < 1.0:
		return
	var scale: float = minf(avail_w / size.x, avail_h / size.y)
	var center_dst: Vector2 = rect.position + rect.size * 0.5

	var guide_color: Color = Color(0.35, 0.28, 0.35)
	for loop in ideal_loops:
		var verts: Array = loop
		for i in range(verts.size()):
			var a: Vector2 = (verts[i] - center_src) * scale + center_dst
			var b: Vector2 = (verts[(i + 1) % verts.size()] - center_src) * scale + center_dst
			_game.draw_line(a, b, guide_color, 2.0, true)

	var player_color: Color = Color(0.95, 0.19, 0.32)
	for loop in player_loops:
		var verts: Array = loop
		for i in range(verts.size()):
			var a: Vector2 = (verts[i] - center_src) * scale + center_dst
			var b: Vector2 = (verts[(i + 1) % verts.size()] - center_src) * scale + center_dst
			_game.draw_line(a, b, player_color, 2.5, true)


func _get_ideal_vertex_loops() -> Array:
	var result: Array = []
	match _game.stage_type:
		"triangle":
			var v: Array[Vector2] = []
			for k in range(3):
				var a: float = _game.polygon_rotation + TAU * k / 3.0
				v.append(_game.current_centroid + Vector2(cos(a), sin(a)) * _game.ideal_display_radius)
			result.append(v)
		"circle":
			var v: Array[Vector2] = []
			for i in range(_game.CIRCLE_SEGMENTS):
				var a: float = TAU * i / _game.CIRCLE_SEGMENTS
				v.append(_game.current_centroid + Vector2(cos(a), sin(a)) * _game.ideal_display_radius)
			result.append(v)
		"square", "rhombus", "hexagon", "star", "cat_face", "fish", "heptagram", "heptagram_silhouette", "rugby_ball":
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			if pts.is_empty():
				return result
			var v: Array[Vector2] = []
			var cos_r: float = cos(_game.correspondence_rotation)
			var sin_r: float = sin(_game.correspondence_rotation)
			for p in pts:
				var tx: float = (p.x * cos_r - p.y * sin_r) * _game.correspondence_scale
				var ty: float = (p.x * sin_r + p.y * cos_r) * _game.correspondence_scale
				v.append(_game.current_centroid + Vector2(tx, ty))
			result.append(v)
		_:
			var v: Array[Vector2] = []
			for i in range(_game.CIRCLE_SEGMENTS):
				var a: float = TAU * i / _game.CIRCLE_SEGMENTS
				v.append(_game.current_centroid + Vector2(cos(a), sin(a)) * _game.ideal_display_radius)
			result.append(v)
	return result


func _get_player_vertex_loops() -> Array:
	var result: Array = []
	var n: int = _game.point_positions.size()
	if n < 2:
		return result
	if _game.is_polygon_walk_order_active():
		var ord: PackedInt32Array = _game.polygon_walk_order
		var vw: Array[Vector2] = []
		for k in range(n):
			vw.append(_game.point_positions[ord[k]])
		result.append(vw)
		return result
	var v0: Array[Vector2] = []
	for i in range(n):
		v0.append(_game.point_positions[i])
	result.append(v0)
	return result
