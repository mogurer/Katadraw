extends Node2D

# =============================================================================
# Stage Select Screen
# ・自キャラ: マウス追跡（lerp）＋ゲームパッドスティック移動
# ・接近したステージの目標図形を吹き出しで表示
# ・確認ポップアップ: 「このステージをプレイしますか？」[はい][いいえ]
# =============================================================================

const _GAME_SCENE := "res://scenes/game.tscn"

# --- 色 ---
const _BG_COLOR       := Color(1.0, 0.937, 0.89)
const _LINE_COLOR      := GameConfig.INK_COLOR
const _LOCKED_COLOR    := Color(0.72, 0.62, 0.60)
const _UNLOCKED_COLOR  := Color(0.95, 0.19, 0.32)
const _CLEARED_COLOR   := Color(0.95, 0.19, 0.32, 0.55)
const _HOVER_COLOR     := Color(1.0, 0.10, 0.20)
const _CHAR_COLOR      := GameConfig.INK_COLOR
const _BUBBLE_BG       := Color(1.0, 0.98, 0.96)
const _BUBBLE_BORDER   := Color(0.95, 0.19, 0.32)
const _POPUP_BG        := Color(1.0, 0.98, 0.96)
const _POPUP_BORDER    := Color(0.95, 0.19, 0.32)
const _BTN_YES_COLOR   := Color(0.95, 0.19, 0.32)
const _BTN_NO_COLOR    := GameConfig.INK_COLOR

# --- [DEBUG] SE選択パネル ---
const _DBG_PANEL_X   := 310.0
const _DBG_PANEL_Y   := 12.0
const _DBG_COL_W     := 108.0
const _DBG_COL_GAP   := 16.0
const _DBG_HEADER_H  := 26.0
const _DBG_ITEM_H    := 22.0
const _DBG_PAD       := 10.0
const _DBG_BG        := Color(0.92, 0.97, 0.98, 0.93)
const _DBG_BD        := Color(0.45, 0.72, 0.80)
const _DBG_SEL       := Color(0.18, 0.55, 0.70)
const _DBG_TXT       := Color(0.25, 0.35, 0.40)

# --- サイズ ---
const _DOT_RADIUS      := 20.0
const _LINE_WIDTH      := 4.0
const _CHAR_RADIUS     := 14.0
const _PROX_DIST       := 140.0   # 吹き出し表示する距離（px）
const _BUBBLE_W        := 225.0   # バブル固定幅 (150 × 1.5)
const _BUBBLE_H        := 300.0   # バブル固定高さ (200 × 1.5)
const _BUBBLE_HDR_H    := 78.0    # ヘッダエリア高さ (52 × 1.5)
const _BUBBLE_FIG_H    := 117.0   # 図形エリア高さ (78 × 1.5)
const _BUBBLE_ROW_H    := 52.5    # BESTレコード各行高さ (35 × 1.5)
const _BUBBLE_STRIPE_W := 22.5    # 左縦ストライプ幅 (15 × 1.5)
const _BUBBLE_LABEL_W  := 67.5    # BEST行ラベルセル幅 (45 × 1.5)
const BUBBLE_OPEN_DUR:  float = 0.18   # 出現アニメーション時間
const BUBBLE_CLOSE_DUR: float = 0.12   # 消滅アニメーション時間
const BORDER_CYCLE:          float = 2.0    # ボーダーライン周期（秒）
const BORDER_ANIM_DUR:       float = 1.0    # ボーダーライン走行時間（秒）
const BORDER_LINE_LEN:       float = 200.0  # バブルボーダーラインの長さ（px）
const POPUP_BORDER_LINE_LEN: float = 350.0  # ダイアログボーダーラインの長さ（px）
const BORDER_WAIT:           float = BORDER_CYCLE - BORDER_ANIM_DUR  # 待機時間 = 1.0秒
const _BUBBLE_DARK     := GameConfig.INK_COLOR
const _BUBBLE_RED      := Color(0.95, 0.19, 0.32)
const _BUBBLE_VAL_BG   := Color(0.87, 0.85, 0.85)
const _POPUP_W         := 700.0
const _POPUP_H         := 250.0

# --- 自キャラ ---
const _CHAR_LERP       := 10.0    # マウス追跡の平滑化係数
const _PAD_SPEED       := 600.0   # ゲームパッド移動速度（px/sec）
const _SNAP_THRESHOLD: float = 0.80      # 右スティックのスナップ入力閾値（80%）
const _SNAP_ANGLE_MAX: float = 45.0      # スナップ候補の最大角度差（度）

# --- Camera2D スクロール ---
const SCROLL_OFFSET_WEIGHT: float = 800.0  # オフセット起因のスクロール最大速度（px/s）
const SCROLL_VEL_WEIGHT: float = 0.3       # アバター移動速度のスクロールへの反映倍率
const SCROLL_DEAD_ZONE_X: float = 0.35  # X方向デッドゾーン半径（half_viewに対する比率）
const SCROLL_DEAD_ZONE_Y: float = 0.25  # Y方向デッドゾーン半径（half_viewに対する比率）

# --- ステージ解放フォーカス演出 ---
const FOCUS_DURATION: float = 0.8  # 1ステージあたりのフォーカス時間（秒）
const FOCUS_LERP: float     = 5.0  # カメラ追従の線形補間係数
const FOCUS_MOVE_SPEED: float = 1200.0    # カメラ移動速度（px/s、リニア）
const UNLOCK_ANIM_DURATION: float = 0.5   # ぼよよん演出の長さ（秒）
const UNLOCK_LINE_FADE_DURATION: float = 2.5  # 描線アニメーション時間（秒）

# --- BGM 曲名表示 ---
const _BGM_TRACK_KEYS: Array[String] = [
	"BGM_01-05",
	"BGM_01-06",
	"BGM_01-08",
	"BGM_02-03",
	"BGM_02-09",
]
const _BGM_LABEL_FONT_SIZE := 20
const _BGM_LABEL_COLOR     := Color(0.5, 0.3, 0.3)
const _BGM_TYPEWRITER_SEC  := 1.0
const _BGM_HOLD_SEC        := 5.0
const _BGM_DISMISS_SEC     := 2.0

var _camera: Camera2D = null  # コードで生成する Camera2D

var _char_pos: Vector2 = Vector2(960, 540)
var _char_target: Vector2 = Vector2(960, 540)
var _char_moved_by_user: bool = false
var _char_vel: Vector2 = Vector2.ZERO  # アバターの移動速度（前フレーム差分）
var _snap_ready: bool = true  # 右スティックがニュートラルに戻ったかどうか

# --- ステージ解放フォーカス演出 ---
var _focus_queue: Array = []      # フォーカス対象ステージID配列
var _is_focusing: bool = false    # フォーカス演出中フラグ
var _focus_elapsed: float = 0.0   # 現在フォーカス経過時間
var _focus_return_id: int = -1    # フォーカス演出終了後に戻るステージID

# --- 最終ステージ演出 ---
var _final_directing: bool = false
var _final_direction_played: bool = false  # セッション中フラグ（セーブなし）
var _final_overlay_alpha: float = 0.0      # 暗転オーバーレイのアルファ値
var _final_spark_drawn: Array = []          # 描画済みエッジ Array[[from: Vector2, to: Vector2]]
var _final_flash_pos: Vector2 = Vector2.ZERO
var _final_flash_alpha: float = 0.0
var _final_phase3: int = 0              # 0=inactive, 1=TAP-TO-START待ち
var _final_phase3_input_received: bool = false
var _final_morph_phase: int = 0   # 0=inactive, 1=morphing, 2=shrinking
var _final_morph_t: float = 0.0   # 0→1 モーフ進行
var _final_shrink_t: float = 0.0  # 0→1 縮小進行
var _final_shrink_end: float = 1.0  # 縮小後の最終スケール（ゲーム内ガイドに合わせて算出）
var _final_morph_src_pts: Array[Vector2] = []
var _final_morph_dst_pts: Array[Vector2] = []
var _final_phase3_hover: bool = false   # THANK YOUボタンのホバー状態
var _final_phase3_btn_rect: Rect2 = Rect2()

# --- ステージ解放演出 ---
var _unlock_anim_stage: int = -1              # 現在ぼよよん演出中のステージID
var _unlock_anim_elapsed: float = 0.0         # ぼよよん演出の経過時間
var _unlock_source_stage: int = -1            # 解放元（クリアした）ステージID
# 接続ライン出現演出: { [min_id, max_id] -> elapsed }
var _line_fade_progress: Dictionary = {}
var _line_draw_from: Dictionary = {}   # key → 描線の始点ステージID
var _line_pending_keys: Dictionary = {}  # まだ進行を開始しないキー（カメラ到着前）
var _newly_unlocked_ids: Array[int] = []  # 今回の解放演出で出現したステージID一覧

# --- アニメーション ---
var _elapsed: float = 0.0
var _anim_freq:  Array[float] = []
var _anim_phase: Array[float] = []
var _anim_amp:   Array[float] = []

# --- 状態 ---
var _nearest: int = -1        # 最近傍ステージ ID

# --- バブルアニメーション（スケール＋フェード）---
# phase: 0=非表示, 1=出現中, 2=全開, 3=消滅中
var _bubble_phase: int = 0
var _bubble_t: float = 0.0
var _bubble_stage_id: int = -1
var _border_phase_t: float = 0.0   # ボーダーアニメーションタイマー（0..BORDER_CYCLE）
var _popup_border_phase_t: float = BORDER_WAIT  # ポップアップボーダーアニメーションタイマー

var _popup_stage: int = -1    # 確認ポップアップ対象（-1 = 非表示）
var _popup_yes_hovered: bool = false
var _popup_no_hovered: bool = false

var _esc_popup: bool = false   # タイトル戻り確認ポップアップ
var _ctrl_held: bool = false   # Ctrlキー押下中フラグ
var _esc_popup_yes_hovered: bool = false
var _esc_popup_no_hovered: bool = false

# --- ZOU ドット（zou_cleared 後）---
var _zou_world_pos: Vector2 = Vector2.ZERO
var _zou_near: bool = false
var _zou_popup: bool = false
var _zou_yes_hovered: bool = false
var _zou_no_hovered: bool = false

var _font: Font
var _font_din: Font = null
var _font_din_logo: FontVariation = null  # STAGESELECTロゴ専用（spacing_glyph=-4、net -5px）
var _stage_cfgs: Array = []
var _dbg_preview: AudioStreamPlayer = null
var _sfx_hover: AudioStreamPlayer = null
var _sfx_click: AudioStreamPlayer = null
var _sfx_on: AudioStreamPlayer = null
var _sfx_spot02: AudioStreamPlayer = null
var _sfx_telop_soft: AudioStreamPlayer = null

# --- BGM 曲名表示 ---
var _bgm_canvas: CanvasLayer = null
var _bgm_container: HBoxContainer = null
var _btn_prev: Button = null
var _btn_next: Button = null
var _bgm_label: Label = null
var _bgm_text: String = ""
var _bgm_tween: Tween = null

# --- BGM 拡大パネル ---
var _bgm_expanded_panel: PanelContainer = null
var _bgm_expanded_prev_btn: Button = null
var _bgm_expanded_next_btn: Button = null
var _bgm_expanded_name_label: Label = null
var _bgm_right_click_held: bool = false
var _bgm_x_btn_held: bool = false
var _bgm_lr_collapse_timer: float = -1.0
var _bgm_expand_tween: Tween = null
var _bgm_expanded: bool = false

# --- 入力モード ---
var _input_mode: int = 0  # 0 = KBM、1 = コントローラ

# --- BGM ゾーン色 ---
const _BGM_ZONE_COLOR          := Color("#433647")  # 未解放
const _BGM_ZONE_UNLOCKED_COLOR := Color("#bc4280")  # 解放済み
const _BGM_ZONE_DOT_RADIUS := _DOT_RADIUS * 1.5

# --- BGM 解禁演出 ---
var _bgm_unlock_directing: bool = false
var _bgm_unlock_phase: int = 0        # 0=inactive 1=cam移動 2=展開待ち 3=待機 4=収納待ち
var _bgm_unlock_elapsed: float = 0.0
var _bgm_unlock_zone_center: Vector2 = Vector2.ZERO
var _bgm_unlock_bgm_id: String = ""
var _bgm_unlock_skip_count: int = 0
var _bgm_unlock_cam_start: Vector2 = Vector2.ZERO
var _bgm_unlock_pending: bool = false  # フォーカス演出終了後に開始するフラグ
var _bgm_unlock_is_preview: bool = false  # デバッグ: プレビュー演出モード（永続変更なし）
var _bgm_unlock_visual_zi: int = -1       # 円変色・音符アイコン出現が確定したゾーンインデックス（-1=まだ）
var _dbg_bgm_preview_zi: int = 0          # デバッグ: 次にプレビューするゾーンインデックス
var _bgm_line_retract_progress: Dictionary = {}  # { zone_idx: float 0..1 } 1.0=完全収納
var _onpu_texture: Texture2D = null
var _onpu_icon_texture: Texture2D = null
var _left_q_texture: Texture2D = null
var _right_e_texture: Texture2D = null


