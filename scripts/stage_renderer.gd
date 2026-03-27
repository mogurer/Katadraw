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
	match _game.stage_type:
		"triangle", "square", "circle", "star", "cat_face", "fish":
			for i in range(n):
				_game.draw_line(_game.point_positions[i], _game.point_positions[(i + 1) % n], _renderer.LINE_COLOR, _renderer.LINE_WIDTH, true)
		"two_circles":
			for i in range(_game.group_split):
				_game.draw_line(_game.point_positions[i], _game.point_positions[(i + 1) % _game.group_split], _renderer.LINE_COLOR, _renderer.LINE_WIDTH, true)
			var g2_size: int = n - _game.group_split
			for i in range(g2_size):
				var idx: int = _game.group_split + i
				var next_idx: int = _game.group_split + (i + 1) % g2_size
				_game.draw_line(_game.point_positions[idx], _game.point_positions[next_idx], _renderer.LINE_COLOR_2, _renderer.LINE_WIDTH, true)
		_:
			for i in range(n):
				_game.draw_line(_game.point_positions[i], _game.point_positions[(i + 1) % n], _renderer.LINE_COLOR, _renderer.LINE_WIDTH, true)


func draw_group_cleared_rings() -> void:
	if _game.stage_type != "two_circles":
		return
	if _game.group1_cleared:
		_draw_ring(_game.current_centroid, _game.ideal_display_radius, _game.IDEAL_CIRCLE_COLOR, 2.5)
	if _game.group2_cleared:
		_draw_ring(_game.current_centroid_2, _game.ideal_display_radius_2, _game.IDEAL_CIRCLE_COLOR, 2.5)


func get_point_base_color(idx: int) -> Color:
	if _game.stage_type == "two_circles" and idx >= _game.group_split:
		return _renderer.POINT_COLOR_2
	return _renderer.POINT_COLOR


# --- 理想形（クリア時） ---

func draw_ideal_shape() -> void:
	match _game.stage_type:
		"triangle":
			_draw_polygon_outline(_game.current_centroid, _game.ideal_display_radius, 3, _game.polygon_rotation, _game.IDEAL_CIRCLE_COLOR, 2.5)
		"square":
			_draw_ideal_points_outline(_game.current_centroid, _game.ideal_points, _game.correspondence_scale, _game.correspondence_rotation, _game.IDEAL_CIRCLE_COLOR, 2.5)
		"cat_face", "fish":
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			_draw_ideal_points_outline(_game.current_centroid, pts, _game.correspondence_scale, _game.correspondence_rotation, _game.IDEAL_CIRCLE_COLOR, 2.5)
		"circle":
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			_draw_ideal_points_outline(_game.current_centroid, pts, _game.correspondence_scale, _game.correspondence_rotation, _game.IDEAL_CIRCLE_COLOR, 2.5)
		"two_circles":
			_draw_ring(_game.current_centroid, _game.ideal_display_radius, _game.IDEAL_CIRCLE_COLOR, 2.5)
			_draw_ring(_game.current_centroid_2, _game.ideal_display_radius_2, _game.IDEAL_CIRCLE_COLOR, 2.5)
		"star":
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			_draw_ideal_points_outline(_game.current_centroid, pts, _game.correspondence_scale, _game.correspondence_rotation, _game.IDEAL_STAR_COLOR, 2.5)
		_:
			_draw_ring(_game.current_centroid, _game.ideal_display_radius, _game.IDEAL_CIRCLE_COLOR, 2.5)


# --- ガイド・ヒント ---

func draw_guide_shape(alpha: float, width_scale: float = 1.0) -> void:
	# 描画の重心に合わせる（square/circle/cat_face/fish は current_centroid で中心がずれないように）
	var center: Vector2 = _game.shape_center
	if _game.stage_type in ["square", "circle", "star", "cat_face", "fish", "heptagram", "heptagram_silhouette"] and _game.point_positions.size() > 0:
		center = _game.current_centroid
	draw_guide_shape_at(center, alpha, width_scale)


