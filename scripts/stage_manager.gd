# =============================================================================
# StageManager - ステージモジュール
# =============================================================================
# ステージ定義の読み込み、点の生成、メトリクス計算、クリア判定を担当する。

class_name StageManager
extends RefCounted

const STAR_RATIO := 0.382  # inner/outer radius for regular 5-pointed star
const CIRCLE_SEGMENTS := 128
# 案F: 複合スコア（平均+最大）
const USE_COMBINED_ARC_ERROR := true
const ARC_ERROR_AVG_WEIGHT := 0.7
const ARC_ERROR_MAX_WEIGHT := 0.3

# 辺・弧ごとハウスドルフ（triangle/circle/square/star/cat_face/fish）
const USE_PER_EDGE_HAUSDORFF := true
## 辺サンプル点を何点おきに間引くか（1=全点使用、2=1点おき、3=2点おき…）。
## 直線辺8点・弧辺6点を前提に設計: 2 で約2×、3 で弧辺3×高速化。
## 端点（先頭・末尾）は sample_step に関わらず必ず評価する。
const HAUSDORFF_SAMPLE_STEP := 1

## cat_face 系の直線辺を square/hex と同様に何分割するか（終点を含む 8 セグメント）
const CAT_FACE_STRAIGHT_EDGE_SAMPLES := 8
## HUD 弧誤差にブレンドする先端（鋭角）ペナルティの割合
const VERTEX_TIP_WEIGHT := 0.3
## 先端とみなす最小の「そり」（内角の補角、度）。これ未満の折れは先端扱いしない
const VERTEX_MIN_TURNING_DEG := 30.0

## 弧を _sample_arc に渡す分割数（num_samples）。全ステージ共通で 6 セグメント
const ARC_OUTLINE_SAMPLES := 6
## 一致度計算時のみ: 弧としてサンプルした閉曲線の辺の距離に掛ける係数（<1 で厳しさ緩和）。直線辺は 1.0
const ARC_SEGMENT_MATCH_LENIENCY_MUL := 0.6

# 案2: スケール基準。90=90%タイル、95=95%タイル、100=最大値（理想側の ideal_ref_r 計算用）
const REF_R_PERCENTILE_90 := 90.0
const REF_R_PERCENTILE_95 := 95.0
const REF_R_PERCENTILE := REF_R_PERCENTILE_95
# ガイド固定サイズ: true で目標図形をプレイヤーに追従せず一定サイズ表示（正帰還ループ防止）
# guide_follows_player_radius が true のとき代表半径に追従（cfg で 0/1、デフォルトは fish のみ 1）
const GUIDE_USE_FIXED_SIZE := true
## HUD 初期配置（正方形）: 各角から重心方向へ寄せる比率（1=角上、小さいほど内側＝引力ですみやすい）
const HUD_SPAWN_SQUARE_CORNER_INWARD := 0.78
## HUD 初期配置（円）: 下半円ガイド上に並べる角度範囲（ラジアン）。画面+y 側（下）に偏る
const HUD_SPAWN_CIRCLE_LOWER_ANGLE_MIN := 0.12 * PI
const HUD_SPAWN_CIRCLE_LOWER_ANGLE_MAX := 0.88 * PI
## HUD 正六角形: ガイド頂点（重心からの距離）に対する KATA 初期頂点の倍率（>1 でガイドより外側）
const HUD_SPAWN_HEX_OUTWARD_MUL := 1.50
## 初期スポーン制約: 画面端から内側この距離以内に入れる（中央に飛び散り防止）
const SPAWN_EDGE_BAND_PX: float = 200.0
## 初期スポーン制約: ガイド輪郭からこの距離以上離れる
const SPAWN_GUIDE_MIN_DIST_PX: float = 100.0

# --- Stage state ---
## 本編進行 index。custom test / rules demo など main 以外は -1。
var current_stage: int = -1
var stage_type: String = "circle"
## StageConfig.guide_follows_player_radius を start_stage で解決した値（描画・_calculate_unified_arc_metrics 用）
var guide_follows_player_radius: bool = false
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

# --- Star ---
var star_rotation: float = 0.0
var star_outer_r: float = 0.0
var star_inner_r: float = 0.0

# --- Polygon (triangle, square) ---
var polygon_rotation: float = -PI / 2.0  # 理想形の向き（描いた形に追従）

# --- Correspondence (square, cat_face) 案C: 点対応マッチング ---
var ideal_points: Array = []  # 理想点（原点中心）。start_stage で設定
var ideal_outline_points: Array = []  # cat_face: 描画用（弧を細かくサンプルした頂点）
## ideal_outline と同じ長さの閉じた輪郭: 辺 i（頂点 i→i+1）が弧サンプル由来なら true
var ideal_outline_segment_is_arc: Array = []
var correspondence_scale: float = 1.0
var correspondence_rotation: float = 0.0
# CustomStageFile / デバッグ用: cfg の shape_polygon_vertices / shape_arc_controls（JSON 由来）
var _cfg_shape_polygon: Array = []
var _cfg_shape_arc: Dictionary = {}

# --- Guide ---
var guide_center_1: Vector2 = Vector2.ZERO
var guide_radius_val: float = 0.0
var ideal_display_radius: float = 0.0   # 理想形描画用。GUIDE_USE_FIXED_SIZE なら guide_radius_val
## start_stage で解決したマージ済み設定（カスタム idx でも game が build_config_for_index に頼らず参照できる）
var effective_config: Dictionary = {}

# --- HUD 固定ガイド（GameConfig.USE_SCREEN_HUD_GUIDE）---
var hud_guide_center: Vector2 = Vector2.ZERO
var hud_guide_scale: float = 1.0
var hud_guide_ref_px: float = 1.0
var hud_guide_outline_world: Array = []
var hud_guide_query_world: Array = []
## hud_guide_outline_world と同じ辺数: 辺が弧サンプル由来か（一致度の弧のみ緩和用）
var hud_guide_segment_is_arc: Array = []
## HUD ガイドの頂点平均などから求めたスポーン基準（自キャラ初期位置・単一閉曲線の KATA 初期円の中心）
var hud_guide_spawn_centroid: Vector2 = Vector2.ZERO
## 単一閉曲線: KATA を載せる初期円半径（ガイド輪郭から重心までの最大距離 × GameConfig.HUD_INITIAL_RING_SCALE_MUL など）
var hud_guide_spawn_ring_radius: float = 1.0
var _hud_layout_vp: Vector2 = Vector2(-1.0, -1.0)
var _hud_layout_sc: Vector2 = Vector2.ZERO
## 画面フィット後の HUD ガイド半径に乗算（1=従来）。rules デモ等で目標円の見た目だけ縮小する。
var hud_guide_layout_scale_mul: float = 1.0

# --- 精度アルファキャッシュ ---
## calculate_metrics() 呼び出し時に全点分の精度アルファを事前計算してキャッシュする。
## 描画パスでの毎フレーム n×O(polyline) 距離計算をゼロにする。
var _accuracy_alpha_cache: PackedFloat32Array = PackedFloat32Array()

# --- Hausdorff 間引き ---
## Hausdorff / HUD 距離計算は重いため、N 回に 1 回だけ実行してキャッシュを再利用する。
const HAUSDORFF_THROTTLE_EVERY: int = 10
var _hausdorff_call_counter: int = 0  # 0 のとき実行
var _run_hausdorff_this_call: bool = true
var _hausdorff_cached_err: float = 0.0


## 閉じた輪郭（末尾＝先頭とみなす）の幾何学的重心。面積ゼロに近いときは頂点の平均
func _hud_outline_area_centroid_or_average(outline: Array) -> Vector2:
	var n: int = outline.size()
	if n == 0:
		return Vector2.ZERO
	if n < 3:
		var s0 := Vector2.ZERO
		for q in outline:
			s0 += q as Vector2
		return s0 / float(n)
	var twice_signed: float = 0.0
	var cx: float = 0.0
	var cy: float = 0.0
	for i in range(n):
		var j: int = (i + 1) % n
		var pi: Vector2 = outline[i] as Vector2
		var pj: Vector2 = outline[j] as Vector2
		var cr: float = pi.x * pj.y - pj.x * pi.y
		twice_signed += cr
		cx += (pi.x + pj.x) * cr
		cy += (pi.y + pj.y) * cr
	var area: float = twice_signed * 0.5
	if absf(area) < 1e-4:
		var s1 := Vector2.ZERO
		for q in outline:
			s1 += q as Vector2
		return s1 / float(n)
	return Vector2(cx / (3.0 * twice_signed), cy / (3.0 * twice_signed))


## KATA 群の重心を hud_guide_spawn_centroid（目標図形の重心）に一致させる
func _align_point_positions_to_guide_centroid(point_positions: Array[Vector2]) -> void:
	if point_positions.is_empty():
		return
	var g: Vector2 = hud_guide_spawn_centroid
	var k := Vector2.ZERO
	for p in point_positions:
		k += p
	k /= float(point_positions.size())
	var d: Vector2 = g - k
	if d.length_squared() < 0.04:
		return
	for i in range(point_positions.size()):
		point_positions[i] += d


func recompute_hud_guide_layout_if_needed(shape_center: Vector2, viewport_size: Vector2) -> void:
	if not GameConfig.USE_SCREEN_HUD_GUIDE:
		return
	if viewport_size == _hud_layout_vp and shape_center.distance_to(_hud_layout_sc) < 0.5:
		return
	recompute_hud_guide_layout(shape_center, viewport_size)