func _ready() -> void:
	var mplus: Font = load("res://assets/fonts/Mplus2-Medium.otf")
	if mplus != null:
		mplus.fallbacks = [ThemeDB.fallback_font]
		_font = mplus
	else:
		_font = ThemeDB.fallback_font
	var din_res: FontFile = load("res://assets/fonts/D-DIN-PRO-700-Bold.otf")
	if din_res != null:
		din_res.fallbacks = [_font]
		din_res.set_extra_spacing(0, TextServer.SPACING_GLYPH, -1)
		_font_din_logo = FontVariation.new()
		_font_din_logo.base_font = din_res
		_font_din_logo.set_spacing(TextServer.SPACING_GLYPH, -4)  # base(-1) + (-4) = net -5px
	_font_din = din_res if din_res != null else _font
	_stage_cfgs = StageData.get_stages()

	# Camera2D をコードで生成してワールド座標追従を有効化
	_camera = Camera2D.new()
	_camera.zoom = Vector2(1.0, 1.0)
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera.make_current()

	# アバター初期位置: 最後にプレイしたステージがあればそこへ、なければステージ0
	var _focus_id: int = StageSelectManager.last_played_stage_id
	if _focus_id < 0 or _focus_id >= StageSelectManager.STAGE_COUNT:
		_focus_id = 0
	var _start: Vector2 = StageSelectManager.get_world_pos(_focus_id)
	_char_pos = _start
	_char_target = _start
	_camera.position = _start

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(StageSelectManager.STAGE_COUNT):
		_anim_freq.append(rng.randf_range(0.5, 1.2))
		_anim_phase.append(rng.randf_range(0.0, TAU))
		_anim_amp.append(rng.randf_range(4.0, 9.0))
	if _is_debug():
		DebugSFXConfig.ensure_counted()
		_dbg_preview = AudioStreamPlayer.new()
		add_child(_dbg_preview)
	if _is_debug() or StageSelectManager.all_cleared or StageSelectManager.zou_cleared:
		StageSelectManager._zou_stage_idx = _find_zou_stage_idx()
	_bgm_canvas = $BgmUI
	_setup_bgm_ui()
	_sfx_hover = AudioStreamPlayer.new()
	_sfx_hover.stream = load("res://assets/sounds/pinon.wav")
	_sfx_hover.volume_db = -10.0
	add_child(_sfx_hover)
	_sfx_click = AudioStreamPlayer.new()
	_sfx_click.stream = load("res://assets/sounds/se_click.wav")
	_sfx_click.volume_db = -14.5
	add_child(_sfx_click)
	_sfx_on = AudioStreamPlayer.new()
	_sfx_on.stream = load("res://assets/sounds/se_on.wav")
	_sfx_on.volume_db = -14.5
	add_child(_sfx_on)
	_sfx_spot02 = AudioStreamPlayer.new()
	_sfx_spot02.stream = load("res://assets/sounds/skill_airdash.wav")
	_sfx_spot02.volume_db = -10.0
	add_child(_sfx_spot02)
	_sfx_telop_soft = AudioStreamPlayer.new()
	_sfx_telop_soft.stream = load("res://assets/sounds/Telop_Soft_25.wav")
	add_child(_sfx_telop_soft)
	_onpu_texture      = load("res://assets/UI/onpu.svg")      as Texture2D
	_onpu_icon_texture = load("res://assets/UI/onpu_icon.svg") as Texture2D
	_left_q_texture    = load("res://assets/UI/LEFT_Q.svg")    as Texture2D
	_right_e_texture   = load("res://assets/UI/RIGHT_E.svg")   as Texture2D
	# 直前クリアで解放されたステージがあれば演出を開始する
	var unlocked: Array[int] = StageSelectManager.last_unlocked_ids.duplicate()
	StageSelectManager.last_unlocked_ids.clear()
	var return_id: int = StageSelectManager.last_played_stage_id
	_unlock_source_stage = return_id
	start_unlock_focus(unlocked, return_id)
	if StageSelectManager.all_cleared and not _final_direction_played and not StageSelectManager.zou_cleared and not StageSelectManager.zou_cleared:
		_play_final_direction.call_deferred()
	if StageSelectManager.zou_cleared:
		_zou_world_pos = StageSelectManager.get_grid_world_pos(1, 8)
		# ZOU クリア後にステージセレクトへ戻ったとき、キャラをマップ中央付近に配置
		if StageSelectManager.last_played_stage_id == StageSelectManager._zou_stage_idx:
			_char_pos = _zou_world_pos
			_char_target = _zou_world_pos
			_camera.position = _zou_world_pos
	# BGM 解放状態を同期してから新解放チェック
	BGMManager.set_unlocked_bgm_ids(StageSelectManager.get_unlocked_bgm_ids())
	# 既解放ゾーンのライン収納を初期化（セーブデータ読み込み時）
	var _already_unlocked := StageSelectManager.get_unlocked_bgm_ids()
	for _zi in range(StageSelectManager._bgm_zones.size()):
		var _init_bgm_id: String = str(StageSelectManager._bgm_zones[_zi].get("unlocks_bgm", ""))
		if _already_unlocked.has(_init_bgm_id):
			_bgm_line_retract_progress[_zi] = 1.0
	var newly_unlocked_bgms: Array[String] = StageSelectManager.check_bgm_unlocks()
	if newly_unlocked_bgms.size() > 0:
		var bgm_id: String = newly_unlocked_bgms[0]
		var zone_idx: int = _get_zone_idx_for_bgm(bgm_id)
		if zone_idx >= 0:
			_bgm_unlock_bgm_id = bgm_id
			_bgm_unlock_zone_center = StageSelectManager.get_bgm_zone_centers()[zone_idx]
			if _is_focusing:
				_bgm_unlock_pending = true
			else:
				_start_bgm_unlock_sequence()
	# 矢印ボタン表示（解放トラック1種のみなら非表示）
	_update_bgm_button_labels()
	_start_bgm_label_anim.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	_process_bubble(delta)
	_process_popup_border(delta)

	# BGM 拡大パネル L/R タイマー
	if _bgm_lr_collapse_timer > 0.0:
		_bgm_lr_collapse_timer -= delta
		if _bgm_lr_collapse_timer <= 0.0:
			_bgm_lr_collapse_timer = -1.0
			if not _bgm_right_click_held and not _bgm_x_btn_held:
				_bgm_do_collapse()

	# BGM ライン収納アニメーション進行（解禁演出とは独立して動く）
	for _rzi in _bgm_line_retract_progress.keys():
		if _bgm_line_retract_progress[_rzi] < 1.0:
			_bgm_line_retract_progress[_rzi] = minf(
				_bgm_line_retract_progress[_rzi] + delta / 2.5, 1.0)

	# 描線アニメーション進行（フォーカス演出終了後も継続するため常時実行）
	var _line_any_active: bool = false
	for _lk in _line_fade_progress:
		if _line_pending_keys.has(_lk):
			continue  # カメラ未到着の線はまだ進めない
		if _line_fade_progress[_lk] < 1.0:
			_line_fade_progress[_lk] = minf(
				_line_fade_progress[_lk] + delta / UNLOCK_LINE_FADE_DURATION, 1.0)
			_line_any_active = true
	if _line_any_active and not _is_focusing:
		queue_redraw()

	# フォーカス演出中は通常の入力・描画更新をスキップ
	if _is_focusing:
		_process_focus(delta)
		queue_redraw()
		return

	# BGM 解禁演出
	if _bgm_unlock_directing:
		_bgm_unlock_elapsed += delta
		match _bgm_unlock_phase:
			1:  # カメラスライド（0.5s EASE_OUT QUAD）
				var t: float = minf(_bgm_unlock_elapsed / 0.5, 1.0)
				var et: float = 1.0 - pow(1.0 - t, 2.0)
				_camera.position = _bgm_unlock_cam_start.lerp(_bgm_unlock_zone_center, et)
				if t >= 1.0:
					_camera.position = _bgm_unlock_zone_center
					_bgm_unlock_phase = 2
					_bgm_unlock_elapsed = 0.0
					_spawn_bgm_unlock_particles(_bgm_unlock_zone_center)
					_bgm_do_expand()
					if not _bgm_unlock_is_preview:
						BGMManager.unlock_bgm(_bgm_unlock_bgm_id)
					var _unlock_zi: int = _get_zone_idx_for_bgm(_bgm_unlock_bgm_id)
					if _unlock_zi >= 0:
						_bgm_line_retract_progress[_unlock_zi] = 0.0
					# 円変色・音符アイコンは 0.3s 後（Phase 2 内で設定）
			2:  # 爆発後: 0.3s で円変色・音符アイコン出現 → ライン収納完了で Phase 3 へ
				if _bgm_unlock_visual_zi < 0 and _bgm_unlock_elapsed >= 0.3:
					_bgm_unlock_visual_zi = _get_zone_idx_for_bgm(_bgm_unlock_bgm_id)
					_bgm_update_expanded_label()
					_update_bgm_button_labels()
				if _bgm_unlock_visual_zi >= 0 and _bgm_line_retract_progress.get(_bgm_unlock_visual_zi, 1.0) >= 1.0:
					_bgm_unlock_phase = 3
					_bgm_unlock_elapsed = 0.0
			3:  # 表示待機（0.5s）
				if _bgm_unlock_elapsed >= 0.5:
					_bgm_unlock_phase = 4
					_bgm_unlock_elapsed = 0.0
					_bgm_do_collapse()
			4:  # 収納アニメーション待ち（0.15s）
				if _bgm_unlock_elapsed >= 0.15:
					_bgm_unlock_directing = false
					_bgm_unlock_phase = 0
					_bgm_unlock_is_preview = false
					_bgm_unlock_visual_zi = -1
					_char_pos = _camera.position
					_char_target = _camera.position
		queue_redraw()
		return

	# 最終ステージ演出中は通常処理をスキップ（コルーチンが制御する）
	if _final_directing:
		queue_redraw()
		return

	# 右スティックによるスナップ移動
	var rx: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var r_magnitude: float = Vector2(rx, ry).length()

	if r_magnitude < 0.2:
		# ニュートラル状態に戻ったらスナップ再入力を許可
		_snap_ready = true
	elif r_magnitude >= _SNAP_THRESHOLD and _snap_ready and _popup_stage < 0 and not _esc_popup:
		# 80%以上倒された かつ スナップ可能状態
		_snap_ready = false
		var stick_dir: Vector2 = Vector2(rx, ry).normalized()
		var snap_target: int = _find_snap_target(stick_dir)
		if snap_target >= 0:
			_char_pos = StageSelectManager.get_world_pos(snap_target)
			_char_target = _char_pos
			_char_moved_by_user = true
			var prev_nearest: int = _nearest
			_nearest = snap_target
			if _nearest != prev_nearest:
				_sfx_hover.play()
			queue_redraw()

	# アバター移動速度を算出（前フレーム差分）
	var prev_char_pos: Vector2 = _char_pos

	# ゲームパッドスティック
	var sx: float = Input.get_axis("ui_left", "ui_right")
	var sy: float = Input.get_axis("ui_up", "ui_down")
	var pad_active: bool = absf(sx) > 0.1 or absf(sy) > 0.1
	if pad_active:
		_char_pos += Vector2(sx, sy).normalized() * _PAD_SPEED * delta
		# アバターはビューポート内に収める
		var half_view: Vector2 = get_viewport_rect().size / 2.0 / _camera.zoom
		var view_min: Vector2 = _camera.position - half_view
		var view_max: Vector2 = _camera.position + half_view
		_char_pos = _char_pos.clamp(view_min, view_max)
		_char_target = _char_pos
		_char_moved_by_user = true
	else:
		# マウス追跡（アバターはビューポート内に収める）
		var half_view: Vector2 = get_viewport_rect().size / 2.0 / _camera.zoom
		var view_min: Vector2 = _camera.position - half_view
		var view_max: Vector2 = _camera.position + half_view
		var clamped_target: Vector2 = _char_target.clamp(view_min, view_max)
		var new_pos: Vector2 = _char_pos.lerp(clamped_target, _CHAR_LERP * delta)
		if new_pos.distance_to(_char_pos) > 0.5:
			_char_moved_by_user = true
		_char_pos = new_pos

	# アバター移動速度を更新
	_char_vel = (_char_pos - prev_char_pos) / delta

	# 最近傍ステージ更新（ユーザー操作で動いたとき・ポップアップ非表示時のみ）
	if _char_moved_by_user and _popup_stage < 0 and not _esc_popup:
		_char_moved_by_user = false
		var prev_nearest: int = _nearest
		_nearest = _find_nearest_accessible()
		if _nearest >= 0 and _nearest != prev_nearest:
			_sfx_hover.play()

	# ZOU 近接チェック
	if StageSelectManager.zou_cleared and not _final_directing:
		var prev_zou_near: bool = _zou_near
		_zou_near = _char_pos.distance_to(_zou_world_pos) < _PROX_DIST
		if _zou_near and not prev_zou_near:
			_sfx_hover.play()

	# BGM ボタンはポップアップ表示中に無効化
	if _btn_prev:
		var popup_open := _popup_stage >= 0 or _esc_popup
		_btn_prev.disabled = popup_open
		_btn_next.disabled = popup_open

	_update_camera(delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	# 入力モード自動切替
	if event is InputEventMouseButton and event.pressed:
		_set_input_mode(0)
	elif event is InputEventKey and event.pressed:
		_set_input_mode(0)
	elif event is InputEventJoypadButton and event.pressed:
		_set_input_mode(1)

	# 最終ステージ演出中: Phase3入力のみ受け付け、他は全てブロック
	if _final_directing:
		if _final_phase3 == 1:
			if event is InputEventMouseMotion:
				var new_hover: bool = _final_phase3_btn_rect.has_point(event.position)
				if new_hover != _final_phase3_hover:
					_final_phase3_hover = new_hover
					queue_redraw()
			if (
				(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or
				(event is InputEventKey and event.pressed and not event.is_echo()) or
				(event is InputEventJoypadButton and event.pressed)
			):
				_final_phase3_input_received = true
		return

	# BGM 解禁演出中: スキップ入力のみ受け付け
	if _bgm_unlock_directing:
		var is_skip: bool = (
			(event is InputEventMouseButton and event.pressed and
				(event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT))
			or (event is InputEventJoypadButton and event.pressed and
				(event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_X))
		)
		if is_skip:
			if _bgm_unlock_phase == 2:
				# Phase2 中: ライン収納を即完了してPhase3へ（演出キャンセル）
				_bgm_advance_from_phase2()
			else:
				_bgm_unlock_skip_count += 1
				if _bgm_unlock_skip_count >= 2:
					_bgm_unlock_skip()
		return

	if event is InputEventKey:
		if event.keycode == KEY_CTRL:
			_ctrl_held = event.pressed
			queue_redraw()

	# マウス位置 → 自キャラターゲット更新
	if event is InputEventMouseMotion:
		_char_target = get_canvas_transform().affine_inverse() * event.position
		_char_moved_by_user = true
		if _esc_popup:
			_update_esc_popup_hover(event.position)
		elif _popup_stage >= 0:
			_update_popup_hover(event.position)

	# [DEBUG] BGM演出プレビュー（B キー: ゾーンを順番にプレビュー）
	if _is_debug() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		_dbg_trigger_bgm_preview()
		get_viewport().set_input_as_handled()
		return

	# [DEBUG] デバッグクリック処理（他のUIより先に処理）
	if _is_debug() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# SE選択パネルはCtrl押下中のみ受け付ける
		if _ctrl_held and _handle_dbg_sfx_click(event.position):
			return

	# タイトル戻り確認ポップアップ
	if _esc_popup:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_esc_popup_click(event.position)
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_esc_popup = false
				queue_redraw()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_handle_esc_popup_confirm(_esc_popup_yes_hovered)
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_B:
				_esc_popup = false
				queue_redraw()
			elif event.button_index == JOY_BUTTON_A:
				_handle_esc_popup_confirm(_esc_popup_yes_hovered)
		return

	# ステージ選択確認ポップアップ
	if _popup_stage >= 0:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_popup_click(event.position)
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_popup_stage = -1
				_nearest = _find_nearest_accessible()
				queue_redraw()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				if _popup_yes_hovered or _popup_no_hovered:
					_handle_popup_confirm(_popup_yes_hovered)
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_B:
				_popup_stage = -1
				_nearest = _find_nearest_accessible()
				queue_redraw()
			elif event.button_index == JOY_BUTTON_A:
				_handle_popup_confirm(_popup_yes_hovered)
		return

	# 決定: マウス左クリック or ゲームパッドA or Enter
	var is_confirm: bool = (
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)
		or (event is InputEventKey and event.pressed and not event.echo
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER))
	)
	if is_confirm and _zou_near and StageSelectManager.zou_cleared:
		_popup_stage = StageSelectManager._zou_stage_idx
		_popup_yes_hovered = true
		_popup_no_hovered = false
		_sfx_click.play()
		queue_redraw()
		return

	if is_confirm and _nearest >= 0:
		_popup_stage = _nearest
		_popup_yes_hovered = true
		_popup_no_hovered = false
		_sfx_click.play()
		queue_redraw()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_esc_popup = true
		_esc_popup_yes_hovered = false
		_esc_popup_no_hovered = false
		_sfx_click.play()
		queue_redraw()

	# Q/E キーでBGM切り替え（ポップアップ非表示中のみ）
	if event is InputEventKey and event.pressed and not event.echo and _popup_stage < 0 and not _esc_popup:
		if event.keycode == KEY_Q:
			BGMManager.select_prev_bgm()
			_start_bgm_label_anim()
			_bgm_lr_collapse_timer = 0.5
			if not _bgm_expanded:
				_bgm_do_expand()
		elif event.keycode == KEY_E:
			BGMManager.select_next_bgm()
			_start_bgm_label_anim()
			_bgm_lr_collapse_timer = 0.5
			if not _bgm_expanded:
				_bgm_do_expand()

	# 右クリック保持で BGM 拡大パネル表示
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and _popup_stage < 0 and not _esc_popup:
		if event.pressed:
			_bgm_right_click_held = true
			_bgm_do_expand()
		else:
			_bgm_right_click_held = false
			if not _bgm_x_btn_held:
				_bgm_do_collapse()

	# L/R ボタンでBGM切り替え（ポップアップ非表示中のみ）
	if event is InputEventJoypadButton and event.pressed and _popup_stage < 0 and not _esc_popup:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			BGMManager.select_prev_bgm()
			_start_bgm_label_anim()
			_bgm_lr_collapse_timer = 0.5
			if not _bgm_expanded:
				_bgm_do_expand()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			BGMManager.select_next_bgm()
			_start_bgm_label_anim()
			_bgm_lr_collapse_timer = 0.5
			if not _bgm_expanded:
				_bgm_do_expand()
		# X ボタン保持で BGM 拡大パネル表示
		elif event.button_index == JOY_BUTTON_X:
			_bgm_x_btn_held = true
			_bgm_do_expand()
		# Start ボタンで ESC ポップアップ
		elif event.button_index == JOY_BUTTON_START:
			if not _esc_popup and _popup_stage < 0 and not _final_directing:
				_esc_popup = true
				_esc_popup_yes_hovered = false
				_esc_popup_no_hovered = false
				_sfx_click.play()
				queue_redraw()

	# X ボタンリリースで収納
	if event is InputEventJoypadButton and not event.pressed and event.button_index == JOY_BUTTON_X:
		_bgm_x_btn_held = false
		if not _bgm_right_click_held:
			_bgm_do_collapse()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size

	# ─── 画面固定レイヤー ───
	# get_canvas_transform() は world→screen。逆変換を draw_set_transform_matrix に
	# 与えることで「draw座標 = screen座標」になる。
	var screen_xform := get_canvas_transform().affine_inverse()
	draw_set_transform_matrix(screen_xform)

	draw_rect(Rect2(Vector2.ZERO, vp), _BG_COLOR)

	# STAGE / SELECT ロゴ（画面固定）
	if _font_din_logo:
		var logo_fs: int = 400
		var logo_x: float = -20.0
		var logo_asc: float = _font_din_logo.get_ascent(logo_fs)
		var logo_dsc: float = _font_din_logo.get_descent(logo_fs)
		var stage_y: float  = logo_asc - 170.0
		var select_y: float = stage_y + logo_dsc + 10.0 + logo_asc - 300.0
		var logo_col := Color(GameConfig.INK_COLOR,0.2)
		draw_string(_font_din_logo, Vector2(logo_x, stage_y),  "STAGE",  HORIZONTAL_ALIGNMENT_LEFT, -1, logo_fs, logo_col)
		draw_string(_font_din_logo, Vector2(logo_x, select_y), "SELECT", HORIZONTAL_ALIGNMENT_LEFT, -1, logo_fs, logo_col)

	# ─── ワールド座標レイヤー ───
	# Identity = ノードのローカル（=ワールド）座標。Camera2D が自動でスクリーンに変換する。
	draw_set_transform_matrix(Transform2D())

	# 接続ライン
	for conn in StageSelectManager.get_connections():
		var a: int = conn[0]
		var b: int = conn[1]
		if StageSelectManager.get_state(a) == StageSelectManager.StageState.LOCKED:
			continue
		if StageSelectManager.get_state(b) == StageSelectManager.StageState.LOCKED:
			continue
		# 描線アニメーション: 解放元ドットから新ドットへ線が伸びる
		var key: String = "%d_%d" % [mini(a, b), maxi(a, b)]
		var from_pt: Vector2
		var to_pt: Vector2
		if _line_fade_progress.has(key):
			var t: float = _line_fade_progress[key]
			var src_id: int = _line_draw_from.get(key, a)
			var dst_id: int = b if src_id == a else a
			from_pt = _dot_pos(src_id)
			to_pt = from_pt.lerp(_dot_pos(dst_id), t)
		else:
			from_pt = _dot_pos(a)
			to_pt = _dot_pos(b)
		draw_line(from_pt, to_pt, _LINE_COLOR, _LINE_WIDTH)

	# BGM 解禁ゾーン: 線・点（解放済み = #f23052、未解放 = #433647）
	if not _final_directing:
		var zones: Array = StageSelectManager._bgm_zones
		var centers: Array[Vector2] = StageSelectManager.get_bgm_zone_centers()
		var unlocked_ids: Array = StageSelectManager.get_unlocked_bgm_ids()
		# 演出中のゾーンは _bgm_unlock_visual_zi が確定するまで視覚的に未解放として扱う
		var _animating_zi: int = -1
		if _bgm_unlock_directing:
			_animating_zi = _get_zone_idx_for_bgm(_bgm_unlock_bgm_id)
		for zi in range(mini(zones.size(), centers.size())):
			var center: Vector2 = centers[zi]
			var bgm_id: String = str(zones[zi].get("unlocks_bgm", ""))
			var is_unlocked: bool
			if zi == _animating_zi:
				is_unlocked = _bgm_unlock_visual_zi >= 0
			else:
				is_unlocked = unlocked_ids.has(bgm_id)
			var zone_color: Color = _BGM_ZONE_UNLOCKED_COLOR if is_unlocked else _BGM_ZONE_COLOR
			var retract_prog: float = _bgm_line_retract_progress.get(zi, 1.0) if is_unlocked else 0.0
			for sid in zones[zi].get("required_stages", []):
				var sid_int: int = int(sid)
				if StageSelectManager.get_state(sid_int) == StageSelectManager.StageState.CLEARED:
					if retract_prog < 1.0:
						var stage_pos: Vector2 = StageSelectManager.get_world_pos(sid_int)
						var draw_start: Vector2 = stage_pos.lerp(center, retract_prog)
						draw_line(draw_start, center, zone_color, _LINE_WIDTH, true)
			draw_circle(center, _BGM_ZONE_DOT_RADIUS, zone_color)
			if is_unlocked and _onpu_texture != null:
				# 音符をドット内に収まるサイズで中央配置（白）
				# SVG内の音符は概ねx:[830,1060] y:[392,634]、中心(945,513)
				const NOTE_H_SVG: float = 242.0
				const NOTE_CX_SVG: float = 945.0
				const NOTE_CY_SVG: float = 513.0
				var svg_scale: float = _BGM_ZONE_DOT_RADIUS * 1.224 / NOTE_H_SVG
				draw_texture_rect(_onpu_texture,
					Rect2(center - Vector2(NOTE_CX_SVG * svg_scale, NOTE_CY_SVG * svg_scale),
						Vector2(1920.0 * svg_scale, 1080.0 * svg_scale)),
					false, Color.WHITE)

	# ステージドット（LOCKEDは描画しない）
	for i in range(StageSelectManager.STAGE_COUNT):
		var state: int = StageSelectManager.get_state(i)
		if state == StageSelectManager.StageState.LOCKED:
			continue
		var pos: Vector2 = _dot_pos(i)
		var is_near: bool = (i == _nearest and _popup_stage < 0 and not _esc_popup)

		# 最終ステージ演出中はzoom逆数でドットサイズを補正
		var draw_radius: float = _DOT_RADIUS / maxf(_camera.zoom.x, 0.01) if _final_directing else _DOT_RADIUS
		# ぼよよんアニメーション中の半径を計算
		if not _final_directing and i == _unlock_anim_stage and _unlock_anim_stage >= 0:
			var t: float = _unlock_anim_elapsed / UNLOCK_ANIM_DURATION
			var bounce: float
			if t < 0.25:
				bounce = lerp(1.0, 1.6, t / 0.25)
			elif t < 0.5:
				bounce = lerp(1.6, 0.8, (t - 0.25) / 0.25)
			elif t < 0.75:
				bounce = lerp(0.8, 1.2, (t - 0.5) / 0.25)
			else:
				bounce = lerp(1.2, 1.0, (t - 0.75) / 0.25)
			draw_radius = _DOT_RADIUS * bounce

		# HOVERドット: 1.5倍に拡大
		if is_near:
			draw_radius *= 1.5

		match state:
			StageSelectManager.StageState.UNLOCKED:
				draw_circle(pos, draw_radius, _HOVER_COLOR if is_near else _UNLOCKED_COLOR)
			StageSelectManager.StageState.CLEARED:
				draw_circle(pos, draw_radius, _HOVER_COLOR if is_near else _CLEARED_COLOR)
				draw_circle(pos, draw_radius * 0.35, Color.WHITE)

	# ZOU ドット（zou_cleared かつ演出終了後）
	if StageSelectManager.zou_cleared and not _final_directing:
		const ZOU_R: float = _DOT_RADIUS * 2.0
		var zou_col: Color = _HOVER_COLOR if _zou_near else GameConfig.INK_COLOR
		draw_circle(_zou_world_pos, ZOU_R, zou_col)
		draw_circle(_zou_world_pos, ZOU_R * 0.35, Color.WHITE)

	# 自キャラ（通常時: ワールド座標レイヤーで描画）
	if _popup_stage < 0 and not _esc_popup and not _final_directing:
		draw_circle(_char_pos, _CHAR_RADIUS, _CHAR_COLOR)
		draw_circle(_char_pos, _CHAR_RADIUS * 0.55, _BG_COLOR)

	# ─── 再び画面固定レイヤーへ戻してUI要素を描画 ───
	draw_set_transform_matrix(get_canvas_transform().affine_inverse())

	# 吹き出し（スケール＋フェードアニメーション）
	if _bubble_phase > 0 and _bubble_stage_id >= 0:
		var params: Vector2 = _get_bubble_draw_params()
		_draw_bubble(_bubble_stage_id, NAN, NAN, params.x, params.y)

	# 装飾トライアングル（左下）
	if not _final_directing:
		var deco_w: float = 500.0
		_draw_tri_deco(Vector2(20.0, vp.y - deco_w * 0.9495 - 20.0), deco_w, Color(GameConfig.INK_COLOR,0.2))

	# ラベル
	if not _final_directing:
		var title_hint: String = "Start: タイトルへ戻る" if _input_mode == 1 else "ESC: タイトルへ戻る"
		draw_string(_font, Vector2(40, vp.y - 32), title_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.5, 0.3, 0.3))

	# 確認ポップアップ
	if _popup_stage >= 0:
		_draw_popup(vp)

	# タイトル戻り確認ポップアップ
	if _esc_popup:
		_draw_esc_popup(vp)

	# [DEBUG] SE選択パネル（Ctrl押下中のみ画面中央に表示）
	if _is_debug() and _ctrl_held and (DebugSFXConfig.in_count > 0 or DebugSFXConfig.out_count > 0):
		_draw_dbg_sfx_panel()

	# 自キャラ（ポップアップ・SEパネル表示中のみ・最前面）
	# ポップアップおよびSEパネルより後に描画することで最前面に表示する
	if (_popup_stage >= 0 or _esc_popup or (_is_debug() and _ctrl_held)) and not _final_directing:
		var screen_char_pos: Vector2 = get_canvas_transform() * _char_pos
		draw_circle(screen_char_pos, _CHAR_RADIUS, _CHAR_COLOR)
		draw_circle(screen_char_pos, _CHAR_RADIUS * 0.55, _BG_COLOR)

	# 最終ステージ演出: 暗転オーバーレイ
	if _final_directing and _final_overlay_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, _final_overlay_alpha))

	# スパーク伝播ライン（暗転レイヤーより上に描画・赤い太線、モーフ前のみ）
	if _final_directing and not _final_spark_drawn.is_empty() and _final_morph_phase == 0:
		var ct: Transform2D = get_canvas_transform()
		for edge in _final_spark_drawn:
			var from_s: Vector2 = ct * (edge[0] as Vector2)
			var to_s: Vector2 = ct * (edge[1] as Vector2)
			draw_line(from_s, to_s, Color(0.95, 0.19, 0.32), 4.0, true)
		if _final_flash_alpha > 0.0:
			var flash_s: Vector2 = ct * _final_flash_pos
			draw_circle(flash_s, 10.0, Color(1.0, 0.5, 0.5, _final_flash_alpha))

	# モーフィング・縮小フェーズ描画（ワールド座標→スクリーン変換）
	if _final_morph_phase >= 1 and _final_morph_src_pts.size() > 1:
		var vp_c: Vector2 = vp * 0.5
		var ct_m: Transform2D = get_canvas_transform()
		var n_mp: int = _final_morph_src_pts.size()
		var s_scale: float = lerpf(1.0, _final_shrink_end, _final_shrink_t)
		for i in range(n_mp):
			var wp: Vector2 = _final_morph_src_pts[i].lerp(_final_morph_dst_pts[i], _final_morph_t)
			var sp: Vector2 = ct_m * wp
			var fp: Vector2 = vp_c + (sp - vp_c) * s_scale
			var wp_n: Vector2 = _final_morph_src_pts[(i + 1) % n_mp].lerp(_final_morph_dst_pts[(i + 1) % n_mp], _final_morph_t)
			var sp_n: Vector2 = ct_m * wp_n
			var fp_n: Vector2 = vp_c + (sp_n - vp_c) * s_scale
			draw_line(fp, fp_n, Color(0.95, 0.19, 0.32), 4.0, true)

	# 最終ステージ演出 Phase3: THANK YOU FOR PLAYING!（ZOU線より上のレイヤー）
	if _final_directing and _final_phase3 >= 1:
		_draw_final_phase3(vp)


