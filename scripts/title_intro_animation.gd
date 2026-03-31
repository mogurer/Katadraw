# =============================================================================
# TitleIntroAnimator - タイトル起動時の K イントロアニメーション（game.gd の状態は触らず、描画・タイムラインのみ）
# =============================================================================
class_name TitleIntroAnimator
extends RefCounted

const TITLE_INTRO_SKIP_FADE := 1.0
# Phase 0〜4: KF 表示〜ロゴへ K 移動。Phase 5〜7 はそのまま。
# セグメント4（KF3→最終K）は効果音なし。セグメント3（KF2→KF3）は catch + ui_move あり。
const TI_PHASE0_DUR := 0.7
const TI_PHASE1_DUR := 1.0
const TI_PHASE2_DUR := 1.0
const TI_PHASE3_DUR := 1.0
const TI_PHASE_TO_FINAL_DUR := 0.2
const TI_PHASE4_DUR := 0.5
const TI_PHASE5_DUR := 3.5
const TI_PHASE6_DUR := 0.7
const TI_PHASE7_DUR := 1.0
const TI_TOTAL_DUR := 9.6
const TI_MOTION_FADE_DUR := 1.5

# 最終 K（_draw_ti_k_move t=0）と同じ AABB へ正規化形状を収める
const K_SHAPE_BBOX_MIN := Vector2(-66.0, -175.0)
const K_SHAPE_BBOX_MAX := Vector2(84.0, 150.0)
# ベクトル K のスケールをロゴ PNG 上の K と揃える係数（まだズレる場合はここだけ微調整）
const K_LOGO_VECTOR_SCALE_MULT := 0.91

