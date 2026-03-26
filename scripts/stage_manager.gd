# =============================================================================
# StageManager - ステージモジュール
# =============================================================================
# ステージ定義の読み込み、点の生成、メトリクス計算、クリア判定を担当する。

class_name StageManager
extends RefCounted

const STAR_RATIO := 0.382  # inner/outer radius for regular 5-pointed star
# 案F: 複合スコア（平均+最大）
const USE_COMBINED_ARC_ERROR := true
const ARC_ERROR_AVG_WEIGHT := 0.7
const ARC_ERROR_MAX_WEIGHT := 0.3

# 辺・弧ごとハウスドルフ（triangle/circle/square/star/cat_face/fish）
const USE_PER_EDGE_HAUSDORFF := true

# 案2: スケール基準。90=90%タイル、95=95%タイル、100=最大値（理想側の ideal_ref_r 計算用）
const REF_R_PERCENTILE_90 := 90.0
const REF_R_PERCENTILE_95 := 95.0
const REF_R_PERCENTILE := REF_R_PERCENTILE_95
# ガイド固定サイズ: true で目標図形をプレイヤーに追従せず一定サイズ表示（正帰還ループ防止）
# fish のみ例外で代表半径に追従（細長シルエットで固定時が窮屈になりやすいため）
const GUIDE_USE_FIXED_SIZE := true


func _guide_follows_player_radius() -> bool:
	return stage_type == "fish"

# --- Stage state ---
var current_stage: int = 0
var stage_type: String = "circle"
var min_radius: float = 0.0
var max_radius: float = 0.0
var clear_threshold: float = 5.0
var num_points: int = 12
var display_rate_min_pct: float = 50.0  # 実現率表示の下限。min_pct～目標 を 0～100 にマッピング

# --- Circle metrics (primary / group 1) ---
var current_centroid: Vector2 = Vector2.ZERO
var current_avg_radius: float = 0.0
var current_circularity_error: float = 100.0
var current_circularity: float = 0.0
var current_smoothness_error: float = 100.0
var current_smoothness: float = 0.0

# --- Two circles (group 2) ---
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
var polygon_rotation: float = -PI / 2.0  # 理想形の向き（描いた形に追従）

# --- Correspondence (square, cat_face) 案C: 点対応マッチング ---
var ideal_points: Array = []  # 理想点（原点中心）。start_stage で設定
var ideal_outline_points: Array = []  # cat_face: 描画用（弧を細かくサンプルした頂点）
var correspondence_scale: float = 1.0
var correspondence_rotation: float = 0.0

# --- Guide ---
var guide_center_1: Vector2 = Vector2.ZERO
var guide_center_2: Vector2 = Vector2.ZERO
var guide_radius_val: float = 0.0
var ideal_display_radius: float = 0.0   # 理想形描画用。GUIDE_USE_FIXED_SIZE なら guide_radius_val
var ideal_display_radius_2: float = 0.0  # two_circles 用


func start_stage(idx: int, shape_center: Vector2, viewport_size: Vector2, point_positions: Array[Vector2]) -> void:
	current_stage = idx
	ideal_outline_points.clear()
	var stages: Array = StageData.get_stages()
	var cfg: Dictionary = stages[idx]
	stage_type = cfg.get("type", "circle")
	min_radius = cfg["min_radius"]
	max_radius = cfg["max_radius"]
	num_points = cfg["num_points"]
	clear_threshold = 100.0 - cfg["clear_pct"]
	display_rate_min_pct = cfg.get("display_rate_min_pct", 50.0)

	guide_radius_val = (min_radius + max_radius) / 2.0
	guide_center_1 = shape_center

	point_positions.clear()
	ideal_points.clear()
	match stage_type:
		"triangle":
			var vr: Array = cfg["vertex_range"]
			var n_verts: int = randi_range(vr[0], vr[1])
			_generate_polygon_group(shape_center, point_positions, num_points, n_verts, cfg["variance"], cfg["zigzag"], -PI / 2.0)
			ideal_outline_points = _build_triangle_outline()
		"circle":
			_generate_circle_shape(shape_center, point_positions, cfg)
			correspondence_scale = guide_radius_val
		"two_circles":
			_generate_two_circles(cfg, point_positions, viewport_size)
			ideal_outline_points = _build_circle_outline()
		"star":
			_generate_star_polygon_shape(shape_center, point_positions, cfg)
			correspondence_scale = guide_radius_val
		"square":
			_generate_square_shape(shape_center, point_positions, cfg)
			ideal_outline_points = _build_square_outline()
			correspondence_scale = guide_radius_val
		"cat_face":
			_generate_cat_face_shape(shape_center, point_positions, cfg)
			correspondence_scale = guide_radius_val
		"fish":
			_generate_fish_shape(shape_center, point_positions, cfg)
			correspondence_scale = guide_radius_val
		"heptagram":
			_generate_heptagram_polygon_shape(shape_center, point_positions, cfg)
			correspondence_scale = guide_radius_val
		"heptagram_silhouette":
			_generate_heptagram_silhouette_polygon_shape(shape_center, point_positions, cfg)
			correspondence_scale = guide_radius_val

	group1_cleared = false
	group2_cleared = false
	ideal_display_radius = guide_radius_val
	ideal_display_radius_2 = guide_radius_val
	calculate_metrics(point_positions)


func _generate_polygon_group(center: Vector2, pts: Array[Vector2], n_pts: int, n_verts: int, variance_factor: float, zigzag_factor: float, angle_offset: float = 0.0) -> void:
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance: float = (max_radius - min_radius) * variance_factor

	var v_angles: Array[float] = []
	var v_dists: Array[float] = []

	for i in range(n_verts):
		var base_angle: float = fposmod(TAU * i / n_verts + angle_offset, TAU)
		var jitter: float = TAU / n_verts * 0.25
		v_angles.append(fposmod(base_angle + randf_range(-jitter, jitter), TAU))
		v_dists.append(base_r + randf_range(-variance, variance))

	var pairs: Array = []
	for i in range(n_verts):
		pairs.append({"a": v_angles[i], "d": v_dists[i]})
	pairs.sort_custom(func(a, b): return a["a"] < b["a"])

	v_angles.clear()
	v_dists.clear()
	for p in pairs:
		v_angles.append(p["a"])
		v_dists.append(p["d"])

	for i in range(n_pts):
		var angle: float = TAU * i / n_pts
		var dist: float = _interp_distance(angle, v_angles, v_dists)

		var zigzag_dir: float = 1.0 if i % 2 == 0 else -1.0
		var zigzag_amount: float = zigzag_factor * base_r * zigzag_dir * randf_range(0.5, 1.0)
		dist += zigzag_amount

		pts.append(center + Vector2(cos(angle), sin(angle)) * dist)


