# =============================================================================
# TitleIntroAnimator - タイトル起動時の K イントロアニメーション（game.gd の状態は触らず、描画・タイムラインのみ）
# =============================================================================
class_name TitleIntroAnimator
extends RefCounted

const TITLE_INTRO_SKIP_FADE := 1.0
# Phase 0〜4: KF 表示〜ロゴへ K 移動。Phase 5〜7 はそのまま。
# TI_EDITOR_KF3 = エディタのシート2（最終の手前）。その後3段階（通常K→白点色変化→白点移動）を経て Phase 4 へ。
# 頂点モーフセグメント1〜3: 開始で ui_catch、区間中 ui_move、終了で停止。
const TI_PHASE0_DUR := 0.7
const TI_PHASE0_HOLD_DUR := 0.9      # Phase 0 完了後の静止間隔
const TI_PHASE1_DUR := 0.5
const TI_PHASE2_DUR := 0.5
const TI_PHASE3_DUR := 0.5
const TI_PHASE_TO_NORMAL_DUR := 0.5  # KF3 → 通常K形状（V2 は K_P2_INITIAL 位置）
const TI_PHASE_NORMAL_HOLD_DUR := 0.4  # 通常K完成後の静止間隔
const TI_PHASE_DOT_COLOR_DUR := 0.4  # 白点カラー変化（暗色 → クリーム）
const TI_PHASE_DOT_MOVE_DUR := 0.5   # 白点移動（K_P2_INITIAL → K_VERTICES[2]）
const TI_PHASE4_DUR := 0.5
const TI_PHASE5_DUR := 3.0
const TI_PHASE6_DUR := 0.7
const TI_PHASE7_DUR := 1.0
const TI_TOTAL_DUR := 10.1
const TI_MOTION_FADE_DUR := 1.5

# 最終 K（_draw_ti_k_move t=0）と同じ AABB へ正規化形状を収める
const K_SHAPE_BBOX_MIN := Vector2(-66.0, -175.0)
const K_SHAPE_BBOX_MAX := Vector2(84.0, 150.0)
# ベクトル K のスケールをロゴ PNG 上の K と揃える係数（まだズレる場合はここだけ微調整）
const K_LOGO_VECTOR_SCALE_MULT := 0.91