# Shape Grid Editor 出力（添付 1〜4 枚目、頂点 0〜11 は K_EDGES 順）
# K キーフレーム（K_EDGES 順）。KF3 = 最終 K（K_VERTICES と一致）
const TI_EDITOR_KF0: Array[Vector2] = [
	Vector2(-22.0000, -150.0000),
	Vector2(10.0000, -150.0000),
	Vector2(84.0000, -175.0000),
	Vector2(84.0000, -26.0000),
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
	Vector2(84.0000, -175.0000),
	Vector2(84.0000, -26.0000),
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
	Vector2(84.0000, -175.0000),
	Vector2(84.0000, -26.0000),
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

const K_WHITE_DOT_IDX := 2

var K_VERTICES: Array = [
	Vector2(-22, -43),
	Vector2(10, -150),
	Vector2(84, -175),
	Vector2(18, -26),
	Vector2(66, 150),
	Vector2(16, 150),
	Vector2(-11, 39),
	Vector2(-22, 75),
	Vector2(-22, 150),
	Vector2(-66, 150),
	Vector2(-66, -150),
	Vector2(-22, -150),
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
# 頂点モーフ区間: 0=なし, 1=KF0→1, 2=KF1→2, 3=KF2→3, 4=KF3→最終K（-1=未初期化）
var _ti_prev_vertex_sound_segment: int = -1
var _ti_motion_played: bool = false

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
	phase0_end: float,
	phase1_end: float,
	phase2_end: float,
	phase3_end: float,
	phase_final_end: float
) -> int:
	if elapsed < phase0_end:
		return 0
	if elapsed < phase1_end:
		return 1
	if elapsed < phase2_end:
		return 2
	if elapsed < phase3_end:
		return 3
	if elapsed < phase_final_end:
		return 4
	return 0


func _vertices_lerp(a: Array, b: Array, t: float) -> Array:
	var out: Array = []
	for i in range(mini(a.size(), b.size())):
		out.append(a[i].lerp(b[i], t))
	return out


func _draw_morph_polygon(vp: Vector2, center: Vector2, sc: float, verts: Array, white_dot_t: float, fill_alpha: float) -> void:
	var dot_color := Color(0.26, 0.21, 0.28)
	var line_color := Color(0.26, 0.21, 0.28)
	var dot_radius: float = 7.0
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
			var white_r: float = dot_radius + 3.0
			var border_w: float = 2.5
			var fill_color := dot_color.lerp(Color(1.0, 0.937, 0.89), white_dot_t)
			_game.draw_circle(p, lerpf(dot_radius, white_r, white_dot_t), dot_color)
			_game.draw_circle(p, lerpf(dot_radius, white_r - border_w, white_dot_t), fill_color)
		else:
			_game.draw_circle(p, dot_radius, dot_color)


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
	var pop: float = _ease_out_back(te * 0.85)
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


func _draw_keyframe_to_final_k(vp: Vector2, t_seg: float) -> void:
	var center: Vector2 = _get_k_center_screen(vp)
	var sc: float = _get_k_draw_scale(vp)
	var te: float = _ease_out_cubic(clampf(t_seg, 0.0, 1.0))
	var from_bbox: Array = _norm_vertices_to_k_bbox(TI_EDITOR_KF3)
	var k1: Array = _k_vertices_deform_array(1.0)
	var verts: Array = _vertices_lerp(from_bbox, k1, te)
	_draw_morph_polygon(vp, center, sc, verts, te, 1.0)


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
	var phase1_end: float = phase0_end + TI_PHASE1_DUR
	var phase2_end: float = phase1_end + TI_PHASE2_DUR
	var phase3_end: float = phase2_end + TI_PHASE3_DUR
	var phase_final_end: float = phase3_end + TI_PHASE_TO_FINAL_DUR
	var phase4_end: float = phase_final_end + TI_PHASE4_DUR
	var phase5_end: float = phase4_end + TI_PHASE5_DUR
	var phase6_end: float = phase5_end + TI_PHASE6_DUR
	var phase7_end: float = phase6_end + TI_PHASE7_DUR

	if not _title_intro_skip:
		# 頂点モーフ区間ごと: 開始時 ui_catch → ui_move ループ、区間終了で ui_move 停止
		var morph_seg: int = _vertex_morph_sound_segment(
			elapsed, phase0_end, phase1_end, phase2_end, phase3_end, phase_final_end
		)
		if morph_seg != _ti_prev_vertex_sound_segment:
			if _ti_prev_vertex_sound_segment >= 1 and _ti_prev_vertex_sound_segment <= 4:
				_game._stop_sfx_move()
				_ti_move_playing = false
			if morph_seg >= 1 and morph_seg <= 4:
				if morph_seg == 4:
					# KF3→最終K: 効果音なし（直前のセグメント3終了で ui_move は停止済み）
					pass
				else:
					_game._play_sfx(_game.sfx_catch)
					_game._start_sfx_move()
					_ti_move_playing = true
			_ti_prev_vertex_sound_segment = morph_seg

		# Phase 0: 1枚目（エディタ KF0）から開始・フェードイン
		if elapsed < phase0_end:
			_draw_keyframe_phase0_show_kf0(vp, elapsed / TI_PHASE0_DUR)
		# Phase 1: 1枚目 → 2枚目
		elif elapsed < phase1_end:
			_draw_keyframe_segment(vp, (elapsed - phase0_end) / TI_PHASE1_DUR, TI_EDITOR_KF0, TI_EDITOR_KF1)
		# Phase 2: 2枚目 → 3枚目
		elif elapsed < phase2_end:
			_draw_keyframe_segment(vp, (elapsed - phase1_end) / TI_PHASE2_DUR, TI_EDITOR_KF1, TI_EDITOR_KF2)
		# Phase 3: 3枚目 → 4枚目（KF2→KF3）
		elif elapsed < phase3_end:
			_draw_keyframe_segment(vp, (elapsed - phase2_end) / TI_PHASE3_DUR, TI_EDITOR_KF2, TI_EDITOR_KF3)
		# 4枚目 → 最終 K（白点＋右上変形。_draw_ti_k_move の t=0 と同じ形）
		elif elapsed < phase_final_end:
			_draw_keyframe_to_final_k(vp, (elapsed - phase3_end) / TI_PHASE_TO_FINAL_DUR)
		# K移動（ロゴ位置へ）— 頂点モーフは終了済み（上で ui_move 停止）
		elif elapsed < phase4_end:
			_draw_ti_k_move(vp, (elapsed - phase_final_end) / TI_PHASE4_DUR)
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


func _draw_ti_k_complete(vp: Vector2, center: Vector2, sc: float, white_dot_t: float, deform_t: float) -> void:
	"""Kの完成形を描画（白点変化・変形対応）"""
	var dot_color := Color(0.26, 0.21, 0.28)
	var line_color := Color(0.26, 0.21, 0.28)
	var dot_radius: float = 7.0
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
			var white_r: float = dot_radius + 3.0
			var border_w: float = 2.5
			var fill_color := dot_color.lerp(Color(1.0, 0.937, 0.89), white_dot_t)
			_game.draw_circle(p, lerpf(dot_radius, white_r, white_dot_t), dot_color)
			_game.draw_circle(p, lerpf(dot_radius, white_r - border_w, white_dot_t), fill_color)
		else:
			_game.draw_circle(p, dot_radius, dot_color)


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
	_draw_ti_k_complete(vp, center, sc, 1.0, 1.0)


func _draw_ti_logo_reveal(vp: Vector2, t: float) -> void:
	"""Phase 7: Kをロゴ位置に描画し、ATA-DRAWをマスクスライドで表示"""
	# ロゴ位置のKを描画
	var logo_info: Dictionary = _get_k_logo_position(vp)
	var center: Vector2 = logo_info["center"]
	var sc: float = logo_info["scale"]
	_draw_ti_k_complete(vp, center, sc, 1.0, 1.0)

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