func draw_guide_shape_at(center: Vector2, alpha: float, width_scale: float = 1.0, size_scale: float = 1.0) -> void:
	"""指定位置を中心にお手本を描画（size_scale で図形全体を拡縮）"""
	var width: float = 3.5 * width_scale
	var offset1: Vector2 = (_game.guide_center_1 - _game.shape_center) * size_scale
	var offset2: Vector2 = (_game.guide_center_2 - _game.shape_center) * size_scale
	var r_scaled: float = _game.guide_radius_val * size_scale
	match _game.stage_type:
		"triangle":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			_draw_polygon_outline(center + offset1, r_scaled, 3, _game.polygon_rotation, col, width)
		"square":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var base_sq: float = _game.correspondence_scale if _game.correspondence_scale >= 10.0 else _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, _game.ideal_points, base_sq * size_scale, _game.correspondence_rotation, col, width)
		"circle":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			var base_ci: float = _game.correspondence_scale if _game.correspondence_scale >= 10.0 else _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, pts, base_ci * size_scale, _game.correspondence_rotation, col, width)
		"two_circles":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			_draw_ring(center + offset1, r_scaled, col, width)
			var col2 := Color(0.75, 0.15, 0.25, 0.7 * alpha)
			_draw_ring(center + offset2, r_scaled, col2, width)
		"star":
			var col := Color(_game.GUIDE_STAR_COLOR.r, _game.GUIDE_STAR_COLOR.g, _game.GUIDE_STAR_COLOR.b, _game.GUIDE_STAR_COLOR.a * alpha)
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			var base_st: float = _game.correspondence_scale if _game.correspondence_scale >= 10.0 else _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, pts, base_st * size_scale, _game.correspondence_rotation, col, width)
		"heptagram", "heptagram_silhouette":
			var col := Color(_game.GUIDE_STAR_COLOR.r, _game.GUIDE_STAR_COLOR.g, _game.GUIDE_STAR_COLOR.b, _game.GUIDE_STAR_COLOR.a * alpha)
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			var base_hp: float = _game.correspondence_scale if _game.correspondence_scale >= 10.0 else _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, pts, base_hp * size_scale, _game.correspondence_rotation, col, width)
		"cat_face":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var pts_cf: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			var base_cf: float = _game.correspondence_scale if _game.correspondence_scale >= 10.0 else _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, pts_cf, base_cf * size_scale, _game.correspondence_rotation, col, width)
		"fish":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var pts_f: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			_draw_ideal_points_outline(center + offset1, pts_f, _game.correspondence_scale * size_scale, _game.correspondence_rotation, col, width)
		_:
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			_draw_ring(center + offset1, r_scaled, col, width)


func get_object_count() -> int:
	"""このステージのオブジェクト数を返す"""
	match _game.stage_type:
		"two_circles":
			return 2
		_:
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
	var width: float = 3.5 * width_scale
	var obj_count: int = get_object_count()
	var ratio: float = _get_size_ratio(obj_count)

	if obj_count <= 1:
		var desired_r: float = minf(available_w, available_h) * ratio / 2.0
		var sc: float = desired_r / maxf(_game.guide_radius_val, 1.0)
		draw_guide_shape_at(center, alpha, width_scale, sc)
		return

	# 複数オブジェクトの場合: 横並びで等間隔配置
	var obj_gap: float = 20.0  # オブジェクト間の隙間
	# 利用可能高さの ratio 分を直径に
	var desired_diameter: float = available_h * ratio
	# 幅方向の制限も考慮
	var max_diameter_w: float = (available_w - obj_gap * (obj_count - 1)) / obj_count
	var diameter: float = minf(desired_diameter, max_diameter_w)
	var r: float = diameter / 2.0

	match _game.stage_type:
		"two_circles":
			var total_span: float = diameter * obj_count + obj_gap * (obj_count - 1)
			var start_x: float = center.x - total_span / 2.0 + r
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var col2 := Color(0.75, 0.15, 0.25, 0.7 * alpha)
			_draw_ring(Vector2(start_x, center.y), r, col, width)
			_draw_ring(Vector2(start_x + diameter + obj_gap, center.y), r, col2, width)
		_:
			var desired_r: float = minf(available_w, available_h) * ratio / 2.0
			var sc: float = desired_r / maxf(_game.guide_radius_val, 1.0)
			draw_guide_shape_at(center, alpha, width_scale, sc)


