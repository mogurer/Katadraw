# BGMManager — AutoLoad singleton for BGM playback control.
#
# --- AutoLoad 登録手順 ---
# 1. Godot エディタのメニューから Project > Project Settings を開く
# 2. 「AutoLoad」タブを選択
# 3. Path 欄に res://scripts/bgm/BGMManager.gd を入力
# 4. Node Name 欄を「BGMManager」に設定
# 5. 「Add」ボタンをクリック
# 以後、どのシーン/スクリプトからも BGMManager.xxx() で呼び出せる。
# -------------------------

extends Node

# ---------- Track data ----------

const TRACKS: Array[Dictionary] = [
	{  # 0: ingame – 01-05
		"intro": "res://assets/sounds/01-05/01-05_0000.ogg",
		"motifs": [
			"res://assets/sounds/01-05/01-05_0010.ogg",
			"res://assets/sounds/01-05/01-05_0020.ogg",
			"res://assets/sounds/01-05/01-05_0030.ogg",
			"res://assets/sounds/01-05/01-05_0040.ogg",
			"res://assets/sounds/01-05/01-05_0050.ogg",
			"res://assets/sounds/01-05/01-05_0060.ogg",
			"res://assets/sounds/01-05/01-05_0070.ogg",
			"res://assets/sounds/01-05/01-05_0080.ogg",
			"res://assets/sounds/01-05/01-05_0090.ogg",
			"res://assets/sounds/01-05/01-05_0100.ogg",
			"res://assets/sounds/01-05/01-05_0110.ogg",
			"res://assets/sounds/01-05/01-05_0120.ogg",
			"res://assets/sounds/01-05/01-05_0130.ogg",
			"res://assets/sounds/01-05/01-05_0140.ogg",
			"res://assets/sounds/01-05/01-05_0150.ogg",
		]
	},
	{  # 1: ingame – 01-06
		"intro": "res://assets/sounds/01-06/01-06_0000.ogg",
		"motifs": [
			"res://assets/sounds/01-06/01-06_0009.ogg",
			"res://assets/sounds/01-06/01-06_0017.ogg",
			"res://assets/sounds/01-06/01-06_0025.ogg",
			"res://assets/sounds/01-06/01-06_0033.ogg",
			"res://assets/sounds/01-06/01-06_0041.ogg",
			"res://assets/sounds/01-06/01-06_0049.ogg",
			"res://assets/sounds/01-06/01-06_0057.ogg",
			"res://assets/sounds/01-06/01-06_0065.ogg",
			"res://assets/sounds/01-06/01-06_0073.ogg",
			"res://assets/sounds/01-06/01-06_0081.ogg",
			"res://assets/sounds/01-06/01-06_0089.ogg",
			"res://assets/sounds/01-06/01-06_0097.ogg",
			"res://assets/sounds/01-06/01-06_0105.ogg",
			"res://assets/sounds/01-06/01-06_0113.ogg",
		]
	},
	{  # 2: ingame – 01-08
		"intro": "res://assets/sounds/01-08/01-08_0000.ogg",
		"motifs": [
			"res://assets/sounds/01-08/01-08_0009.ogg",
			"res://assets/sounds/01-08/01-08_0017.ogg",
			"res://assets/sounds/01-08/01-08_0025.ogg",
			"res://assets/sounds/01-08/01-08_0033.ogg",
			"res://assets/sounds/01-08/01-08_0041.ogg",
			"res://assets/sounds/01-08/01-08_0049.ogg",
			"res://assets/sounds/01-08/01-08_0057.ogg",
			"res://assets/sounds/01-08/01-08_0065.ogg",
			"res://assets/sounds/01-08/01-08_0073.ogg",
			"res://assets/sounds/01-08/01-08_0081.ogg",
			"res://assets/sounds/01-08/01-08_0089.ogg",
			"res://assets/sounds/01-08/01-08_0097.ogg",
			"res://assets/sounds/01-08/01-08_0105.ogg",
			"res://assets/sounds/01-08/01-08_0113.ogg",
			"res://assets/sounds/01-08/01-08_0121.ogg",
		]
	},
	{  # 3: ingame – 02-03
		"intro": "res://assets/sounds/02-03/02-03_0000.ogg",
		"motifs": [
			"res://assets/sounds/02-03/02-03_0010.ogg",
			"res://assets/sounds/02-03/02-03_0020.ogg",
			"res://assets/sounds/02-03/02-03_0030.ogg",
			"res://assets/sounds/02-03/02-03_0040.ogg",
			"res://assets/sounds/02-03/02-03_0050.ogg",
			"res://assets/sounds/02-03/02-03_0060.ogg",
			"res://assets/sounds/02-03/02-03_0070.ogg",
			"res://assets/sounds/02-03/02-03_0080.ogg",
			"res://assets/sounds/02-03/02-03_0085.ogg",
			"res://assets/sounds/02-03/02-03_0095.ogg",
			"res://assets/sounds/02-03/02-03_0105.ogg",
			"res://assets/sounds/02-03/02-03_0115.ogg",
		]
	},
	{  # 4: ingame – 02-09
		"intro": "res://assets/sounds/02-09/02-09_0000.ogg",
		"motifs": [
			"res://assets/sounds/02-09/02-09_0010.ogg",
			"res://assets/sounds/02-09/02-09_0020.ogg",
			"res://assets/sounds/02-09/02-09_0030.ogg",
			"res://assets/sounds/02-09/02-09_0040.ogg",
		]
	},
	{  # 5: title
		"intro": "res://assets/sounds/Title/KATADRAW_Title_0000.ogg",
		"motifs": [
			"res://assets/sounds/Title/KATADRAW_Title_0010.ogg",
			"res://assets/sounds/Title/KATADRAW_Title_0020.ogg",
			"res://assets/sounds/Title/KATADRAW_Title_0030.ogg",
			"res://assets/sounds/Title/KATADRAW_Title_0040.ogg",
			"res://assets/sounds/Title/KATADRAW_Title_0050.ogg",
		]
	},
]

