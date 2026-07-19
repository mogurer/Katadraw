# =============================================================================
# StageRenderer - 図形タイプごとの描画
# =============================================================================
# ガイド、ヒント、理想形、線、HUD、クリア表示など、図形タイプに依存する描画を担当。
# 新規図形追加時はこのファイルの match に分岐を追加する。

class_name StageRenderer
extends RefCounted

## HUD プレイ中ガイドの芯線幅（px）。`draw_hud_overlay_guide` と UIRenderer のガイド乗り表示と同期
const HUD_GUIDE_LINE_WIDTH_PX := 3.5

## HUD 固定ガイド: 法線方向の外側グラデーション（px）。旧実装の最大 19 付近の約3倍
const _HUD_GUIDE_GLOW_MAX_OFFSET_PX := 10.0
## 層数（多いほど滑らか。外にいくほど透過率が下がる）
const _HUD_GUIDE_GLOW_LAYERS := 8
## 近接表示用空間グリッドのセルサイズ (px)。頂点開示距離 20px の 4 倍以上を確保。
const _PROX_GRID_CELL := 80.0

var _game: Node2D
var _draw_canvas: Node2D = null  # draw calls の転送先（設定時は draw_* のみここへ、property access は _game）
var _renderer: UIRenderer

## 近接表示用ガイド辺空間グリッド（フレームをまたいで再利用）
var _prox_grid: Dictionary = {}   # Vector2i → Array [[va, vb, vi], ...]
var _prox_grid_n: int = -1        # 前回ビルド時の辺数（変化時のみ再構築）


func _init(game: Node2D, renderer: UIRenderer) -> void:
	_game = game
	_renderer = renderer


# --- 線・ポイント色 ---

func draw_stage_lines() -> void:
	var n: int = _game.point_positions.size()
	var n_corners: int = _game.stage_manager.get_corner_positions_world().size()
	if _game.is_polygon_walk_order_active():
		var ord: PackedInt32Array = _game.polygon_walk_order
		for k in range(n):
			var a: int = ord[k]
			var b: int = ord[(k + 1) % n]
			var w: float = _renderer.LINE_WIDTH if _is_kata_edge_correct(a, b, n_corners) else _renderer.LINE_WIDTH / 3.0
			_game.draw_line(_game.point_positions[a], _game.point_positions[b], _renderer.LINE_COLOR, w, true)
		return
	match _game.stage_type:
		"triangle", "square", "rhombus", "hexagon", "circle", "star", "cat_face", "fish", "heptagram", "heptagram_silhouette", "rugby_ball":
			for i in range(n):
				var b: int = (i + 1) % n
				var w: float = _renderer.LINE_WIDTH if _is_kata_edge_correct(i, b, n_corners) else _renderer.LINE_WIDTH / 3.0
				_game.draw_line(_game.point_positions[i], _game.point_positions[b], _renderer.LINE_COLOR, w, true)
		_:
			for i in range(n):
				var b: int = (i + 1) % n
				var w: float = _renderer.LINE_WIDTH if _is_kata_edge_correct(i, b, n_corners) else _renderer.LINE_WIDTH / 3.0
				_game.draw_line(_game.point_positions[i], _game.point_positions[b], _renderer.LINE_COLOR, w, true)


func _is_kata_edge_correct(a: int, b: int, n_corners: int) -> bool:
	if n_corners <= 0:
		return false
	var ih: InputHandler = _game.input_handler
	if not ih.is_point_corner_snapped(a) or not ih.is_point_corner_snapped(b):
		return false
	var ca: int = ih.get_point_snap_corner_index(a)
	var cb: int = ih.get_point_snap_corner_index(b)
	if ca < 0 or cb < 0:
		return false
	return cb == (ca + 1) % n_corners or ca == (cb + 1) % n_corners


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
			var col_st := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			var base_st: float = _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, pts, base_st * size_scale, _game.correspondence_rotation, col_st, width)
		"heptagram", "heptagram_silhouette":
			var col_hp := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
			var pts: Array = _game.ideal_outline_points if _game.ideal_outline_points.size() > 0 else _game.ideal_points
			var base_hp: float = _game.guide_radius_val
			_draw_ideal_points_outline(center + offset1, pts, base_hp * size_scale, _game.correspondence_rotation, col_hp, width)
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
	var width: float = HUD_GUIDE_LINE_WIDTH_PX
	var col_g := Color(_game.GUIDE_COLOR.r, _game.GUIDE_COLOR.g, _game.GUIDE_COLOR.b, _game.GUIDE_COLOR.a * alpha)
	_draw_hud_polyline_world(sm.hud_guide_outline_world, col_g, width)