func _generate_two_circles(cfg: Dictionary, pts: Array[Vector2], vp: Vector2) -> void:
	var sizes: Array = cfg["group_sizes"]
	group_split = sizes[0]

	var right_x: float = vp.x * GameConfig.UI_WIDTH_RATIO
	var right_w: float = vp.x * 0.75
	var center1 := Vector2(right_x + right_w * 0.35, vp.y * 0.35)
	var center2 := Vector2(right_x + right_w * 0.65, vp.y * 0.65)
	guide_center_1 = center1
	guide_center_2 = center2

	var vr: Array = cfg["vertex_range"]
	_generate_polygon_group(center1, pts, sizes[0], randi_range(vr[0], vr[1]), cfg["variance"], cfg["zigzag"])
	_generate_polygon_group(center2, pts, sizes[1], randi_range(vr[0], vr[1]), cfg["variance"], cfg["zigzag"])


func _generate_circle_shape(center: Vector2, pts: Array[Vector2], cfg: Dictionary) -> void:
	"""円（4頂点・全辺弧）の理想点を生成"""
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance_factor: float = cfg.get("variance", 0.35)
	var n: int = num_points

	var verts: Array = get_circle_polygon_vertices()
	var arc_ctrls: Dictionary = get_circle_arc_controls()
	ideal_points = _sample_points_on_polygon_with_arcs(verts, arc_ctrls, n)
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls)
	var c := _perimeter_centroid(ideal_outline_points)
	var max_d: float = 0.001
	for p in ideal_points:
		max_d = maxf(max_d, (p - c).length())
	for p in ideal_outline_points:
		max_d = maxf(max_d, (p - c).length())
	var normalized_ideal: Array = []
	for p in ideal_points:
		normalized_ideal.append((p - c) / max_d)
	ideal_points = normalized_ideal
	var normalized_outline: Array = []
	for p in ideal_outline_points:
		normalized_outline.append((p - c) / max_d)
	ideal_outline_points = normalized_outline

	for i in range(n):
		var ideal: Vector2 = ideal_points[i]
		var noise: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * variance_factor
		pts.append(center + (ideal + noise) * base_r)


func _generate_star_polygon_shape(center: Vector2, pts: Array[Vector2], cfg: Dictionary) -> void:
	"""星（10頂点・全辺直線）の理想点を生成"""
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance_factor: float = cfg.get("variance", 0.55)
	var n: int = num_points

	var verts: Array = get_star_polygon_vertices()
	var arc_ctrls: Dictionary = get_star_arc_controls()
	ideal_points = _sample_points_on_polygon_with_arcs(verts, arc_ctrls, n)
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls)
	var c := _perimeter_centroid(ideal_outline_points)
	var max_d: float = 0.001
	for p in ideal_points:
		max_d = maxf(max_d, (p - c).length())
	for p in ideal_outline_points:
		max_d = maxf(max_d, (p - c).length())
	var normalized_ideal: Array = []
	for p in ideal_points:
		normalized_ideal.append((p - c) / max_d)
	ideal_points = normalized_ideal
	var normalized_outline: Array = []
	for p in ideal_outline_points:
		normalized_outline.append((p - c) / max_d)
	ideal_outline_points = normalized_outline

	for i in range(n):
		var ideal: Vector2 = ideal_points[i]
		var noise: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * variance_factor
		pts.append(center + (ideal + noise) * base_r)


func _generate_star_shape(center: Vector2, pts: Array[Vector2], zigzag_factor: float) -> void:
	"""旧星生成（two_circles 等で _build_star_outline を使う場合のフォールバック）"""
	var base_r: float = (min_radius + max_radius) / 2.0
	for i in range(num_points):
		var angle: float = TAU * i / num_points
		var ideal_d: float = _star_distance_at_angle(angle, -PI / 2.0, base_r, base_r * STAR_RATIO)
		var noise: float = ideal_d * zigzag_factor * randf_range(-1.0, 1.0)
		pts.append(center + Vector2(cos(angle), sin(angle)) * (ideal_d + noise))


func _generate_square_shape(center: Vector2, pts: Array[Vector2], cfg: Dictionary) -> void:
	"""案C: 正方形の理想点を生成し、変形版をプレイ開始用に作成"""
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance_factor: float = cfg.get("variance", 0.20)
	var n: int = num_points

	ideal_points.clear()
	for i in range(n):
		var t: float = float(i) / float(n)
		var side: int = int(t * 4) % 4
		var u: float = (t * 4.0) - floor(t * 4.0)
		var v: Vector2
		match side:
			0: v = Vector2(lerpf(-1.0, 1.0, u), -1.0)  # 下辺
			1: v = Vector2(1.0, lerpf(-1.0, 1.0, u))   # 右辺
			2: v = Vector2(lerpf(1.0, -1.0, u), 1.0)   # 上辺
			_: v = Vector2(-1.0, lerpf(1.0, -1.0, u))  # 左辺
		var ideal: Vector2 = v * (1.0 / sqrt(2.0))
		ideal_points.append(ideal)
		var noise: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * variance_factor
		pts.append(center + (ideal + noise) * base_r)


func _generate_cat_face_shape(center: Vector2, pts: Array[Vector2], cfg: Dictionary) -> void:
	"""案C: ねこの顔の理想点を生成。直線エッジと弧エッジを分けて処理"""
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance_factor: float = cfg.get("variance", 0.15)
	var n: int = num_points

	var verts: Array = _get_cat_face_polygon_vertices()
	var arc_ctrls: Dictionary = get_cat_face_arc_controls()
	ideal_points = _sample_points_on_polygon_with_arcs(verts, arc_ctrls, n)
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls)
	# 周長の重心で中心化し、同一スケールで正規化（製作中図形とガイドの中心一致用）
	var c := _perimeter_centroid(ideal_outline_points)
	var max_d: float = 0.001
	for p in ideal_points:
		max_d = maxf(max_d, (p - c).length())
	for p in ideal_outline_points:
		max_d = maxf(max_d, (p - c).length())
	var normalized_ideal: Array = []
	for p in ideal_points:
		normalized_ideal.append((p - c) / max_d)
	ideal_points = normalized_ideal
	var normalized_outline: Array = []
	for p in ideal_outline_points:
		normalized_outline.append((p - c) / max_d)
	ideal_outline_points = normalized_outline

	for i in range(n):
		var ideal: Vector2 = ideal_points[i]
		var noise: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * variance_factor
		pts.append(center + (ideal + noise) * base_r)