func recompute_hud_guide_layout(shape_center: Vector2, viewport_size: Vector2) -> void:
	hud_guide_center = shape_center
	hud_guide_outline_world.clear()
	hud_guide_query_world.clear()
	hud_guide_segment_is_arc.clear()
	_hud_layout_vp = viewport_size
	_hud_layout_sc = shape_center
	if not GameConfig.USE_SCREEN_HUD_GUIDE:
		return

	var play_w: float = viewport_size.x * (1.0 - GameConfig.UI_WIDTH_RATIO)
	var play_h: float = viewport_size.y
	var margin: float = GameConfig.HUD_GUIDE_MARGIN_FRAC
	var inner_w: float = play_w * (1.0 - 2.0 * margin)
	var inner_h: float = play_h * (1.0 - 2.0 * margin)

	if ideal_outline_points.is_empty():
		hud_guide_scale = guide_radius_val * hud_guide_layout_scale_mul
		hud_guide_ref_px = maxf(hud_guide_scale, 1.0)
		hud_guide_spawn_centroid = shape_center
		hud_guide_spawn_ring_radius = maxf(hud_guide_scale, 1.0) * GameConfig.HUD_INITIAL_RING_SCALE_MUL
		guide_center_1 = hud_guide_spawn_centroid
		_apply_hud_correspondence_scale()
		return

	var rot: float = _hud_outline_rotation_for_layout()
	var cos_r: float = cos(rot)
	var sin_r: float = sin(rot)
	var rotated: Array = []
	for p in ideal_outline_points:
		var pr: Vector2 = p as Vector2
		rotated.append(
			Vector2(pr.x * cos_r - pr.y * sin_r, pr.x * sin_r + pr.y * cos_r)
		)
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	for p in rotated:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var bb_w: float = maxf(max_x - min_x, 0.001)
	var bb_h: float = maxf(max_y - min_y, 0.001)
	var s: float = minf(inner_w / bb_w, inner_h / bb_h) * hud_guide_layout_scale_mul
	hud_guide_scale = s
	for p in rotated:
		hud_guide_outline_world.append(shape_center + p * s)
	if ideal_outline_segment_is_arc.size() == hud_guide_outline_world.size():
		hud_guide_segment_is_arc = ideal_outline_segment_is_arc.duplicate()
	hud_guide_query_world = _make_runtime_query_polyline(hud_guide_outline_world)
	hud_guide_spawn_centroid = _hud_outline_area_centroid_or_average(hud_guide_outline_world)
	hud_guide_ref_px = 0.001
	for q in hud_guide_outline_world:
		hud_guide_ref_px = maxf(hud_guide_ref_px, q.distance_to(hud_guide_spawn_centroid))
	hud_guide_ref_px = maxf(hud_guide_ref_px, 1.0)
	var max_from_c: float = 0.001
	for q in hud_guide_outline_world:
		max_from_c = maxf(max_from_c, hud_guide_spawn_centroid.distance_to(q as Vector2))
	hud_guide_spawn_ring_radius = maxf(max_from_c * GameConfig.HUD_INITIAL_RING_SCALE_MUL, 12.0)
	guide_center_1 = hud_guide_spawn_centroid
	_apply_hud_correspondence_scale()


func _hud_outline_rotation_for_layout() -> float:
	return 0.0


func _apply_hud_correspondence_scale() -> void:
	if not GameConfig.USE_SCREEN_HUD_GUIDE:
		return
	if ideal_outline_points.is_empty():
		return
	correspondence_scale = hud_guide_scale
	if stage_type == "triangle":
		ideal_display_radius = hud_guide_scale


func _regular_hexagon_unit_vertices() -> Array:
	"""正六角形の頂点（外接円半径1・中心原点・上向き頂点から時計回り）"""
	var verts: Array = []
	for k in range(6):
		var a: float = -PI / 2.0 + TAU * float(k) / 6.0
		verts.append(Vector2(cos(a), sin(a)))
	return verts


func _resample_closed_polyline_points(polyline: Array, n: int) -> Array:
	if polyline.is_empty() or n <= 0:
		return []
	if polyline.size() == 1:
		var single: Array = []
		for _i in range(n):
			single.append(polyline[0])
		return single

	var lengths: Array = [0.0]
	var total_len: float = 0.0
	for i in range(polyline.size()):
		var a: Vector2 = polyline[i] as Vector2
		var b: Vector2 = polyline[(i + 1) % polyline.size()] as Vector2
		total_len += a.distance_to(b)
		lengths.append(total_len)

	if total_len <= 0.001:
		var copy_pts: Array = []
		for i in range(n):
			copy_pts.append(polyline[i % polyline.size()])
		return copy_pts

	var result: Array = []
	result.resize(n)
	var seg_idx: int = 0
	var seg_last: int = polyline.size() - 1
	for i in range(n):
		var target_len: float = total_len * float(i) / float(n)
		# ポインタを前方にのみ進める（単調増加なので逆戻りしない）
		while seg_idx < seg_last and lengths[seg_idx + 1] < target_len:
			seg_idx += 1
		var a: Vector2 = polyline[seg_idx] as Vector2
		var b: Vector2 = polyline[(seg_idx + 1) % polyline.size()] as Vector2
		var seg_start: float = lengths[seg_idx]
		var seg_end: float = lengths[seg_idx + 1]
		var denom: float = maxf(seg_end - seg_start, 0.0001)
		var t: float = clampf((target_len - seg_start) / denom, 0.0, 1.0)
		result[i] = a.lerp(b, t)
	return result


func _make_runtime_query_polyline(polyline: Array) -> Array:
	if polyline.size() <= 128:
		return polyline.duplicate()
	return _resample_closed_polyline_points(polyline, 128)


func _keep_points_inside_playfield(pts: Array[Vector2], viewport_size: Vector2) -> void:
	if pts.is_empty():
		return
	# 上下左右 40px マージン
	const PLAY_MARGIN: float = 40.0
	var play_left: float  = PLAY_MARGIN
	var play_right: float = viewport_size.x - PLAY_MARGIN
	var play_top: float   = PLAY_MARGIN
	var play_bottom: float = viewport_size.y - PLAY_MARGIN
	# STAGE/TIME UI 禁忌ゾーン（右上）: HUDボックス左端 + ラベル幅(約130) + 40px余白
	# box_x_base = vp.x - 384 (= right_margin24 + box_w350 + extra10)
	# ラベルはさらに左に ~130px → 禁忌左端 = vp.x - 384 - 130 - 40 = vp.x - 554
	# TIME 下端 = 160 (time_y100 + box_h60)、40px余白 → 禁忌下端 = 200
	var ui_x_left: float   = viewport_size.x - 554.0
	const UI_Y_BOTTOM: float = 200.0  # TIME下端160 + 余白40

	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	for p in pts:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)

	# グループ全体をシフト（基本マージン逸脱を補正）
	var offset := Vector2.ZERO
	if min_x < play_left:
		offset.x = play_left - min_x
	elif max_x > play_right:
		offset.x = play_right - max_x
	if min_y < play_top:
		offset.y = play_top - min_y
	elif max_y > play_bottom:
		offset.y = play_bottom - max_y
	if offset != Vector2.ZERO:
		for i in range(pts.size()):
			pts[i] = pts[i] + offset

	# 個別クランプ: 基本マージン + 右上 UI 禁忌ゾーン
	for i in range(pts.size()):
		var p: Vector2 = pts[i]
		p.x = clampf(p.x, play_left, play_right)
		p.y = clampf(p.y, play_top, play_bottom)
		# 右上 UI 禁忌ゾーン内にある点は UI 下端まで押し下げる
		if p.x >= ui_x_left and p.y < UI_Y_BOTTOM:
			p.y = UI_Y_BOTTOM
		pts[i] = p


## 初期スポーン制約: 各点を
##   ① 画面端から SPAWN_EDGE_BAND_PX 以内（端バンドへ最小移動）
##   ② ガイド輪郭から SPAWN_GUIDE_MIN_DIST_PX 以上離れる
## の条件を満たすよう補正し、最後に playfield 内クランプを掛ける。
func _constrain_spawn_to_edge_band(pts: Array[Vector2], viewport_size: Vector2) -> void:
	if pts.is_empty():
		return
	var vp := viewport_size
	var has_outline: bool = hud_guide_outline_world.size() >= 2
	for i in range(pts.size()):
		var p: Vector2 = pts[i]

		# ① 画面端から SPAWN_EDGE_BAND_PX 以内
		var d_l: float = p.x
		var d_r: float = vp.x - p.x
		var d_t: float = p.y
		var d_b: float = vp.y - p.y
		if minf(minf(d_l, d_r), minf(d_t, d_b)) > SPAWN_EDGE_BAND_PX:
			# 中央にいる → 最小移動量で端バンドへ
			var candidates := [
				Vector2(SPAWN_EDGE_BAND_PX, p.y),
				Vector2(vp.x - SPAWN_EDGE_BAND_PX, p.y),
				Vector2(p.x, SPAWN_EDGE_BAND_PX),
				Vector2(p.x, vp.y - SPAWN_EDGE_BAND_PX),
			]
			var best: Vector2 = candidates[0]
			var best_d: float = p.distance_to(best)
			for c in candidates:
				var cd: float = p.distance_to(c)
				if cd < best_d:
					best_d = cd
					best = c
			p = best

		# ② ガイド輪郭から SPAWN_GUIDE_MIN_DIST_PX 以上離れる
		if has_outline:
			var dist_g: float = _distance_to_polyline(p, hud_guide_outline_world)
			if dist_g < SPAWN_GUIDE_MIN_DIST_PX:
				var away: Vector2 = p - hud_guide_spawn_centroid
				if away.length_squared() < 1e-4:
					away = Vector2.RIGHT
				p += away.normalized() * (SPAWN_GUIDE_MIN_DIST_PX - dist_g)

		pts[i] = p

	# 最終スクリーン内クランプ（既存ロジック流用）
	_keep_points_inside_playfield(pts, viewport_size)