# ---------- 吹き出し ----------

func _draw_bubble(stage_id: int, fixed_bx: float = NAN, fixed_by: float = NAN,
		bub_scale: float = 1.0, bub_alpha: float = 1.0) -> void:
	# _draw_bubble はスクリーン座標セクションで呼ばれる。ワールド座標を画面座標へ変換する。
	var dot: Vector2 = get_canvas_transform() * _dot_pos(stage_id)
	var bw: float = _BUBBLE_W
	var bh: float = _BUBBLE_H
	var vp: Vector2 = get_viewport_rect().size
	var bx: float
	var by: float
	var draw_tail: bool
	if is_nan(fixed_bx):
		bx = dot.x + _DOT_RADIUS + 12.0
		by = dot.y - bh - _DOT_RADIUS
		bx = clampf(bx, 6.0, vp.x - bw - 6.0)
		by = clampf(by, 6.0, vp.y - bh - 6.0)
		draw_tail = true
	else:
		bx = fixed_bx
		by = fixed_by
		draw_tail = false

	# スケール変換（バブル中心を軸・均等スケール）
	if bub_scale != 1.0:
		var cx: float = bx + bw * 0.5
		var cy: float = by + bh * 0.5
		var s: float = bub_scale
		var scale_xform := Transform2D(
			Vector2(s, 0.0),
			Vector2(0.0, s),
			Vector2(cx * (1.0 - s), cy * (1.0 - s))
		)
		draw_set_transform_matrix(get_canvas_transform().affine_inverse() * scale_xform)

	var bd: float    = 4.5
	var str_w: float = _BUBBLE_STRIPE_W   # 縦ストライプ幅 = 15px
	var ix: float    = bx + bd
	var iy: float    = by + bd
	var iw: float    = bw - bd * 2.0      # 144px
	var ih: float    = bh - bd * 2.0      # 194px

	# ─── ドロップシャドウ ───
	draw_rect(Rect2(bx + 12.5, by + 12.5, bw, bh), Color(GameConfig.INK_COLOR,0.30 * bub_alpha))

	# ─── 外枠 ───
	draw_rect(Rect2(bx, by, bw, bh), _BUBBLE_DARK)

	# ─── 右コンテンツ背景（白・全高） ───
	var cx: float = ix + str_w    # bx + 18
	var cw: float = iw - str_w    # 129px
	draw_rect(Rect2(cx, iy, cw, ih), _BUBBLE_BG)

	# ─── 左縦ストライプ（全高・ダークのみ）───
	draw_rect(Rect2(ix, iy, str_w, ih), _BUBBLE_DARK)

	# ─── ストライプ内 トライアングル（▷◁▷◁▷ 下から 100%→20%） ───
	var para_zone_bot: float = iy + _BUBBLE_HDR_H + _BUBBLE_FIG_H
	var tri_count_b: int  = 10
	var tri_mid_b: float  = ix + str_w * 0.5
	var shape_h_b: float  = str_w * 1.155
	var half_h_b: float   = shape_h_b * 0.5
	var notch_h_b: float  = shape_h_b * 0.25
	var spacing_b: float  = str_w * 0.712
	var last_cy_b: float  = para_zone_bot - half_h_b - 5.0 + 100.0
	var first_cy_b: float = last_cy_b - float(tri_count_b - 1) * spacing_b
	for tri_i_b in range(tri_count_b):
		var cy_b: float   = first_cy_b + float(tri_i_b) * spacing_b
		var tri_a_b: float = float(tri_i_b + 1) * 0.10
		var tri_col: Color = Color(_BUBBLE_RED.r, _BUBBLE_RED.g, _BUBBLE_RED.b, bub_alpha * tri_a_b)
		var pts_b: PackedVector2Array
		if tri_i_b % 2 == 0:  # ▷ 右向き（左辺フラット）
			pts_b = PackedVector2Array([
				Vector2(ix,          cy_b - half_h_b),
				Vector2(tri_mid_b,   cy_b - notch_h_b),
				Vector2(ix + str_w,  cy_b),
				Vector2(tri_mid_b,   cy_b + notch_h_b),
				Vector2(ix,          cy_b + half_h_b),
			])
		else:                  # ◁ 左向き（右辺フラット）
			pts_b = PackedVector2Array([
				Vector2(ix + str_w, cy_b - half_h_b),
				Vector2(ix + str_w, cy_b + half_h_b),
				Vector2(tri_mid_b,  cy_b + notch_h_b),
				Vector2(ix,         cy_b),
				Vector2(tri_mid_b,  cy_b - notch_h_b),
			])
		draw_colored_polygon(pts_b, tri_col)

	# ─── プレイ済み（クリア済み）判定 ───
	var has_rec: bool = StageSelectManager.get_best_time(stage_id) >= 0.0
	var is_zou: bool = stage_id == StageSelectManager._zou_stage_idx

	# ─── ヘッダ: #N ───
	var num_fs: int = 39
	var num_str: String = "#60" if is_zou else "#%d" % (stage_id + 1)
	draw_string(_font_din, Vector2(cx + 7.5, iy - 6.0 + _font_din.get_ascent(num_fs)),
		num_str, HORIZONTAL_ALIGNMENT_LEFT, cw - 12.0, num_fs, _BUBBLE_DARK)

	# ─── ヘッダ: ステージ名（未プレイは ???） ───
	var name_str: String
	if is_zou:
		name_str = tr("STAGE_ZOU") if has_rec else "???"
	else:
		name_str = StageSelectManager.get_stage_name(stage_id) if has_rec else "???"
	if not name_str.is_empty():
		var name_fs: int = 20
		draw_string(_font, Vector2(cx + 7.5, iy + 47.5 + _font.get_ascent(name_fs)),
			name_str, HORIZONTAL_ALIGNMENT_LEFT, cw - 12.0, name_fs, _BUBBLE_DARK)

	# ─── 図形エリア（未プレイは大きな ? をグレーで表示） ───
	var hdr_fig_h: float = _BUBBLE_HDR_H + _BUBBLE_FIG_H
	var fig_cx: float = cx + cw * 0.5
	var fig_cy: float = iy + _BUBBLE_HDR_H + _BUBBLE_FIG_H * 0.5
	if has_rec:
		var shape_r: float = 52.5 if stage_id >= 4 else 42.0
		_draw_mini_shape(stage_id, Vector2(fig_cx, fig_cy), shape_r)
	else:
		var q_fs: int = 66
		var q_c: Color = Color(0.72, 0.68, 0.66)
		var q_asc: float = _font_din.get_ascent(q_fs)
		var q_dsc: float = _font_din.get_descent(q_fs)
		draw_string(_font_din, Vector2(cx, fig_cy + (q_asc - q_dsc) * 0.5), "?",
			HORIZONTAL_ALIGNMENT_CENTER, cw, q_fs, q_c)

	# ─── BEST 枠 2 本 ───
	var box_pad: float  = 7.5
	var box_gap: float  = 4.5
	var rows_top: float = iy + hdr_fig_h
	var rows_bot: float = iy + ih - box_pad
	var row_h: float    = (rows_bot - rows_top - box_gap) * 0.5
	var box_x: float    = ix + box_pad + 20.0
	var box_w: float    = iw - box_pad * 2.0 - 20.0
	var label_w: float  = _BUBBLE_LABEL_W   # 67.5px

	var bt_str: String = "%.2f" % StageSelectManager.get_best_time(stage_id) if has_rec else "---"
	var bm_str: String = "%d"   % StageSelectManager.get_best_move_count(stage_id) if has_rec else "---"

	_draw_bubble_best_row(box_x, rows_top,                   box_w, row_h, label_w, "BEST", "CLEAR", "TIME",  bt_str)
	_draw_bubble_best_row(box_x, rows_top + row_h + box_gap, box_w, row_h, label_w, "BEST", "TRY",   "COUNT", bm_str)

	# ─── しっぽ ───
	var tail_base_x: float = clampf(dot.x - _DOT_RADIUS * 0.5, bx + 12.0, bx + bw - 12.0)
	if draw_tail:
		var tail_tip: Vector2 = dot + Vector2(-_DOT_RADIUS * 0.5, -_DOT_RADIUS * 0.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tail_base_x - 9.0, by + bh),
			Vector2(tail_base_x + 9.0, by + bh),
			tail_tip,
		]), _BUBBLE_DARK)

	# ─── 四隅サークル（ボタン・リザルトと同じデザイン言語） ───
	var corner_r: float = bd * 1.25   # ≈ 5.6px
	draw_circle(Vector2(bx + 1.0,      by + 1.0),      corner_r, _BUBBLE_DARK)
	draw_circle(Vector2(bx + bw - 1.0, by + 1.0),      corner_r, _BUBBLE_DARK)
	draw_circle(Vector2(bx + 1.0,      by + bh - 1.0), corner_r, _BUBBLE_DARK)
	draw_circle(Vector2(bx + bw - 1.0, by + bh - 1.0), corner_r, _BUBBLE_DARK)

	# ─── ボーダーラインアニメーション（時計回り、しっぽ付け根スタート）───
	if draw_tail and _border_phase_t >= BORDER_WAIT:
		var anim_t: float = minf((_border_phase_t - BORDER_WAIT) / BORDER_ANIM_DUR, 1.0)
		var perimeter: float = 2.0 * (bw + bh)
		var head_d: float = anim_t * (perimeter + BORDER_LINE_LEN)
		var tail_d: float = head_d - BORDER_LINE_LEN
		_draw_border_line(bx, by, bw, bh, tail_base_x, tail_d, head_d,
				Color(0.95, 0.19, 0.32, bub_alpha))

	# スクリーン座標系を復元
	if bub_scale != 1.0:
		draw_set_transform_matrix(get_canvas_transform().affine_inverse())


