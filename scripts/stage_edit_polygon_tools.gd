# =============================================================================
# Stage Edit キャンバス用 — KatadrawShapeEditor（shape_grid_editor.gd）と同じ幾何モデル
# 正規化座標（中心原点・Y は画面下向き＝Godot スクリーンと一致）で頂点・辺を保持
# =============================================================================
class_name StageEditPolygonTools

const ARC_SAMPLE_COUNT: int = 16


static func norm_to_screen(norm: Vector2, rect: Rect2) -> Vector2:
	var c: Vector2 = rect.position + rect.size * 0.5
	var rad: float = minf(rect.size.x, rect.size.y) * 0.42
	return c + Vector2(norm.x * rad, norm.y * rad)


static func screen_to_norm(screen: Vector2, rect: Rect2) -> Vector2:
	var c: Vector2 = rect.position + rect.size * 0.5
	var rad: float = minf(rect.size.x, rect.size.y) * 0.42
	if rad < 0.001:
		return Vector2.ZERO
	var d: Vector2 = screen - c
	return Vector2(roundf(d.x / rad), roundf(d.y / rad))


static func screen_to_norm_exact(screen: Vector2, rect: Rect2) -> Vector2:
	var c: Vector2 = rect.position + rect.size * 0.5
	var rad: float = minf(rect.size.x, rect.size.y) * 0.42
	if rad < 0.001:
		return Vector2.ZERO
	var d: Vector2 = screen - c
	return Vector2(d.x / rad, d.y / rad)