func draw_hint_shape(alpha: float) -> void:
	var width: float = 3.5
	match _game.stage_type:
		"triangle":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			_draw_polygon_outline(_game.current_centroid, _game.ideal_display_radius, 3, _game.polygon_rotation, col, width)
		"square":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			_draw_ideal_points_outline(_game.current_centroid, _game.ideal_points, _game.correspondence_scale, _game.correspondence_rotation, col, width)
		"cat_face", "fish":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			_draw_ideal_points_outline(_game.current_centroid, pts, _game.correspondence_scale, _game.correspondence_rotation, col, width)
		"circle":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			_draw_ideal_points_outline(_game.current_centroid, pts, _game.correspondence_scale, _game.correspondence_rotation, col, width)
		"two_circles":
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			_draw_ring(_game.current_centroid, _game.ideal_display_radius, col, width)
			var col2 := Color(0.75, 0.15, 0.25, 0.7 * alpha)
			_draw_ring(_game.current_centroid_2, _game.ideal_display_radius_2, col2, width)
		"star":
			var col := Color(_game.GUIDE_STAR_COLOR.r, _game.GUIDE_STAR_COLOR.g, _game.GUIDE_STAR_COLOR.b, _game.GUIDE_STAR_COLOR.a * alpha)
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			_draw_ideal_points_outline(_game.current_centroid, pts, _game.correspondence_scale, _game.correspondence_rotation, col, width)
		_:
			var col := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			_draw_ring(_game.current_centroid, _game.ideal_display_radius, col, width)


func get_type_description() -> String:
	match _game.stage_type:
		"triangle":
			return _game.tr("GUIDE_TYPE_TRIANGLE")
		"square":
			return _game.tr("GUIDE_TYPE_SQUARE")
		"cat_face":
			return _game.tr("GUIDE_TYPE_CAT_FACE")
		"fish":
			return _game.tr("GUIDE_TYPE_FISH")
		"circle":
			return _game.tr("GUIDE_TYPE_CIRCLE")
		"two_circles":
			return _game.tr("GUIDE_TYPE_TWO_CIRCLES")
		"star":
			return _game.tr("GUIDE_TYPE_STAR")
		_:
			return ""


# --- HUD メトリクス ---

func draw_hud_metrics(hx: float, hw: float, goal_pct: float, draw_string_fit: Callable) -> void:
	match _game.stage_type:
		"triangle", "square", "circle", "star", "cat_face", "fish":
			var smooth_color: Color = _metric_color(_game.current_smoothness_error)
			draw_string_fit.call(Vector2(hx, 240), _game.tr("HUD_SMOOTHNESS") % _game.current_smoothness, hw, 66, smooth_color)
			draw_string_fit.call(Vector2(hx, 330), _game.tr("HUD_GOAL_BOTH") % goal_pct, hw, 45, Color(0.45, 0.38, 0.45))
		"two_circles":
			var sz: int = 50
			var c1_sm_col: Color = _metric_color(_game.current_smoothness_error)
			draw_string_fit.call(Vector2(hx, 235), _game.tr("HUD_C1_SMOOTHNESS") % _game.current_smoothness, hw, sz, c1_sm_col)
			var c2_sm_col: Color = _metric_color(_game.current_smoothness_error_2)
			draw_string_fit.call(Vector2(hx, 290), _game.tr("HUD_C2_SMOOTHNESS") % _game.current_smoothness_2, hw, sz, c2_sm_col)
			draw_string_fit.call(Vector2(hx, 355), _game.tr("HUD_GOAL_ALL") % goal_pct, hw, 45, Color(0.45, 0.38, 0.45))
		_:
			var smooth_color: Color = _metric_color(_game.current_smoothness_error)
			draw_string_fit.call(Vector2(hx, 240), _game.tr("HUD_SMOOTHNESS") % _game.current_smoothness, hw, 66, smooth_color)
			draw_string_fit.call(Vector2(hx, 330), _game.tr("HUD_GOAL_BOTH") % goal_pct, hw, 45, Color(0.45, 0.38, 0.45))