const _INGAME_TRACK_COUNT: int = 5

# ---------- Constants ----------

const _BASE_VOLUME_DB: float = -8.5
const _FADE_DURATION: float = 1.0
const _CLEAR_VOLUME_BOOST_DB: float = 3.0
const _COUNTDOWN_VOLUME_REDUCE_DB: float = -3.0  # カウントダウン中の音量低下量（dB）

# ---------- State ----------

var _ingame_track_idx: int = 0  # 現在選択中のインゲームBGM（0〜_INGAME_TRACK_COUNT-1）
var _track_idx: int = 0
var _motif_idx: int = 0
var _in_intro: bool = false
var _virtual_pos: float = 0.0
var _virtual_elapsed: float = 0.0

# resume_ingame() 前にイントロが終了したら先頭から再スタートする
var _waiting_for_resume: bool = false

# ☆: クリア後「次へ」直後 〜 カウントダウン開始前のプリカウントダウン状態
var _in_pre_countdown: bool = false
var _pre_countdown_motif_idx: int = 0

# ★: カウントダウン中（guide_countdown 開始〜ゲーム開始1秒後）の音量低下フラグ
var _countdown_active: bool = false

# ①: デモ→ステージ1 無音待機。resume_ingame() から1秒後に play_ingame() を起動する。
var _first_stage_pending: bool = false
var _first_stage_bgm_pending: bool = false  # タイマーが有効かどうか

var _players: Array[AudioStreamPlayer] = []
var _active_player: int = 0
var _streams: Dictionary = {}

var _muted: bool = false
var _volume_offset_db: float = 0.0
var _clear_boost_active: bool = false