# ---------- 近接ガイド表示（プレイ中） ----------

const _REVEAL_RADIUS        := 150.0   # KATA→角の近接 / A+X 時の自キャラ周辺表示半径（px）
const _REVEAL_SAMPLE_STEP   := 8.0     # サンプリング間隔（px）
const _FULL_REVEAL_FADE_PX  := 50.0    # 半辺表示セグメント端フェード距離（px）
const _CORNER_MARKER_RADIUS := 6.0     # 角のみ表示時のマーカー半径（px）


## プレイ中のガイド近接表示。draw_hud_overlay_guide の代替。
## - コーナー吸着済み KATA: その角から前後それぞれ半辺を表示
## - それ以外: 任意 KATA から 150px 以内の shape 角のみマーカー表示
## - 自キャラ周辺: 通常は非表示 / A+X 同時押し中のみ 150px 圏でガイド線
func draw_guide_proximity_reveal() -> void:
	if not GameConfig.USE_SCREEN_HUD_GUIDE:
		return
	var loop: Array = _game.stage_manager.hud_guide_outline_world
	var n: int = loop.size()
	if n < 2:
		return

	var ih: InputHandler = _game.input_handler
	var kata_pts: Array[Vector2] = []
	for p: Vector2 in _game.point_positions:
		kata_pts.append(p)

	var col: Color = _game.GUIDE_COLOR
	var width: float = HUD_GUIDE_LINE_WIDTH_PX

	var snapped_corner_indices: Dictionary = {}
	var shape_corners: Array = _game.stage_manager.get_corner_positions_world()
	var n_corners: int = shape_corners.size()
	var n_kata: int = _game.point_positions.size()
	for i in range(n_kata):
		if not ih.is_point_corner_snapped(i):
			continue
		var ci: int = ih.get_point_snap_corner_index(i)
		if ci < 0 or ci >= n_corners:
			continue
		snapped_corner_indices[ci] = true

	# 正しい順番で結ばれているKATA辺に対応するコーナー区間（ci→ci+1）を求める
	var hide_guide_seg_after: Dictionary = {}
	if n_corners > 0:
		if _game.is_polygon_walk_order_active():
			var ord: PackedInt32Array = _game.polygon_walk_order
			for k in range(n_kata):
				var a: int = ord[k]
				var b: int = ord[(k + 1) % n_kata]
				if ih.is_point_corner_snapped(a) and ih.is_point_corner_snapped(b):
					var ca: int = ih.get_point_snap_corner_index(a)
					var cb: int = ih.get_point_snap_corner_index(b)
					if ca >= 0 and cb >= 0:
						if cb == (ca + 1) % n_corners:
							hide_guide_seg_after[ca] = true
						elif cb == (ca - 1 + n_corners) % n_corners:
							hide_guide_seg_after[cb] = true
		else:
			for i2 in range(n_kata):
				var j: int = (i2 + 1) % n_kata
				if ih.is_point_corner_snapped(i2) and ih.is_point_corner_snapped(j):
					var ca2: int = ih.get_point_snap_corner_index(i2)
					var cb2: int = ih.get_point_snap_corner_index(j)
					if ca2 >= 0 and cb2 >= 0:
						if cb2 == (ca2 + 1) % n_corners:
							hide_guide_seg_after[ca2] = true
						elif cb2 == (ca2 - 1 + n_corners) % n_corners:
							hide_guide_seg_after[cb2] = true

	var corner_markers: Array[Vector2] = []
	var rsq: float = _REVEAL_RADIUS * _REVEAL_RADIUS
	for ci in range(n_corners):
		if snapped_corner_indices.has(ci):
			continue
		var cp: Vector2 = shape_corners[ci] as Vector2
		for p: Vector2 in kata_pts:
			if p.distance_squared_to(cp) <= rsq:
				corner_markers.append(cp)
				break

	# コーナー吸着: 論理角から前後それぞれ半分の辺
	for ci in snapped_corner_indices:
		if n_corners < 2:
			continue
		var cp: Vector2 = shape_corners[ci] as Vector2
		var ci_prev: int = (ci - 1 + n_corners) % n_corners
		var ci_next: int = (ci + 1) % n_corners
		var cp_prev: Vector2 = shape_corners[ci_prev] as Vector2
		var cp_next: Vector2 = shape_corners[ci_next] as Vector2
		# 隣の角も吸着済みなら中間地点で合流するのでフェードさせない
		var prev_also_snapped: bool = snapped_corner_indices.has(ci_prev)
		var next_also_snapped: bool = snapped_corner_indices.has(ci_next)
		# 正しい順番でKATA辺が結ばれている区間はガイド線を非表示（黒いKATA線のみで表示）
		if not hide_guide_seg_after.has(ci_prev):
			_draw_guide_seg_full(cp_prev, cp, col, width, not prev_also_snapped, false, 0.5, 1.0)
		if not hide_guide_seg_after.has(ci):
			_draw_guide_seg_full(cp, cp_next, col, width, false, not next_also_snapped, 0.0, 0.5)

	for cp: Vector2 in corner_markers:
		_draw_guide_corner_marker(cp, col)