## 円（circle）の輪郭頂点（4頂点・全辺弧。Shape Grid Editor 出力）
static func get_circle_polygon_vertices() -> Array:
	var v: Array = []
	v.append(Vector2(-1.0000, 0.0000))
	v.append(Vector2(0.0000, -1.0000))
	v.append(Vector2(1.0000, 0.0000))
	v.append(Vector2(0.0000, 1.0000))
	return v


static func get_circle_arc_controls() -> Dictionary:
	var arc_ctrls: Dictionary = {}
	arc_ctrls[0] = Vector2(-0.7071, 0.7071)
	arc_ctrls[1] = Vector2(-0.7071, -0.7071)
	arc_ctrls[2] = Vector2(0.7071, -0.7071)
	arc_ctrls[3] = Vector2(0.7071, 0.7071)
	return arc_ctrls


## 星（star）の輪郭頂点（10頂点・全辺直線。Shape Grid Editor 出力）
static func get_star_polygon_vertices() -> Array:
	var v: Array = []
	v.append(Vector2(0.0000, -0.9645))
	v.append(Vector2(0.3937, -0.4396))
	v.append(Vector2(0.9186, -0.3084))
	v.append(Vector2(0.5249, 0.1509))
	v.append(Vector2(0.5905, 0.8070))
	v.append(Vector2(0.0000, 0.5446))
	v.append(Vector2(-0.5905, 0.8070))
	v.append(Vector2(-0.5249, 0.1509))
	v.append(Vector2(-0.9186, -0.3084))
	v.append(Vector2(-0.3937, -0.4396))
	return v


static func get_star_arc_controls() -> Dictionary:
	return {}


## 七芒星（heptagram）の輪郭頂点（7頂点・全辺直線。Shape Grid Editor で編集）
static func get_heptagram_polygon_vertices() -> Array:
	var v: Array = []
	v.append(Vector2(0.0000, -0.9701))
	v.append(Vector2(0.9701, 0.2425))
	v.append(Vector2(-0.4244, 0.8489))
	v.append(Vector2(-0.7882, -0.6063))
	v.append(Vector2(0.7882, -0.6063))
	v.append(Vector2(0.4244, 0.8489))
	v.append(Vector2(-0.9701, 0.2425))
	return v


static func get_heptagram_arc_controls() -> Dictionary:
	return {}


## 七芒星のシルエット（14頂点・全辺直線。Shape Grid Editor で編集）
static func get_heptagram_silhouette_polygon_vertices() -> Array:
	var v: Array = []
	v.append(Vector2(0.0000, -0.9701))
	v.append(Vector2(0.3032, -0.6063))
	v.append(Vector2(0.7882, -0.6063))
	v.append(Vector2(0.6670, -0.1213))
	v.append(Vector2(0.9701, 0.2425))
	v.append(Vector2(0.5457, 0.4244))
	v.append(Vector2(0.4244, 0.8489))
	v.append(Vector2(0.0000, 0.6670))
	v.append(Vector2(-0.4244, 0.8489))
	v.append(Vector2(-0.5457, 0.4244))
	v.append(Vector2(-0.9701, 0.2425))
	v.append(Vector2(-0.6670, -0.1819))
	v.append(Vector2(-0.7882, -0.6063))
	v.append(Vector2(-0.3032, -0.6063))
	return v


static func get_heptagram_silhouette_arc_controls() -> Dictionary:
	return {}


## ねこの顔の輪郭頂点（Shape Grid Editor 別プロジェクトで編集し出力した頂点を貼り付け）
static func get_cat_face_polygon_vertices() -> Array:
	"""頂点のみ（0-1-2-3-4-5-6）。直線は点、弧は端点のみ"""
	var v: Array = []
	v.append(Vector2(-0.5625, 0.0156))
	v.append(Vector2(-0.4219, -0.4063))
	v.append(Vector2(-0.1406, -0.1250))
	v.append(Vector2(0.1406, -0.1250))
	v.append(Vector2(0.4219, -0.4063))
	v.append(Vector2(0.5625, 0.0156))
	v.append(Vector2(0.0000, 1.0000))
	return v


## 弧エッジの arc_control（Shape Grid Editor の出力で arc_ctrls を貼り付け）
static func get_cat_face_arc_controls() -> Dictionary:
	"""エッジ番号 → arc_control。5→6 と 6→0 が弧の場合、{5: ..., 6: ...}"""
	var arc_ctrls: Dictionary = {}
	# 以下をエクスポート出力で置換:
	arc_ctrls[5] = Vector2(-0.5625, 0.0156)
	arc_ctrls[6] = Vector2(0.5625, 0.0156)
	return arc_ctrls




func _get_cat_face_polygon_vertices() -> Array:
	return get_cat_face_polygon_vertices()


## さかなの輪郭頂点（線が交差する形状。回転非対応・弧誤差のみで評価）
static func get_fish_polygon_vertices() -> Array:
	"""頂点（0-1-2-3-4-5-6）。全エッジ直線。尾で線が交差"""
	var v: Array = []
	v.append(Vector2(-0.9791, -0.0000))
	v.append(Vector2(-0.5983, -0.3807))
	v.append(Vector2(0.1632, -0.3807))
	v.append(Vector2(0.9247, 0.3807))
	v.append(Vector2(0.9247, -0.3807))
	v.append(Vector2(0.1632, 0.3807))
	v.append(Vector2(-0.5983, 0.3807))
	return v


static func get_fish_arc_controls() -> Dictionary:
	"""弧エッジなし"""
	return {}


func _generate_fish_shape(center: Vector2, pts: Array[Vector2], cfg: Dictionary) -> void:
	"""さかなの理想点を生成。全エッジ直線"""
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance_factor: float = cfg.get("variance", 0.15)
	var n: int = num_points

	var verts: Array = get_fish_polygon_vertices()
	var arc_ctrls: Dictionary = get_fish_arc_controls()
	ideal_points = _sample_points_on_polygon_with_arcs(verts, arc_ctrls, n)
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls)
	var c := _perimeter_centroid(ideal_outline_points)
	var max_d: float = 0.001
	for p in ideal_points:
		max_d = maxf(max_d, (p - c).length())
	for p in ideal_outline_points:
		max_d = maxf(max_d, (p - c).length())
	var normalized_ideal: Array = []
	for p in ideal_points:
		normalized_ideal.append((p - c) / max_d)
	ideal_points = normalized_ideal
	var normalized_outline: Array = []
	for p in ideal_outline_points:
		normalized_outline.append((p - c) / max_d)
	ideal_outline_points = normalized_outline

	for i in range(n):
		var ideal: Vector2 = ideal_points[i]
		var noise: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * variance_factor
		pts.append(center + (ideal + noise) * base_r)