var _fading: bool = false
var _fade_elapsed: float = 0.0
var _fade_in_idx: int = 1
var _fade_out_idx: int = 0


func _ready() -> void:
	for track: Dictionary in TRACKS:
		var stream := load(track["intro"]) as AudioStreamOggVorbis
		if stream != null:
			stream.loop = false
		_streams[track["intro"]] = stream
		for path: String in track["motifs"]:
			stream = load(path) as AudioStreamOggVorbis
			if stream != null:
				stream.loop = false
			_streams[path] = stream

	for i: int in 2:
		var p := AudioStreamPlayer.new()
		add_child(p)
		p.finished.connect(_on_player_finished.bind(i))
		_players.append(p)


func _process(delta: float) -> void:
	if _in_intro:
		_virtual_elapsed += delta
		_virtual_pos += delta
		var motif_stream: AudioStream = _streams.get(_current_motif_path())
		if motif_stream != null:
			var motif_len: float = motif_stream.get_length()
			if motif_len > 0.0 and _virtual_pos >= motif_len:
				_virtual_pos = 0.0

	if not _fading:
		return

	_fade_elapsed += delta
	var t: float = minf(_fade_elapsed / _FADE_DURATION, 1.0)
	if _muted:
		_players[_fade_in_idx].volume_db  = -80.0
		_players[_fade_out_idx].volume_db = -80.0
	else:
		var base_db: float = _base_db()
		_players[_fade_in_idx].volume_db  = base_db + linear_to_db(sin(t * PI / 2.0))
		_players[_fade_out_idx].volume_db = base_db + linear_to_db(cos(t * PI / 2.0))
	if t >= 1.0:
		_players[_fade_out_idx].stop()
		_fading = false


# ---------- Public API ----------

## タイトルBGM開始（イントロ先頭から）。
func play_title() -> void:
	_stop_all()
	_active_player = 0
	_track_idx = _INGAME_TRACK_COUNT  # title は末尾インデックス
	_motif_idx = 0
	_in_intro = true
	_in_pre_countdown = false
	_waiting_for_resume = false
	_countdown_active = false
	_first_stage_pending = false
	_first_stage_bgm_pending = false
	_clear_boost_active = false
	_virtual_pos = 0.0
	_virtual_elapsed = 0.0
	_play_on_active(TRACKS[_track_idx]["intro"])


## インゲームBGM開始（イントロ先頭から）。選択中の _ingame_track_idx を使用。
func play_ingame() -> void:
	_stop_all()
	_active_player = 0
	_track_idx = _ingame_track_idx
	_motif_idx = 0
	_in_intro = true
	_in_pre_countdown = false
	_waiting_for_resume = false
	_countdown_active = false
	_first_stage_pending = false
	_first_stage_bgm_pending = false
	_clear_boost_active = false
	_virtual_pos = 0.0
	_virtual_elapsed = 0.0
	_play_on_active(TRACKS[_track_idx]["intro"])


## ①: デモ画面からステージ1へ。BGMを停止し、無音でカウントダウン待機状態に入る。
## resume_ingame() から1秒後に play_ingame() が呼ばれてイントロ再生が始まる。
func start_first_stage() -> void:
	_stop_all()
	_track_idx = _ingame_track_idx
	_motif_idx = 0
	_in_intro = false
	_in_pre_countdown = false
	_waiting_for_resume = false
	_countdown_active = false
	_first_stage_pending = true
	_first_stage_bgm_pending = false
	_clear_boost_active = false
	_virtual_pos = 0.0
	_virtual_elapsed = 0.0