func _draw_guide_corner_marker(center: Vector2, col: Color) -> void:
	var r: float = _CORNER_MARKER_RADIUS
	_game.draw_circle(center, r * 1.35, Color(col.r, col.g, col.b, col.a * 0.35))
	_game.draw_circle(center, r, col)


func _draw_guide_seg_full(va: Vector2, vb: Vector2, col: Color, width: float,
		fade_a: bool, fade_b: bool, t_start: float = 0.0, t_end: float = 1.0) -> void:
	var full_len: float = va.distance_to(vb)
	if full_len < 0.5:
		return
	var draw_len: float = full_len * (t_end - t_start)
	if draw_len < 0.5:
		return
	var n_pts: int = maxi(2, int(draw_len / _REVEAL_SAMPLE_STEP) + 1)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var ft: float = minf(_FULL_REVEAL_FADE_PX / draw_len, 0.4)
	for i in range(n_pts):
		var local_t: float = float(i) / float(n_pts - 1)
		var alpha: float = col.a
		if fade_a and local_t < ft:
			alpha *= smoothstep(0.0, ft, local_t)
		if fade_b and local_t > 1.0 - ft:
			alpha *= smoothstep(0.0, ft, 1.0 - local_t)
		pts.append(va.lerp(vb, t_start + local_t * (t_end - t_start)))
		cols.append(Color(col.r, col.g, col.b, alpha))
	_game.draw_polyline_colors(pts, cols, width, true)


func _rebuild_prox_grid_if_needed(loop: Array) -> void:
	var n: int = loop.size()
	if n == _prox_grid_n:
		return
	_prox_grid_n = n
	_prox_grid.clear()
	var cell: float = _PROX_GRID_CELL
	for vi in range(n):
		var va: Vector2 = loop[vi] as Vector2
		var vb: Vector2 = loop[(vi + 1) % n] as Vector2
		var c0x: int = int(floor(minf(va.x, vb.x) / cell))
		var c1x: int = int(floor(maxf(va.x, vb.x) / cell))
		var c0y: int = int(floor(minf(va.y, vb.y) / cell))
		var c1y: int = int(floor(maxf(va.y, vb.y) / cell))
		for cx in range(c0x, c1x + 1):
			for cy in range(c0y, c1y + 1):
				var k := Vector2i(cx, cy)
				if not _prox_grid.has(k):
					_prox_grid[k] = []
				(_prox_grid[k] as Array).append([va, vb, vi])


## 辺 [va,vb] と半径 r の円の交差を辺パラメータ [t0,t1] で返す。交差なしは (-1,-1)。
func _seg_circle_t_range(va: Vector2, vb: Vector2, center: Vector2, r: float) -> Vector2:
	var d: Vector2 = vb - va
	var f: Vector2 = va - center
	var a2: float = d.dot(d)
	if a2 < 1e-8:
		return Vector2(-1.0, -1.0)
	var b2: float = 2.0 * f.dot(d)
	var c2: float = f.dot(f) - r * r
	var disc: float = b2 * b2 - 4.0 * a2 * c2
	if disc < 0.0:
		return Vector2(-1.0, -1.0)
	var sq: float = sqrt(disc)
	var inv: float = 0.5 / a2
	var t0: float = clampf((-b2 - sq) * inv, 0.0, 1.0)
	var t1: float = clampf((-b2 + sq) * inv, 0.0, 1.0)
	if t1 - t0 < 1e-6:
		return Vector2(-1.0, -1.0)
	return Vector2(t0, t1)