func _draw_bubble_best_row(bx: float, by: float, bw: float, bh: float, lw: float,
		l1: String, l2: String, l3: String, value_str: String) -> void:
	# ラベルセル（ダーク）
	draw_rect(Rect2(bx, by, lw, bh), _BUBBLE_DARK)
	# ラベルテキスト（白・行間を半分に詰める）
	var lfs: int = 12
	var lasc: float = _font.get_ascent(lfs)
	var ldsc: float = _font.get_descent(lfs)
	var lh: float   = (lasc + ldsc + 1.0) * 0.5 + 3.0   # 行間 +3px (2 × 1.5)
	var block_h: float = lh * 2.0 + lasc + ldsc
	var ty: float = by + (bh - block_h) * 0.5 + lasc
	var tx: float = bx + 4.5
	var tw: float = lw - 6.0
	draw_string(_font, Vector2(tx, ty),            l1, HORIZONTAL_ALIGNMENT_LEFT, tw, lfs, _BUBBLE_BG)
	draw_string(_font, Vector2(tx, ty + lh),       l2, HORIZONTAL_ALIGNMENT_LEFT, tw, lfs, _BUBBLE_BG)
	draw_string(_font, Vector2(tx, ty + lh * 2.0), l3, HORIZONTAL_ALIGNMENT_LEFT, tw, lfs, _BUBBLE_BG)
	# 値テキスト（DIN Bold・右寄せ・グレー背景）
	var vx: float  = bx + lw
	var vw: float  = bw - lw
	var vfs: int   = 34
	var vasc: float = _font_din.get_ascent(vfs)
	var vdsc: float = _font_din.get_descent(vfs)
	draw_rect(Rect2(vx, by, vw, bh), _BUBBLE_VAL_BG)
	draw_string(_font_din, Vector2(vx, by + (bh + vasc - vdsc) * 0.5),
		value_str, HORIZONTAL_ALIGNMENT_RIGHT, vw - 7.5, vfs, _BUBBLE_DARK)


func _draw_mini_shape(stage_id: int, center: Vector2, r: float) -> void:
	var cfg: Dictionary = {}
	if stage_id < _stage_cfgs.size():
		cfg = _stage_cfgs[stage_id] as Dictionary
	var stype: String = str(cfg.get("shape_type", cfg.get("type", "circle")))
	var fill_c := Color(_BUBBLE_RED.r, _BUBBLE_RED.g, _BUBBLE_RED.b, 0.22)
	var line_c := _BUBBLE_DARK
	var pts := PackedVector2Array()

	# カスタム形状: shape_polygon_vertices が存在する場合はそちらを優先
	if cfg.has("shape_polygon_vertices"):
		var raw: Array = cfg["shape_polygon_vertices"] as Array
		if not raw.is_empty():
			var raw_pts := PackedVector2Array()
			var max_dist: float = 0.01
			for v in raw:
				var arr: Array = v as Array
				var p := Vector2(float(arr[0]), float(arr[1]))
				raw_pts.append(p)
				max_dist = maxf(max_dist, p.length())
			var sc: float = r / max_dist
			for p in raw_pts:
				pts.append(center + p * sc)
	else:
		match stype:
			"triangle":
				for i in range(3):
					var a: float = -PI * 0.5 + float(i) * TAU / 3.0
					pts.append(center + Vector2(cos(a), sin(a)) * r)
			"square":
				var h: float = r * 0.707
				pts = PackedVector2Array([
					center + Vector2(-h, -h), center + Vector2(h, -h),
					center + Vector2(h,  h),  center + Vector2(-h, h),
				])
			"rhombus":
				pts = PackedVector2Array([
					center + Vector2(0, -r),        center + Vector2(r * 0.72, 0),
					center + Vector2(0,  r),        center + Vector2(-r * 0.72, 0),
				])
			"hexagon":
				for i in range(6):
					var a: float = float(i) * TAU / 6.0 - PI / 6.0
					pts.append(center + Vector2(cos(a), sin(a)) * r)
			_:  # circle やその他
				draw_circle(center, r, fill_c)
				var cp := PackedVector2Array()
				for i in range(32):
					cp.append(center + Vector2(cos(float(i) * TAU / 32.0), sin(float(i) * TAU / 32.0)) * r)
				draw_polyline(cp + PackedVector2Array([cp[0]]), line_c, 2.25)
				return

	if pts.size() < 3:
		return
	draw_colored_polygon(pts, fill_c)
	draw_polyline(pts + PackedVector2Array([pts[0]]), line_c, 2.25)
	for p in pts:
		draw_circle(p, 3.0, line_c)


# ---------- ポップアップ ----------

func _popup_rects(vp: Vector2) -> Dictionary:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5
	var popup_rect := Rect2(cx - _POPUP_W * 0.5, cy - _POPUP_H * 0.5, _POPUP_W, _POPUP_H)
	var btn_w: float  = 220.0
	var btn_h: float  = 64.0
	var cbtn_gap: float = btn_w * 0.5 + 30.0   # = 140
	var btn_cy: float = cy + 40.0
	var yes_rect := Rect2(cx - cbtn_gap - btn_w * 0.5, btn_cy - btn_h * 0.5, btn_w, btn_h)
	var no_rect  := Rect2(cx + cbtn_gap - btn_w * 0.5, btn_cy - btn_h * 0.5, btn_w, btn_h)
	return { "popup": popup_rect, "yes": yes_rect, "no": no_rect }


func _stage_popup_rects(vp: Vector2) -> Dictionary:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5
	var pw: float = _POPUP_W
	var ph: float = _POPUP_H
	# バブル(300) + ギャップ(20) + ダイアログ(280) = 600px を縦中央配置
	var bubble_gap: float = 20.0
	var popup_top: float = cy + (_BUBBLE_H + bubble_gap - ph) * 0.5
	var popup_rect := Rect2(cx - pw * 0.5, popup_top, pw, ph)
	var btn_w: float  = 220.0
	var btn_h: float  = 64.0
	var cbtn_gap: float = btn_w * 0.5 + 30.0
	var btn_cy: float = popup_top + ph * 0.5 + 40.0
	var yes_rect := Rect2(cx - cbtn_gap - btn_w * 0.5, btn_cy - btn_h * 0.5, btn_w, btn_h)
	var no_rect  := Rect2(cx + cbtn_gap - btn_w * 0.5, btn_cy - btn_h * 0.5, btn_w, btn_h)
	return { "popup": popup_rect, "yes": yes_rect, "no": no_rect }