# --- クリアオーバーレイ ---

func draw_clear_metrics(tx: float, y: float, tw: float) -> void:
	# 実現率（表示値）をクリア画面にも表示。切り捨てで100.0%と未クリアの不整合を防ぐ
	var circ_display: float = _game.get_display_reproduction_rate_floor(_game.current_circularity)
	var circ2_display: float = _game.get_display_reproduction_rate_floor(_game.current_circularity_2)
	match _game.stage_type:
		"triangle", "square", "circle", "star", "cat_face", "fish":
			_game.draw_string(_game.font, Vector2(tx, y + 196), _game.tr("CLEAR_CIRC_SMOOTH") % [circ_display, _game.current_smoothness], HORIZONTAL_ALIGNMENT_CENTER, tw, 34, Color(0.26, 0.21, 0.28))
		"two_circles":
			_game.draw_string(_game.font, Vector2(tx, y + 196), _game.tr("CLEAR_C1") % [circ_display, _game.current_smoothness], HORIZONTAL_ALIGNMENT_CENTER, tw, 31, Color(0.26, 0.21, 0.28))
			_game.draw_string(_game.font, Vector2(tx, y + 237), _game.tr("CLEAR_C2") % [circ2_display, _game.current_smoothness_2], HORIZONTAL_ALIGNMENT_CENTER, tw, 31, Color(0.26, 0.21, 0.28))
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


func _draw_ideal_points_outline(center: Vector2, points: Array, scale: float, rotation: float, color: Color, width: float) -> void:
	"""理想点を回転・スケール・平行移動して多角形として描画"""
	if points.size() < 2:
		return
	var draw_scale: float = scale
	if not _game.guide_follows_player_radius and draw_scale < 10.0:
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

func draw_clear_shapes(rect: Rect2) -> void:
	"""ステージクリア画面に目標ガイドと最終形を rect 内に収めて重ねて描画"""
	var ideal_loops: Array = _get_ideal_vertex_loops()
	var player_loops: Array = _get_player_vertex_loops()
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
	var margin: float = 20.0
	var avail_w: float = rect.size.x - margin * 2.0
	var avail_h: float = rect.size.y - margin * 2.0
	var scale: float = minf(avail_w / size.x, avail_h / size.y)
	var center_dst: Vector2 = rect.position + rect.size * 0.5

	# 目標ガイド（下層）: 黒系ベース
	var guide_color: Color = Color(0.35, 0.28, 0.35)
	for loop in ideal_loops:
		var verts: Array = loop
		for i in range(verts.size()):
			var a: Vector2 = (verts[i] - center_src) * scale + center_dst
			var b: Vector2 = (verts[(i + 1) % verts.size()] - center_src) * scale + center_dst
			_game.draw_line(a, b, guide_color, 2.0, true)

	# 実現図形（上層）: 赤系
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
		"square", "star", "cat_face", "fish":
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
		"two_circles":
			var v1: Array[Vector2] = []
			for i in range(_game.CIRCLE_SEGMENTS):
				var a: float = TAU * i / _game.CIRCLE_SEGMENTS
				v1.append(_game.current_centroid + Vector2(cos(a), sin(a)) * _game.ideal_display_radius)
			result.append(v1)
			var v2: Array[Vector2] = []
			for i in range(_game.CIRCLE_SEGMENTS):
				var a: float = TAU * i / _game.CIRCLE_SEGMENTS
				v2.append(_game.current_centroid_2 + Vector2(cos(a), sin(a)) * _game.ideal_display_radius_2)
			result.append(v2)
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
	match _game.stage_type:
		"two_circles":
			var v1: Array[Vector2] = []
			for i in range(_game.group_split):
				v1.append(_game.point_positions[i])
			result.append(v1)
			var v2: Array[Vector2] = []
			for i in range(_game.group_split, n):
				v2.append(_game.point_positions[i])
			result.append(v2)
		_:
			var v: Array[Vector2] = []
			for i in range(n):
				v.append(_game.point_positions[i])
			result.append(v)
	return result