## 近接表示辺の描画: 各プローブの円と辺の交差区間を求めてマージし描画する。
## O(M×samples) のサンプリングループを O(M) の解析的区間計算に置き換えた。
func _draw_guide_seg_proximity(va: Vector2, vb: Vector2,
		probes: Array[Vector2], col: Color, width: float) -> void:
	if va.distance_squared_to(vb) < 0.25:
		return
	# 各プローブの可視区間 [t0, t1] を収集
	var intervals: Array = []
	for p: Vector2 in probes:
		var iv: Vector2 = _seg_circle_t_range(va, vb, p, _REVEAL_RADIUS)
		if iv.x >= 0.0:
			intervals.append([iv.x, iv.y])
	if intervals.is_empty():
		return
	# t0 順にソートしてマージ、各区間を draw_line で描画
	intervals.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var t0: float = float(intervals[0][0])
	var t1: float = float(intervals[0][1])
	for j in range(1, intervals.size()):
		var nx: float = float(intervals[j][0])
		var ny: float = float(intervals[j][1])
		if nx <= t1:
			t1 = maxf(t1, ny)
		else:
			_game.draw_line(va.lerp(vb, t0), va.lerp(vb, t1), col, width, true)
			t0 = nx
			t1 = ny
	_game.draw_line(va.lerp(vb, t0), va.lerp(vb, t1), col, width, true)


func _dist_to_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.dot(ab)
	if len_sq < 0.0001:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / len_sq, 0.0, 1.0))


## HUD 固定ガイド: 法線方向に外側へ薄くなるグラデーション → 最後に均一の芯線（図形間で色の差は出さない）
func _draw_hud_polyline_world(verts: Array, color: Color, width: float) -> void:
	if verts.size() < 2:
		return
	var n: int = verts.size()
	# 大オフセット（外＝最も薄い）→ 小の順に下敷き
	for li in range(_HUD_GUIDE_GLOW_LAYERS, 0, -1):
		var r: float = float(li) / float(_HUD_GUIDE_GLOW_LAYERS + 1)  # 0 にはならず、1 も取らない
		var off: float = _HUD_GUIDE_GLOW_MAX_OFFSET_PX * r
		# 外 (r 大) ほど乗算アルファが小さく
		var am: float = pow(1.0 - r, 1.15) * 0.5
		var w_g: float = maxf(0.6, width * (0.4 + 0.55 * (1.0 - r)))
		var line_c: Color = Color(color.r, color.g, color.b, color.a * am)
		for side in [-1.0, 1.0]:
			for i in range(n):
				var a: Vector2 = verts[i] as Vector2
				var b: Vector2 = verts[(i + 1) % n] as Vector2
				var seg: Vector2 = b - a
				var el: float = seg.length()
				if el < 0.001:
					continue
				var orth: Vector2 = Vector2(-seg.y, seg.x) / el * (off * side)
				_game.draw_line(a + orth, b + orth, line_c, w_g, true)
	_draw_world_loop(verts, color, width)


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
	var lk: String = str(_game.stage_effective_cfg.get("locale_key", "")).strip_edges()
	if lk != "":
		return _game.tr(lk)
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
			_game.draw_string(_game.font, Vector2(tx, y + 196), _game.tr("CLEAR_CIRC_SMOOTH") % [circ_display, _game.current_smoothness], HORIZONTAL_ALIGNMENT_CENTER, tw, 34, GameConfig.INK_COLOR)
		_:
			_game.draw_string(_game.font, Vector2(tx, y + 196), _game.tr("CLEAR_CIRC_SMOOTH") % [circ_display, _game.current_smoothness], HORIZONTAL_ALIGNMENT_CENTER, tw, 34, GameConfig.INK_COLOR)


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