## ☆: クリア後「次へ」直後（ガイド表示前）。プリカウントダウン状態へ移行。
## モチーフ残り1秒未満なら _0000 へクロスフェード。それ以外は継続再生。
## モチーフが自然終了したときは _on_player_finished が _0000 へリダイレクトする。
func begin_pre_countdown() -> void:
	_clear_boost_active = false
	if _first_stage_pending:
		return  # ①: 無音のまま待機
	if _in_intro:
		# 既に _0000 再生中（直前のステージでクロスフェード済み等）
		_waiting_for_resume = true
		return
	_in_pre_countdown = true
	_pre_countdown_motif_idx = _motif_idx
	if _motif_remaining() < 1.0:
		# ループ末尾1秒未満: 直ちに _0000 へクロスフェード
		_crossfade_to(TRACKS[_track_idx]["intro"], _players[_active_player].get_playback_position())
		_in_intro = true
		_waiting_for_resume = true


## ★: カウントダウン開始（guide_info → guide_countdown 遷移時）。
## プリカウントダウン中でまだモチーフ再生中なら残り時間を再チェックしてクロスフェード判断。
## BGM音量を -3dB 低下させる。
func begin_countdown() -> void:
	if _first_stage_pending:
		return  # ①: 無音のまま
	if _in_pre_countdown and not _in_intro:
		# カウントダウン開始時点で再チェック
		if _motif_remaining() < 1.0:
			_crossfade_to(TRACKS[_track_idx]["intro"], _players[_active_player].get_playback_position())
			_in_intro = true
			_waiting_for_resume = true
	_countdown_active = true
	_sync_volume()


## カウントダウン終了 → モチーフへ復帰。音量は1秒後に元に戻す。
func resume_ingame() -> void:
	_waiting_for_resume = false
	_countdown_active = false

	if _first_stage_pending:
		# ①: 1秒後に _0000 から再生開始
		_first_stage_pending = false
		_first_stage_bgm_pending = true
		get_tree().create_timer(1.0).timeout.connect(func():
			if _first_stage_bgm_pending:
				_first_stage_bgm_pending = false
				play_ingame()
		)
		return

	# 1秒後に音量を戻す
	get_tree().create_timer(1.0).timeout.connect(func(): _sync_volume())

	if _in_pre_countdown:
		_in_pre_countdown = false
		if _in_intro:
			# _0000 → 保存モチーフN へクロスフェード（先頭から）
			_motif_idx = _pre_countdown_motif_idx
			_in_intro = false
			_crossfade_to(_current_motif_path(), 0.0)
		# else: モチーフN 再生継続 → 自然終了後 N+1 へ（B案）
		return

	# 初回ステージの _0000 自然終了ルート
	if not _in_intro:
		return
	if _motif_idx == 0:
		# _0000 → _0010 へ自然遷移。_on_player_finished に任せる。
		return
	var sync_pos: float = _players[_active_player].get_playback_position()
	_crossfade_to(_current_motif_path(), sync_pos)
	_in_intro = false


## ④: クリア演出（モチーフ再生継続 + 音量を上げる）。
## _in_intro が true のときは何もしない。
func play_clear() -> void:
	if _in_intro:
		return
	_clear_boost_active = true
	_sync_volume()


## ステージクリア後ステージセレクトへ戻る際の状態リセット。BGM再生は継続する。
func resume_stage_select() -> void:
	_clear_boost_active = false
	_in_pre_countdown = false
	_countdown_active = false
	_sync_volume()


## ステージセレクト: 次のインゲームBGMへ切り替え（先頭から再生）。
func select_next_bgm() -> void:
	_ingame_track_idx = (_ingame_track_idx + 1) % _INGAME_TRACK_COUNT
	play_ingame()


## ステージセレクト: 前のインゲームBGMへ切り替え（先頭から再生）。
func select_prev_bgm() -> void:
	_ingame_track_idx = (_ingame_track_idx - 1 + _INGAME_TRACK_COUNT) % _INGAME_TRACK_COUNT
	play_ingame()


## 全停止・状態リセット。
func stop() -> void:
	_stop_all()
	_in_intro = false
	_in_pre_countdown = false
	_waiting_for_resume = false
	_countdown_active = false
	_first_stage_pending = false
	_first_stage_bgm_pending = false
	_clear_boost_active = false
	_track_idx = 0
	_motif_idx = 0
	_virtual_pos = 0.0
	_virtual_elapsed = 0.0