## 円ガイド: 各点をガイド重心からの半径 hud_guide_ref_px（輪郭との整合）の円周上へ投影
func _snap_point_positions_to_hud_circle_ring(point_positions: Array[Vector2]) -> void:
	var c: Vector2 = hud_guide_spawn_centroid
	var r: float = maxf(hud_guide_ref_px, 1.0)
	for q in hud_guide_outline_world:
		r = maxf(r, c.distance_to(q as Vector2))
	for i in range(point_positions.size()):
		var d: Vector2 = point_positions[i] - c
		if d.length_squared() < 1e-10:
			var a: float = TAU * float(i) / float(maxi(point_positions.size(), 1))
			d = Vector2(cos(a), sin(a))
		point_positions[i] = c + d.normalized() * r


## 右上 UI 禁忌で y が動いたあとも、KATA 群の重心がガイド重心に戻るよう keep と整列を交互に 2 回
func _finalize_hud_spawn_points_align_centroid(point_positions: Array[Vector2], viewport_size: Vector2) -> void:
	if point_positions.is_empty():
		return
	_keep_points_inside_playfield(point_positions, viewport_size)
	_align_point_positions_to_guide_centroid(point_positions)
	_keep_points_inside_playfield(point_positions, viewport_size)
	_align_point_positions_to_guide_centroid(point_positions)


## 円ステージ: 周上維持のため keep の後にリングへ投影（重心合わせはしない）
func _finalize_hud_spawn_points_circle_on_guide(point_positions: Array[Vector2], viewport_size: Vector2) -> void:
	if point_positions.is_empty():
		return
	for _k in range(2):
		_keep_points_inside_playfield(point_positions, viewport_size)
		_snap_point_positions_to_hud_circle_ring(point_positions)


## HUD 正方形ガイド: 輪郭の 4 角（各辺先頭サンプル）を world 座標で取得
func _hud_square_corner_world_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var outline: Array = hud_guide_outline_world
	if outline.size() < 32:
		return out
	for k in range(4):
		out.append(outline[k * 8] as Vector2)
	return out


## HUD ひし形: 輪郭サンプル密度は正方形と同一（辺 8 × 4）
func _hud_rhombus_corner_world_positions() -> Array[Vector2]:
	return _hud_square_corner_world_positions()


## ひし形・4 点: 正方形と同じ「角からわずかに内側」初期配置
func _rebuild_initial_points_hud_rhombus_attract_friendly(point_positions: Array[Vector2], _viewport_size: Vector2) -> bool:
	var corners: Array[Vector2] = _hud_rhombus_corner_world_positions()
	if corners.size() != 4:
		return false
	point_positions.clear()
	var cent: Vector2 = hud_guide_spawn_centroid
	var t: float = HUD_SPAWN_SQUARE_CORNER_INWARD
	for i in range(4):
		var cw: Vector2 = corners[i]
		point_positions.append(cent + (cw - cent) * t)
	return true


## HUD 正六角形: 輪郭の 6 頂点（各辺先頭サンプル）を world 座標で取得（辺8サンプル×6＝48点）
func _hud_hex_corner_world_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var outline: Array = hud_guide_outline_world
	if outline.size() < 48:
		return out
	for k in range(6):
		out.append(outline[k * 8] as Vector2)
	return out


## 正六角形・6 点: ガイド頂点より重心方向へ HUD_SPAWN_HEX_OUTWARD_MUL だけ外側（同重心・やや大きい）
func _rebuild_initial_points_hud_hex_ring_outward(point_positions: Array[Vector2], _viewport_size: Vector2) -> bool:
	var corners: Array[Vector2] = _hud_hex_corner_world_positions()
	if corners.size() != 6:
		return false
	point_positions.clear()
	var cent: Vector2 = hud_guide_spawn_centroid
	var mul: float = HUD_SPAWN_HEX_OUTWARD_MUL
	for i in range(6):
		var cw: Vector2 = corners[i]
		var radial: Vector2 = cw - cent
		point_positions.append(cent + radial * mul)
	return true


## 正方形・4 点: 各理想角に対応する位置を、角から重心へ HUD_SPAWN_SQUARE_CORNER_INWARD だけ内側に固定
func _rebuild_initial_points_hud_square_attract_friendly(point_positions: Array[Vector2], _viewport_size: Vector2) -> bool:
	var corners: Array[Vector2] = _hud_square_corner_world_positions()
	if corners.size() != 4:
		return false
	point_positions.clear()
	var cent: Vector2 = hud_guide_spawn_centroid
	var t: float = HUD_SPAWN_SQUARE_CORNER_INWARD
	for i in range(4):
		var cw: Vector2 = corners[i]
		point_positions.append(cent + (cw - cent) * t)
	return true


## 円: ガイド重心からの最大距離＝円半径として周上に全点を置き、角度を下半分（+y 側）に偏らせる
func _rebuild_initial_points_hud_circle_guide_lower_bias(point_positions: Array[Vector2], _viewport_size: Vector2) -> bool:
	var c: Vector2 = hud_guide_spawn_centroid
	var r: float = 0.001
	for q in hud_guide_outline_world:
		r = maxf(r, c.distance_to(q as Vector2))
	r = maxf(r, hud_guide_ref_px)
	if r < 4.0:
		return false
	var n: int = num_points
	if n < 1:
		return false
	point_positions.clear()
	var a0: float = HUD_SPAWN_CIRCLE_LOWER_ANGLE_MIN
	var a1: float = HUD_SPAWN_CIRCLE_LOWER_ANGLE_MAX
	var span: float = maxf(a1 - a0, 0.001)
	for i in range(n):
		var u: float = float(i) / float(maxi(n - 1, 1))
		# 下半円（+y 側）の中央付近に角度を寄せる（等間隔 u を cos で変形）
		var u_c: float = 0.5 * (1.0 - cos(PI * u))
		var a: float = a0 + span * u_c
		point_positions.append(c + Vector2(cos(a), sin(a)) * r)
	return true


func _rebuild_initial_points_from_hud_guide(cfg: Dictionary, viewport_size: Vector2, point_positions: Array[Vector2]) -> void:
	if not GameConfig.USE_SCREEN_HUD_GUIDE:
		return
	point_positions.clear()

	# 正方形: 4 角を理想対応に合わせ、角からわずかに内側（引力ですぐガイドへ）
	if stage_type == "square" and num_points == 4:
		if _rebuild_initial_points_hud_square_attract_friendly(point_positions, viewport_size):
			_finalize_hud_spawn_points_align_centroid(point_positions, viewport_size)
			return

	# ひし形: 正方形と同様（輪郭 32 点・4 角）
	if stage_type == "rhombus" and num_points == 4:
		if _rebuild_initial_points_hud_rhombus_attract_friendly(point_positions, viewport_size):
			_finalize_hud_spawn_points_align_centroid(point_positions, viewport_size)
			return

	# 正六角形: 6 頂点をガイドよりわずかに外側（同重心）
	if stage_type == "hexagon" and num_points == 6:
		if _rebuild_initial_points_hud_hex_ring_outward(point_positions, viewport_size):
			_finalize_hud_spawn_points_align_centroid(point_positions, viewport_size)
			return

	# 円: 全点をガイド円周上に置き、下半分（画面 +y 側）に偏って配置
	if stage_type == "circle":
		if _rebuild_initial_points_hud_circle_guide_lower_bias(point_positions, viewport_size):
			_finalize_hud_spawn_points_circle_on_guide(point_positions, viewport_size)
			return

	# 単一閉曲線ステージ（fish / mug / heptagram_silhouette / rugby_ball 等）ほか、
	# 正方形・六角・円以外: 横長のなめらかな楕円周上に等角度配置（円形リングは使わない）
	var n_pts: int = num_points
	var ring_r: float = maxf(hud_guide_spawn_ring_radius, 12.0)
	var ax: float = ring_r
	var ay: float = ring_r * GameConfig.HUD_SPAWN_ELLIPSE_VERTICAL_FRAC
	for i in range(n_pts):
		var ang: float = TAU * float(i) / float(maxi(n_pts, 1))
		point_positions.append(
			hud_guide_spawn_centroid + Vector2(ax * cos(ang), ay * sin(ang))
		)

	_finalize_hud_spawn_points_align_centroid(point_positions, viewport_size)


func start_stage(idx: int, shape_center: Vector2, viewport_size: Vector2, point_positions: Array[Vector2], cfg_override: Dictionary = {}) -> void:
	var cfg: Dictionary = cfg_override
	if cfg.is_empty():
		var stages: Array = GameConfig.get_play_stage_rows()
		if idx < 0 or idx >= stages.size():
			push_error("StageManager: 無効なステージ index %d" % idx)
			return
		cfg = stages[idx]
	start_stage_with_config(idx, cfg, shape_center, viewport_size, point_positions)