func _draw_popup(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(GameConfig.INK_COLOR,0.50))
	var r: Dictionary = _stage_popup_rects(vp)
	var pr: Rect2 = r["popup"]
	var yr: Rect2 = r["yes"]
	var nr: Rect2 = r["no"]

	# バブルをダイアログ上辺から20px上に離して水平中央配置（ダイアログより先に描画）
	var bubble_bx: float = pr.position.x + (pr.size.x - _BUBBLE_W) * 0.5
	var bubble_by: float = pr.position.y - _BUBBLE_H - 20.0
	_draw_bubble(_popup_stage, bubble_bx, bubble_by)

	draw_rect(Rect2(pr.position + Vector2(15.0, 15.0), pr.size), Color(GameConfig.INK_COLOR,0.25))
	draw_rect(pr, Color(1.0, 1.0, 1.0))
	_draw_rect_border_with_corners_local(pr, GameConfig.INK_COLOR, 5.75)

	# 問いかけ文（ESCダイアログと同一レイアウト）
	var q_fs: int = 42
	var dialog_cy: float = pr.position.y + pr.size.y * 0.5
	draw_string(_font_din, Vector2(pr.position.x, dialog_cy - 45.0), "このステージをプレイしますか？",
		HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, q_fs, Color(0.95, 0.19, 0.32))

	_draw_popup_btn(yr, "はい",   _popup_yes_hovered)
	_draw_popup_btn(nr, "いいえ", _popup_no_hovered)

	if _popup_border_phase_t >= BORDER_WAIT:
		var anim_t: float = minf((_popup_border_phase_t - BORDER_WAIT) / BORDER_ANIM_DUR, 1.0)
		var perimeter: float = 2.0 * (pr.size.x + pr.size.y)
		var head_d: float = anim_t * (perimeter + POPUP_BORDER_LINE_LEN)
		var tail_d: float = head_d - POPUP_BORDER_LINE_LEN
		_draw_border_line_topleft(pr.position.x, pr.position.y, pr.size.x, pr.size.y,
				tail_d, head_d, Color(0.95, 0.19, 0.32))