## ミュート切り替え。
func set_mute(muted: bool) -> void:
	_muted = muted
	_sync_volume()


## 音量オフセット設定（dB）。
func set_volume_db(offset_db: float) -> void:
	_volume_offset_db = offset_db
	_sync_volume()


# ---------- Private helpers ----------

func _on_player_finished(player_index: int) -> void:
	if player_index != _active_player:
		return

	# フェードイン中のプレイヤーがイントロ終端に到達した場合、クロスフェードを中断する。
	# このままにするとフェードアウト側が誤って次の音源を停止してしまう。
	if _fading and player_index == _fade_in_idx:
		_players[_fade_out_idx].stop()
		_fading = false

	_active_player = 1 - _active_player

	if _in_intro:
		if _waiting_for_resume:
			# resume_ingame() 前にイントロが終了 → 先頭から再スタートして待機継続
			_play_on_active(TRACKS[_track_idx]["intro"])
		else:
			# イントロ自然終了 → モチーフ01（_0010）へ
			_motif_idx = 0
			_in_intro = false
			_play_on_active(_current_motif_path())
	else:
		if _in_pre_countdown:
			# プリカウントダウン中にモチーフN が自然終了 → N+1 をスキップして _0000 へ
			_in_intro = true
			_waiting_for_resume = true
			_play_on_active(TRACKS[_track_idx]["intro"])
		else:
			_motif_idx = (_motif_idx + 1) % _motifs().size()
			_play_on_active(_current_motif_path())


func _motifs() -> Array:
	return TRACKS[_track_idx]["motifs"]


func _current_motif_path() -> String:
	return _motifs()[_motif_idx]


## 現在再生中のモチーフの残り時間（秒）を返す。再生中でなければ大きい値を返す。
func _motif_remaining() -> float:
	var mstream: AudioStream = _streams.get(_current_motif_path())
	if mstream == null:
		return 9999.0
	var mlen: float = mstream.get_length()
	if mlen <= 0.0:
		return 9999.0
	return maxf(mlen - _players[_active_player].get_playback_position(), 0.0)


func _crossfade_to(path: String, sync_pos: float) -> void:
	if _fading:
		_players[_fade_in_idx].volume_db = _base_db()
		_players[_fade_out_idx].stop()
		_active_player = _fade_in_idx
		_fading = false

	var new_idx: int = 1 - _active_player
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		push_error("BGMManager: stream not found: %s" % path)
		return

	_players[new_idx].stream = stream
	_players[new_idx].volume_db = -80.0
	_players[new_idx].play(sync_pos)

	_fade_out_idx = _active_player
	_fade_in_idx = new_idx
	_active_player = new_idx
	_fading = true
	_fade_elapsed = 0.0


func _play_on_active(path: String) -> void:
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		push_error("BGMManager: stream not found: %s" % path)
		return
	var p: AudioStreamPlayer = _players[_active_player]
	p.stream = stream
	p.volume_db = _base_db()
	p.play()


func _stop_all() -> void:
	_fading = false
	for p: AudioStreamPlayer in _players:
		p.stop()


func _sync_volume() -> void:
	if _fading:
		return  # _process が毎フレーム各プレイヤーの音量を適用する
	var db: float = _base_db()
	for p: AudioStreamPlayer in _players:
		if p.playing:
			p.volume_db = db


func _base_db() -> float:
	if _muted:
		return -80.0
	var boost: float = _CLEAR_VOLUME_BOOST_DB if _clear_boost_active else 0.0
	var countdown_red: float = _COUNTDOWN_VOLUME_REDUCE_DB if _countdown_active else 0.0
	return _BASE_VOLUME_DB + _volume_offset_db + boost + countdown_red
