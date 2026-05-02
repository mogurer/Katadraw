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
	{  # 0: ingame
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
	{  # 1: title
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

# ---------- Constants ----------

const _BASE_VOLUME_DB: float = -8.5
const _FADE_DURATION: float = 1.0
const _CLEAR_VOLUME_BOOST_DB: float = 3.0  # クリア時の音量上乗せ量（dB）

# ---------- State ----------

var _track_idx: int = 0
var _motif_idx: int = 0
var _in_intro: bool = false
var _virtual_pos: float = 0.0
var _virtual_elapsed: float = 0.0

# true = begin_countdown() 後、resume_ingame() 前（イントロが途中終了したら再スタート）
var _waiting_for_resume: bool = false

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
		var base_db: float = _BASE_VOLUME_DB + _volume_offset_db
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
	_track_idx = 1
	_motif_idx = 0
	_in_intro = true
	_waiting_for_resume = false
	_clear_boost_active = false
	_virtual_pos = 0.0
	_virtual_elapsed = 0.0
	_play_on_active(TRACKS[_track_idx]["intro"])


## インゲームBGM開始（イントロ先頭から）。
func play_ingame() -> void:
	_stop_all()
	_active_player = 0
	_track_idx = 0
	_motif_idx = 0
	_in_intro = true
	_waiting_for_resume = false
	_clear_boost_active = false
	_virtual_pos = 0.0
	_virtual_elapsed = 0.0
	_play_on_active(TRACKS[_track_idx]["intro"])


## ⑤-2: カウントダウン終了 → モチーフへ復帰。
## _motif_idx == 0 のときはクロスフェードせずイントロを自然終了させる（仕様②）。
## _in_intro が false のときは何もしない。
func resume_ingame() -> void:
	_waiting_for_resume = false
	if not _in_intro:
		return
	if _motif_idx == 0:
		# 仕様②: 0000 → 0010 へ自然遷移。_on_player_finished に任せる。
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


## ⑤-0: 次ステージ準備（ガイド表示前）。
## モチーフ→イントロへクロスフェード + 音量を戻す。
## _in_intro が true のとき（初回ステージ等）はクロスフェードをスキップする。
func begin_countdown() -> void:
	_clear_boost_active = false
	if _in_intro:
		_sync_volume()
		return
	var motif_pos: float = _players[_active_player].get_playback_position()
	_crossfade_to(TRACKS[_track_idx]["intro"], motif_pos)
	_in_intro = true
	_waiting_for_resume = true
	_virtual_pos = motif_pos
	_virtual_elapsed = 0.0


## 全停止・状態リセット。
func stop() -> void:
	_stop_all()
	_in_intro = false
	_waiting_for_resume = false
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
			# resume_ingame() 後（または初回）のイントロ自然終了 → モチーフ01へ
			_motif_idx = 0
			_in_intro = false
			_play_on_active(_current_motif_path())
	else:
		_motif_idx = (_motif_idx + 1) % _motifs().size()
		_play_on_active(_current_motif_path())


func _motifs() -> Array:
	return TRACKS[_track_idx]["motifs"]


func _current_motif_path() -> String:
	return _motifs()[_motif_idx]


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
	return _BASE_VOLUME_DB + _volume_offset_db + boost