func _generate_heptagram_polygon_shape(center: Vector2, pts: Array[Vector2], cfg: Dictionary) -> void:
	"""七芒星（14頂点・全辺直線）の理想点を生成"""
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance_factor: float = cfg.get("variance", 0.50)
	var n: int = num_points

	var verts: Array = get_heptagram_polygon_vertices()
	var arc_ctrls: Dictionary = get_heptagram_arc_controls()
	ideal_points = _sample_points_on_polygon_with_arcs(verts, arc_ctrls, n)
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls)
	var c := _perimeter_centroid(ideal_outline_points)
	var max_d: float = 0.001
	for p in ideal_points:
		max_d = maxf(max_d, (p - c).length())
	for p in ideal_outline_points:
		max_d = maxf(max_d, (p - c).length())
	var normalized_ideal: Array = []
	for p in ideal_points:
		normalized_ideal.append((p - c) / max_d)
	ideal_points = normalized_ideal
	var normalized_outline: Array = []
	for p in ideal_outline_points:
		normalized_outline.append((p - c) / max_d)
	ideal_outline_points = normalized_outline

	for i in range(n):
		var ideal: Vector2 = ideal_points[i]
		var noise: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * variance_factor
		pts.append(center + (ideal + noise) * base_r)


func _generate_heptagram_silhouette_polygon_shape(center: Vector2, pts: Array[Vector2], cfg: Dictionary) -> void:
	"""七芒星のシルエット（14頂点・全辺直線）の理想点を生成"""
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance_factor: float = cfg.get("variance", 0.50)
	var n: int = num_points

	var verts: Array = get_heptagram_silhouette_polygon_vertices()
	var arc_ctrls: Dictionary = get_heptagram_silhouette_arc_controls()
	ideal_points = _sample_points_on_polygon_with_arcs(verts, arc_ctrls, n)
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls)
	var c := _perimeter_centroid(ideal_outline_points)
	var max_d: float = 0.001
	for p in ideal_points:
		max_d = maxf(max_d, (p - c).length())
	for p in ideal_outline_points:
		max_d = maxf(max_d, (p - c).length())
	var normalized_ideal: Array = []
	for p in ideal_points:
		normalized_ideal.append((p - c) / max_d)
	ideal_points = normalized_ideal
	var normalized_outline: Array = []
	for p in ideal_outline_points:
		normalized_outline.append((p - c) / max_d)
	ideal_outline_points = normalized_outline

	for i in range(n):
		var ideal: Vector2 = ideal_points[i]
		var noise: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * variance_factor
		pts.append(center + (ideal + noise) * base_r)