# Shape Grid Editor 出力（頂点 0〜11 は K_EDGES 順）
# TI_EDITOR_KF0..2 = シート5..3、TI_EDITOR_KF3 = シート2。K_VERTICES = シート1（完成・KF3→最終モーフの終点）
const TI_EDITOR_KF0: Array[Vector2] = [
	Vector2(-22.0000, -150.0000),
	Vector2(10.0000, -150.0000),
	Vector2(66.0000, -150.0000),
	Vector2(66.0000, -26.0000),
	Vector2(66.0000, 150.0000),
	Vector2(16.0000, 150.0000),
	Vector2(-11.0000, 150.0000),
	Vector2(-22.0000, 150.0000),
	Vector2(-22.0000, 150.0000),
	Vector2(-66.0000, 150.0000),
	Vector2(-66.0000, -150.0000),
	Vector2(-22.0000, -150.0000),
]
const TI_EDITOR_KF1: Array[Vector2] = [
	Vector2(-22.0000, -43.0000),
	Vector2(10.0000, -150.0000),
	Vector2(66.0000, -150.0000),
	Vector2(66.0000, -26.0000),
	Vector2(66.0000, 150.0000),
	Vector2(16.0000, 150.0000),
	Vector2(-11.0000, 150.0000),
	Vector2(-22.0000, 150.0000),
	Vector2(-22.0000, 150.0000),
	Vector2(-66.0000, 150.0000),
	Vector2(-66.0000, -150.0000),
	Vector2(-22.0000, -150.0000),
]
const TI_EDITOR_KF2: Array[Vector2] = [
	Vector2(-22.0000, -43.0000),
	Vector2(10.0000, -150.0000),
	Vector2(66.0000, -150.0000),
	Vector2(66.0000, -26.0000),
	Vector2(66.0000, 150.0000),
	Vector2(16.0000, 150.0000),
	Vector2(-11.0000, 39.0000),
	Vector2(-22.0000, 75.0000),
	Vector2(-22.0000, 150.0000),
	Vector2(-66.0000, 150.0000),
	Vector2(-66.0000, -150.0000),
	Vector2(-22.0000, -150.0000),
]
const TI_EDITOR_KF3: Array[Vector2] = [
	Vector2(-22.0000, -43.0000),
	Vector2(10.0000, -150.0000),
	Vector2(66.0000, -150.0000),
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

const K_WHITE_DOT_IDX := 2
# 他頂点のドット半径（スクリーンpx）。右上○の基準もこれ（Phase4 まではスケール1）
const K_VERTEX_DOT_RADIUS_PX := 7.0
# 白化アニメ時の外側へのはみ出し量（基準スケール時の px）
const K_WHITE_DOT_WHITE_R_EXTRA_BASE_PX := 3.0
# 右上「○」の線の太さ（二重 draw_circle のリング幅、基準スケール時の px）
const K_WHITE_DOT_RING_WIDTH_BASE_PX := 5.0
# Phase4（K がロゴへ移動する区間）終了時点で右上○の半径をこの倍率まで変化（開始時は1.0）
const K_WHITE_DOT_RADIUS_SCALE_PHASE4 := 1.5

var K_VERTICES: Array = [
	Vector2(-22.0, -43.0),
	Vector2(10.0, -150.0),
	Vector2(90.0, -160.0),
	Vector2(18.0, -26.0),
	Vector2(66.0, 150.0),
	Vector2(16.0, 150.0),
	Vector2(-11.0, 39.0),
	Vector2(-22.0, 75.0),
	Vector2(-22.0, 150.0),
	Vector2(-66.0, 150.0),
	Vector2(-66.0, -150.0),
	Vector2(-22.0, -150.0),
]

var K_EDGES: Array = [
	[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6],
	[6, 7], [7, 8], [8, 9], [9, 10], [10, 11], [11, 0],
]

var K_P2_INITIAL := Vector2(59, -150)

var _title_intro_time: float = -1.0
var _title_intro_skip: bool = false
var _title_intro_skip_time: float = -1.0
var _ti_move_playing: bool = false
# 頂点モーフ区間: 0=なし, 1=KF0→1, 2=KF1→2, 3=KF2→3（-1=未初期化）
var _ti_prev_vertex_sound_segment: int = -1
var _ti_motion_played: bool = false
var _ti_point_played: bool = false      # Phase 0 ポップイン時の ui_point.wav
var _ti_dot_catch_played: bool = false  # 白点カラー変化開始時の ui_catch.wav
var _ti_match_played: bool = false      # 白点移動完了時の match.mp3

var _game: Node2D
var _suppress_hover_sfx: Callable

func _init(game: Node2D, suppress_hover_sfx: Callable) -> void:
	_game = game
	_suppress_hover_sfx = suppress_hover_sfx

func reset() -> void:
	_title_intro_time = Time.get_ticks_msec() / 1000.0
	_title_intro_skip = false
	_title_intro_skip_time = -1.0
	_ti_move_playing = false
	_ti_prev_vertex_sound_segment = -1
	_ti_motion_played = false
	_ti_point_played = false
	_ti_dot_catch_played = false
	_ti_match_played = false

func start_skip() -> void:
	if _title_intro_skip:
		return
	_title_intro_skip = true
	_title_intro_skip_time = Time.get_ticks_msec() / 1000.0

func is_done() -> bool:
	if _title_intro_time < 0.0:
		return true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _title_intro_time
	return elapsed >= TI_TOTAL_DUR

func is_skip_done() -> bool:
	if not _title_intro_skip or _title_intro_skip_time < 0.0:
		return false
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _title_intro_skip_time
	return elapsed >= TITLE_INTRO_SKIP_FADE

func _ease_out_cubic(t: float) -> float:
	var t1: float = 1.0 - t
	return 1.0 - t1 * t1 * t1

func _ease_in_out_cubic(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	else:
		var p: float = -2.0 * t + 2.0
		return 1.0 - p * p * p / 2.0

func _draw_bg(vp: Vector2) -> void:
	if _game.bg_texture:
		_game.draw_texture_rect(_game.bg_texture, Rect2(Vector2.ZERO, vp), false)
	else:
		_game.draw_rect(Rect2(Vector2.ZERO, vp), Color.WHITE)

func _get_k_center_screen(vp: Vector2) -> Vector2:
	"""Phase 1-5: K描画時の画面中央位置"""
	return Vector2(vp.x / 2.0, vp.y / 2.0)


func _k_vertices_centroid() -> Vector2:
	var c := Vector2.ZERO
	for v in K_VERTICES:
		c += v as Vector2
	return c / float(K_VERTICES.size())


func _get_k_logo_position(vp: Vector2) -> Dictionary:
	"""Phase 6以降: Kがロゴ位置に移動した後の中心とスケール。
	k_img_center はロゴ PNG 上で「完成 K の重心に相当する点」。描画は center + v*sc なので、
	多角形の重心をその点に一致させるため center を重心オフセットで補正する。"""
	var draw_w: float = vp.x * 0.85 * 1.2
	var tex_w: float = 1456.0  # ロゴ画像のサイズ
	var tex_h: float = 816.0
	var scale_f: float = draw_w / tex_w
	var draw_h: float = tex_h * scale_f
	var logo_cy: float = vp.y * 0.38 * 0.8
	var logo_pos := Vector2((vp.x - draw_w) / 2.0, logo_cy - draw_h / 2.0)
	# K部分のロゴ画像内での中心（ピクセル座標、拡大画像から計測）
	# x: 195→265 に補正（完成ロゴとの位置ズレを解消: +128-58=+70）
	var k_img_center := Vector2(275.0, 408.0)
	var k_screen_center := logo_pos + k_img_center * scale_f
	var k_scale: float = scale_f * K_LOGO_VECTOR_SCALE_MULT
	var centroid := _k_vertices_centroid()
	# 頂点座標の原点ではなく重心を k_img_center に合わせる（PNG の K とサイズ感・位置を一致させやすい）
	var center := k_screen_center - centroid * k_scale
	return {"center": center, "scale": k_scale}


func _get_k_draw_scale(vp: Vector2) -> float:
	"""Phase 1-5: 画面中央でのKの描画スケール（Kが画面の45%程度に収まるサイズ）"""
	var target_h: float = vp.y * 0.45
	var k_raw_h: float = 325.0  # K_VERTICESのY範囲（-175〜150、変形含む）
	return target_h / k_raw_h


func _k_vertex_deform(deform_t: float, idx: int) -> Vector2:
	if idx == K_WHITE_DOT_IDX:
		return K_P2_INITIAL.lerp(K_VERTICES[K_WHITE_DOT_IDX], deform_t)
	return K_VERTICES[idx]


func _k_vertices_deform_array(deform_t: float) -> Array:
	var out: Array = []
	for i in range(K_VERTICES.size()):
		out.append(_k_vertex_deform(deform_t, i))
	return out


func _norm_vertices_to_k_bbox(verts_norm: Array) -> Array:
	var xmin: float = 1e9
	var xmax: float = -1e9
	var ymin: float = 1e9
	var ymax: float = -1e9
	for v in verts_norm:
		var p: Vector2 = v as Vector2
		xmin = minf(xmin, p.x)
		xmax = maxf(xmax, p.x)
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	var dx: float = xmax - xmin
	var dy: float = ymax - ymin
	var out: Array = []
	for v in verts_norm:
		var p: Vector2 = v as Vector2
		var tx: float = 0.5 if dx < 1e-8 else (p.x - xmin) / dx
		var ty: float = 0.5 if dy < 1e-8 else (p.y - ymin) / dy
		out.append(
			Vector2(
				lerpf(K_SHAPE_BBOX_MIN.x, K_SHAPE_BBOX_MAX.x, tx),
				lerpf(K_SHAPE_BBOX_MIN.y, K_SHAPE_BBOX_MAX.y, ty)
			)
		)
	return out


func _vertex_morph_sound_segment(
	elapsed: float,
	phase0_hold_end: float,
	phase1_end: float,
	phase2_end: float,
	phase3_end: float
) -> int:
	if elapsed < phase0_hold_end:
		return 0
	if elapsed < phase1_end:
		return 1
	if elapsed < phase2_end:
		return 2
	if elapsed < phase3_end:
		return 3
	return 0


func _vertices_lerp(a: Array, b: Array, t: float) -> Array:
	var out: Array = []
	for i in range(mini(a.size(), b.size())):
		out.append(a[i].lerp(b[i], t))
	return out


func _draw_morph_polygon(
	vp: Vector2,
	center: Vector2,
	sc: float,
	verts: Array,
	white_dot_t: float,
	fill_alpha: float,
	white_dot_scale: float = 1.0
) -> void:
	var dot_color := Color(0.26, 0.21, 0.28)
	var line_color := Color(0.26, 0.21, 0.28)
	var line_width: float = 3.0

	var screen_pts: PackedVector2Array = PackedVector2Array()
	for v in verts:
		screen_pts.append(center + v * sc)

	if fill_alpha > 0.001 and screen_pts.size() >= 3:
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(screen_pts)
		var fill_col := Color(0.26, 0.21, 0.28, 0.22 * fill_alpha)
		for ti in range(0, tris.size(), 3):
			var tri: PackedVector2Array = PackedVector2Array([
				screen_pts[tris[ti]],
				screen_pts[tris[ti + 1]],
				screen_pts[tris[ti + 2]],
			])
			_game.draw_colored_polygon(tri, fill_col)

	for edge in K_EDGES:
		var a: int = edge[0]
		var b: int = edge[1]
		var pa: Vector2 = center + verts[a] * sc
		var pb: Vector2 = center + verts[b] * sc
		_game.draw_line(pa, pb, line_color, line_width, true)

	for i in range(verts.size()):
		var p: Vector2 = center + verts[i] * sc
		if i == K_WHITE_DOT_IDX:
			var wr: float = K_VERTEX_DOT_RADIUS_PX * white_dot_scale
			var extra: float = K_WHITE_DOT_WHITE_R_EXTRA_BASE_PX * white_dot_scale
			var ring_w: float = K_WHITE_DOT_RING_WIDTH_BASE_PX * white_dot_scale
			var white_r: float = wr + extra
			var fill_color := dot_color.lerp(Color(1.0, 0.937, 0.89), white_dot_t)
			_game.draw_circle(p, lerpf(wr, white_r, white_dot_t), dot_color)
			_game.draw_circle(
				p,
				lerpf(wr, white_r - ring_w, white_dot_t),
				fill_color
			)
		else:
			_game.draw_circle(p, K_VERTEX_DOT_RADIUS_PX, dot_color)


func _ease_out_back(t: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	var t1: float = t - 1.0
	return 1.0 + c3 * t1 * t1 * t1 + c1 * t1 * t1


func _draw_keyframe_phase0_show_kf0(vp: Vector2, t: float) -> void:
	var center: Vector2 = _get_k_center_screen(vp)
	var sc: float = _get_k_draw_scale(vp)
	var te: float = _ease_in_out_cubic(clampf(t, 0.0, 1.0))
	var verts: Array = _norm_vertices_to_k_bbox(TI_EDITOR_KF0)
	var c := Vector2.ZERO
	for v in verts:
		c += v as Vector2
	c /= float(verts.size())
	var pop: float = _ease_out_back(te)
	var sc_mul: float = lerpf(0.08, 1.0, pop)
	for i in range(verts.size()):
		verts[i] = c + (verts[i] as Vector2 - c) * sc_mul
	_draw_morph_polygon(vp, center, sc, verts, 0.0, te)


func _draw_keyframe_segment(vp: Vector2, t_seg: float, kf_a: Array, kf_b: Array) -> void:
	var center: Vector2 = _get_k_center_screen(vp)
	var sc: float = _get_k_draw_scale(vp)
	var te: float = _ease_in_out_cubic(clampf(t_seg, 0.0, 1.0))
	var verts_n: Array = _vertices_lerp(kf_a, kf_b, te)
	var verts: Array = _norm_vertices_to_k_bbox(verts_n)
	_draw_morph_polygon(vp, center, sc, verts, 0.0, 1.0)


func _draw_keyframe_to_normal_k(vp: Vector2, t_seg: float) -> void:
	"""Phase遷移 sub1: KF3_bbox → 通常K形状（V2はK_P2_INITIAL、白点は暗色のまま）"""
	var center: Vector2 = _get_k_center_screen(vp)
	var sc: float = _get_k_draw_scale(vp)
	var te: float = _ease_out_cubic(clampf(t_seg, 0.0, 1.0))
	var from_bbox: Array = _norm_vertices_to_k_bbox(TI_EDITOR_KF3)
	var k_normal: Array = _k_vertices_deform_array(0.0)
	var verts: Array = _vertices_lerp(from_bbox, k_normal, te)
	_draw_morph_polygon(vp, center, sc, verts, 0.0, 1.0)


func _draw_centered_k_dot_anim(vp: Vector2, white_dot_t: float, deform_t: float) -> void:
	"""Phase遷移 sub2-3: 通常K形状（中央描画）で白点カラー変化・移動アニメ（t値は呼び出し元でeasing済み）"""
	var center: Vector2 = _get_k_center_screen(vp)
	var sc: float = _get_k_draw_scale(vp)
	var verts: Array = _k_vertices_deform_array(deform_t)
	_draw_morph_polygon(vp, center, sc, verts, white_dot_t, 1.0)


func draw(vp: Vector2) -> void:
	# 背景（本編と同じBG画像を使用）
	_draw_bg(vp)

	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - _title_intro_time

	# スキップ中のクロスフェード
	var skip_alpha: float = 0.0
	if _title_intro_skip:
		var skip_elapsed: float = now - _title_intro_skip_time
		skip_alpha = clampf(skip_elapsed / TITLE_INTRO_SKIP_FADE, 0.0, 1.0)

	# フェーズ判定
	var phase0_end: float = TI_PHASE0_DUR
	var phase0_hold_end: float = phase0_end + TI_PHASE0_HOLD_DUR
	var phase1_end: float = phase0_hold_end + TI_PHASE1_DUR
	var phase2_end: float = phase1_end + TI_PHASE2_DUR
	var phase3_end: float = phase2_end + TI_PHASE3_DUR
	var phase_to_normal_end: float = phase3_end + TI_PHASE_TO_NORMAL_DUR
	var phase_normal_hold_end: float = phase_to_normal_end + TI_PHASE_NORMAL_HOLD_DUR
	var phase_dot_color_end: float = phase_normal_hold_end + TI_PHASE_DOT_COLOR_DUR
	var phase_dot_move_end: float = phase_dot_color_end + TI_PHASE_DOT_MOVE_DUR
	var phase4_end: float = phase_dot_move_end + TI_PHASE4_DUR
	var phase5_end: float = phase4_end + TI_PHASE5_DUR
	var phase6_end: float = phase5_end + TI_PHASE6_DUR
	var phase7_end: float = phase6_end + TI_PHASE7_DUR

	if not _title_intro_skip:
		# Phase 0 ポップイン開始: ui_point.wav
		if not _ti_point_played:
			_game._play_sfx(_game.sfx_point)
			_ti_point_played = true

		# 頂点モーフ区間（Phase 1〜3）: 開始時 ui_catch → ui_move ループ、区間終了で停止
		var morph_seg: int = _vertex_morph_sound_segment(
			elapsed, phase0_hold_end, phase1_end, phase2_end, phase3_end
		)
		if morph_seg != _ti_prev_vertex_sound_segment:
			if _ti_prev_vertex_sound_segment >= 1 and _ti_prev_vertex_sound_segment <= 3:
				_game._stop_sfx_move()
				_ti_move_playing = false
			if morph_seg >= 1 and morph_seg <= 3:
				_game._play_sfx(_game.sfx_catch)
				_game._start_sfx_move()
				_ti_move_playing = true
			_ti_prev_vertex_sound_segment = morph_seg

		# 白点カラー変化フェーズ開始: ui_catch.wav
		if elapsed >= phase_normal_hold_end and not _ti_dot_catch_played:
			_game._play_sfx(_game.sfx_catch)
			_ti_dot_catch_played = true

		# 白点移動フェーズ: ui_move.wav ループ（開始・終了管理）
		if elapsed >= phase_dot_color_end and elapsed < phase_dot_move_end:
			if not _ti_move_playing:
				_game._start_sfx_move()
				_ti_move_playing = true
		elif elapsed >= phase_dot_move_end and _ti_move_playing:
			_game._stop_sfx_move()
			_ti_move_playing = false

		# 白点移動完了: match.mp3
		if elapsed >= phase_dot_move_end and not _ti_match_played:
			_game._play_sfx(_game.sfx_clear)
			_ti_match_played = true

		# Phase 0: KF0 ポップイン
		if elapsed < phase0_end:
			_draw_keyframe_phase0_show_kf0(vp, elapsed / TI_PHASE0_DUR)
		# Phase 0 Hold: KF0 静止
		elif elapsed < phase0_hold_end:
			_draw_keyframe_phase0_show_kf0(vp, 1.0)
		# Phase 1: KF0 → KF1
		elif elapsed < phase1_end:
			_draw_keyframe_segment(vp, (elapsed - phase0_hold_end) / TI_PHASE1_DUR, TI_EDITOR_KF0, TI_EDITOR_KF1)
		# Phase 2: KF1 → KF2
		elif elapsed < phase2_end:
			_draw_keyframe_segment(vp, (elapsed - phase1_end) / TI_PHASE2_DUR, TI_EDITOR_KF1, TI_EDITOR_KF2)
		# Phase 3: KF2 → KF3
		elif elapsed < phase3_end:
			_draw_keyframe_segment(vp, (elapsed - phase2_end) / TI_PHASE3_DUR, TI_EDITOR_KF2, TI_EDITOR_KF3)
		# Phase 遷移 sub1: KF3 → 通常K形状（V2 は K_P2_INITIAL 位置、白点は暗色）
		elif elapsed < phase_to_normal_end:
			_draw_keyframe_to_normal_k(vp, (elapsed - phase3_end) / TI_PHASE_TO_NORMAL_DUR)
		# Phase 遷移 sub1 Hold: 通常K完成後の静止
		elif elapsed < phase_normal_hold_end:
			_draw_centered_k_dot_anim(vp, 0.0, 0.0)
		# Phase 遷移 sub2: 白点カラー変化（暗色 → クリーム）
		elif elapsed < phase_dot_color_end:
			var raw_t: float = (elapsed - phase_normal_hold_end) / TI_PHASE_DOT_COLOR_DUR
			_draw_centered_k_dot_anim(vp, _ease_in_out_cubic(raw_t), 0.0)
		# Phase 遷移 sub3: 白点移動（K_P2_INITIAL → K_VERTICES[2]）
		elif elapsed < phase_dot_move_end:
			var raw_t: float = (elapsed - phase_dot_color_end) / TI_PHASE_DOT_MOVE_DUR
			_draw_centered_k_dot_anim(vp, 1.0, _ease_out_cubic(raw_t))
		# Phase 4: K移動（ロゴ位置へ）
		elif elapsed < phase4_end:
			_draw_ti_k_move(vp, (elapsed - phase_dot_move_end) / TI_PHASE4_DUR)
		# Phase 5: ATA-DRAWスライドイン
		elif elapsed < phase5_end:
			var phase5_t: float = (elapsed - phase4_end) / TI_PHASE5_DUR
			_draw_ti_logo_reveal(vp, phase5_t)
			# SE: motion.mp3 再生開始
			if not _ti_motion_played:
				_game._play_sfx(_game.sfx_motion)
				_ti_motion_played = true
			# フェードアウト: Phase5終了の1.0秒前から音量を下げる
			var remaining: float = phase5_end - elapsed
			if remaining < TI_MOTION_FADE_DUR and _game.sfx_motion.playing:
				var fade_t: float = remaining / TI_MOTION_FADE_DUR  # 1.0→0.0
				_game.sfx_motion.volume_db = -14.5 + linear_to_db(maxf(fade_t, 0.001))
		# Phase 6: ロゴ完成状態で静止（1.5秒）
		elif elapsed < phase6_end:
			_draw_ti_logo_reveal(vp, 1.0)
			# motion.mp3 停止
			if _game.sfx_motion.playing:
				_game.sfx_motion.stop()
		# Phase 7: タイトル画面へクロスフェード
		elif elapsed < phase7_end:
			_draw_ti_logo_reveal(vp, 1.0)
			var fade_t: float = (elapsed - phase6_end) / TI_PHASE7_DUR
			_suppress_hover_sfx.call(0.5)  # クロスフェード中のホバーSE抑制
			_draw_title_fade_overlay(vp, _ease_in_out_cubic(fade_t))
		# Phase 8: 完了（タイトル画面）
		else:
			_draw_ti_logo_reveal(vp, 1.0)
			_draw_title_fade_overlay(vp, 1.0)

	# スキップ時クロスフェード: タイトル画面を重ねてフェードイン
	if _title_intro_skip:
		# SE停止
		if _ti_move_playing:
			_game._stop_sfx_move()
			_ti_move_playing = false
		if _game.sfx_motion.playing:
			_game.sfx_motion.stop()
		# 裏でイントロ最終フレームを描画
		_draw_ti_logo_reveal(vp, 1.0)
		# タイトル画面をフェードインで重ねる
		_draw_title_fade_overlay(vp, skip_alpha)


func _draw_ti_k_complete(
	vp: Vector2,
	center: Vector2,
	sc: float,
	white_dot_t: float,
	deform_t: float,
	white_dot_scale: float = 1.0
) -> void:
	"""Kの完成形を描画（白点変化・変形対応）。white_dot_scale は右上○の倍率（Phase4 以降で 1.5 など）。"""
	var dot_color := Color(0.26, 0.21, 0.28)
	var line_color := Color(0.26, 0.21, 0.28)
	var line_width: float = 3.0

	# P2（右上先端）の変形位置を計算（初期位置→ロゴ最終位置）
	var p2_deformed: Vector2 = K_P2_INITIAL.lerp(K_VERTICES[K_WHITE_DOT_IDX], deform_t)

	# 全辺を描画
	for edge in K_EDGES:
		var a: int = edge[0]
		var b: int = edge[1]
		var va: Vector2 = K_VERTICES[a] if a != K_WHITE_DOT_IDX else p2_deformed
		var vb: Vector2 = K_VERTICES[b] if b != K_WHITE_DOT_IDX else p2_deformed
		var pa: Vector2 = center + va * sc
		var pb: Vector2 = center + vb * sc
		_game.draw_line(pa, pb, line_color, line_width, true)

	# 全頂点にドットを描画
	for i in range(K_VERTICES.size()):
		var v: Vector2 = K_VERTICES[i] if i != K_WHITE_DOT_IDX else p2_deformed
		var p: Vector2 = center + v * sc
		if i == K_WHITE_DOT_IDX:
			# P2: 白点への変化アニメーション
			var wr: float = K_VERTEX_DOT_RADIUS_PX * white_dot_scale
			var extra: float = K_WHITE_DOT_WHITE_R_EXTRA_BASE_PX * white_dot_scale
			var ring_w: float = K_WHITE_DOT_RING_WIDTH_BASE_PX * white_dot_scale
			var white_r: float = wr + extra
			var fill_color := dot_color.lerp(Color(1.0, 0.937, 0.89), white_dot_t)
			_game.draw_circle(p, lerpf(wr, white_r, white_dot_t), dot_color)
			_game.draw_circle(
				p,
				lerpf(wr, white_r - ring_w, white_dot_t),
				fill_color
			)
		else:
			_game.draw_circle(p, K_VERTEX_DOT_RADIUS_PX, dot_color)


func _draw_ti_k_move(vp: Vector2, t: float) -> void:
	"""Phase 6: Kが画面中央からロゴ位置に移動"""
	var logo_info: Dictionary = _get_k_logo_position(vp)
	var centroid := _k_vertices_centroid()
	var sc_start: float = _get_k_draw_scale(vp)
	var sc_end: float = logo_info["scale"]
	var center_start: Vector2 = _get_k_center_screen(vp) - centroid * sc_start
	var center_end: Vector2 = logo_info["center"]

	var eased: float = _ease_out_cubic(t)
	var center: Vector2 = center_start.lerp(center_end, eased)
	var sc: float = lerpf(sc_start, sc_end, eased)
	var dot_scale: float = lerpf(1.0, K_WHITE_DOT_RADIUS_SCALE_PHASE4, eased)
	_draw_ti_k_complete(vp, center, sc, 1.0, 1.0, dot_scale)


func _draw_ti_logo_reveal(vp: Vector2, t: float) -> void:
	"""Phase 7: Kをロゴ位置に描画し、ATA-DRAWをマスクスライドで表示"""
	# ロゴ位置のKを描画
	var logo_info: Dictionary = _get_k_logo_position(vp)
	var center: Vector2 = logo_info["center"]
	var sc: float = logo_info["scale"]
	_draw_ti_k_complete(vp, center, sc, 1.0, 1.0, K_WHITE_DOT_RADIUS_SCALE_PHASE4)

	# ATA-DRAW部分（logo02）をマスクスライドで表示
	if _game.title_logo02_texture:
		var tex_size: Vector2 = _game.title_logo02_texture.get_size()
		var draw_w: float = vp.x * 0.85 * 1.2
		var logo_scale: float = draw_w / 1456.0
		var draw_h: float = tex_size.y * (draw_w / tex_size.x)
		var logo_cy: float = vp.y * 0.38 * 0.8
		var logo_pos := Vector2((vp.x - draw_w) / 2.0, logo_cy - draw_h / 2.0)

		# マスク: 左端（K部分の右端あたり）から右端へ
		var eased: float = _ease_out_cubic(t)
		var mask_x: float = logo_pos.x + draw_w * eased
		# テクスチャの表示可能範囲をClipで制限
		# draw_texture_rect_regionを使用してマスク効果を実現
		var visible_w: float = draw_w * eased
		if visible_w > 0:
			var src_w: float = tex_size.x * eased
			var src_rect := Rect2(0, 0, src_w, tex_size.y)
			var dst_rect := Rect2(logo_pos, Vector2(visible_w, draw_h))
			_game.draw_texture_rect_region(_game.title_logo02_texture, dst_rect, src_rect)


func _draw_title_fade_overlay(vp: Vector2, alpha: float) -> void:
	"""タイトル画面の内容をアルファ付きで描画（クロスフェード用：ロゴとBGのみ）"""
	# 背景をアルファ付きで重ねる（クロスフェード用）
	if _game.bg_texture:
		_game.draw_texture_rect(_game.bg_texture, Rect2(Vector2.ZERO, vp), false, Color(1, 1, 1, alpha))
	else:
		_game.draw_rect(Rect2(Vector2.ZERO, vp), Color(_game.BG_COLOR.r, _game.BG_COLOR.g, _game.BG_COLOR.b, alpha))

	var cy: float = vp.y * 0.38 * 0.8
	if _game.title_logo_texture:
		var tex_size: Vector2 = _game.title_logo_texture.get_size()
		var draw_w: float = vp.x * 0.85 * 1.2
		var scale_f: float = draw_w / tex_size.x
		var draw_h: float = tex_size.y * scale_f
		var pos := Vector2((vp.x - draw_w) / 2.0, cy - draw_h / 2.0)
		_game.draw_texture_rect(_game.title_logo_texture, Rect2(pos, Vector2(draw_w, draw_h)), false, Color(1, 1, 1, alpha))