func start_stage_with_config(idx: int, cfg: Dictionary, shape_center: Vector2, viewport_size: Vector2, point_positions: Array[Vector2]) -> void:
	current_stage = int(cfg.get("stage_index", -1))
	ideal_outline_points.clear()
	ideal_outline_segment_is_arc.clear()
	effective_config = cfg.duplicate(true)
	hud_guide_layout_scale_mul = float(cfg.get("hud_guide_layout_scale_mul", 1.0))
	stage_type = str(cfg.get("shape_type", cfg.get("type", "circle")))
	min_radius = cfg["min_radius"]
	max_radius = cfg["max_radius"]
	num_points = cfg["num_points"]
	clear_threshold = 100.0 - cfg["clear_pct"]
	display_rate_min_pct = cfg.get("display_rate_min_pct", 50.0)
	guide_follows_player_radius = StageConfig.resolve_guide_follows_player_radius(cfg, stage_type)

	guide_radius_val = (min_radius + max_radius) / 2.0
	guide_center_1 = shape_center
	hud_guide_spawn_centroid = shape_center
	hud_guide_spawn_ring_radius = maxf(guide_radius_val * GameConfig.HUD_INITIAL_RING_SCALE_MUL, 12.0)

	_cfg_shape_polygon.clear()
	_cfg_shape_arc.clear()
	if cfg.has("shape_polygon_vertices"):
		_cfg_shape_polygon = _parse_polygon_vertices_from_cfg(cfg["shape_polygon_vertices"])
	if cfg.has("shape_arc_controls"):
		_cfg_shape_arc = _parse_arc_controls_from_cfg(cfg["shape_arc_controls"])

	point_positions.clear()
	ideal_points.clear()
	match stage_type:
		"triangle":
			var vr: Array = cfg["vertex_range"]
			var n_verts: int = randi_range(vr[0], vr[1])
			_generate_polygon_group(shape_center, point_positions, num_points, n_verts, cfg["variance"], cfg["zigzag"], -PI / 2.0)
			ideal_outline_points = _build_triangle_outline()
			ideal_outline_segment_is_arc = _outline_segments_all_straight(ideal_outline_points.size())
		"circle":
			_generate_circle_shape(shape_center, point_positions, cfg)
			correspondence_scale = guide_radius_val
		"star":
			_generate_star_polygon_shape(shape_center, point_positions, cfg)
			correspondence_scale = guide_radius_val
		"square":
			_generate_square_shape(shape_center, point_positions, cfg)
			ideal_outline_points = _build_square_outline()
			ideal_outline_segment_is_arc = _outline_segments_all_straight(ideal_outline_points.size())
			correspondence_scale = guide_radius_val
		"rhombus":
			_generate_rhombus_shape(shape_center, point_positions, cfg)
			var b_rh: float = float(cfg.get("rhombus_vertical_half", 0.5))
			ideal_outline_points = _build_rhombus_outline(b_rh)
			ideal_outline_segment_is_arc = _outline_segments_all_straight(ideal_outline_points.size())
			correspondence_scale = guide_radius_val
		"hexagon":
			_generate_hexagon_shape(shape_center, point_positions, cfg)
			ideal_outline_points = _build_hexagon_outline()
			ideal_outline_segment_is_arc = _outline_segments_all_straight(ideal_outline_points.size())
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
		"rugby_ball":
			_generate_rugby_ball_polygon_shape(shape_center, point_positions, cfg)
			correspondence_scale = guide_radius_val
		_:
			push_error("StageManager: 未対応の type '%s'" % stage_type)
			return

	ideal_display_radius = guide_radius_val
	var skip_hud_initial_layout: bool = bool(cfg.get("skip_hud_initial_layout", false))
	if GameConfig.USE_SCREEN_HUD_GUIDE:
		recompute_hud_guide_layout(shape_center, viewport_size)
	if not skip_hud_initial_layout:
		_rebuild_initial_points_from_hud_guide(cfg, viewport_size, point_positions)
	if current_stage >= 0 and stage_type not in ["triangle", "square", "hexagon", "circle"]:
		_constrain_spawn_to_edge_band(point_positions, viewport_size)
	# ステージ切り替え時は前ステージのキャッシュを破棄し、必ずフル計算を行う
	_hausdorff_call_counter = 0
	_hausdorff_cached_err = 100.0
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


func _generate_circle_shape(center: Vector2, pts: Array[Vector2], cfg: Dictionary) -> void:
	"""円（4頂点・全辺弧）の理想点を生成"""
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance_factor: float = cfg.get("variance", 0.35)
	var n: int = num_points

	var verts: Array = get_circle_polygon_vertices()
	var arc_ctrls: Dictionary = get_circle_arc_controls()
	ideal_points = _sample_points_on_polygon_with_arcs(verts, arc_ctrls, n)
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls, -1, ideal_outline_segment_is_arc)
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
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls, -1, ideal_outline_segment_is_arc)
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
	"""旧星生成（_build_star_outline を使う場合のフォールバック）"""
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


func _generate_rhombus_shape(center: Vector2, pts: Array[Vector2], cfg: Dictionary) -> void:
	"""ひし形: 4 辺上に理想点。輪郭は _build_rhombus_outline と辺 8 サンプルで整合"""
	var b_half: float = float(cfg.get("rhombus_vertical_half", 0.5))
	var a: float = 1.0
	var verts: Array = [
		Vector2(0.0, -b_half),
		Vector2(a, 0.0),
		Vector2(0.0, b_half),
		Vector2(-a, 0.0),
	]
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance_factor: float = float(cfg.get("variance", 0.0))
	var n: int = num_points
	ideal_points.clear()
	for i in range(n):
		var t: float = float(i) / float(n)
		var side: int = int(t * 4.0) % 4
		var u: float = (t * 4.0) - floor(t * 4.0)
		var p1: Vector2 = verts[side]
		var p2: Vector2 = verts[(side + 1) % 4]
		var ideal: Vector2 = p1.lerp(p2, u)
		ideal_points.append(ideal)
		var noise: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * variance_factor
		pts.append(center + (ideal + noise) * base_r)


func _build_rhombus_outline(vertical_half: float) -> Array:
	"""横長のひし形（半横 a=1、半縦 = vertical_half）。辺 8 サンプル×4=32 点。"""
	var a: float = 1.0
	var b: float = vertical_half
	var verts: Array = [
		Vector2(0.0, -b),
		Vector2(a, 0.0),
		Vector2(0.0, b),
		Vector2(-a, 0.0),
	]
	var result: Array = []
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		for k in range(8):
			result.append(p1.lerp(p2, float(k) / 8.0))
	return result