func _circumcenter(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	"""3点を通る円の中心"""
	var d: float = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 0.0001:
		return Vector2(NAN, NAN)
	var ux: float = ((a.x * a.x + a.y * a.y) * (b.y - c.y) + (b.x * b.x + b.y * b.y) * (c.y - a.y) + (c.x * c.x + c.y * c.y) * (a.y - b.y)) / d
	var uy: float = ((a.x * a.x + a.y * a.y) * (c.x - b.x) + (b.x * b.x + b.y * b.y) * (a.x - c.x) + (c.x * c.x + c.y * c.y) * (b.x - a.x)) / d
	return Vector2(ux, uy)


func _angle_between(ang: float, from_a: float, to_b: float) -> bool:
	"""ang が from_a から to_b への弧上にあるか"""
	var span: float = to_b - from_a
	if absf(span) >= TAU:
		return true
	var d: float = ang - from_a
	while d > PI:
		d -= TAU
	while d <= -PI:
		d += TAU
	return (span > 0 and d >= 0 and d <= span) or (span < 0 and d <= 0 and d >= span)


func _sample_arc(a: Vector2, b: Vector2, ac: Vector2, num_samples: int) -> Array:
	"""3点で決まる円の弧 a→b（acを通らない方）を num_samples 点でサンプル"""
	var center: Vector2 = _circumcenter(a, b, ac)
	if center.x != center.x:
		return [a, b]
	var r: float = a.distance_to(center)
	if r < 0.001:
		return [a, b]
	var ang_a: float = atan2(a.y - center.y, a.x - center.x)
	var ang_b: float = atan2(b.y - center.y, b.x - center.x)
	var ang_ac: float = atan2(ac.y - center.y, ac.x - center.x)
	var delta: float = ang_b - ang_a
	while delta > PI:
		delta -= TAU
	while delta <= -PI:
		delta += TAU
	# ac が短い弧上にあれば長い弧を描く（ac を通らない弧を描く）
	var c_on_short: bool = _angle_between(ang_ac, ang_a, ang_a + delta)
	if c_on_short:
		delta = delta - TAU if delta > 0 else delta + TAU
	var result: Array = []
	for k in range(num_samples + 1):
		var t: float = float(k) / float(num_samples)
		var ang: float = ang_a + delta * t
		result.append(center + Vector2(cos(ang), sin(ang)) * r)
	return result


func _sample_points_on_polygon_with_arcs(verts: Array, arc_ctrls: Dictionary, n: int) -> Array:
	"""多角形の周上に n 点を等間隔でサンプル。弧エッジは弧に沿ってサンプル"""
	if verts.size() < 2:
		return []
	var seg_lengths: Array = []
	var total: float = 0.0
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		var len: float
		if arc_ctrls.has(i):
			var arc_pts: Array = _sample_arc(p1, p2, arc_ctrls[i], 16)
			len = 0.0
			for k in range(arc_pts.size() - 1):
				len += arc_pts[k].distance_to(arc_pts[k + 1])
		else:
			len = p1.distance_to(p2)
		total += len
		seg_lengths.append({"start": total - len, "end": total, "p1": p1, "p2": p2, "arc_ac": arc_ctrls.get(i, null)})
	if total < 0.001:
		return []
	var result: Array = []
	for i in range(n):
		var t: float = (float(i) / float(n)) * total
		if t >= total:
			t = total - 0.001
		for seg in seg_lengths:
			if t <= seg["end"]:
				var local_t: float = (t - seg["start"]) / (seg["end"] - seg["start"]) if (seg["end"] - seg["start"]) > 0.001 else 0.0
				local_t = clampf(local_t, 0.0, 1.0)
				if seg["arc_ac"] != null:
					var arc_pts: Array = _sample_arc(seg["p1"], seg["p2"], seg["arc_ac"], 16)
					var idx: int = clampi(int(local_t * 16.0), 0, 15)
					var frac: float = clampf(local_t * 16.0 - idx, 0.0, 1.0)
					result.append(arc_pts[idx].lerp(arc_pts[idx + 1], frac))
				else:
					result.append(seg["p1"].lerp(seg["p2"], local_t))
				break
	return result


func _build_cat_face_outline(verts: Array, arc_ctrls: Dictionary) -> Array:
	"""描画用の輪郭頂点（弧を細かくサンプル）"""
	if verts.is_empty():
		return []
	var result: Array = [verts[0]]
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		if arc_ctrls.has(i):
			var arc_pts: Array = _sample_arc(p1, p2, arc_ctrls[i], 24)
			for k in range(1, arc_pts.size()):
				result.append(arc_pts[k])
		else:
			result.append(p2)
	return result


func _build_circle_outline(samples: int = 32) -> Array:
	"""単位円の輪郭（半径1、中心原点）"""
	var result: Array = []
	for i in range(samples):
		var a: float = TAU * float(i) / float(samples)
		result.append(Vector2(cos(a), sin(a)))
	return result


func _build_triangle_outline() -> Array:
	"""正三角形の輪郭（頂点上向き、外接円半径1）。GodotはY+が下なので頂点は(0,-1)"""
	var verts: Array = [
		Vector2(0.0, -1.0),
		Vector2(-sqrt(3.0) / 2.0, 0.5),
		Vector2(sqrt(3.0) / 2.0, 0.5),
	]
	var result: Array = []
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		for k in range(8):
			result.append(p1.lerp(p2, float(k) / 8.0))
	return result


func _build_star_outline() -> Array:
	"""5角星の輪郭（外径1、内径STAR_RATIO、1頂点上向き）"""
	var result: Array = []
	for i in range(10):
		var ang: float = -PI / 2.0 + TAU * float(i) / 10.0
		var r: float = 1.0 if i % 2 == 0 else STAR_RATIO
		result.append(Vector2(cos(ang), sin(ang)) * r)
	return result


func _build_square_outline() -> Array:
	"""正方形の輪郭（辺長sqrt2、中心原点）"""
	var h: float = 1.0 / sqrt(2.0)
	var verts: Array = [
		Vector2(-h, -h),
		Vector2(h, -h),
		Vector2(h, h),
		Vector2(-h, h),
	]
	var result: Array = []
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		for k in range(8):
			result.append(p1.lerp(p2, float(k) / 8.0))
	return result


func _get_outline_edges_for_stage(stage_t: String) -> Array:
	"""辺・弧ごとの点列を返す。Editor由来の「ポイント間を辺または弧で結ぶ」定義。
	two_circles は空を返し、従来方式に任せる。"""
	match stage_t:
		"triangle":
			return _build_triangle_edges()
		"circle":
			return _build_polygon_arc_edges(get_circle_polygon_vertices(), get_circle_arc_controls())
		"square":
			return _build_square_edges()
		"cat_face":
			return _build_polygon_arc_edges(_get_cat_face_polygon_vertices(), get_cat_face_arc_controls())
		"fish":
			return _build_polygon_arc_edges(get_fish_polygon_vertices(), get_fish_arc_controls())
		"star":
			return _build_polygon_arc_edges(get_star_polygon_vertices(), get_star_arc_controls())
		"heptagram":
			return _build_polygon_arc_edges(get_heptagram_polygon_vertices(), get_heptagram_arc_controls())
		"heptagram_silhouette":
			return _build_polygon_arc_edges(get_heptagram_silhouette_polygon_vertices(), get_heptagram_silhouette_arc_controls())
		_:
			return []


func _build_triangle_edges() -> Array:
	"""正三角形：3辺。各辺8サンプル"""
	var verts: Array = [
		Vector2(0.0, -1.0),
		Vector2(-sqrt(3.0) / 2.0, 0.5),
		Vector2(sqrt(3.0) / 2.0, 0.5),
	]
	var result: Array = []
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		var edge_pts: Array = []
		for k in range(8):
			edge_pts.append(p1.lerp(p2, float(k) / 8.0))
		result.append(edge_pts)
	return result


func _build_square_edges() -> Array:
	"""正方形：4辺。各辺8サンプル"""
	var h: float = 1.0 / sqrt(2.0)
	var verts: Array = [
		Vector2(-h, -h),
		Vector2(h, -h),
		Vector2(h, h),
		Vector2(-h, h),
	]
	var result: Array = []
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		var edge_pts: Array = []
		for k in range(8):
			edge_pts.append(p1.lerp(p2, float(k) / 8.0))
		result.append(edge_pts)
	return result


func _build_polygon_arc_edges(verts: Array, arc_ctrls: Dictionary) -> Array:
	"""多角形+弧：各辺をサンプル。cat_face/fish用。輪郭と同様に正規化して返す"""
	if verts.size() < 2:
		return []
	var outline: Array = [verts[0]]
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		if arc_ctrls.has(i):
			var arc_pts: Array = _sample_arc(p1, p2, arc_ctrls[i], 24)
			for k in range(1, arc_pts.size()):
				outline.append(arc_pts[k])
		else:
			outline.append(p2)
	var c: Vector2 = _perimeter_centroid(outline)
	var max_d: float = 0.001
	for p in outline:
		max_d = maxf(max_d, (p - c).length())
	var result: Array = []
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		var edge_pts: Array = []
		if arc_ctrls.has(i):
			var arc_pts: Array = _sample_arc(p1, p2, arc_ctrls[i], 24)
			for ap in arc_pts:
				edge_pts.append((ap - c) / max_d)
		else:
			edge_pts.append((p1 - c) / max_d)
			edge_pts.append((p2 - c) / max_d)
		result.append(edge_pts)
	return result


func _sample_points_on_polygon(verts: Array, n: int) -> Array:
	"""多角形の周上に n 点を等間隔でサンプル"""
	var perim: Array = []
	var total: float = 0.0
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		total += p1.distance_to(p2)
		perim.append(total)
	var result: Array = []
	for i in range(n):
		var t: float = (float(i) / float(n)) * total
		if t >= total:
			t = total - 0.001
		var idx: int = 0
		for j in range(perim.size()):
			if t <= perim[j]:
				idx = j
				break
		var p1: Vector2 = verts[idx]
		var p2: Vector2 = verts[(idx + 1) % verts.size()]
		var seg_start: float = 0.0 if idx == 0 else perim[idx - 1]
		var seg_len: float = p1.distance_to(p2)
		var u: float = (t - seg_start) / seg_len if seg_len > 0.001 else 0.0
		result.append(p1.lerp(p2, clampf(u, 0.0, 1.0)))
	return result


func _percentile_distance_from_center(pts: Array, center: Vector2, pct: float) -> float:
	"""点列から center への距離の pct% タイルを返す（0-100）。外れ値除外＋尖り反映"""
	if pts.is_empty():
		return 1.0
	var dists: Array = []
	for p in pts:
		dists.append((p - center).length())
	dists.sort()
	var n: int = dists.size()
	var idx: int = clampi(int(ceil(n * pct / 100.0)) - 1, 0, n - 1)
	return maxf(dists[idx], 1.0)


func _percentile_length_from_origin(pts: Array, pct: float) -> float:
	"""点列の原点からの距離の pct% タイル（理想輪郭用）"""
	if pts.is_empty():
		return 0.001
	var dists: Array = []
	for p in pts:
		dists.append(p.length())
	dists.sort()
	var n: int = dists.size()
	var idx: int = clampi(int(ceil(n * pct / 100.0)) - 1, 0, n - 1)
	return maxf(dists[idx], 0.001)


func _perimeter_centroid(pts: Array) -> Vector2:
	"""周長の重心: 各辺の中点を辺の長さで重み付けして平均"""
	if pts.is_empty():
		return Vector2.ZERO
	if pts.size() == 1:
		return pts[0]
	var sum_weighted := Vector2.ZERO
	var total_len: float = 0.0
	for i in range(pts.size()):
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % pts.size()]
		var seg_len: float = p1.distance_to(p2)
		if seg_len >= 0.001:
			var mid: Vector2 = (p1 + p2) * 0.5
			sum_weighted += mid * seg_len
			total_len += seg_len
	if total_len < 0.001:
		return Vector2.ZERO
	return sum_weighted / total_len