func _update_popup_hover(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _stage_popup_rects(vp)
	var new_yes: bool = (r["yes"] as Rect2).has_point(pos)
	var new_no: bool  = (r["no"]  as Rect2).has_point(pos)
	if (new_yes and not _popup_yes_hovered) or (new_no and not _popup_no_hovered):
		_sfx_on.play()
	_popup_yes_hovered = new_yes
	_popup_no_hovered  = new_no


func _handle_popup_click(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _stage_popup_rects(vp)
	if (r["yes"] as Rect2).has_point(pos):
		_handle_popup_confirm(true)
	elif (r["no"] as Rect2).has_point(pos):
		_handle_popup_confirm(false)
	elif not (r["popup"] as Rect2).has_point(pos):
		# パネル外クリックで閉じる
		_popup_stage = -1
		_nearest = _find_nearest_accessible()
		queue_redraw()


func _handle_popup_confirm(yes: bool) -> void:
	_sfx_click.play()
	if yes:
		StageSelectManager.pending_stage_id = _popup_stage
		TransitionManager.play_triangle(func(): get_tree().change_scene_to_file(_GAME_SCENE))
	else:
		_popup_stage = -1
		_nearest = _find_nearest_accessible()
		queue_redraw()


# ---------- ヘルパー ----------

func _dot_pos(i: int) -> Vector2:
	if i == StageSelectManager._zou_stage_idx:
		return _zou_world_pos
	var base: Vector2 = StageSelectManager.get_world_pos(i)
	var oy: float = sin(_elapsed * _anim_freq[i] + _anim_phase[i]) * _anim_amp[i]
	return base + Vector2(0.0, oy)


func _calc_world_bounds() -> Rect2:
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	var found: bool = false
	for i in range(StageSelectManager.STAGE_COUNT):
		if StageSelectManager.get_state(i) == StageSelectManager.StageState.LOCKED:
			continue
		var pos: Vector2 = StageSelectManager.get_world_pos(i)
		min_x = minf(min_x, pos.x)
		min_y = minf(min_y, pos.y)
		max_x = maxf(max_x, pos.x)
		max_y = maxf(max_y, pos.y)
		found = true
	if not found:
		return Rect2(Vector2.ZERO, Vector2(1920.0, 1080.0))
	var margin: float = 200.0
	return Rect2(min_x - margin, min_y - margin,
				 max_x - min_x + margin * 2.0,
				 max_y - min_y + margin * 2.0)


func _update_camera(delta: float) -> void:
	if _camera == null or _is_focusing:
		return
	if _popup_stage >= 0 or _esc_popup:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_view: Vector2 = viewport_size / 2.0 / _camera.zoom

	# 画面中心からのアバターのオフセットを -1〜1 に正規化
	var offset: Vector2 = _char_pos - _camera.position
	var offset_ratio: Vector2 = Vector2(
		offset.x / half_view.x,
		offset.y / half_view.y
	)

	# 楕円デッドゾーンの内外判定
	# (offset_ratio.x / DEAD_ZONE_X)^2 + (offset_ratio.y / DEAD_ZONE_Y)^2 > 1.0 なら外側
	var ellipse_val: float = pow(offset_ratio.x / SCROLL_DEAD_ZONE_X, 2.0) \
		+ pow(offset_ratio.y / SCROLL_DEAD_ZONE_Y, 2.0)
	var outside_dead_zone: bool = ellipse_val > 1.0

	var scroll_speed: Vector2 = Vector2.ZERO

	if outside_dead_zone:
		# デッドゾーン外: オフセット起因のスクロール速度（二乗で端に近いほど加速）
		var scroll_from_offset: Vector2 = Vector2(
			sign(offset_ratio.x) * pow(absf(offset_ratio.x), 2.0),
			sign(offset_ratio.y) * pow(absf(offset_ratio.y), 2.0)
		) * SCROLL_OFFSET_WEIGHT

		# アバター移動速度起因のスクロール速度
		var scroll_from_vel: Vector2 = _char_vel * SCROLL_VEL_WEIGHT

		scroll_speed = scroll_from_offset + scroll_from_vel

	_camera.position += scroll_speed * delta

	# カメラ位置をUNLOCKED/CLEAREDノードの範囲内にクランプ
	var cam_bounds: Rect2 = _calc_world_bounds()
	_camera.position = _camera.position.clamp(
		cam_bounds.position, cam_bounds.position + cam_bounds.size)


func start_unlock_focus(unlocked_ids: Array, return_stage_id: int = -1) -> void:
	_focus_return_id = return_stage_id
	if unlocked_ids.is_empty():
		return

	_newly_unlocked_ids = unlocked_ids.duplicate()

	# 事前登録: カメラ到着前に線が全体表示されることを防ぐ（progress=0 で pending 状態に置く）
	if return_stage_id >= 0:
		for uid in _newly_unlocked_ids:
			var pre_key: String = "%d_%d" % [mini(return_stage_id, uid), maxi(return_stage_id, uid)]
			_line_fade_progress[pre_key] = 0.0
			_line_draw_from[pre_key] = return_stage_id
			_line_pending_keys[pre_key] = true
	for conn in StageSelectManager.get_connections():
		var _ca: int = conn[0]
		var _cb: int = conn[1]
		if _newly_unlocked_ids.has(_ca) and _newly_unlocked_ids.has(_cb):
			var inter_pre_key: String = "%d_%d" % [_ca, _cb]
			if not _line_pending_keys.has(inter_pre_key):
				_line_fade_progress[inter_pre_key] = 0.0
				_line_draw_from[inter_pre_key] = _ca
				_line_pending_keys[inter_pre_key] = true

	# 時計回りにソート（直前ステージを中心とした角度順）
	var center: Vector2 = Vector2.ZERO
	if return_stage_id >= 0:
		center = StageSelectManager.get_world_pos(return_stage_id)
	var sorted_ids: Array = unlocked_ids.duplicate()
	sorted_ids.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector2 = StageSelectManager.get_world_pos(a) - center
		var pb: Vector2 = StageSelectManager.get_world_pos(b) - center
		return -pa.angle() < -pb.angle()
	)
	_focus_queue = sorted_ids
	_is_focusing = true
	_focus_elapsed = 0.0
	_unlock_anim_stage = -1
	_unlock_anim_elapsed = 0.0


func _process_focus(delta: float) -> void:
	# ── フェーズ1: ぼよよん演出中 ──
	if _unlock_anim_stage >= 0:
		_unlock_anim_elapsed += delta
		if _unlock_anim_elapsed >= UNLOCK_ANIM_DURATION:
			# ぼよよん終了 → 次のステージへ
			_unlock_anim_stage = -1
			_unlock_anim_elapsed = 0.0
			_focus_elapsed = 0.0
		queue_redraw()
		return

	# ── フェーズ2: キュー終了チェック ──
	if not _is_focusing or _focus_queue.is_empty():
		_is_focusing = false
		# 全ノードを巡り終えたら直前ステージへ戻り、自キャラを画面中央（カメラ位置）へ揃える
		if _focus_return_id >= 0:
			var return_pos: Vector2 = StageSelectManager.get_world_pos(_focus_return_id)
			_camera.position = return_pos
			_focus_return_id = -1
		# 自キャラをカメラ中央（画面中央）へ配置
		_char_pos = _camera.position
		_char_target = _camera.position
		return

	# ── フェーズ3: カメラ移動（リニア） ──
	var target_id: int = _focus_queue[0]
	var target_pos: Vector2 = StageSelectManager.get_world_pos(target_id)
	_camera.position = _camera.position.move_toward(target_pos, FOCUS_MOVE_SPEED * delta)

	if _camera.position.distance_to(target_pos) < 2.0:
		# 到着 → ぼよよん演出開始
		_camera.position = target_pos
		_focus_queue.pop_front()
		_unlock_anim_stage = target_id
		_unlock_anim_elapsed = 0.0

		# 接続ラインの描画アニメーション開始（pending 解除 = カメラ到着のタイミングで進行開始）
		if _unlock_source_stage >= 0:
			var key: String = "%d_%d" % [mini(_unlock_source_stage, target_id),
										  maxi(_unlock_source_stage, target_id)]
			_line_fade_progress[key] = 0.0
			_line_draw_from[key] = _unlock_source_stage
			_line_pending_keys.erase(key)

		# 新規解放ステージ同士を結ぶ線：pending 解除または新規登録
		for conn in StageSelectManager.get_connections():
			var ca: int = conn[0]
			var cb: int = conn[1]
			if ca != target_id and cb != target_id:
				continue
			var other_id: int = cb if ca == target_id else ca
			if not _newly_unlocked_ids.has(other_id):
				continue
			var inter_key: String = "%d_%d" % [ca, cb]
			if _line_pending_keys.has(inter_key):
				_line_draw_from[inter_key] = target_id  # 描く方向を到着順に合わせる
				_line_pending_keys.erase(inter_key)
			elif not _line_fade_progress.has(inter_key):
				_line_fade_progress[inter_key] = 0.0
				_line_draw_from[inter_key] = target_id

		# パーティクル生成
		_spawn_unlock_particles(target_pos)

		if _focus_queue.is_empty():
			_is_focusing = false
			if _bgm_unlock_pending:
				_bgm_unlock_pending = false
				_start_bgm_unlock_sequence()

	queue_redraw()


func _find_snap_target(stick_dir: Vector2) -> int:
	var best_id: int = -1
	var best_dist: float = INF
	var angle_limit: float = deg_to_rad(_SNAP_ANGLE_MAX)

	for i in range(StageSelectManager.STAGE_COUNT):
		var state: int = StageSelectManager.get_state(i)
		if state == StageSelectManager.StageState.LOCKED:
			continue
		var pos: Vector2 = StageSelectManager.get_world_pos(i)
		var to_stage: Vector2 = pos - _char_pos
		var dist: float = to_stage.length()
		if dist < 1.0:
			continue  # 現在地点と同じ位置は除外
		var angle_diff: float = absf(stick_dir.angle_to(to_stage.normalized()))
		if angle_diff <= angle_limit:
			if dist < best_dist:
				best_dist = dist
				best_id = i

	return best_id


# ---------- バブルアニメーション ----------

func _ease_out_back(t: float) -> float:
	const c1 := 1.70158
	const c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


func _ease_in_cubic(t: float) -> float:
	return t * t * t


func _get_bubble_want_id() -> int:
	if _popup_stage >= 0 or _esc_popup or _final_directing or _is_focusing:
		return -1
	if StageSelectManager.zou_cleared and _zou_near:
		return StageSelectManager._zou_stage_idx
	if _nearest >= 0 and not _zou_near:
		return _nearest
	return -1


func _get_bubble_draw_params() -> Vector2:
	# returns Vector2(scale, alpha)
	var t: float
	match _bubble_phase:
		1:  # 出現中
			t = minf(_bubble_t / BUBBLE_OPEN_DUR, 1.0)
			return Vector2(_ease_out_back(t), t)
		2:  # 全開
			return Vector2(1.0, 1.0)
		3:  # 消滅中
			t = minf(_bubble_t / BUBBLE_CLOSE_DUR, 1.0)
			var inv: float = 1.0 - _ease_in_cubic(t)
			return Vector2(inv, inv)
		_:
			return Vector2.ZERO


func _process_bubble(delta: float) -> void:
	var want_id: int = _get_bubble_want_id()
	match _bubble_phase:
		0:  # 非表示
			if want_id >= 0:
				_bubble_stage_id = want_id
				_bubble_phase = 1
				_bubble_t = 0.0
		1:  # 出現中
			_bubble_t += delta
			if want_id < 0:
				_bubble_phase = 3
				_bubble_t = 0.0
			elif want_id != _bubble_stage_id:
				_bubble_stage_id = want_id
				_bubble_t = 0.0
			elif _bubble_t >= BUBBLE_OPEN_DUR:
				_bubble_t = 0.0
				_bubble_phase = 2
		2:  # 全開
			if want_id < 0:
				_bubble_phase = 3
				_bubble_t = 0.0
			elif want_id != _bubble_stage_id:
				_bubble_stage_id = want_id
				_bubble_phase = 1
				_bubble_t = 0.0
		3:  # 消滅中
			_bubble_t += delta
			if want_id >= 0:
				_bubble_stage_id = want_id
				_bubble_phase = 1
				_bubble_t = 0.0
			elif _bubble_t >= BUBBLE_CLOSE_DUR:
				_bubble_t = 0.0
				_bubble_phase = 0
				_bubble_stage_id = -1

	# ボーダーラインタイマー: 全開中のみ進行、それ以外はリセット
	if _bubble_phase == 2:
		_border_phase_t = fmod(_border_phase_t + delta, BORDER_CYCLE)
	else:
		_border_phase_t = 0.0


# ---------- ボーダーラインアニメーション ----------

# 外周上の距離 d（しっぽ付け根=0、時計回り）をスクリーン座標に変換
func _get_perimeter_pos(d: float, bx: float, by: float, bw: float, bh: float,
		start_x: float) -> Vector2:
	var d0: float = (bx + bw) - start_x   # 底辺右端まで
	var d1: float = d0 + bh               # 右辺上端まで
	var d2: float = d1 + bw               # 上辺左端まで
	var d3: float = d2 + bh               # 左辺下端まで
	if d < d0:
		return Vector2(start_x + d, by + bh)
	elif d < d1:
		return Vector2(bx + bw, by + bh - (d - d0))
	elif d < d2:
		return Vector2(bx + bw - (d - d1), by)
	elif d < d3:
		return Vector2(bx, by + (d - d2))
	else:
		return Vector2(bx + (d - d3), by + bh)


# 外周上の tail_d〜head_d 区間に赤ラインを描画（コーナーで折れ曲がる）
func _draw_border_line(bx: float, by: float, bw: float, bh: float,
		start_x: float, tail_d: float, head_d: float, color: Color) -> void:
	var perimeter: float = 2.0 * (bw + bh)
	# コーナー地点（start_xからの累積距離）
	var d0: float = (bx + bw) - start_x
	var d1: float = d0 + bh
	var d2: float = d1 + bw
	var d3: float = d2 + bh
	# 外周範囲内にクランプ
	var vis_tail: float = maxf(tail_d, 0.0)
	var vis_head: float = minf(head_d, perimeter)
	if vis_tail >= vis_head:
		return
	# コーナーをブレークポイントとして収集し、線分ごとに描画
	var bp: Array[float] = [vis_tail, vis_head]
	for corner in [d0, d1, d2, d3]:
		if corner > vis_tail and corner < vis_head:
			bp.append(corner)
	bp.sort()
	for i in range(bp.size() - 1):
		var from_pos: Vector2 = _get_perimeter_pos(bp[i],     bx, by, bw, bh, start_x)
		var to_pos:   Vector2 = _get_perimeter_pos(bp[i + 1], bx, by, bw, bh, start_x)
		draw_line(from_pos, to_pos, color, 7.0, true)


func _process_popup_border(delta: float) -> void:
	if _popup_stage >= 0 or _esc_popup:
		_popup_border_phase_t = fmod(_popup_border_phase_t + delta, BORDER_CYCLE)
	else:
		_popup_border_phase_t = BORDER_WAIT


func _get_perimeter_pos_topleft(d: float, bx: float, by: float, bw: float, bh: float) -> Vector2:
	var d0: float = bw
	var d1: float = d0 + bh
	var d2: float = d1 + bw
	var d3: float = d2 + bh
	if d < d0:
		return Vector2(bx + d, by)
	elif d < d1:
		return Vector2(bx + bw, by + (d - d0))
	elif d < d2:
		return Vector2(bx + bw - (d - d1), by + bh)
	elif d < d3:
		return Vector2(bx, by + bh - (d - d2))
	else:
		return Vector2(bx + (d - d3), by)


func _draw_border_line_topleft(bx: float, by: float, bw: float, bh: float,
		tail_d: float, head_d: float, color: Color) -> void:
	var perimeter: float = 2.0 * (bw + bh)
	var d0: float = bw
	var d1: float = d0 + bh
	var d2: float = d1 + bw
	var d3: float = d2 + bh
	var vis_tail: float = maxf(tail_d, 0.0)
	var vis_head: float = minf(head_d, perimeter)
	if vis_tail >= vis_head:
		return
	var bp: Array[float] = [vis_tail, vis_head]
	for corner in [d0, d1, d2, d3]:
		if corner > vis_tail and corner < vis_head:
			bp.append(corner)
	bp.sort()
	for i in range(bp.size() - 1):
		var from_pos: Vector2 = _get_perimeter_pos_topleft(bp[i],     bx, by, bw, bh)
		var to_pos:   Vector2 = _get_perimeter_pos_topleft(bp[i + 1], bx, by, bw, bh)
		draw_line(from_pos, to_pos, color, 5.0, true)


func _find_nearest_accessible() -> int:
	var best: int = -1
	var best_d: float = _PROX_DIST
	for i in range(StageSelectManager.STAGE_COUNT):
		var state: int = StageSelectManager.get_state(i)
		if state == StageSelectManager.StageState.LOCKED:
			continue
		var d: float = _char_pos.distance_to(_dot_pos(i))
		if d < best_d:
			best_d = d
			best = i
	return best


# ---------- タイトル戻りポップアップ ----------

func _draw_esc_popup(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(GameConfig.INK_COLOR,0.50))
	var r: Dictionary = _popup_rects(vp)
	var pr: Rect2 = r["popup"]
	var yr: Rect2 = r["yes"]
	var nr: Rect2 = r["no"]
	var cy: float  = pr.position.y + pr.size.y * 0.5

	draw_rect(Rect2(pr.position + Vector2(15.0, 15.0), pr.size), Color(GameConfig.INK_COLOR,0.25))
	draw_rect(pr, Color(1.0, 1.0, 1.0))
	_draw_rect_border_with_corners_local(pr, GameConfig.INK_COLOR, 5.75)

	draw_string(_font_din, Vector2(pr.position.x, cy - 45.0), "タイトル画面へ戻りますか？",
		HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 42, Color(0.95, 0.19, 0.32))

	_draw_popup_btn(yr, "はい",   _esc_popup_yes_hovered)
	_draw_popup_btn(nr, "いいえ", _esc_popup_no_hovered)

	if _popup_border_phase_t >= BORDER_WAIT:
		var anim_t: float = minf((_popup_border_phase_t - BORDER_WAIT) / BORDER_ANIM_DUR, 1.0)
		var perimeter: float = 2.0 * (pr.size.x + pr.size.y)
		var head_d: float = anim_t * (perimeter + POPUP_BORDER_LINE_LEN)
		var tail_d: float = head_d - POPUP_BORDER_LINE_LEN
		_draw_border_line_topleft(pr.position.x, pr.position.y, pr.size.x, pr.size.y,
				tail_d, head_d, Color(0.95, 0.19, 0.32))


func _update_esc_popup_hover(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _popup_rects(vp)
	var new_yes: bool = (r["yes"] as Rect2).has_point(pos)
	var new_no: bool  = (r["no"]  as Rect2).has_point(pos)
	if (new_yes and not _esc_popup_yes_hovered) or (new_no and not _esc_popup_no_hovered):
		_sfx_on.play()
	_esc_popup_yes_hovered = new_yes
	_esc_popup_no_hovered  = new_no


func _handle_esc_popup_click(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _popup_rects(vp)
	if (r["yes"] as Rect2).has_point(pos):
		_handle_esc_popup_confirm(true)
	elif (r["no"] as Rect2).has_point(pos):
		_handle_esc_popup_confirm(false)
	elif not (r["popup"] as Rect2).has_point(pos):
		_esc_popup = false
		queue_redraw()


func _handle_esc_popup_confirm(yes: bool) -> void:
	_sfx_click.play()
	if yes:
		BGMManager.stop()
		TransitionManager.play_diagonal(func(): get_tree().change_scene_to_file(_GAME_SCENE))
	else:
		_esc_popup = false
		queue_redraw()


# ---------- ポップアップ共通ヘルパー ----------

func _draw_rect_border_with_corners_local(rect: Rect2, color: Color, bw: float) -> void:
	var dot_r: float = bw * 1.25
	draw_rect(rect, color, false, bw)
	draw_circle(rect.position,                        dot_r, color)
	draw_circle(Vector2(rect.end.x, rect.position.y), dot_r, color)
	draw_circle(Vector2(rect.position.x, rect.end.y), dot_r, color)
	draw_circle(rect.end,                             dot_r, color)


func _draw_zou_popup(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(GameConfig.INK_COLOR,0.50))
	var r: Dictionary = _popup_rects(vp)
	var pr: Rect2 = r["popup"]
	var yr: Rect2 = r["yes"]
	var nr: Rect2 = r["no"]
	draw_rect(Rect2(pr.position + Vector2(15.0, 15.0), pr.size), Color(GameConfig.INK_COLOR,0.25))
	draw_rect(pr, Color(1.0, 1.0, 1.0))
	_draw_rect_border_with_corners_local(pr, GameConfig.INK_COLOR, 5.75)
	var q_fs: int = 42
	var dialog_cy: float = pr.position.y + pr.size.y * 0.5
	draw_string(_font_din if _font_din != null else _font,
		Vector2(pr.position.x, dialog_cy - 45.0), "ZOU をリプレイしますか？",
		HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, q_fs, Color(0.95, 0.19, 0.32))
	_draw_popup_btn(yr, "はい",   _zou_yes_hovered)
	_draw_popup_btn(nr, "いいえ", _zou_no_hovered)


func _update_zou_popup_hover(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _popup_rects(vp)
	var new_yes: bool = (r["yes"] as Rect2).has_point(pos)
	var new_no: bool  = (r["no"]  as Rect2).has_point(pos)
	if (new_yes and not _zou_yes_hovered) or (new_no and not _zou_no_hovered):
		_sfx_on.play()
	_zou_yes_hovered = new_yes
	_zou_no_hovered  = new_no


func _handle_zou_popup_click(pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var r: Dictionary = _popup_rects(vp)
	if (r["yes"] as Rect2).has_point(pos):
		_handle_zou_popup_confirm(true)
	elif (r["no"] as Rect2).has_point(pos):
		_handle_zou_popup_confirm(false)
	elif not (r["popup"] as Rect2).has_point(pos):
		_zou_popup = false
		queue_redraw()


func _handle_zou_popup_confirm(yes: bool) -> void:
	_sfx_click.play()
	if yes:
		StageSelectManager.pending_stage_id = StageSelectManager._zou_stage_idx
		TransitionManager.play_triangle(func(): get_tree().change_scene_to_file(_GAME_SCENE))
	else:
		_zou_popup = false
		queue_redraw()


func _draw_popup_btn(rect: Rect2, label: String, hovered: bool) -> void:
	const BTN_BW: float = 5.75
	var dot_r: float = BTN_BW * 1.25
	var fs: int = 40
	var baseline_y: float = rect.position.y + (rect.size.y + _font.get_ascent(fs) - _font.get_descent(fs)) * 0.5
	if hovered:
		# アニメーション形状変化（ui_renderer の ON ボタンと同仕様）
		var t: float = Time.get_ticks_msec() / 500.0
		var mo: float = minf(5.0, minf(rect.size.x, rect.size.y) * 0.45)
		var pts := PackedVector2Array([
			Vector2(rect.position.x + sin(t * 0.71 + 0.00) * mo, rect.position.y + sin(t * 0.53 + 1.10) * mo),
			Vector2(rect.end.x      + sin(t * 0.63 + 2.30) * mo, rect.position.y + sin(t * 0.79 + 3.50) * mo),
			Vector2(rect.end.x      + sin(t * 0.58 + 4.70) * mo, rect.end.y      + sin(t * 0.67 + 5.90) * mo),
			Vector2(rect.position.x + sin(t * 0.82 + 7.10) * mo, rect.end.y      + sin(t * 0.61 + 8.30) * mo),
		])
		var so := Vector2(12.5, 12.5)
		draw_colored_polygon(PackedVector2Array([pts[0]+so, pts[1]+so, pts[2]+so, pts[3]+so]),
			Color(GameConfig.INK_COLOR,0.30))
		draw_colored_polygon(pts, Color(0.95, 0.19, 0.32, 0.9))
		for i in range(4):
			draw_line(pts[i], pts[(i + 1) % 4], GameConfig.INK_COLOR, BTN_BW, true)
		for c in pts:
			draw_circle(c, dot_r, GameConfig.INK_COLOR)
		draw_string(_font, Vector2(rect.position.x, baseline_y), label,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, Color(1.0, 0.937, 0.89))
	else:
		draw_rect(Rect2(rect.position + Vector2(12.5, 12.5), rect.size), Color(GameConfig.INK_COLOR,0.30))
		draw_rect(rect, Color(1.0, 0.937, 0.89))
		_draw_rect_border_with_corners_local(rect, GameConfig.INK_COLOR, BTN_BW)
		draw_string(_font, Vector2(rect.position.x, baseline_y), label,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, GameConfig.INK_COLOR)


func _draw_tri_deco(origin: Vector2, w: float, color: Color) -> void:
	var h: float = w * 0.9495  # SVG bbox 475.5 / 500.85
	var shapes: Array = [
		[Vector2(0.2886,0.1754), Vector2(0.2886,0.3510), Vector2(0.1442,0.2633), Vector2(0.0000,0.1754), Vector2(0.1442,0.0877), Vector2(0.2886,0.0000)],
		[Vector2(0.0010,0.3918), Vector2(0.0010,0.2165), Vector2(0.1454,0.3041), Vector2(0.2896,0.3918), Vector2(0.1454,0.4795), Vector2(0.0010,0.5672)],
		[Vector2(0.6101,0.1968), Vector2(0.4659,0.2847), Vector2(0.3218,0.3722), Vector2(0.3216,0.1969), Vector2(0.3216,0.0213), Vector2(0.4659,0.1091)],
		[Vector2(0.3557,0.3918), Vector2(0.5000,0.3040), Vector2(0.6442,0.2163), Vector2(0.6442,0.3918), Vector2(0.6443,0.5673), Vector2(0.4999,0.4794)],
		[Vector2(0.7114,0.6081), Vector2(0.8557,0.5202), Vector2(0.9999,0.4326), Vector2(0.9999,0.6080), Vector2(1.0000,0.7836), Vector2(0.8557,0.6958)],
		[Vector2(0.0010,0.8244), Vector2(0.0010,0.6490), Vector2(0.1454,0.7367), Vector2(0.2896,0.8244), Vector2(0.1454,0.9121), Vector2(0.0010,1.0000)],
	]
	for shape in shapes:
		var pts := PackedVector2Array()
		for p in shape:
			pts.append(origin + Vector2((p as Vector2).x * w, (p as Vector2).y * h))
		draw_colored_polygon(pts, color)


# ---------- [DEBUG] SE選択パネル ----------

func _is_debug() -> bool:
	return OS.has_feature("editor") or Engine.is_editor_hint()


func _find_zou_stage_idx() -> int:
	# [DEBUG] キャッシュを強制リセットしてマニフェスト変更を反映させる
	StageData._stages_cache_ready = false
	var stages: Array = StageData.get_stages()
	for i in range(stages.size()):
		if str(stages[i].get("_source_file", "")) == "zou.json":
			return i
	return -1


# ---------- 最終ステージ演出 ----------

func _compute_angular_walk_order(positions: Array[Vector2]) -> PackedInt32Array:
	var n: int = positions.size()
	var centroid: Vector2 = Vector2.ZERO
	for p in positions:
		centroid += p
	centroid /= float(n)
	var items: Array[Dictionary] = []
	for i in range(n):
		var d: Vector2 = positions[i] - centroid
		items.append({"idx": i, "ang": atan2(d.y, d.x)})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["ang"] as float) < (b["ang"] as float)
	)
	var result := PackedInt32Array()
	result.resize(n)
	for t in range(n):
		result[t] = items[t]["idx"] as int
	return result


func _draw_final_phase3(vp: Vector2) -> void:
	if _final_phase3 != 1:
		return
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5
	var fnt: Font = _font_din if _font_din != null else _font
	const FS: int = 36
	const PAD_X: float = 44.0
	const PAD_Y: float = 22.0
	var text: String = "THANK YOU FOR PLAYING!"
	var tw: float = fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	var th: float = fnt.get_ascent(FS) + fnt.get_descent(FS)
	var bw: float = tw + PAD_X * 2.0
	var bh: float = th + PAD_Y * 2.0
	var btn: Rect2 = Rect2(cx - bw * 0.5, cy - bh * 0.5, bw, bh)
	_final_phase3_btn_rect = btn
	var bg_color: Color = Color(0.95, 0.19, 0.32) if _final_phase3_hover else Color.WHITE
	draw_rect(btn, bg_color, true)
	draw_rect(btn, GameConfig.INK_COLOR, false, 3.0)
	var text_color: Color = Color.WHITE if _final_phase3_hover else GameConfig.INK_COLOR
	var text_cx: float = cx - 185.0
	var text_y: float = cy + fnt.get_ascent(FS) * 0.5 - fnt.get_descent(FS) * 0.5
	draw_string(fnt, Vector2(text_cx, text_y), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, FS, text_color)


func _play_final_direction() -> void:
	_final_directing = true
	_final_direction_played = true

	# ── Prologue: 背景暗転（3秒）+ BGMフェードダウン ──
	var dim_tween: Tween = create_tween()
	dim_tween.tween_property(self, "_final_overlay_alpha", 0.7, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var bgm_tween: Tween = create_tween()
	bgm_tween.tween_method(func(v: float) -> void: BGMManager.set_volume_db(v), 0.0, -80.0, 3.0)
	bgm_tween.tween_callback(func() -> void: BGMManager.stop())

	await dim_tween.finished

	# ── Phase 1: ZOU輪郭弧長順でステージドットを巡回 ──

	# ステージマップの AABB
	var positions: Array[Vector2] = []
	for i in range(StageSelectManager.STAGE_COUNT):
		positions.append(StageSelectManager.get_world_pos(i))
	var aabb_min: Vector2 = positions[0]
	var aabb_max: Vector2 = positions[0]
	for p in positions:
		aabb_min = Vector2(minf(aabb_min.x, p.x), minf(aabb_min.y, p.y))
		aabb_max = Vector2(maxf(aabb_max.x, p.x), maxf(aabb_max.y, p.y))
	var aabb_center: Vector2 = (aabb_min + aabb_max) * 0.5

	# モーフィング前の輪郭経路（ステージIDの順序リスト）
	var walk_order: Array = [14,19,25,29,24,17,16,23,32,33,37,45,49,48,47,46,38,39,30,26,21,20,10,7,5,0,1,2,3,4,6,9]

	var n: int = walk_order.size()

	# 起点: last_played_stage_id をwalk_order上で探す（なければ0から）
	var start_stage: int = StageSelectManager.last_played_stage_id
	if start_stage < 0 or start_stage >= StageSelectManager.STAGE_COUNT:
		start_stage = 0
	var start_walk_idx: int = 0
	for k in range(n):
		if walk_order[k] == start_stage:
			start_walk_idx = k
			break

	_final_spark_drawn = []

	# ── Phase 1a: 全エッジをなぞる ──
	for edge_i in range(n):
		var from_i: int = (start_walk_idx + edge_i) % n
		var to_i: int = (from_i + 1) % n
		var from_pos: Vector2 = positions[walk_order[from_i]]
		var to_pos: Vector2 = positions[walk_order[to_i]]

		# カメラを次のポイントへ（全エッジ）
		var cam_tween: Tween = create_tween()
		cam_tween.tween_property(_camera, "position", to_pos, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# エッジ登録＋フラッシュ
		_final_spark_drawn.append([from_pos, to_pos])
		_final_flash_pos = from_pos
		_final_flash_alpha = 1.0
		var flash_tween: Tween = create_tween()
		flash_tween.tween_property(self, "_final_flash_alpha", 0.0, 0.1)
		_sfx_spot02.play()

		await get_tree().create_timer(0.1).timeout
		queue_redraw()

	# ── Phase 1b: ズームアウト（1.0秒）→ 1秒待機 ──
	var zoom_tw_ph1b: Tween = create_tween()
	zoom_tw_ph1b.set_parallel(true)
	zoom_tw_ph1b.tween_property(_camera, "zoom", Vector2(0.3, 0.3), 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	zoom_tw_ph1b.tween_property(_camera, "position", aabb_center, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await zoom_tw_ph1b.finished
	await get_tree().create_timer(1.0).timeout

	# ── Phase 1c: モーフィング（1.5秒）──
	var src_w: Array[Vector2] = []
	for wi in range(n):
		src_w.append(positions[walk_order[(start_walk_idx + wi) % n]])
	var dst_w: Array[Vector2] = []
	var stage_list: Array = StageData.get_stages()
	var zou_si: int = StageSelectManager._zou_stage_idx
	if zou_si >= 0 and zou_si < stage_list.size():
		var zd_m: Dictionary = stage_list[zou_si]
		var verts_m: Array = zd_m.get("shape_polygon_vertices", [])
		if verts_m.size() > 0:
			var vm_min_x: float = INF; var vm_max_x: float = -INF
			var vm_min_y: float = INF; var vm_max_y: float = -INF
			for vm_v in verts_m:
				vm_min_x = minf(vm_min_x, float(vm_v[0])); vm_max_x = maxf(vm_max_x, float(vm_v[0]))
				vm_min_y = minf(vm_min_y, float(vm_v[1])); vm_max_y = maxf(vm_max_y, float(vm_v[1]))
			var vm_cx: float = (vm_min_x + vm_max_x) * 0.5
			var vm_cy: float = (vm_min_y + vm_max_y) * 0.5
			var vm_span: float = maxf(vm_max_x - vm_min_x, vm_max_y - vm_min_y)
			var vp_m: Vector2 = get_viewport_rect().size
			# 1.5×1.3=1.95倍サイズ（係数0.39）
			var mws: float = vp_m.y / 0.3 * 0.39 / maxf(vm_span * 0.5, 0.001)
			# ゲーム内ガイド（draw_guide_shape_fit_max: desired_r=min(600,360)/2=180px）に合わせた縮小係数
			_final_shrink_end = 180.0 / maxf(vp_m.y * 0.39, 1.0)
			var dst_wc: Vector2 = aabb_center + Vector2(-20.0, 20.0) / 0.3
			for vm_v in verts_m:
				dst_w.append(dst_wc + Vector2(float(vm_v[0]) - vm_cx, float(vm_v[1]) - vm_cy) * mws)
			if dst_w.size() > 1:
				var best_rot: int = 0
				var best_d: float = INF
				for ri in range(dst_w.size()):
					var d: float = dst_w[ri].distance_squared_to(src_w[0])
					if d < best_d:
						best_d = d
						best_rot = ri
				if best_rot > 0:
					var dst_rot: Array[Vector2] = []
					for ri in range(dst_w.size()):
						dst_rot.append(dst_w[(ri + best_rot) % dst_w.size()])
					dst_w = dst_rot
	_final_morph_src_pts = _resample_polygon(src_w, 200)
	_final_morph_dst_pts = _resample_polygon(dst_w, 200)
	_final_morph_t = 0.0
	_final_shrink_t = 0.0
	_final_morph_phase = 1
	_sfx_telop_soft.play()
	queue_redraw()
	var morph_tw: Tween = create_tween()
	morph_tw.tween_property(self, "_final_morph_t", 1.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await morph_tw.finished

	# ── Phase 2: ウェイト（3秒） ──
	await get_tree().create_timer(3.0).timeout

	# ── Phase 3: THANK YOU FOR PLAYING! ボタン ──
	_final_phase3 = 1
	_final_phase3_input_received = false
	_final_phase3_hover = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	queue_redraw()

	while not _final_phase3_input_received:
		await get_tree().process_frame

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_final_phase3_hover = false

	# ── Phase 4: ボタン消去・即時縮小 ──
	_final_phase3 = 0
	queue_redraw()
	var shrink_tw: Tween = create_tween()
	shrink_tw.tween_property(self, "_final_shrink_t", 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await shrink_tw.finished

	# ── Phase 5: BGM開始 → ゲーム遷移 ──
	_final_morph_phase = 0
	BGMManager.set_volume_db(0.0)
	BGMManager.stop()
	_final_overlay_alpha = 0.0
	StageSelectManager.pending_stage_id = StageSelectManager._zou_stage_idx
	TransitionManager.play_triangle(func(): get_tree().change_scene_to_file(_GAME_SCENE))


func _resample_polygon(pts: Array[Vector2], target_n: int) -> Array[Vector2]:
	var m: int = pts.size()
	if m < 2 or target_n < 2:
		return pts.duplicate()
	# 累積弧長を計算（閉じた多角形）
	var arc: Array[float] = []
	arc.append(0.0)
	for i in range(m):
		arc.append(arc[-1] + pts[i].distance_to(pts[(i + 1) % m]))
	var total: float = arc[-1]
	if total < 0.001:
		var r: Array[Vector2] = []
		for _i in range(target_n):
			r.append(pts[0])
		return r
	var result: Array[Vector2] = []
	for si in range(target_n):
		var t_target: float = float(si) / float(target_n) * total
		# 二分探索で対応エッジを特定
		var lo: int = 0
		var hi: int = m - 1
		while lo < hi:
			var mid: int = (lo + hi) / 2
			if arc[mid + 1] < t_target:
				lo = mid + 1
			else:
				hi = mid
		var frac: float = 0.0
		var edge_len: float = arc[lo + 1] - arc[lo]
		if edge_len > 0.001:
			frac = (t_target - arc[lo]) / edge_len
		result.append(pts[lo].lerp(pts[(lo + 1) % m], frac))
	return result


func _dbg_panel_rect() -> Rect2:
	var rows: int = maxi(DebugSFXConfig.in_count, DebugSFXConfig.out_count)
	var pw: float = _DBG_COL_W * 2.0 + _DBG_COL_GAP + _DBG_PAD * 2.0
	var ph: float = _DBG_HEADER_H + rows * _DBG_ITEM_H + _DBG_PAD + 18.0
	var vp: Vector2 = get_viewport_rect().size
	var px: float = (vp.x - pw) * 0.5
	var py: float = (vp.y - ph) * 0.5
	return Rect2(px, py, pw, ph)


func _dbg_item_rect(col: int, row: int) -> Rect2:
	var pr: Rect2 = _dbg_panel_rect()
	var cx: float = pr.position.x + _DBG_PAD + col * (_DBG_COL_W + _DBG_COL_GAP)
	var cy: float = pr.position.y + _DBG_HEADER_H + row * _DBG_ITEM_H
	return Rect2(cx, cy, _DBG_COL_W, _DBG_ITEM_H)


func _draw_dbg_sfx_panel() -> void:
	var pr: Rect2 = _dbg_panel_rect()
	draw_rect(pr.grow(2.0), _DBG_BD)
	draw_rect(pr, _DBG_BG)
	var in_x: float = pr.position.x + _DBG_PAD
	var out_x: float = in_x + _DBG_COL_W + _DBG_COL_GAP
	var hy: float = pr.position.y + _DBG_HEADER_H * 0.78
	draw_string(_font, Vector2(in_x, hy), "in",
		HORIZONTAL_ALIGNMENT_CENTER, _DBG_COL_W, 15, _DBG_SEL)
	draw_string(_font, Vector2(out_x, hy), "out",
		HORIZONTAL_ALIGNMENT_CENTER, _DBG_COL_W, 15, _DBG_TXT)
	for row in range(DebugSFXConfig.in_count):
		_draw_dbg_item(0, row, row == DebugSFXConfig.in_idx)
	for row in range(DebugSFXConfig.out_count):
		_draw_dbg_item(1, row, row == DebugSFXConfig.out_idx)
	# ガイドテキスト
	var pr2: Rect2 = _dbg_panel_rect()
	draw_string(_font, Vector2(pr2.position.x, pr2.end.y - 5.0),
		"Ctrl キーを押している間だけ表示・操作可能",
		HORIZONTAL_ALIGNMENT_CENTER, pr2.size.x, 10,
		Color(0.45, 0.72, 0.80, 0.8))


func _draw_dbg_item(col: int, row: int, selected: bool) -> void:
	var r: Rect2 = _dbg_item_rect(col, row)
	var cy: float = r.position.y + r.size.y * 0.5
	var cx: float = r.position.x + 10.0
	var cr: float = 5.5
	var c: Color = _DBG_SEL if selected else _DBG_TXT
	if selected:
		draw_circle(Vector2(cx, cy), cr, c)
		draw_circle(Vector2(cx, cy), cr * 0.38, _DBG_BG)
	else:
		draw_circle(Vector2(cx, cy), cr, Color(c, 0.20))
		draw_arc(Vector2(cx, cy), cr, 0.0, TAU, 16, c, 1.2)
	draw_string(_font, Vector2(cx + cr + 5.0, r.position.y + r.size.y * 0.78),
		"%02d" % (row + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)


func _handle_dbg_sfx_click(pos: Vector2) -> bool:
	if DebugSFXConfig.in_count == 0 and DebugSFXConfig.out_count == 0:
		return false
	for row in range(DebugSFXConfig.in_count):
		if _dbg_item_rect(0, row).has_point(pos):
			DebugSFXConfig.in_idx = row
			if _dbg_preview:
				_dbg_preview.stream = load(DebugSFXConfig.in_path(row))
				_dbg_preview.play()
			queue_redraw()
			return true
	for row in range(DebugSFXConfig.out_count):
		if _dbg_item_rect(1, row).has_point(pos):
			DebugSFXConfig.out_idx = row
			if _dbg_preview:
				_dbg_preview.stream = load(DebugSFXConfig.out_path(row))
				_dbg_preview.play()
			queue_redraw()
			return true
	return false


# ---------- BGM 曲名表示 ----------

func _mk_bgm_btn(label_text: String) -> Button:
	var b := Button.new()
	b.text = label_text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", _BGM_LABEL_FONT_SIZE)
	b.add_theme_color_override("font_color", Color("#f23052"))
	b.add_theme_color_override("font_hover_color", Color("#f23052").lightened(0.25))
	b.add_theme_color_override("font_pressed_color", Color("#f23052").darkened(0.20))
	b.add_theme_color_override("font_disabled_color", Color(0.949, 0.188, 0.322, 0.35))
	return b


func _mk_note_label() -> Control:
	if _onpu_icon_texture != null:
		var t := TextureRect.new()
		t.texture = _onpu_icon_texture
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(18, 20)
		return t
	var l := Label.new()
	l.text = "♪"
	l.add_theme_font_size_override("font_size", _BGM_LABEL_FONT_SIZE)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _setup_bgm_ui() -> void:
	# フルスクリーン基準コントロール（CanvasLayer 内でアンカー基準を確保）
	var anchor := Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bgm_canvas.add_child(anchor)

	# 右下ラベル背景パネル（拡大パネルと同デザイン）
	var small_panel := PanelContainer.new()
	small_panel.anchor_left   = 1.0
	small_panel.anchor_right  = 1.0
	small_panel.anchor_top    = 1.0
	small_panel.anchor_bottom = 1.0
	small_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	small_panel.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	small_panel.offset_right  = -20.0
	small_panel.offset_bottom = -14.0
	var small_style := StyleBoxFlat.new()
	small_style.bg_color = Color(0.263, 0.212, 0.278, 0.9)
	small_style.set_corner_radius_all(10)
	small_style.content_margin_left   = 8.0
	small_style.content_margin_right  = 8.0
	small_style.content_margin_top    = 4.0
	small_style.content_margin_bottom = 4.0
	small_panel.add_theme_stylebox_override("panel", small_style)
	anchor.add_child(small_panel)

	# HBoxContainer: 背景パネル内に配置
	_bgm_container = HBoxContainer.new()
	_bgm_container.add_theme_constant_override("separation", 8)
	small_panel.add_child(_bgm_container)

	_btn_prev = Button.new()
	_btn_prev.flat = true
	_btn_prev.focus_mode = Control.FOCUS_NONE
	_btn_prev.expand_icon = true
	_btn_prev.custom_minimum_size = Vector2(36, 20)
	if _left_q_texture != null:
		_btn_prev.icon = _left_q_texture
	else:
		_btn_prev.text = "◀[Q]"
		_btn_prev.add_theme_font_size_override("font_size", _BGM_LABEL_FONT_SIZE)
		_btn_prev.add_theme_color_override("font_color", Color("#f23052"))
	_bgm_container.add_child(_btn_prev)

	_bgm_container.add_child(_mk_note_label())

	_bgm_label = Label.new()
	_bgm_label.name = "BgmNameLabel"
	_bgm_label.visible_characters = 0
	_bgm_label.add_theme_font_size_override("font_size", _BGM_LABEL_FONT_SIZE)
	_bgm_label.add_theme_color_override("font_color", Color.WHITE)
	if _font_din != null:
		_bgm_label.add_theme_font_override("font", _font_din)
	_bgm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bgm_label.hide()
	_bgm_container.add_child(_bgm_label)

	_btn_next = Button.new()
	_btn_next.flat = true
	_btn_next.focus_mode = Control.FOCUS_NONE
	_btn_next.expand_icon = true
	_btn_next.custom_minimum_size = Vector2(36, 20)
	if _right_e_texture != null:
		_btn_next.icon = _right_e_texture
	else:
		_btn_next.text = "[E]▶"
		_btn_next.add_theme_font_size_override("font_size", _BGM_LABEL_FONT_SIZE)
		_btn_next.add_theme_color_override("font_color", Color("#f23052"))
	_bgm_container.add_child(_btn_next)

	_btn_prev.pressed.connect(_on_bgm_btn_prev)
	_btn_next.pressed.connect(_on_bgm_btn_next)

	# 拡大パネル（右クリック / X ボタン保持で表示）
	var exp_anchor := Control.new()
	exp_anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	exp_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bgm_canvas.add_child(exp_anchor)

	_bgm_expanded_panel = PanelContainer.new()
	_bgm_expanded_panel.anchor_left   = 0.5
	_bgm_expanded_panel.anchor_right  = 0.5
	_bgm_expanded_panel.anchor_top    = 0.5
	_bgm_expanded_panel.anchor_bottom = 0.5
	_bgm_expanded_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bgm_expanded_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_bgm_expanded_panel.visible = false
	var exp_style := StyleBoxFlat.new()
	exp_style.bg_color = Color(0.263, 0.212, 0.278, 0.9)  # #433647 90%
	exp_style.set_corner_radius_all(10)
	exp_style.content_margin_left   = 20.0
	exp_style.content_margin_right  = 20.0
	exp_style.content_margin_top    = 12.0
	exp_style.content_margin_bottom = 12.0
	_bgm_expanded_panel.add_theme_stylebox_override("panel", exp_style)
	exp_anchor.add_child(_bgm_expanded_panel)
	_bgm_expanded_panel.resized.connect(func() -> void:
		_bgm_expanded_panel.pivot_offset = _bgm_expanded_panel.size / 2.0
	)

	var exp_hbox := HBoxContainer.new()
	exp_hbox.add_theme_constant_override("separation", 16)
	_bgm_expanded_panel.add_child(exp_hbox)

	var exp_btn_color := Color("#f23052")
	_bgm_expanded_prev_btn = Button.new()
	_bgm_expanded_prev_btn.flat = true
	_bgm_expanded_prev_btn.expand_icon = true
	_bgm_expanded_prev_btn.custom_minimum_size = Vector2(90, 50)
	if _left_q_texture != null:
		_bgm_expanded_prev_btn.icon = _left_q_texture
	else:
		_bgm_expanded_prev_btn.text = "◀[Q]"
		_bgm_expanded_prev_btn.add_theme_font_size_override("font_size", 50)
		_bgm_expanded_prev_btn.add_theme_color_override("font_color", exp_btn_color)
	exp_hbox.add_child(_bgm_expanded_prev_btn)

	_bgm_expanded_name_label = Label.new()
	_bgm_expanded_name_label.add_theme_font_size_override("font_size", 36)
	_bgm_expanded_name_label.add_theme_color_override("font_color", Color.WHITE)
	if _font_din != null:
		_bgm_expanded_name_label.add_theme_font_override("font", _font_din)
	_bgm_expanded_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exp_hbox.add_child(_bgm_expanded_name_label)

	_bgm_expanded_next_btn = Button.new()
	_bgm_expanded_next_btn.flat = true
	_bgm_expanded_next_btn.expand_icon = true
	_bgm_expanded_next_btn.custom_minimum_size = Vector2(90, 50)
	if _right_e_texture != null:
		_bgm_expanded_next_btn.icon = _right_e_texture
	else:
		_bgm_expanded_next_btn.text = "[E]▶"
		_bgm_expanded_next_btn.add_theme_font_size_override("font_size", 50)
		_bgm_expanded_next_btn.add_theme_color_override("font_color", exp_btn_color)
	exp_hbox.add_child(_bgm_expanded_next_btn)

	_bgm_expanded_prev_btn.pressed.connect(_on_bgm_btn_prev)
	_bgm_expanded_next_btn.pressed.connect(_on_bgm_btn_next)


func _start_bgm_label_anim() -> void:
	if _bgm_tween:
		_bgm_tween.kill()
		_bgm_tween = null

	var idx := BGMManager.get_ingame_track_idx()
	if idx < 0 or idx >= _BGM_TRACK_KEYS.size():
		return

	_bgm_text = tr(_BGM_TRACK_KEYS[idx])
	_bgm_label.text = _bgm_text
	_bgm_label.visible_characters = 0
	_bgm_label.show()

	_bgm_tween = create_tween()
	(_bgm_tween
		.tween_property(_bgm_label, "visible_characters", len(_bgm_text), _BGM_TYPEWRITER_SEC)
		.set_trans(Tween.TRANS_LINEAR))
	_bgm_tween.tween_interval(_BGM_HOLD_SEC)
	_bgm_tween.tween_callback(_begin_dismiss)


func _begin_dismiss() -> void:
	if _bgm_tween:
		_bgm_tween.kill()
		_bgm_tween = null

	var n := len(_bgm_text)
	if n == 0:
		_bgm_label.hide()
		return

	_bgm_tween = create_tween()
	var step := _BGM_DISMISS_SEC / float(n)
	for i in range(n):
		_bgm_tween.tween_interval(step)
		_bgm_tween.tween_callback(_dismiss_step.bind(i + 1))
	_bgm_tween.tween_callback(func() -> void:
		_bgm_label.hide()
		_bgm_text = ""
	)


func _spawn_unlock_particles(world_pos: Vector2) -> void:
	var screen_pos: Vector2 = get_canvas_transform() * world_pos
	var p := CPUParticles2D.new()
	_bgm_canvas.add_child(p)
	p.position = screen_pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.7
	p.spread = 180.0
	p.gravity = Vector2(0.0, 80.0)
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = Color(0.95, 0.19, 0.32, 1.0)
	var t1 := Timer.new()
	t1.wait_time = 1.5
	t1.one_shot = true
	p.add_child(t1)
	t1.timeout.connect(p.queue_free)
	t1.start()


func _dismiss_step(skip: int) -> void:
	var rect := _bgm_label.get_global_rect()
	_spawn_bgm_particle(Vector2(rect.position.x + 2.0, rect.get_center().y))
	_bgm_label.text = _bgm_text.substr(skip)


func _spawn_bgm_particle(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	_bgm_canvas.add_child(p)
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 6
	p.lifetime = 0.6
	p.spread = 180.0
	p.gravity = Vector2(0.0, 150.0)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 100.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.8, 0.5, 0.5, 1.0)
	var t2 := Timer.new()
	t2.wait_time = 1.2
	t2.one_shot = true
	p.add_child(t2)
	t2.timeout.connect(p.queue_free)
	t2.start()


func _on_bgm_btn_prev() -> void:
	BGMManager.select_prev_bgm()
	_start_bgm_label_anim()


func _on_bgm_btn_next() -> void:
	BGMManager.select_next_bgm()
	_start_bgm_label_anim()


# --- BGM 拡大パネル制御 ---

func _bgm_do_expand() -> void:
	if _bgm_expanded or BGMManager.get_unlocked_track_count() <= 1:
		return
	_bgm_expanded = true
	_bgm_update_expanded_label()
	_bgm_expanded_panel.visible = true
	_bgm_expanded_panel.scale = Vector2(0.25, 0.25)
	_bgm_expanded_panel.modulate.a = 0.0
	if _bgm_expand_tween:
		_bgm_expand_tween.kill()
	_bgm_expand_tween = create_tween()
	_bgm_expand_tween.tween_property(_bgm_expanded_panel, "scale", Vector2.ONE, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bgm_expand_tween.parallel().tween_property(_bgm_expanded_panel, "modulate:a", 1.0, 0.15)


func _bgm_do_collapse() -> void:
	if not _bgm_expanded:
		return
	_bgm_expanded = false
	if _bgm_expand_tween:
		_bgm_expand_tween.kill()
	_bgm_expand_tween = create_tween()
	_bgm_expand_tween.tween_property(_bgm_expanded_panel, "scale", Vector2(0.25, 0.25), 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_bgm_expand_tween.parallel().tween_property(_bgm_expanded_panel, "modulate:a", 0.0, 0.15)
	_bgm_expand_tween.tween_callback(func() -> void: _bgm_expanded_panel.visible = false)


func _bgm_update_expanded_label() -> void:
	if not _bgm_expanded_name_label:
		return
	var idx := BGMManager.get_ingame_track_idx()
	if idx >= 0 and idx < _BGM_TRACK_KEYS.size():
		_bgm_expanded_name_label.text = tr(_BGM_TRACK_KEYS[idx])
	var show_arrows: bool = BGMManager.get_unlocked_track_count() > 1
	if _bgm_expanded_prev_btn:
		_bgm_expanded_prev_btn.visible = show_arrows
	if _bgm_expanded_next_btn:
		_bgm_expanded_next_btn.visible = show_arrows


# --- 入力モード切替 ---

func _set_input_mode(mode: int) -> void:
	if _input_mode == mode:
		return
	_input_mode = mode
	_update_bgm_button_labels()
	queue_redraw()


func _update_bgm_button_labels() -> void:
	var is_kb: bool = (_input_mode == 0)
	var show_arrows: bool = BGMManager.get_unlocked_track_count() > 1
	if _btn_prev:
		if is_kb and _left_q_texture != null:
			_btn_prev.icon = _left_q_texture
			_btn_prev.text = ""
		else:
			_btn_prev.icon = null
			_btn_prev.text = "◀[L]"
			_btn_prev.add_theme_font_size_override("font_size", _BGM_LABEL_FONT_SIZE)
			_btn_prev.add_theme_color_override("font_color", Color("#f23052"))
		_btn_prev.visible = show_arrows
	if _btn_next:
		if is_kb and _right_e_texture != null:
			_btn_next.icon = _right_e_texture
			_btn_next.text = ""
		else:
			_btn_next.icon = null
			_btn_next.text = "[R]▶"
			_btn_next.add_theme_font_size_override("font_size", _BGM_LABEL_FONT_SIZE)
			_btn_next.add_theme_color_override("font_color", Color("#f23052"))
		_btn_next.visible = show_arrows
	if _bgm_expanded_prev_btn:
		if is_kb and _left_q_texture != null:
			_bgm_expanded_prev_btn.icon = _left_q_texture
			_bgm_expanded_prev_btn.text = ""
		else:
			_bgm_expanded_prev_btn.icon = null
			_bgm_expanded_prev_btn.text = "◀[L]"
			_bgm_expanded_prev_btn.add_theme_font_size_override("font_size", 50)
			_bgm_expanded_prev_btn.add_theme_color_override("font_color", Color("#f23052"))
	if _bgm_expanded_next_btn:
		if is_kb and _right_e_texture != null:
			_bgm_expanded_next_btn.icon = _right_e_texture
			_bgm_expanded_next_btn.text = ""
		else:
			_bgm_expanded_next_btn.icon = null
			_bgm_expanded_next_btn.text = "[R]▶"
			_bgm_expanded_next_btn.add_theme_font_size_override("font_size", 50)
			_bgm_expanded_next_btn.add_theme_color_override("font_color", Color("#f23052"))


# --- BGM 解禁ゾーン ---

func _start_bgm_unlock_sequence() -> void:
	_bgm_unlock_directing = true
	_bgm_unlock_phase = 1
	_bgm_unlock_elapsed = 0.0
	_bgm_unlock_skip_count = 0
	_bgm_unlock_cam_start = _camera.position
	_bgm_unlock_visual_zi = -1


func _bgm_advance_from_phase2() -> void:
	var _zi: int = _get_zone_idx_for_bgm(_bgm_unlock_bgm_id)
	if _zi >= 0:
		_bgm_line_retract_progress[_zi] = 1.0
	if _bgm_unlock_visual_zi < 0 and _zi >= 0:
		_bgm_unlock_visual_zi = _zi
		_bgm_update_expanded_label()
		_update_bgm_button_labels()
	_bgm_unlock_phase = 3
	_bgm_unlock_elapsed = 0.0
	queue_redraw()


func _bgm_unlock_skip() -> void:
	_bgm_unlock_directing = false
	_bgm_unlock_phase = 0
	_camera.position = _bgm_unlock_zone_center
	_char_pos = _camera.position
	_char_target = _camera.position
	if not _bgm_unlock_is_preview:
		BGMManager.unlock_bgm(_bgm_unlock_bgm_id)
	_bgm_unlock_is_preview = false
	_bgm_unlock_visual_zi = -1
	var _skip_zi: int = _get_zone_idx_for_bgm(_bgm_unlock_bgm_id)
	if _skip_zi >= 0:
		_bgm_line_retract_progress[_skip_zi] = 1.0
	_bgm_update_expanded_label()
	_update_bgm_button_labels()
	if _bgm_expanded:
		if _bgm_expand_tween:
			_bgm_expand_tween.kill()
		_bgm_expanded = false
		_bgm_expanded_panel.visible = false


func _dbg_trigger_bgm_preview() -> void:
	if _bgm_unlock_directing or _is_focusing:
		return
	var zones: Array = StageSelectManager._bgm_zones
	if zones.is_empty():
		return
	var centers: Array[Vector2] = StageSelectManager.get_bgm_zone_centers()
	if centers.size() != zones.size():
		return
	var zi: int = _dbg_bgm_preview_zi % zones.size()
	_dbg_bgm_preview_zi = (zi + 1) % zones.size()
	_bgm_unlock_bgm_id = str(zones[zi].get("unlocks_bgm", ""))
	_bgm_unlock_zone_center = centers[zi]
	_bgm_line_retract_progress[zi] = 0.0  # ラインを一時的に復元
	_bgm_unlock_is_preview = true
	_start_bgm_unlock_sequence()


func _get_zone_idx_for_bgm(bgm_id: String) -> int:
	var zones: Array = StageSelectManager._bgm_zones
	for i in range(zones.size()):
		if str(zones[i].get("unlocks_bgm", "")) == bgm_id:
			return i
	return -1


func _spawn_bgm_unlock_particles(world_pos: Vector2) -> void:
	var screen_pos: Vector2 = get_canvas_transform() * world_pos
	var p := CPUParticles2D.new()
	_bgm_canvas.add_child(p)
	p.position = screen_pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 180
	p.lifetime = 1.2
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0.0, 200.0)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = _BGM_ZONE_COLOR
	var t := Timer.new()
	t.wait_time = 2.0
	t.one_shot = true
	p.add_child(t)
	t.timeout.connect(p.queue_free)
	t.start()