func _build_rhombus_edges(vertical_half: float) -> Array:
	var a: float = 1.0
	var b: float = vertical_half
	var verts: Array = [
		Vector2(0.0, -b),
		Vector2(a, 0.0),
		Vector2(0.0, b),
		Vector2(-a, 0.0),
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


func _generate_hexagon_shape(center: Vector2, pts: Array[Vector2], cfg: Dictionary) -> void:
	"""正六角形: 周上に理想点を配置（外接円半径基準は square と同様）"""
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance_factor: float = cfg.get("variance", 0.20)
	var n: int = num_points
	var verts: Array = _regular_hexagon_unit_vertices()
	ideal_points.clear()
	for i in range(n):
		var t: float = float(i) / float(n)
		var side: int = int(t * 6.0) % 6
		var u: float = (t * 6.0) - floor(t * 6.0)
		var p1: Vector2 = verts[side]
		var p2: Vector2 = verts[(side + 1) % 6]
		var ideal: Vector2 = p1.lerp(p2, u)
		ideal_points.append(ideal)
		var noise: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * variance_factor
		pts.append(center + (ideal + noise) * base_r)


static func _parse_vec2_item_static(v: Variant) -> Variant:
	if typeof(v) == TYPE_VECTOR2:
		return v
	if typeof(v) == TYPE_ARRAY:
		var a: Array = v as Array
		if a.size() < 2:
			return null
		return Vector2(float(a[0]), float(a[1]))
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v as Dictionary
		if not d.has("x") or not d.has("y"):
			return null
		return Vector2(float(d["x"]), float(d["y"]))
	return null


func _parse_vec2_item(v: Variant) -> Variant:
	return _parse_vec2_item_static(v)


func _parse_polygon_vertices_from_cfg(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for item in v as Array:
		var p: Variant = _parse_vec2_item(item)
		if p != null:
			out.append(p)
	return out


static func _parse_arc_controls_from_cfg_static(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for k in v as Dictionary:
		var p: Variant = _parse_vec2_item_static((v as Dictionary)[k])
		if p == null:
			continue
		var ki: int = int(k) if str(k).is_valid_int() else int(k)
		out[ki] = p
	return out


func _parse_arc_controls_from_cfg(v: Variant) -> Dictionary:
	return _parse_arc_controls_from_cfg_static(v)


func _generate_cat_face_shape(center: Vector2, pts: Array[Vector2], cfg: Dictionary) -> void:
	"""案C: ねこの顔の理想点を生成。直線エッジと弧エッジを分けて処理"""
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance_factor: float = cfg.get("variance", 0.15)
	var n: int = num_points

	var verts: Array = _cfg_shape_polygon if _cfg_shape_polygon.size() >= 3 else _get_cat_face_polygon_vertices()
	var arc_ctrls: Dictionary = _cfg_shape_arc if not _cfg_shape_arc.is_empty() else get_cat_face_arc_controls()
	ideal_points = _sample_points_on_polygon_with_arcs(verts, arc_ctrls, n)
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls, -1, ideal_outline_segment_is_arc)
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


static func _heptagram_polygon_vertices_embedded() -> Array:
	var v: Array = []
	v.append(Vector2(0.0000, -0.9701))
	v.append(Vector2(0.9701, 0.2425))
	v.append(Vector2(-0.4244, 0.8489))
	v.append(Vector2(-0.7882, -0.6063))
	v.append(Vector2(0.7882, -0.6063))
	v.append(Vector2(0.4244, 0.8489))
	v.append(Vector2(-0.9701, 0.2425))
	return v


static func _heptagram_silhouette_polygon_vertices_embedded() -> Array:
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


## ラグビーボール（builtin rugby_ball.json と同一。8 頂点＋弧エッジ）
static func rugby_ball_polygon_vertices_embedded() -> Array:
	var v: Array = []
	v.append(Vector2(-0.871080160140991, -0.638792097568512))
	v.append(Vector2(-0.81300812959671, -0.81300812959671))
	v.append(Vector2(-0.638792097568512, -0.871080160140991))
	v.append(Vector2(0.464576065540314, -0.464576065540314))
	v.append(Vector2(0.871080160140991, 0.638792097568512))
	v.append(Vector2(0.81300812959671, 0.81300812959671))
	v.append(Vector2(0.638792097568512, 0.871080160140991))
	v.append(Vector2(-0.464576065540314, 0.464576065540314))
	return v


static func rugby_ball_arc_controls_embedded() -> Dictionary:
	var d: Dictionary = {}
	d[0] = Vector2(-0.871080160140991, -0.580720067024231)
	d[1] = Vector2(-0.871080160140991, -0.696864128112793)
	d[2] = Vector2(0.871080160140991, 0.638792097568512)
	d[3] = Vector2(-0.638792097568512, -0.871080160140991)
	d[4] = Vector2(0.871080160140991, 0.522648096084595)
	d[5] = Vector2(0.871080160140991, 0.754936099052429)
	d[6] = Vector2(-0.871080160140991, -0.638792097568512)
	d[7] = Vector2(0.638792097568512, 0.871080160140991)
	return d


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

	var verts: Array = _cfg_shape_polygon if _cfg_shape_polygon.size() >= 3 else get_fish_polygon_vertices()
	var arc_ctrls: Dictionary = _cfg_shape_arc if not _cfg_shape_arc.is_empty() else get_fish_arc_controls()
	ideal_points = _sample_points_on_polygon_with_arcs(verts, arc_ctrls, n)
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls, -1, ideal_outline_segment_is_arc)
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

	var verts: Array = _cfg_shape_polygon if _cfg_shape_polygon.size() >= 3 else _heptagram_polygon_vertices_embedded()
	var arc_ctrls: Dictionary = _cfg_shape_arc if not _cfg_shape_arc.is_empty() else {}
	ideal_points = _sample_points_on_polygon_with_arcs(verts, arc_ctrls, n)
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls, -1, ideal_outline_segment_is_arc)
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

	var verts: Array = _cfg_shape_polygon if _cfg_shape_polygon.size() >= 3 else _heptagram_silhouette_polygon_vertices_embedded()
	var arc_ctrls: Dictionary = _cfg_shape_arc if not _cfg_shape_arc.is_empty() else {}
	ideal_points = _sample_points_on_polygon_with_arcs(verts, arc_ctrls, n)
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls, -1, ideal_outline_segment_is_arc)
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


func _generate_rugby_ball_polygon_shape(center: Vector2, pts: Array[Vector2], cfg: Dictionary) -> void:
	"""ラグビーボール輪郭（多角形＋弧）。fish / mug と同じ正規化。JSON 未指定時は埋め込み頂点・弧を使用"""
	var base_r: float = (min_radius + max_radius) / 2.0
	var variance_factor: float = cfg.get("variance", 0.15)
	var n: int = num_points

	var verts: Array = _cfg_shape_polygon if _cfg_shape_polygon.size() >= 3 else rugby_ball_polygon_vertices_embedded()
	var arc_ctrls: Dictionary = (
		_cfg_shape_arc if not _cfg_shape_arc.is_empty() else rugby_ball_arc_controls_embedded()
	)
	ideal_points = _sample_points_on_polygon_with_arcs(verts, arc_ctrls, n)
	ideal_outline_points = _build_cat_face_outline(verts, arc_ctrls, -1, ideal_outline_segment_is_arc)
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


## _sample_arc が共線などで [a,b] のみ返す場合でも OOB にならないよう、local_t に沿った点を返す
func _point_on_arc_polyline(arc_pts: Array, local_t: float, p1: Vector2, p2: Vector2) -> Vector2:
	var lt: float = clampf(local_t, 0.0, 1.0)
	var n_sz: int = arc_pts.size()
	if n_sz < 2:
		return p1.lerp(p2, lt)
	if n_sz == 2:
		return (arc_pts[0] as Vector2).lerp(arc_pts[1] as Vector2, lt)
	var num_steps: int = n_sz - 1
	var f_idx: float = lt * float(num_steps)
	var idx: int = clampi(int(f_idx), 0, num_steps - 1)
	var frac: float = clampf(f_idx - float(idx), 0.0, 1.0)
	return (arc_pts[idx] as Vector2).lerp(arc_pts[idx + 1] as Vector2, frac)


func _sample_points_on_polygon_with_arcs(verts: Array, arc_ctrls: Dictionary, n: int) -> Array:
	"""多角形の周上に n 点を等間隔でサンプル。弧エッジは弧に沿ってサンプル"""
	if verts.size() < 2:
		return []
	var arc_seg_n: int = ARC_OUTLINE_SAMPLES
	var seg_lengths: Array = []
	var total: float = 0.0
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		var len: float
		if arc_ctrls.has(i):
			var arc_pts: Array = _sample_arc(p1, p2, arc_ctrls[i], arc_seg_n)
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
	var last_seg: Dictionary = seg_lengths[seg_lengths.size() - 1]
	for i in range(n):
		var t: float = (float(i) / float(n)) * total
		if t >= total:
			t = maxf(total - 1e-4, 0.0)
		var placed: bool = false
		for seg in seg_lengths:
			if t <= seg["end"] + 1e-6:
				var local_t: float = (t - seg["start"]) / (seg["end"] - seg["start"]) if (seg["end"] - seg["start"]) > 0.001 else 0.0
				local_t = clampf(local_t, 0.0, 1.0)
				if seg["arc_ac"] != null:
					var arc_pts: Array = _sample_arc(seg["p1"], seg["p2"], seg["arc_ac"], arc_seg_n)
					result.append(_point_on_arc_polyline(arc_pts, local_t, seg["p1"], seg["p2"]))
				else:
					result.append(seg["p1"].lerp(seg["p2"], local_t))
				placed = true
				break
		if not placed:
			# Fallback when no segment matches t (prevents ideal_points OOB).
			var p_end: Vector2 = last_seg["p2"]
			result.append(p_end)
	while result.size() < n:
		if result.is_empty():
			result.append(verts[0])
		else:
			result.append(result[result.size() - 1])
	return result


func _outline_segments_all_straight(m: int) -> Array:
	var a: Array = []
	for _i in range(m):
		a.append(false)
	return a


func _segment_flags_include_arc(flags: Array) -> bool:
	for v in flags:
		if v:
			return true
	return false


func _build_cat_face_outline(
	verts: Array, arc_ctrls: Dictionary, arc_samples: int = -1, out_segment_is_arc: Variant = null
) -> Array:
	"""描画用の輪郭頂点（弧をサンプル）。直線辺は 8 セグメント補間。
	out_segment_is_arc が非 null なら、閉じた輪郭の辺 i（頂点 i→i+1）が弧サンプル由来かを格納する。"""
	if verts.is_empty():
		if out_segment_is_arc != null:
			out_segment_is_arc.clear()
		return []
	var n_arc: int = arc_samples if arc_samples >= 0 else ARC_OUTLINE_SAMPLES
	var result: Array = [verts[0]]
	var n_e: int = verts.size()
	if out_segment_is_arc != null:
		out_segment_is_arc.clear()
	for i in range(n_e):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % n_e]
		if arc_ctrls.has(i):
			var arc_pts: Array = _sample_arc(p1, p2, arc_ctrls[i], n_arc)
			for k in range(1, arc_pts.size()):
				if out_segment_is_arc != null:
					out_segment_is_arc.append(true)
				result.append(arc_pts[k])
		else:
			var ns: int = CAT_FACE_STRAIGHT_EDGE_SAMPLES
			for k in range(1, ns + 1):
				if out_segment_is_arc != null:
					out_segment_is_arc.append(false)
				result.append(p1.lerp(p2, float(k) / float(ns)))
	if out_segment_is_arc != null:
		var M: int = result.size()
		if out_segment_is_arc.size() == M - 1:
			# 始点へ戻る閉じ辺（重複頂点時はゼロ長）— 一致度の弧緩和は掛けない
			out_segment_is_arc.append(false)
		elif out_segment_is_arc.size() != M:
			out_segment_is_arc.clear()
			for _idx in range(M):
				out_segment_is_arc.append(false)
	return result


