extends CanvasLayer

# 画面遷移エフェクトマネージャー（AutoLoad: "TransitionManager"）
# play_*() を呼ぶと、カバーアニメーション → on_mid コールバック（シーン切替等）
# → リビールアニメーション の順で実行される。
# use_se=false を渡すとSEをカット（デフォルトはtrue）。

const COVER_DUR  := 0.32
const HOLD_DUR   := 0.05
const REVEAL_DUR := 0.32

# SE統合用シグナル（将来 AudioStreamPlayer を接続）
signal se_wipe_start
signal se_wipe_reveal

var _type: String = ""
var _active: bool = false
var _phase: int = 0       # 0=cover  1=hold  2=reveal
var _elapsed: float = 0.0
var _on_mid: Callable
var _mid_done: bool = false

var _node: Node2D  # _DrawNode インスタンス（型は Node2D で宣言）

var _sfx_triangle: AudioStreamPlayer  # ts02.wav
var _sfx_polygon:  AudioStreamPlayer  # ts03.wav
var _sfx_diagonal: AudioStreamPlayer  # ts01.wav


func _ready() -> void:
	layer = 100
	var dn := _DrawNode.new()
	dn.mgr = self
	_node = dn
	add_child(_node)
	_sfx_triangle = _make_sfx("res://assets/sounds/ts02.wav")
	_sfx_polygon  = _make_sfx("res://assets/sounds/ts03.wav")
	_sfx_diagonal = _make_sfx("res://assets/sounds/ts01.wav")
	# SE音量を設定ファイルから読み込んで初期適用（game.gd が後から set_se_volume_db() で上書きする）
	var cfg := ConfigFile.new()
	if cfg.load("user://config.cfg") == OK:
		var se_vol: int = clampi(int(cfg.get_value("settings", "se_volume", 5)), 0, 10)
		var offset_db: float = -80.0 if se_vol <= 0 else (se_vol - 5) * 3.0
		set_se_volume_db(-14.5 + offset_db)


func _make_sfx(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = -14.5
	add_child(p)
	return p


## game.gd の _apply_se_volume() から呼ばれる。SE 音量変更時に遷移 SE を同期する。
func set_se_volume_db(base_db: float) -> void:
	_sfx_triangle.volume_db = base_db
	_sfx_polygon.volume_db  = base_db
	_sfx_diagonal.volume_db = base_db


func is_active() -> bool:
	return _active


# ---------- 公開API ----------

# 汎用ワイプ：三角形マスク（STAGE1 三角形モチーフ）
func play_triangle(on_mid: Callable, use_se: bool = true) -> void:
	_play("triangle", on_mid, use_se)


# クリア→ステージセレクト：六角形展開（Bワイプ）
func play_polygon(on_mid: Callable, use_se: bool = true) -> void:
	_play("polygon", on_mid, use_se)


# タイトル→ステージセレクト：斜めワイプ（Aワイプ）
func play_diagonal(on_mid: Callable, use_se: bool = true) -> void:
	_play("diagonal", on_mid, use_se)


# ---------- 内部 ----------

func _play(type: String, on_mid: Callable, use_se: bool) -> void:
	_type = type
	_phase = 0
	_elapsed = 0.0
	_active = true
	_mid_done = false
	_on_mid = on_mid
	se_wipe_start.emit()
	if use_se:
		_play_se(type)
	_node.queue_redraw()


func _play_se(type: String) -> void:
	match type:
		"triangle": _sfx_triangle.play()
		"polygon":  _sfx_polygon.play()
		"diagonal": _sfx_diagonal.play()


func _get_t() -> float:
	if not _active:
		return 0.0
	var raw: float
	match _phase:
		0:
			raw = clampf(_elapsed / COVER_DUR, 0.0, 1.0)
			return _smooth(raw)
		1:
			return 1.0
		2:
			raw = clampf(_elapsed / REVEAL_DUR, 0.0, 1.0)
			return 1.0 - _smooth(raw)
	return 0.0


func _smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	var dur: float
	match _phase:
		0: dur = COVER_DUR
		1: dur = HOLD_DUR
		_: dur = REVEAL_DUR
	if _elapsed >= dur:
		_elapsed = 0.0
		_phase += 1
		match _phase:
			1:
				if not _mid_done:
					_mid_done = true
					if _on_mid.is_valid():
						_on_mid.call()
			2:
				se_wipe_reveal.emit()
			3:
				_active = false
				_type = ""
	_node.queue_redraw()


# ---------- 描画ノード ----------

class _DrawNode extends Node2D:
	var mgr  # TransitionManager インスタンス（AutoLoad）

	const LINE_W  := 5.0
	const DOT_R   := 12.0

	func _draw() -> void:
		if mgr == null or not mgr._active:
			return
		var vp: Vector2 = get_viewport_rect().size
		var t: float = mgr._get_t()
		if t <= 0.0:
			return
		match mgr._type:
			"triangle":
				_draw_triangle(vp, t)
			"polygon":
				_draw_polygon(vp, t)
			"diagonal":
				_draw_diagonal(vp, t)

	# 三角形マスクワイプ（汎用）— STAGE1三角形モチーフ・白の線と点
	# COVER: 中心から拡大しながら時計回り360°回転。REVEAL: 逆順（縮小しながら同方向回転）。
	func _draw_triangle(vp: Vector2, t: float) -> void:
		var cx: float = vp.x * 0.5
		var cy: float = vp.y * 0.5
		var max_r: float = vp.length()
		var r: float = t * max_r
		if r < 2.0:
			return
		var base_angle: float = -PI * 0.5
		var rotation_offset: float = t * TAU
		var pts := PackedVector2Array()
		for k in range(3):
			var a: float = base_angle + rotation_offset + TAU * float(k) / 3.0
			pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
		draw_colored_polygon(pts, GameConfig.INK_COLOR)
		for k in range(3):
			draw_line(pts[k], pts[(k + 1) % 3], Color.WHITE, LINE_W, true)
		for k in range(3):
			draw_circle(pts[k], DOT_R, Color.WHITE)

	# 六角形展開ワイプ（Bワイプ）— 黒の線と点
	func _draw_polygon(vp: Vector2, t: float) -> void:
		var cx: float = vp.x * 0.5
		var cy: float = vp.y * 0.5
		var max_r: float = vp.length()
		var r: float = t * max_r
		if r < 2.0:
			return
		var pts := PackedVector2Array()
		for k in range(6):
			var a: float = TAU * float(k) / 6.0
			pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
		draw_colored_polygon(pts, Color(0.95, 0.19, 0.32))
		# KATAスタイル：黒い線と点
		for k in range(6):
			draw_line(pts[k], pts[(k + 1) % 6], GameConfig.INK_COLOR, LINE_W, true)
		for k in range(6):
			draw_circle(pts[k], DOT_R, GameConfig.INK_COLOR)

	# 斜めワイプ 左→右（Aワイプ）
	func _draw_diagonal(vp: Vector2, t: float) -> void:
		var k: float = lerp(-vp.y, vp.x, t)
		var pts := PackedVector2Array()
		pts.append(Vector2(0.0, 0.0))
		pts.append(Vector2(clampf(k, 0.0, vp.x), 0.0))
		pts.append(Vector2(clampf(k + vp.y, 0.0, vp.x), vp.y))
		pts.append(Vector2(0.0, vp.y))
		draw_colored_polygon(pts, GameConfig.INK_COLOR)