func draw_ideal_only(rect: Rect2, color: Color = Color(0.9490, 0.1882, 0.3216), line_width: float = 4.0) -> void:
	"""見本の図形のみを rect 内に大きく描画（クリア画面右パネル用）"""
	var ideal_loops: Array = _get_ideal_vertex_loops()
	if ideal_loops.is_empty():
		return
	var all: Array[Vector2] = []
	for loop in ideal_loops:
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
	var margin: float = 24.0
	var avail_w: float = rect.size.x - margin * 2.0
	var avail_h: float = rect.size.y - margin * 2.0
	if avail_w < 1.0 or avail_h < 1.0:
		return
	var scale: float = minf(avail_w / size.x, avail_h / size.y)
	var center_dst: Vector2 = rect.position + rect.size * 0.5
	for loop in ideal_loops:
		var verts: Array = loop
		for i in range(verts.size()):
			var a: Vector2 = (verts[i] - center_src) * scale + center_dst
			var b: Vector2 = (verts[(i + 1) % verts.size()] - center_src) * scale + center_dst
			_game.draw_line(a, b, color, line_width, true)


func draw_ideal_filled(rect: Rect2, fill_color: Color, line_color: Color, line_width: float = 4.0, dot_radius: float = 6.0) -> void:
	"""塗りつぶし＋頂点ドット付きで見本図形を描画（クリア画面の完成系表示用）"""
	var ideal_loops: Array = _get_ideal_vertex_loops()
	if ideal_loops.is_empty():
		return
	var all: Array[Vector2] = []
	for loop in ideal_loops:
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
	if size.x < 1.0: size.x = 1.0
	if size.y < 1.0: size.y = 1.0
	var margin: float = 24.0
	var avail_w: float = rect.size.x - margin * 2.0
	var avail_h: float = rect.size.y - margin * 2.0
	if avail_w < 1.0 or avail_h < 1.0:
		return
	var scale: float = minf(avail_w / size.x, avail_h / size.y)
	var center_dst: Vector2 = rect.position + rect.size * 0.5
	# 頂点を変換
	var transformed_loops: Array = []
	for loop in ideal_loops:
		var pts := PackedVector2Array()
		for v in loop:
			pts.append((v - center_src) * scale + center_dst)
		transformed_loops.append(pts)
	var dc: Node2D = _draw_canvas if _draw_canvas != null else _game
	# 塗りつぶし
	for pts in transformed_loops:
		dc.draw_colored_polygon(pts, fill_color)
	# 輪郭線
	for pts in transformed_loops:
		for i in range(pts.size()):
			dc.draw_line(pts[i], pts[(i + 1) % pts.size()], line_color, line_width, true)
	# 頂点ドット
	var cos_rd: float = cos(_game.correspondence_rotation)
	var sin_rd: float = sin(_game.correspondence_rotation)
	var sc_d: float   = _game.correspondence_scale
	for cp in _game.stage_manager.shape_corner_points:
		var p: Vector2 = cp as Vector2
		var tx: float = (p.x * cos_rd - p.y * sin_rd) * sc_d
		var ty: float = (p.x * sin_rd + p.y * cos_rd) * sc_d
		var w: Vector2 = _game.current_centroid + Vector2(tx, ty)
		var dp: Vector2 = (w - center_src) * scale + center_dst
		dc.draw_circle(dp, dot_radius, line_color)


## 保存済みループを rect 内にスケールして重ね描き（リザルト一覧サムネイル用）
func draw_result_thumbnail(rect: Rect2, ideal_loops: Array, player_loops: Array) -> void:
	if ideal_loops.is_empty() and player_loops.is_empty():
		return
	# --- 全点の合算（スケール計算用: 理想＋プレイヤー両方を収める）---
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
	# --- center_src は理想図形の bbox 中心に固定する ---
	# 合算 bbox 中心を使うと、プレイヤーが非対称にはみ出たとき
	# ガイドが表示枠の中央からずれて見える問題が起きるため。
	var ideal_all: Array[Vector2] = []
	for loop in ideal_loops:
		ideal_all.append_array(loop)
	var ideal_min: Vector2 = ideal_all[0] if not ideal_all.is_empty() else all[0]
	var ideal_max: Vector2 = ideal_all[0] if not ideal_all.is_empty() else all[0]
	for p in ideal_all:
		ideal_min.x = minf(ideal_min.x, p.x)
		ideal_min.y = minf(ideal_min.y, p.y)
		ideal_max.x = maxf(ideal_max.x, p.x)
		ideal_max.y = maxf(ideal_max.y, p.y)
	var center_src: Vector2 = (ideal_min + ideal_max) * 0.5
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