func get_normalized_outline_for_icon_debug(type_str: String) -> Array:
	"""デバッグUIアイコン用。理想輪郭を start_stage 時と同じ正規化（周長重心＋max_d）で返す。"""
	var verts: Array = []
	var arc_ctrls: Dictionary = {}
	match type_str:
		"fish":
			verts = get_fish_polygon_vertices()
			arc_ctrls = get_fish_arc_controls()
		"cat_face":
			verts = get_cat_face_polygon_vertices()
			arc_ctrls = get_cat_face_arc_controls()
		"rugby_ball":
			verts = rugby_ball_polygon_vertices_embedded()
			arc_ctrls = rugby_ball_arc_controls_embedded()
		_:
			return []
	if verts.is_empty():
		return []
	var outline: Array = _build_cat_face_outline(verts, arc_ctrls)
	var c := _perimeter_centroid(outline)
	var max_d: float = 0.001
	for p in outline:
		max_d = maxf(max_d, ((p as Vector2) - c).length())
	var out: Array = []
	for p in outline:
		out.append(((p as Vector2) - c) / max_d)
	return out


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


func _build_hexagon_outline() -> Array:
	"""正六角形の輪郭（外接円半径1・中心原点）。各辺 8 サンプルで計48点"""
	var verts: Array = _regular_hexagon_unit_vertices()
	var result: Array = []
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		for k in range(8):
			result.append(p1.lerp(p2, float(k) / 8.0))
	return result


func _get_outline_edges_for_stage(stage_t: String) -> Array:
	"""辺・弧ごとの点列を返す。Editor由来の「ポイント間を辺または弧で結ぶ」定義。"""
	match stage_t:
		"triangle":
			return _build_triangle_edges()
		"circle":
			return _build_polygon_arc_edges(get_circle_polygon_vertices(), get_circle_arc_controls())
		"square":
			return _build_square_edges()
		"rhombus":
			return _build_rhombus_edges(float(effective_config.get("rhombus_vertical_half", 0.5)))
		"hexagon":
			return _build_hexagon_edges()
		"cat_face":
			var cv: Array = _cfg_shape_polygon if _cfg_shape_polygon.size() >= 3 else _get_cat_face_polygon_vertices()
			var cc: Dictionary = _cfg_shape_arc if not _cfg_shape_arc.is_empty() else get_cat_face_arc_controls()
			return _build_polygon_arc_edges(cv, cc)
		"fish":
			var fv: Array = _cfg_shape_polygon if _cfg_shape_polygon.size() >= 3 else get_fish_polygon_vertices()
			var fc: Dictionary = _cfg_shape_arc if not _cfg_shape_arc.is_empty() else get_fish_arc_controls()
			return _build_polygon_arc_edges(fv, fc)
		"star":
			return _build_polygon_arc_edges(get_star_polygon_vertices(), get_star_arc_controls())
		"heptagram":
			var hv: Array = _cfg_shape_polygon if _cfg_shape_polygon.size() >= 3 else _heptagram_polygon_vertices_embedded()
			var ha: Dictionary = _cfg_shape_arc if not _cfg_shape_arc.is_empty() else {}
			return _build_polygon_arc_edges(hv, ha)
		"heptagram_silhouette":
			var hsv: Array = _cfg_shape_polygon if _cfg_shape_polygon.size() >= 3 else _heptagram_silhouette_polygon_vertices_embedded()
			var hsa: Dictionary = _cfg_shape_arc if not _cfg_shape_arc.is_empty() else {}
			return _build_polygon_arc_edges(hsv, hsa)
		"rugby_ball":
			var rv: Array = _cfg_shape_polygon if _cfg_shape_polygon.size() >= 3 else rugby_ball_polygon_vertices_embedded()
			var ra: Dictionary = _cfg_shape_arc if not _cfg_shape_arc.is_empty() else rugby_ball_arc_controls_embedded()
			return _build_polygon_arc_edges(rv, ra)
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
	"""多角形+弧：各辺をサンプル。cat_face/fish用。輪郭は _build_cat_face_outline と同一密度で正規化して返す"""
	if verts.size() < 2:
		return []
	var outline: Array = _build_cat_face_outline(verts, arc_ctrls)
	var c: Vector2 = _perimeter_centroid(outline)
	var max_d: float = 0.001
	for p in outline:
		max_d = maxf(max_d, (p - c).length())
	var ns: int = CAT_FACE_STRAIGHT_EDGE_SAMPLES
	var result: Array = []
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		var edge_pts: Array = []
		if arc_ctrls.has(i):
			var arc_pts: Array = _sample_arc(p1, p2, arc_ctrls[i], ARC_OUTLINE_SAMPLES)
			for ap in arc_pts:
				edge_pts.append((ap - c) / max_d)
		else:
			for k in range(ns):
				var pt: Vector2 = p1.lerp(p2, float(k) / float(ns))
				edge_pts.append((pt - c) / max_d)
		result.append(edge_pts)
	return result


func _build_hexagon_edges() -> Array:
	"""正六角形：6辺。各辺8サンプル"""
	var verts: Array = _regular_hexagon_unit_vertices()
	var result: Array = []
	for i in range(verts.size()):
		var p1: Vector2 = verts[i]
		var p2: Vector2 = verts[(i + 1) % verts.size()]
		var edge_pts: Array = []
		for k in range(8):
			edge_pts.append(p1.lerp(p2, float(k) / 8.0))
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
	var n: int = pts.size()
	var dists: PackedFloat32Array = PackedFloat32Array()
	dists.resize(n)
	for i in range(n):
		dists[i] = (pts[i] - center).length()
	dists.sort()
	var idx: int = clampi(int(ceil(n * pct / 100.0)) - 1, 0, n - 1)
	return maxf(dists[idx], 1.0)


func _percentile_length_from_origin(pts: Array, pct: float) -> float:
	"""点列の原点からの距離の pct% タイル（理想輪郭用）"""
	if pts.is_empty():
		return 0.001
	var n: int = pts.size()
	var dists: PackedFloat32Array = PackedFloat32Array()
	dists.resize(n)
	for i in range(n):
		dists[i] = pts[i].length()
	dists.sort()
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


func _hausdorff_edge_to_user(
	edge_pts: Array, user_pts: Array, sample_step: int, arc_leniency_mul: float = 1.0
) -> float:
	"""有向ハウスドルフ h(edge→user): 辺上のサンプル点からユーザー輪郭への距離の最大。
	sample_step おきに間引いて評価し、端点（先頭・末尾）は常に含む。
	arc_leniency_mul < 1 のとき弧エッジのみ距離を掛けて緩和（一致度用）。"""
	var sz: int = edge_pts.size()
	if sz == 0:
		return 0.0
	var worst: float = 0.0
	var step: int = maxi(sample_step, 1)
	var i: int = 0
	while i < sz:
		var d: float = _distance_to_polyline(edge_pts[i], user_pts)
		if arc_leniency_mul < 0.999:
			d *= arc_leniency_mul
		worst = maxf(worst, d)
		i += step
	var last: int = sz - 1
	if last % step != 0:
		var d_last: float = _distance_to_polyline(edge_pts[last], user_pts)
		if arc_leniency_mul < 0.999:
			d_last *= arc_leniency_mul
		worst = maxf(worst, d_last)
	return worst


func _arc_controls_for_hausdorff_metrics() -> Dictionary:
	match stage_type:
		"circle":
			return get_circle_arc_controls()
		"cat_face":
			return _cfg_shape_arc if not _cfg_shape_arc.is_empty() else get_cat_face_arc_controls()
		"fish":
			return _cfg_shape_arc if not _cfg_shape_arc.is_empty() else get_fish_arc_controls()
		"star":
			return get_star_arc_controls()
		"rugby_ball":
			return _cfg_shape_arc if not _cfg_shape_arc.is_empty() else rugby_ball_arc_controls_embedded()
		"heptagram", "heptagram_silhouette":
			return _cfg_shape_arc
		_:
			return {}


func _eval_arc_error_per_edge_hausdorff(
	curr_scaled: Array, edges: Array, ref_size: float, sample_step: int, arc_ctrls: Dictionary = {}
) -> float:
	"""辺・弧ごとに h(edge→user) を算出し、平均で集約。ref_size で正規化して誤差率に。
	sample_step で辺サンプル点を間引く（端点は常に評価）。"""
	if edges.is_empty():
		return 100.0
	var sum_h: float = 0.0
	for ei in range(edges.size()):
		var emul: float = ARC_SEGMENT_MATCH_LENIENCY_MUL if arc_ctrls.has(ei) else 1.0
		sum_h += _hausdorff_edge_to_user(edges[ei], curr_scaled, sample_step, emul)
	return sum_h / float(edges.size()) / ref_size * 100.0


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


func _guide_vertex_adjacent_to_arc(vertex_idx: int, segment_is_arc: Array) -> bool:
	var m: int = segment_is_arc.size()
	if m < 1 or vertex_idx < 0:
		return false
	return bool(segment_is_arc[(vertex_idx - 1 + m) % m]) or bool(segment_is_arc[vertex_idx % m])


func _distance_to_polyline_with_arc_leniency(
	p: Vector2, polyline: Array, segment_is_arc: Array, arc_distance_mul: float
) -> float:
	"""閉じたポリラインへ、弧サンプル辺だけ距離に arc_distance_mul（<1）を掛けて最短を取る"""
	if polyline.is_empty():
		return INF
	if polyline.size() == 1:
		return p.distance_to(polyline[0])
	if arc_distance_mul >= 0.999 or segment_is_arc.size() != polyline.size():
		return _distance_to_polyline(p, polyline)
	var best: float = INF
	var m: int = polyline.size()
	for i in range(m):
		var a: Vector2 = polyline[i] as Vector2
		var b: Vector2 = polyline[(i + 1) % m] as Vector2
		var d: float = _distance_to_segment(p, a, b)
		if bool(segment_is_arc[i]):
			d *= arc_distance_mul
		best = minf(best, d)
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
	if GameConfig.USE_SCREEN_HUD_GUIDE:
		correspondence_rotation = 0.0
		return
	var ideal_ref_r: float = _percentile_length_from_origin(ideal_outline_points, REF_R_PERCENTILE)
	if GUIDE_USE_FIXED_SIZE:
		correspondence_scale = guide_radius_val / ideal_ref_r
	else:
		correspondence_scale = current_avg_radius / ideal_ref_r
	correspondence_rotation = 0.0