static func circumcenter(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var d: float = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 0.0001:
		return Vector2(NAN, NAN)
	var ux: float = ((a.x * a.x + a.y * a.y) * (b.y - c.y) + (b.x * b.x + b.y * b.y) * (c.y - a.y) + (c.x * c.x + c.y * c.y) * (a.y - b.y)) / d
	var uy: float = ((a.x * a.x + a.y * a.y) * (c.x - b.x) + (b.x * b.x + b.y * b.y) * (a.x - c.x) + (c.x * c.x + c.y * c.y) * (b.x - a.x)) / d
	return Vector2(ux, uy)


static func sample_arc_3points(a: Vector2, b: Vector2, c: Vector2) -> Array:
	var center: Vector2 = circumcenter(a, b, c)
	if center.x != center.x:
		return [a, b]
	var r: float = a.distance_to(center)
	if r < 0.001:
		return [a, b]
	var ang_a: float = atan2(a.y - center.y, a.x - center.x)
	var ang_b: float = atan2(b.y - center.y, b.x - center.x)
	var ang_c: float = atan2(c.y - center.y, c.x - center.x)
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


static func _angle_between(ang: float, from_a: float, to_b: float) -> bool:
	var span: float = to_b - from_a
	if absf(span) >= TAU:
		return true
	var d: float = ang - from_a
	while d > PI:
		d -= TAU
	while d <= -PI:
		d += TAU
	return (span > 0 and d >= 0 and d <= span) or (span < 0 and d <= 0 and d >= span)


static func point_to_segment_distance(pt: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.0001:
		return pt.distance_to(a)
	var ap: Vector2 = pt - a
	var t: float = clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return pt.distance_to(proj)


static func compute_arc_central_angle(pa: Vector2, pb: Vector2, pc: Vector2) -> float:
	var center: Vector2 = circumcenter(pa, pb, pc)
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


static func distance_to_edge_screen(
	verts: Array[Vector2],
	edges: Array[Dictionary],
	edge_idx: int,
	screen_pos: Vector2,
	rect: Rect2
) -> float:
	var n: int = verts.size()
	if edge_idx < 0 or edge_idx >= n:
		return INF
	var p0: Vector2 = norm_to_screen(verts[edge_idx], rect)
	var p1: Vector2 = norm_to_screen(verts[(edge_idx + 1) % n], rect)
	var edge: Dictionary = edges[edge_idx]
	var is_arc: bool = edge.get("type", "line") == "arc" and edge.has("arc_control")
	if is_arc:
		var ac: Vector2 = norm_to_screen(edge["arc_control"], rect)
		var arc_pts: Array = sample_arc_3points(p0, p1, ac)
		var d: float = INF
		for k in range(arc_pts.size() - 1):
			var seg_d: float = point_to_segment_distance(screen_pos, arc_pts[k], arc_pts[k + 1])
			d = minf(d, seg_d)
		return d
	return point_to_segment_distance(screen_pos, p0, p1)


static func find_nearest_edge_screen(
	verts: Array[Vector2],
	edges: Array[Dictionary],
	screen_pos: Vector2,
	rect: Rect2,
	max_d: float
) -> int:
	var best: int = -1
	var best_d: float = max_d
	for i in range(edges.size()):
		var d: float = distance_to_edge_screen(verts, edges, i, screen_pos, rect)
		if d < best_d:
			best_d = d
			best = i
	return best


static func find_closest_on_arc_norm(
	ga: Vector2,
	gb: Vector2,
	gctrl: Vector2,
	screen_pos: Vector2,
	rect: Rect2
) -> Vector2:
	var sa: Vector2 = norm_to_screen(ga, rect)
	var sb: Vector2 = norm_to_screen(gb, rect)
	var sctrl: Vector2 = norm_to_screen(gctrl, rect)
	var arc_pts: Array = sample_arc_3points(sa, sb, sctrl)
	var best_idx: int = 0
	var best_d: float = screen_pos.distance_to(arc_pts[0])
	for k in range(1, arc_pts.size()):
		var d: float = screen_pos.distance_to(arc_pts[k])
		if d < best_d:
			best_d = d
			best_idx = k
	var closest_screen: Vector2 = arc_pts[best_idx]
	var nn: Vector2 = screen_to_norm_exact(closest_screen, rect)
	nn.x = clampf(nn.x, -1.35, 1.35)
	nn.y = clampf(nn.y, -1.35, 1.35)
	return nn


static func add_point_on_edge(
	verts: Array[Vector2],
	edges: Array[Dictionary],
	edge_idx: int,
	screen_pos: Vector2,
	rect: Rect2,
	as_arc: bool
) -> void:
	var n: int = verts.size()
	if edge_idx < 0 or edge_idx >= n:
		return
	var p0: Vector2 = verts[edge_idx]
	var p1: Vector2 = verts[(edge_idx + 1) % n]
	var grid_pos: Vector2
	if as_arc and edges[edge_idx].get("type", "line") == "arc" and edges[edge_idx].has("arc_control"):
		grid_pos = find_closest_on_arc_norm(p0, p1, edges[edge_idx]["arc_control"], screen_pos, rect)
	else:
		var p0s: Vector2 = norm_to_screen(p0, rect)
		var p1s: Vector2 = norm_to_screen(p1, rect)
		var ab: Vector2 = p1s - p0s
		var len_sq: float = ab.length_squared()
		var proj: Vector2
		if len_sq < 0.0001:
			proj = p0s
		else:
			var t: float = clampf((screen_pos - p0s).dot(ab) / len_sq, 0.0, 1.0)
			proj = p0s + ab * t
		var proj_norm: Vector2 = screen_to_norm_exact(proj, rect)
		proj_norm.x = clampf(proj_norm.x, -1.35, 1.35)
		proj_norm.y = clampf(proj_norm.y, -1.35, 1.35)
		if as_arc:
			# 直線辺上に投影だけだと 3 点が共線になり、弧が退化してジグザグになる。クリック側へ微小な法線オフセットを入れる
			var seg: Vector2 = p1 - p0
			var seg_len_sq: float = seg.length_squared()
			if seg_len_sq > 1e-12:
				var perp_n: Vector2 = Vector2(-seg.y, seg.x).normalized()
				var mouse_norm: Vector2 = screen_to_norm_exact(screen_pos, rect)
				var mid_n: Vector2 = (p0 + p1) * 0.5
				var toward: float = perp_n.dot(mouse_norm - mid_n)
				var sign_b: float = 1.0 if toward >= 0.0 else -1.0
				var bulge: float = maxf(0.008, minf(0.08, sqrt(seg_len_sq) * 0.06))
				grid_pos = proj_norm + perp_n * bulge * sign_b
			else:
				grid_pos = proj_norm
			grid_pos.x = clampf(grid_pos.x, -1.35, 1.35)
			grid_pos.y = clampf(grid_pos.y, -1.35, 1.35)
		else:
			grid_pos = proj_norm
	if grid_pos.distance_to(p0) < 0.01 or grid_pos.distance_to(p1) < 0.01:
		return
	var idx: int = edge_idx + 1
	verts.insert(idx, grid_pos)
	if as_arc:
		edges.insert(idx, {"type": "arc", "arc_control": p0})
		edges[edge_idx] = {"type": "arc", "arc_control": p1}
	else:
		edges.insert(idx, {"type": "line"})
		edges[edge_idx] = {"type": "line"}


static func delete_point(verts: Array[Vector2], edges: Array[Dictionary], idx: int) -> void:
	if verts.size() <= 3:
		return
	var n: int = verts.size()
	var prev_idx: int = (idx - 1 + n) % n
	verts.remove_at(idx)
	edges.remove_at(idx)
	var update_idx: int = prev_idx if prev_idx < idx else prev_idx - 1
	if update_idx >= 0 and update_idx < edges.size():
		edges[update_idx] = {"type": "line"}


static func fix_arc_chain_controls(verts: Array[Vector2], edges: Array[Dictionary], pt_idx: int) -> void:
	if pt_idx < 0 or verts.size() < 3:
		return
	var n: int = verts.size()
	var prev_e: int = (pt_idx - 1 + n) % n
	var curr_e: int = pt_idx
	var prev_pt: int = (pt_idx - 1 + n) % n
	var next_pt: int = (pt_idx + 1) % n
	var pa: Vector2 = verts[prev_pt]
	var pb: Vector2 = verts[pt_idx]
	var pc: Vector2 = verts[next_pt]
	var circ: Vector2 = circumcenter(pa, pb, pc)
	if circ.x != circ.x:
		return
	var r: float = pa.distance_to(circ)
	if r < 0.001:
		return
	edges[prev_e] = {"type": "arc", "arc_control": verts[next_pt]}
	edges[curr_e] = {"type": "arc", "arc_control": verts[prev_pt]}


static func _angle_on_arc(ang_ctrl: float, ang_a: float, ang_b: float, arc_span: float) -> bool:
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


static func update_arc_control_for_angle(
	verts: Array[Vector2],
	edges: Array[Dictionary],
	edge_idx: int,
	angle_rad: float,
	rect: Rect2,
	original_center_screen: Variant,
	previous_center_screen: Variant
) -> Variant:
	if edge_idx < 0 or edge_idx >= edges.size():
		return null
	var edge: Dictionary = edges[edge_idx]
	if edge.get("type", "line") != "arc":
		return null
	var n: int = verts.size()
	var ga: Vector2 = verts[edge_idx]
	var gb: Vector2 = verts[(edge_idx + 1) % n]
	var sa: Vector2 = norm_to_screen(ga, rect)
	var sb: Vector2 = norm_to_screen(gb, rect)
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
	var old_ctrl_screen: Vector2 = norm_to_screen(edge["arc_control"], rect)
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
	var comp_span: float = TAU - angle_rad
	var arc_end: float = ang_a + (angle_rad if delta > 0 else -angle_rad)
	var ang_mid: float = arc_end + (comp_span * 0.5 if delta > 0 else -comp_span * 0.5)
	var mid_screen: Vector2 = center + Vector2(cos(ang_mid), sin(ang_mid)) * r
	var new_ctrl: Vector2 = screen_to_norm_exact(mid_screen, rect)
	if new_ctrl.distance_to(ga) < 0.0005 or new_ctrl.distance_to(gb) < 0.0005:
		var ang_third: float = arc_end + (comp_span * 0.33 if delta > 0 else -comp_span * 0.33)
		mid_screen = center + Vector2(cos(ang_third), sin(ang_third)) * r
		new_ctrl = screen_to_norm_exact(mid_screen, rect)
	edges[edge_idx]["arc_control"] = new_ctrl
	return center


static func apply_left_drag_arc_update(
	verts: Array[Vector2],
	edges: Array[Dictionary],
	rect: Rect2,
	single_arc_edge: int,
	single_arc_angle: float,
	both_edges: Array[int],
	both_angles: Array[float],
	both_centers: Array[Vector2],
	both_last_centers: Array[Vector2]
) -> void:
	if single_arc_edge >= 0 and single_arc_angle > 0.0001:
		update_arc_control_for_angle(verts, edges, single_arc_edge, single_arc_angle, rect, null, null)
	elif both_edges.size() >= 2 and both_angles.size() >= 2:
		var orig0: Variant = both_centers[0] if both_centers.size() > 0 and both_centers[0].x == both_centers[0].x else null
		var orig1: Variant = both_centers[1] if both_centers.size() > 1 and both_centers[1].x == both_centers[1].x else null
		var prev0: Variant = both_last_centers[0] if both_last_centers.size() > 0 else null
		var prev1: Variant = both_last_centers[1] if both_last_centers.size() > 1 else null
		if both_angles[0] > 0.0001:
			var c0: Variant = update_arc_control_for_angle(verts, edges, both_edges[0], both_angles[0], rect, orig0, prev0)
			if c0 is Vector2:
				if both_last_centers.size() < 1:
					both_last_centers.append(c0)
				else:
					both_last_centers[0] = c0
		if both_angles[1] > 0.0001:
			var c1: Variant = update_arc_control_for_angle(verts, edges, both_edges[1], both_angles[1], rect, orig1, prev1)
			if c1 is Vector2:
				if both_last_centers.size() < 2:
					both_last_centers.append(c1)
				else:
					both_last_centers[1] = c1


static func ensure_not_on_adjacent_norm(verts: Array[Vector2], dragging_idx: int, grid_pos: Vector2) -> Vector2:
	if dragging_idx < 0 or verts.size() < 3:
		return grid_pos
	var n: int = verts.size()
	var prev_idx: int = (dragging_idx - 1 + n) % n
	var next_idx: int = (dragging_idx + 1) % n
	var prev_pos: Vector2 = verts[prev_idx]
	var next_pos: Vector2 = verts[next_idx]
	if grid_pos.distance_to(prev_pos) < 0.0005 or grid_pos.distance_to(next_pos) < 0.0005:
		var orig: Vector2 = verts[dragging_idx]
		var cands: Array[Vector2] = [
			Vector2(grid_pos.x + 0.02, grid_pos.y), Vector2(grid_pos.x - 0.02, grid_pos.y),
			Vector2(grid_pos.x, grid_pos.y + 0.02), Vector2(grid_pos.x, grid_pos.y - 0.02),
		]
		var best: Vector2 = orig
		var best_d: float = INF
		for c in cands:
			if c.distance_to(prev_pos) < 0.0005 or c.distance_to(next_pos) < 0.0005:
				continue
			var d: float = c.distance_to(grid_pos)
			if d < best_d:
				best_d = d
				best = c
		return best
	return grid_pos


static func get_left_drag_norm(
	verts: Array[Vector2],
	edges: Array[Dictionary],
	rect: Rect2,
	dragging_idx: int,
	screen_mouse: Vector2,
	drag_offset_norm: Vector2
) -> Vector2:
	var result: Vector2 = screen_to_norm_exact(screen_mouse, rect) + drag_offset_norm
	result.x = clampf(result.x, -1.35, 1.35)
	result.y = clampf(result.y, -1.35, 1.35)
	return ensure_not_on_adjacent_norm(verts, dragging_idx, result)


## Edit 保存時の num_points:（直線辺の数）+（曲線辺の数×2）+ 1
static func compute_num_points_from_edges(edges: Array) -> int:
	var n_line: int = 0
	var n_arc: int = 0
	for e in edges:
		if e is Dictionary and e.get("type", "line") == "arc" and e.has("arc_control"):
			n_arc += 1
		else:
			n_line += 1
	return n_line + n_arc * 2 + 1


static func mirror_vertices_edges_horiz(verts: Array[Vector2], edges: Array[Dictionary]) -> void:
	for i in range(verts.size()):
		verts[i].x *= -1.0
	for e in edges:
		if e.get("type", "line") == "arc" and e.has("arc_control"):
			var ac: Vector2 = e["arc_control"]
			e["arc_control"] = Vector2(-ac.x, ac.y)


static func mirror_vertices_edges_vert(verts: Array[Vector2], edges: Array[Dictionary]) -> void:
	for i in range(verts.size()):
		verts[i].y *= -1.0
	for e in edges:
		if e.get("type", "line") == "arc" and e.has("arc_control"):
			var ac: Vector2 = e["arc_control"]
			e["arc_control"] = Vector2(ac.x, -ac.y)


static func build_arc_controls_for_save(edges: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for i in range(edges.size()):
		var e: Dictionary = edges[i]
		if e.get("type", "line") == "arc" and e.has("arc_control"):
			out[str(i)] = e["arc_control"] as Vector2
	return out


## JSON shape ブロックから頂点・辺（STAGE DEBUG 一覧プレビュー用）
static func shape_polygon_vertices_and_edges(sh: Dictionary) -> Dictionary:
	var out: Dictionary = { "ok": false }
	var pv: Variant = sh.get("polygon_vertices", [])
	if typeof(pv) != TYPE_ARRAY:
		return out
	var verts: Array[Vector2] = []
	for p in pv as Array:
		var v2: Variant = CustomStageFile._parse_vec2(p)
		if v2 != null:
			verts.append(v2 as Vector2)
	if verts.size() < 3:
		return out
	var n: int = verts.size()
	var edges: Array[Dictionary] = []
	for j in range(n):
		edges.append({"type": "line"})
	var ac: Variant = sh.get("arc_controls", {})
	if typeof(ac) == TYPE_DICTIONARY:
		for ks in ac as Dictionary:
			var ei: int = int(str(ks))
			var v2: Variant = CustomStageFile._parse_vec2((ac as Dictionary)[ks])
			if v2 != null and ei >= 0 and ei < n:
				edges[ei] = {"type": "arc", "arc_control": v2 as Vector2}
	out["ok"] = true
	out["verts"] = verts
	out["edges"] = edges
	return out