func _min_dist_to_points(p: Vector2, pts: Array) -> float:
	"""点 p から点列 pts のいずれかへの最短距離"""
	var best: float = INF
	for q in pts:
		best = minf(best, p.distance_to(q))
	return best


func _hausdorff_edge_to_user(edge_pts: Array, user_pts: Array) -> float:
	"""有向ハウスドルフ h(edge→user): 辺上の各点からユーザー輪郭（点を結んだ多角形）への距離の最大"""
	var worst: float = 0.0
	for ep in edge_pts:
		# ユーザー「点」ではなく輪郭（閉じたポリライン）への距離を使う
		var d: float = _distance_to_polyline(ep, user_pts)
		worst = maxf(worst, d)
	return worst


func _eval_arc_error_per_edge_hausdorff(curr_scaled: Array, edges: Array, ref_size: float) -> float:
	"""辺・弧ごとに h(edge→user) を算出し、平均で集約。ref_size で正規化して誤差率に"""
	if edges.is_empty():
		return 100.0
	var per_edge_h: Array = []
	for edge_pts in edges:
		per_edge_h.append(_hausdorff_edge_to_user(edge_pts, curr_scaled))
	var sum_h: float = 0.0
	for h in per_edge_h:
		sum_h += h
	var avg_h: float = sum_h / float(edges.size())
	return avg_h / ref_size * 100.0


func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	"""点 p から線分 a-b への最短距離"""
	var ab: Vector2 = b - a
	var ap: Vector2 = p - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.0001:
		return ap.length()
	var t: float = clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return p.distance_to(closest)


func _distance_to_polyline(p: Vector2, polyline: Array) -> float:
	"""点 p から閉じたポリラインへの最短距離（弧を含む輪郭をサンプルした点列に対応）"""
	if polyline.is_empty():
		return INF
	if polyline.size() == 1:
		return p.distance_to(polyline[0])
	var best: float = INF
	for i in range(polyline.size()):
		var a: Vector2 = polyline[i]
		var b: Vector2 = polyline[(i + 1) % polyline.size()]
		best = minf(best, _distance_to_segment(p, a, b))
	return best


func _eval_arc_error(curr: Array, outline: Array, n: int, phi: float, scale: float) -> float:
	"""弧対応誤差: 各ユーザー点から理想輪郭（回転・スケール後）への最短距離の平均"""
	var per_pt: Array = _eval_arc_error_per_point(curr, outline, n, phi, scale)
	var total: float = 0.0
	for d in per_pt:
		total += d
	return total / n


func _eval_arc_error_per_point(curr: Array, outline: Array, n: int, phi: float, scale: float) -> Array:
	"""各ユーザー点から理想輪郭への距離を返す（デバッグ用）"""
	var work: Array = outline
	if outline.size() > 32:
		work = []
		for i in range(0, outline.size(), 2):
			work.append(outline[i])
		if work.size() < 3:
			work = outline
	var cos_p: float = cos(phi)
	var sin_p: float = sin(phi)
	var transformed: Array = []
	for p in work:
		var rp: Vector2 = Vector2(p.x * cos_p - p.y * sin_p, p.x * sin_p + p.y * cos_p) * scale
		transformed.append(rp)
	var result: Array = []
	for j in range(n):
		result.append(_distance_to_polyline(curr[j], transformed))
	return result


func _center_and_normalize_points(pts: Array) -> Array:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var max_d: float = 0.001
	for p in pts:
		max_d = maxf(max_d, (p - c).length())
	var result: Array = []
	for p in pts:
		result.append((p - c) / max_d)
	return result


func _center_and_normalize_by_perimeter(pts: Array) -> Array:
	"""周長の重心で中心化し、最大距離で正規化"""
	var c := _perimeter_centroid(pts)
	var max_d: float = 0.001
	for p in pts:
		max_d = maxf(max_d, (p - c).length())
	var result: Array = []
	for p in pts:
		result.append((p - c) / max_d)
	return result


func _normalize_points_to_match(pts: Array, ref: Array) -> Array:
	"""pts を ref と同じ重心・スケールで正規化（ガイドと描画サイズの一致用）"""
	if ref.is_empty():
		return _center_and_normalize_points(pts)
	var c := Vector2.ZERO
	for p in ref:
		c += p
	c /= ref.size()
	var max_d: float = 0.001
	for p in pts:
		max_d = maxf(max_d, (p - c).length())
	var result: Array = []
	for p in pts:
		result.append((p - c) / max_d)
	return result