func calculate_metrics(point_positions: Array[Vector2]) -> void:
	"""全図形で統一: 弧誤差のみ、回転非対応"""
	_run_hausdorff_this_call = (_hausdorff_call_counter == 0)
	_hausdorff_call_counter = (_hausdorff_call_counter + 1) % HAUSDORFF_THROTTLE_EVERY
	match stage_type:
		"triangle", "circle":
			var m: Dictionary = _calc_unified_arc_metrics(point_positions, 0, point_positions.size())
			current_centroid = m["centroid"]
			current_avg_radius = m["avg_r"]
			if GameConfig.USE_SCREEN_HUD_GUIDE:
				ideal_display_radius = hud_guide_scale if stage_type == "triangle" else hud_guide_ref_px
			else:
				ideal_display_radius = guide_radius_val if GUIDE_USE_FIXED_SIZE else current_avg_radius
			current_circularity_error = m["circ_err"]
			current_circularity = m["circ"]
			current_smoothness_error = 0.0
			current_smoothness = 100.0
			_set_correspondence_scale_from_outline()
			if stage_type == "triangle":
				polygon_rotation = -PI / 2.0  # 頂点上向きでガイド表示
		"square", "rhombus", "hexagon", "star", "cat_face", "fish", "heptagram", "heptagram_silhouette", "rugby_ball":
			_calculate_unified_arc_metrics(point_positions)
	_rebuild_accuracy_alpha_cache(point_positions)


func _rebuild_accuracy_alpha_cache(point_positions: Array[Vector2]) -> void:
	"""全点の精度アルファを事前計算してキャッシュする。描画パスでの距離計算を排除する。"""
	var n: int = point_positions.size()
	_accuracy_alpha_cache.resize(n)
	for i in range(n):
		_accuracy_alpha_cache[i] = _compute_one_accuracy_alpha(i, point_positions)


## 閉じたガイド輪郭（末尾≠先頭・_resample と同様に閉じる）の各頂点で、進行方向の「曲がり角」が閾値以上なら { "pos", "weight" } を追加。weight は曲がりのラジアン。
func _get_guide_sharp_vertices(polyline: Array) -> Array:
	var out: Array = []
	var m: int = polyline.size()
	if m < 3:
		return out
	var min_turn: float = deg_to_rad(VERTEX_MIN_TURNING_DEG)
	for i in range(m):
		var prev: Vector2 = polyline[(i - 1 + m) % m] as Vector2
		var curr: Vector2 = polyline[i] as Vector2
		var next: Vector2 = polyline[(i + 1) % m] as Vector2
		var v1: Vector2 = curr - prev
		var v2: Vector2 = next - curr
		var len1: float = v1.length()
		var len2: float = v2.length()
		if len1 < 1e-5 or len2 < 1e-5:
			continue
		var turning_rad: float = acos(clampf(v1.normalized().dot(v2.normalized()), -1.0, 1.0))
		if turning_rad >= min_turn:
			out.append({"pos": curr, "weight": turning_rad})
	return out


func _calc_hud_screen_arc_metrics(
	pts: Array[Vector2], from_idx: int, to_idx: int, ring_center: Vector2, ring_r: float
) -> Dictionary:
	var n: int = to_idx - from_idx
	if n < 1:
		return {"centroid": Vector2.ZERO, "avg_r": 0.0, "circ_err": 100.0, "circ": 0.0}
	var group_pts: Array = []
	for i in range(from_idx, to_idx):
		group_pts.append(pts[i])
	var centroid: Vector2 = _perimeter_centroid(group_pts)
	var avg_r: float = _percentile_distance_from_center(group_pts, centroid, REF_R_PERCENTILE)
	var ring_mode: bool = ring_r > 0.0
	if not ring_mode and hud_guide_outline_world.size() < 2:
		return {"centroid": Vector2.ZERO, "avg_r": 0.0, "circ_err": 100.0, "circ": 0.0}
	var ref_r: float = maxf(hud_guide_ref_px, 1.0)
	var per_pt: Array = []
	var player_outline: Array = []
	if ring_mode:
		for i in range(from_idx, to_idx):
			per_pt.append(_distance_point_to_circle_ring_outline(pts[i], ring_center, ring_r))
	else:
		var guide_outline_src: Array = hud_guide_query_world if hud_guide_query_world.size() >= 2 else hud_guide_outline_world
		var use_arc_lenient: bool = (
			hud_guide_segment_is_arc.size() == hud_guide_outline_world.size()
			and hud_guide_outline_world.size() >= 2
			and ARC_SEGMENT_MATCH_LENIENCY_MUL < 0.9
			and _segment_flags_include_arc(hud_guide_segment_is_arc)
		)
		var guide_for_dist: Array = hud_guide_outline_world if use_arc_lenient else guide_outline_src
		var K: int = maxi(guide_for_dist.size(), 16)
		player_outline = _resample_closed_polyline_points(group_pts, K)
		if use_arc_lenient:
			for p in player_outline:
				per_pt.append(
					_distance_to_polyline_with_arc_leniency(
						p, hud_guide_outline_world, hud_guide_segment_is_arc, ARC_SEGMENT_MATCH_LENIENCY_MUL
					)
				)
			for j in range(hud_guide_outline_world.size()):
				var d_gp: float = _distance_to_polyline(hud_guide_outline_world[j] as Vector2, player_outline)
				if _guide_vertex_adjacent_to_arc(j, hud_guide_segment_is_arc):
					d_gp *= ARC_SEGMENT_MATCH_LENIENCY_MUL
				per_pt.append(d_gp)
		else:
			for p in player_outline:
				per_pt.append(_distance_to_polyline(p, guide_outline_src))
			for gp in guide_outline_src:
				per_pt.append(_distance_to_polyline(gp, player_outline))
	var avg_d: float = 0.0
	var max_d: float = 0.0
	for d in per_pt:
		avg_d += d
		max_d = maxf(max_d, d)
	avg_d /= per_pt.size()
	var combined: float = ARC_ERROR_AVG_WEIGHT * avg_d + ARC_ERROR_MAX_WEIGHT * max_d
	var circ_err: float = combined / ref_r * 100.0
	if not ring_mode:
		var sharp: Array = _get_guide_sharp_vertices(hud_guide_outline_world)
		if not sharp.is_empty():
			var tip_num: float = 0.0
			var tip_den: float = 0.0
			for item in sharp:
				var w: float = float(item.get("weight", 0.0))
				var pos: Vector2 = item.get("pos", Vector2.ZERO) as Vector2
				var d_tip: float = _distance_to_polyline(pos, player_outline)
				tip_num += w * (d_tip / ref_r * 100.0)
				tip_den += w
			if tip_den > 0.0:
				var tip_err: float = tip_num / tip_den
				circ_err = circ_err * (1.0 - VERTEX_TIP_WEIGHT) + tip_err * VERTEX_TIP_WEIGHT
	return {
		"centroid": centroid,
		"avg_r": avg_r,
		"circ_err": circ_err,
		"circ": maxf(0.0, 100.0 - circ_err),
	}


func _calc_unified_arc_metrics(pts: Array[Vector2], from_idx: int, to_idx: int) -> Dictionary:
	"""弧誤差のみ・回転非対応。指定範囲の点群を評価"""
	var n: int = to_idx - from_idx
	if GameConfig.USE_SCREEN_HUD_GUIDE:
		if n < 1:
			return {"centroid": Vector2.ZERO, "avg_r": 0.0, "circ_err": 100.0, "circ": 0.0}
		# HUD 距離計算は重いため、THROTTLE_EVERY 回に 1 回だけ実行してキャッシュを再利用する
		if _run_hausdorff_this_call:
			var full_m: Dictionary = _calc_hud_screen_arc_metrics(pts, from_idx, to_idx, Vector2.ZERO, -1.0)
			_hausdorff_cached_err = full_m["circ_err"]
			return full_m
		# 間引きフレーム: centroid/avg_r のみ再計算（O(n)）、circ_err はキャッシュ値を使う
		var light_pts: Array = []
		for i in range(from_idx, to_idx):
			light_pts.append(pts[i])
		var light_centroid: Vector2 = _perimeter_centroid(light_pts)
		var light_avg_r: float = _percentile_distance_from_center(light_pts, light_centroid, REF_R_PERCENTILE)
		return {
			"centroid": light_centroid,
			"avg_r": light_avg_r,
			"circ_err": _hausdorff_cached_err,
			"circ": maxf(0.0, 100.0 - _hausdorff_cached_err),
		}
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
	# scale_inv = 1/ref_r でプレイヤーを理想と同じ単位スケールに合わせる
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
			# 辺・弧ごとハウスドルフ h(edge→user) を平均で集約（弧エッジのみ距離を緩和）
			# THROTTLE_EVERY 回に 1 回だけ実行してキャッシュを再利用する
			if _run_hausdorff_this_call:
				_hausdorff_cached_err = _eval_arc_error_per_edge_hausdorff(
					curr_scaled, edges, ref_size, HAUSDORFF_SAMPLE_STEP, _arc_controls_for_hausdorff_metrics()
				)
			circ_err = _hausdorff_cached_err
		else:
			# circle: 辺定義なし → 従来方式
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
	if GameConfig.USE_SCREEN_HUD_GUIDE:
		ideal_display_radius = hud_guide_ref_px
	else:
		var use_fixed_guide: bool = GUIDE_USE_FIXED_SIZE and not guide_follows_player_radius
		ideal_display_radius = guide_radius_val if use_fixed_guide else current_avg_radius
	current_circularity_error = m["circ_err"]
	current_circularity = m["circ"]
	current_smoothness_error = 0.0
	current_smoothness = 100.0

	if GameConfig.USE_SCREEN_HUD_GUIDE:
		_apply_hud_correspondence_scale()
		correspondence_rotation = 0.0
		polygon_rotation = 0.0
		return
	var use_fixed_guide2: bool = GUIDE_USE_FIXED_SIZE and not guide_follows_player_radius
	var ideal_ref_r: float = _percentile_length_from_origin(ideal_outline_points, REF_R_PERCENTILE)
	if use_fixed_guide2:
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