func _interp_distance(angle: float, v_a: Array[float], v_d: Array[float]) -> float:
	var n: int = v_a.size()
	for i in range(n):
		var a1: float = v_a[i]
		var a2: float = v_a[(i + 1) % n]
		var d1: float = v_d[i]
		var d2: float = v_d[(i + 1) % n]

		if a2 <= a1:
			a2 += TAU

		var check: float = angle
		if check < a1:
			check += TAU

		if check >= a1 and check < a2:
			var t: float = (check - a1) / (a2 - a1)
			return lerpf(d1, d2, t)

	return v_d[0]


func _star_distance_at_angle(angle: float, rotation: float, outer_r: float, inner_r: float) -> float:
	var verts: Array[Vector2] = []
	for k in range(5):
		verts.append(Vector2(cos(rotation + k * TAU / 5.0), sin(rotation + k * TAU / 5.0)) * outer_r)
		verts.append(Vector2(cos(rotation + TAU / 10.0 + k * TAU / 5.0), sin(rotation + TAU / 10.0 + k * TAU / 5.0)) * inner_r)

	var ray_dx: float = cos(angle)
	var ray_dy: float = sin(angle)
	var best_t: float = -1.0

	for i in range(10):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % 10]
		var ex: float = p2.x - p1.x
		var ey: float = p2.y - p1.y

		var det: float = ray_dy * ex - ray_dx * ey
		if absf(det) < 0.0001:
			continue

		var t: float = (p1.y * ex - p1.x * ey) / det
		var s: float = (ray_dx * p1.y - ray_dy * p1.x) / det

		if t > 0.0 and s >= 0.0 and s <= 1.0:
			if best_t < 0.0 or t < best_t:
				best_t = t

	return best_t if best_t > 0.0 else outer_r


func _set_correspondence_scale_from_outline() -> void:
	"""ideal_outline_points から correspondence_scale を設定（get_point_accuracy_alpha 用）"""
	var ideal_ref_r: float = _percentile_length_from_origin(ideal_outline_points, REF_R_PERCENTILE)
	if GUIDE_USE_FIXED_SIZE:
		correspondence_scale = guide_radius_val / ideal_ref_r
	else:
		correspondence_scale = current_avg_radius / ideal_ref_r
	correspondence_rotation = 0.0


func calculate_metrics(point_positions: Array[Vector2]) -> void:
	"""全図形で統一: 弧誤差のみ、回転非対応"""
	match stage_type:
		"triangle", "circle":
			var m: Dictionary = _calc_unified_arc_metrics(point_positions, 0, point_positions.size())
			current_centroid = m["centroid"]
			current_avg_radius = m["avg_r"]
			ideal_display_radius = guide_radius_val if GUIDE_USE_FIXED_SIZE else current_avg_radius
			current_circularity_error = m["circ_err"]
			current_circularity = m["circ"]
			current_smoothness_error = 0.0
			current_smoothness = 100.0
			_set_correspondence_scale_from_outline()
			if stage_type == "triangle":
				polygon_rotation = -PI / 2.0  # 頂点上向きでガイド表示
		"two_circles":
			var m1: Dictionary = _calc_unified_arc_metrics(point_positions, 0, group_split)
			current_centroid = m1["centroid"]
			current_avg_radius = m1["avg_r"]
			ideal_display_radius = guide_radius_val if GUIDE_USE_FIXED_SIZE else current_avg_radius
			current_circularity_error = m1["circ_err"]
			current_circularity = m1["circ"]
			current_smoothness_error = 0.0
			current_smoothness = 100.0

			var m2: Dictionary = _calc_unified_arc_metrics(point_positions, group_split, point_positions.size())
			current_centroid_2 = m2["centroid"]
			current_avg_radius_2 = m2["avg_r"]
			ideal_display_radius_2 = guide_radius_val if GUIDE_USE_FIXED_SIZE else current_avg_radius_2
			current_circularity_error_2 = m2["circ_err"]
			current_circularity_2 = m2["circ"]
			current_smoothness_error_2 = 0.0
			current_smoothness_2 = 100.0
			_set_correspondence_scale_from_outline()
		"square", "star", "cat_face", "fish", "heptagram", "heptagram_silhouette":
			_calculate_unified_arc_metrics(point_positions)


func _calc_unified_arc_metrics(pts: Array[Vector2], from_idx: int, to_idx: int) -> Dictionary:
	"""弧誤差のみ・回転非対応。指定範囲の点群を評価"""
	var n: int = to_idx - from_idx
	if n < 3 or ideal_outline_points.is_empty():
		return {"centroid": Vector2.ZERO, "avg_r": 0.0, "circ_err": 100.0, "circ": 0.0}

	var group_pts: Array = []
	for i in range(from_idx, to_idx):
		group_pts.append(pts[i])

	var centroid := _perimeter_centroid(group_pts)
	var curr: Array = []
	for p in group_pts:
		curr.append(p - centroid)
	var ref_r: float = _percentile_distance_from_center(group_pts, centroid, REF_R_PERCENTILE)
	# 理想輪郭・edges は max_d で正規化（最大距離=1）。プレイヤーも同じスケールに合わせる
	var ideal_max_r: float = 0.001
	for p in ideal_outline_points:
		ideal_max_r = maxf(ideal_max_r, p.length())
	# scale_inv = 1/ref_r でプレイヤーを理想と同じ単位スケール（max≈1）に
	var scale_inv: float = 1.0 / maxf(ref_r, 1.0)
	var curr_scaled: Array = []
	for c in curr:
		curr_scaled.append(c * scale_inv)
	var ref_size: float = maxf(ideal_max_r, 0.001)
	var circ_err: float
	var per_pt: Array = []  # 案F用・デバッグ用
	if USE_PER_EDGE_HAUSDORFF:
		var edges: Array = _get_outline_edges_for_stage(stage_type)
		if not edges.is_empty():
			# 辺・弧ごとハウスドルフ h(edge→user) を平均で集約
			circ_err = _eval_arc_error_per_edge_hausdorff(curr_scaled, edges, ref_size)
		else:
			# circle/two_circles: 辺定義なし → 従来方式
			if USE_COMBINED_ARC_ERROR:
				per_pt = _eval_arc_error_per_point(curr_scaled, ideal_outline_points, n, 0.0, 1.0)
				var avg_d: float = 0.0
				var max_d: float = 0.0
				for d in per_pt:
					avg_d += d
					max_d = maxf(max_d, d)
				avg_d /= n
				var combined: float = ARC_ERROR_AVG_WEIGHT * avg_d + ARC_ERROR_MAX_WEIGHT * max_d
				circ_err = combined / ref_size * 100.0
			else:
				var raw_arc: float = _eval_arc_error(curr_scaled, ideal_outline_points, n, 0.0, 1.0)
				circ_err = raw_arc / ref_size * 100.0
	elif USE_COMBINED_ARC_ERROR:
		# 案F: 複合スコア（辺ハウスドルフ未使用時）
		per_pt = _eval_arc_error_per_point(curr_scaled, ideal_outline_points, n, 0.0, 1.0)
		var avg_d: float = 0.0
		var max_d: float = 0.0
		for d in per_pt:
			avg_d += d
			max_d = maxf(max_d, d)
		avg_d /= n
		var combined: float = ARC_ERROR_AVG_WEIGHT * avg_d + ARC_ERROR_MAX_WEIGHT * max_d
		circ_err = combined / ref_size * 100.0
	else:
		var raw_arc: float = _eval_arc_error(curr_scaled, ideal_outline_points, n, 0.0, 1.0)
		circ_err = raw_arc / ref_size * 100.0

	return {
		"centroid": centroid,
		"avg_r": ref_r,
		"circ_err": circ_err,
		"circ": maxf(0.0, 100.0 - circ_err),
	}


func _calculate_unified_arc_metrics(pts: Array[Vector2]) -> void:
	"""square, cat_face, fish 用。弧誤差（打点分布に依存しない）"""
	var n: int = pts.size()
	if n == 0 or ideal_outline_points.is_empty():
		current_circularity_error = 100.0
		current_circularity = 0.0
		current_smoothness_error = 0.0
		current_smoothness = 100.0
		return

	var m: Dictionary = _calc_unified_arc_metrics(pts, 0, n)
	current_centroid = m["centroid"]
	current_avg_radius = m["avg_r"]
	var use_fixed_guide: bool = GUIDE_USE_FIXED_SIZE and not _guide_follows_player_radius()
	ideal_display_radius = guide_radius_val if use_fixed_guide else current_avg_radius
	current_circularity_error = m["circ_err"]
	current_circularity = m["circ"]
	current_smoothness_error = 0.0
	current_smoothness = 100.0

	var ideal_ref_r: float = _percentile_length_from_origin(ideal_outline_points, REF_R_PERCENTILE)
	if use_fixed_guide:
		correspondence_scale = guide_radius_val / ideal_ref_r
	else:
		correspondence_scale = current_avg_radius / ideal_ref_r
	correspondence_rotation = 0.0
	polygon_rotation = 0.0


func _transform_ideal_point(ideal: Vector2) -> Vector2:
	"""理想点を現在の回転・スケールで変換（平行移動は呼び出し側で加算）"""
	var cos_r: float = cos(correspondence_rotation)
	var sin_r: float = sin(correspondence_rotation)
	return Vector2(
		ideal.x * cos_r - ideal.y * sin_r,
		ideal.x * sin_r + ideal.y * cos_r
	) * correspondence_scale


func get_point_accuracy_alpha(idx: int, point_positions: Array[Vector2]) -> float:
	"""全図形で統一: 理想輪郭への距離から精度を算出"""
	if idx < 0 or idx >= point_positions.size():
		return 1.0
	var p: Vector2 = point_positions[idx]
	var ideal_dist: float
	var ref_r: float = maxf(current_avg_radius, 1.0)

	match stage_type:
		"triangle", "circle":
			var centroid: Vector2 = current_centroid
			var curr_p: Vector2 = p - centroid
			var transformed: Array = []
			for op in ideal_outline_points:
				transformed.append(op * correspondence_scale)
			ideal_dist = _distance_to_polyline(curr_p, transformed)
		"square", "star", "cat_face", "fish", "heptagram", "heptagram_silhouette":
			var ideal_pos: Vector2 = current_centroid + _transform_ideal_point(ideal_points[idx])
			ideal_dist = p.distance_to(ideal_pos)
		"two_circles":
			var centroid: Vector2 = current_centroid_2 if idx >= group_split else current_centroid
			ref_r = current_avg_radius_2 if idx >= group_split else current_avg_radius
			var ideal_ref_r: float = _percentile_length_from_origin(ideal_outline_points, REF_R_PERCENTILE)
			var scale: float = ref_r / ideal_ref_r
			var curr_p: Vector2 = p - centroid
			var transformed: Array = []
			for op in ideal_outline_points:
				transformed.append(op * scale)
			ideal_dist = _distance_to_polyline(curr_p, transformed)
		_:
			return 1.0

	ref_r = maxf(ref_r, 1.0)
	var error_ratio: float = clampf(ideal_dist / ref_r, 0.0, 1.0)
	var accuracy: float = 1.0 - error_ratio

	var alpha: float
	if accuracy < 0.90:
		alpha = 0.25
	elif accuracy < 0.95:
		var t: float = (accuracy - 0.90) / 0.05
		var step: int = mini(int(t * 4.0), 3)
		alpha = 0.35 + step * 0.05
	else:
		var t: float = (accuracy - 0.95) / 0.05
		var step: int = mini(int(t * 4.0), 3)
		alpha = 0.65 + step * 0.1167
	return alpha


func is_locked(idx: int) -> bool:
	if stage_type != "two_circles":
		return false
	if idx < group_split:
		return group1_cleared
	return group2_cleared


func is_group_clear(group: int) -> bool:
	# 実現率100でクリア = current >= goal_pct (clear_pct)
	var goal_pct: float = 100.0 - clear_threshold
	if group == 1:
		return current_circularity >= goal_pct
	else:
		return current_circularity_2 >= goal_pct


func is_clear() -> bool:
	# 実現率100でクリア = current >= goal_pct (clear_pct)
	var goal_pct: float = 100.0 - clear_threshold
	match stage_type:
		"triangle", "circle", "square", "cat_face", "fish", "star", "heptagram", "heptagram_silhouette":
			return current_circularity >= goal_pct
		"two_circles":
			return group1_cleared and group2_cleared
	return false


func set_group1_cleared() -> void:
	group1_cleared = true


func set_group2_cleared() -> void:
	group2_cleared = true


func get_target_center_for_point(idx: int) -> Vector2:
	if stage_type == "two_circles":
		return current_centroid_2 if idx >= group_split else current_centroid
	return current_centroid