func get_point_accuracy_alpha(idx: int, _point_positions: Array[Vector2]) -> float:
	"""キャッシュから精度アルファを返す。calculate_metrics() 呼び出し後に有効。"""
	if idx >= 0 and idx < _accuracy_alpha_cache.size():
		return _accuracy_alpha_cache[idx]
	return 1.0


func _compute_one_accuracy_alpha(idx: int, point_positions: Array[Vector2]) -> float:
	"""全図形で統一: 理想輪郭への距離から精度を算出（キャッシュ再構築用の実計算）"""
	if idx < 0 or idx >= point_positions.size():
		return 1.0
	var p: Vector2 = point_positions[idx]
	if GameConfig.USE_SCREEN_HUD_GUIDE:
		var ideal_dist_hud: float
		if (
			hud_guide_segment_is_arc.size() == hud_guide_outline_world.size()
			and hud_guide_outline_world.size() >= 2
			and ARC_SEGMENT_MATCH_LENIENCY_MUL < 0.9
			and _segment_flags_include_arc(hud_guide_segment_is_arc)
		):
			ideal_dist_hud = _distance_to_polyline_with_arc_leniency(
				p, hud_guide_outline_world, hud_guide_segment_is_arc, ARC_SEGMENT_MATCH_LENIENCY_MUL
			)
		else:
			ideal_dist_hud = get_distance_to_hint_guide_outline(p)
		var ref_r_hud: float = maxf(hud_guide_ref_px, 1.0)
		var error_ratio_hud: float = clampf(ideal_dist_hud / ref_r_hud, 0.0, 1.0)
		var accuracy_hud: float = 1.0 - error_ratio_hud
		if accuracy_hud < 0.90:
			return 0.25
		if accuracy_hud < 0.95:
			var t_mid: float = (accuracy_hud - 0.90) / 0.05
			var step_mid: int = mini(int(t_mid * 4.0), 3)
			return 0.35 + step_mid * 0.05
		var t_hi: float = (accuracy_hud - 0.95) / 0.05
		var step_hi: int = mini(int(t_hi * 4.0), 3)
		return 0.65 + step_hi * 0.1167
	var ideal_dist: float
	var ref_r: float = maxf(guide_radius_val, 1.0)

	match stage_type:
		"triangle", "circle":
			ideal_dist = get_distance_to_hint_guide_outline(p)
		"square", "rhombus", "hexagon", "star", "cat_face", "fish", "heptagram", "heptagram_silhouette", "rugby_ball":
			if idx >= 0 and idx < ideal_points.size():
				var ideal_pos: Vector2 = _fixed_guide_target_position_from_ideal(guide_center_1, ideal_points[idx])
				ideal_dist = p.distance_to(ideal_pos)
			else:
				ideal_dist = get_distance_to_hint_guide_outline(p)
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


func _hint_ideal_draw_scale(scale: float) -> float:
	"""StageRenderer._draw_ideal_points_outline と同じスケール解決（ヒントガイドと一致）"""
	var draw_scale: float = scale
	if not guide_follows_player_radius and draw_scale < 10.0:
		draw_scale = guide_radius_val
	return draw_scale


func _world_polyline_from_ideal(center: Vector2, ideal_pts: Array, scale: float, rotation: float) -> Array:
	if ideal_pts.is_empty():
		return []
	var draw_scale: float = _hint_ideal_draw_scale(scale)
	var cos_r: float = cos(rotation)
	var sin_r: float = sin(rotation)
	var verts: Array = []
	for pt in ideal_pts:
		var tx: float = (pt.x * cos_r - pt.y * sin_r) * draw_scale
		var ty: float = (pt.x * sin_r + pt.y * cos_r) * draw_scale
		verts.append(center + Vector2(tx, ty))
	return verts


func _fixed_guide_polyline_from_ideal(center: Vector2, ideal_pts: Array) -> Array:
	return _world_polyline_from_ideal(center, ideal_pts, guide_radius_val, correspondence_rotation)


func _fixed_guide_target_position_from_ideal(center: Vector2, ideal: Vector2) -> Vector2:
	var cos_r: float = cos(correspondence_rotation)
	var sin_r: float = sin(correspondence_rotation)
	var tx: float = (ideal.x * cos_r - ideal.y * sin_r) * guide_radius_val
	var ty: float = (ideal.x * sin_r + ideal.y * cos_r) * guide_radius_val
	return center + Vector2(tx, ty)


func get_fixed_guide_loops_world() -> Array:
	var loops: Array = []
	match stage_type:
		"triangle":
			loops.append(_regular_polygon_loop_world(guide_center_1, guide_radius_val, 3, polygon_rotation))
		"square", "rhombus", "hexagon":
			loops.append(_fixed_guide_polyline_from_ideal(guide_center_1, ideal_points))
		"circle", "star", "cat_face", "fish", "heptagram", "heptagram_silhouette", "rugby_ball":
			var pts: Array = ideal_outline_points if ideal_outline_points.size() > 0 else ideal_points
			loops.append(_fixed_guide_polyline_from_ideal(guide_center_1, pts))
		_:
			loops.append(_circle_loop_world(guide_center_1, guide_radius_val))
	var filtered: Array = []
	for loop in loops:
		var points: Array = loop as Array
		if points.size() >= 2:
			filtered.append(points)
	return filtered


func get_active_guide_loops_world() -> Array:
	if not GameConfig.USE_SCREEN_HUD_GUIDE:
		return get_fixed_guide_loops_world()
	if hud_guide_query_world.size() >= 2:
		return [hud_guide_query_world.duplicate()]
	if hud_guide_outline_world.size() >= 2:
		return [hud_guide_outline_world.duplicate()]
	return get_fixed_guide_loops_world()


func _regular_polygon_loop_world(center: Vector2, radius: float, n_sides: int, rotation: float) -> Array:
	var verts: Array = []
	for k in range(n_sides):
		var a: float = rotation + TAU * k / float(maxi(n_sides, 1))
		verts.append(center + Vector2(cos(a), sin(a)) * radius)
	return verts


func _circle_loop_world(center: Vector2, radius: float) -> Array:
	var verts: Array = []
	for i in range(CIRCLE_SEGMENTS):
		var a: float = TAU * float(i) / float(maxi(CIRCLE_SEGMENTS, 1))
		verts.append(center + Vector2(cos(a), sin(a)) * radius)
	return verts


func _distance_point_to_regular_polygon_outline(
	p: Vector2, center: Vector2, radius: float, n_sides: int, rotation: float
) -> float:
	if n_sides < 2 or radius <= 0.0:
		return INF
	var verts: Array = []
	for k in range(n_sides):
		var a: float = rotation + TAU * k / float(n_sides)
		verts.append(center + Vector2(cos(a), sin(a)) * radius)
	return _distance_to_polyline(p, verts)


func _distance_point_to_circle_ring_outline(p: Vector2, center: Vector2, r: float) -> float:
	if r <= 0.0:
		return INF
	return absf(p.distance_to(center) - r)


## プレイ中ヒントガイド（draw_hint_shape）と同じ形状への最短距離（画面座標・px）
func get_distance_to_hint_guide_outline(p: Vector2) -> float:
	if GameConfig.USE_SCREEN_HUD_GUIDE:
		if hud_guide_query_world.size() >= 2:
			return _distance_to_polyline(p, hud_guide_query_world)
		if hud_guide_outline_world.size() >= 2:
			return _distance_to_polyline(p, hud_guide_outline_world)
		return INF
	var best: float = INF
	for loop in get_fixed_guide_loops_world():
		var verts: Array = loop as Array
		if verts.size() >= 2:
			best = minf(best, _distance_to_polyline(p, verts))
	return best


func is_locked(_idx: int) -> bool:
	return false


func is_clear() -> bool:
	# 実現率100でクリア = current >= goal_pct (clear_pct)
	var goal_pct: float = 100.0 - clear_threshold
	match stage_type:
		"triangle", "circle", "square", "rhombus", "hexagon", "cat_face", "fish", "star", "heptagram", "heptagram_silhouette", "rugby_ball":
			return current_circularity >= goal_pct
	return false


func get_target_center_for_point(_idx: int) -> Vector2:
	return guide_center_1
