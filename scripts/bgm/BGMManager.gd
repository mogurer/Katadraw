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

# ---------- Public state ----------

## Current match accuracy, 0.0–1.0. Update via set_match_rate().
var match_rate: float = 0.0

# ---------- Private state ----------

var _demo_reached: bool = false
var _all_cleared: bool = false   # BGMSequencer 再実装
var _no_input_time: float = 0.0  # BGMSequencer 再実装

var _ingame_active: bool = false

var _sequencer: BGMSequencer
var _players: Array[AudioStreamPlayer] = []
var _active_player: int = 0         # index of the currently playing player (0 or 1)
var _streams: Dictionary = {}       # path → AudioStream, preloaded at startup

var _muted: bool = false
var _volume_offset_db: float = 0.0
const _BASE_VOLUME_DB: float = -8.5

# --- Ingame progress BGM ---

const _INGAME_PATHS: Array[String] = [
	"res://assets/sounds/0105/01-05_00.ogg",
	"res://assets/sounds/0105/01-05_10.ogg",
	"res://assets/sounds/0105/01-05_20.ogg",
	"res://assets/sounds/0105/01-05_30.ogg",
	"res://assets/sounds/0105/01-05_40.ogg",
	"res://assets/sounds/0105/01-05_50.ogg",
	"res://assets/sounds/0105/01-05_60.ogg",
	"res://assets/sounds/0105/01-05_70.ogg",
	"res://assets/sounds/0105/01-05_80.ogg",
	"res://assets/sounds/0105/01-05_Clear.ogg",
]

var _current_progress: float = 0.0   # last received progress value (0.0–100.0)
var _current_ingame_path: String = "" # currently playing progress track path

const _FADE_DURATION: float = 1.0
var _fading: bool = false
var _fade_elapsed: float = 0.0
var _fade_in_idx: int = 0
var _fade_out_idx: int = 1


func _ready() -> void:
	_sequencer = BGMSequencer.new()
	# BGMSequencer 再実装: PHASE_JOIN 遷移時に _ingame_active を true にする
	_sequencer.join_started.connect(func(): _ingame_active = true)

	# Preload all title segment streams so _on_finished → play is essentially hitless.
	for path: String in BGMSequencer.PATHS.values():
		_streams[path] = load(path)

	# Preload ingame progress tracks with loop=true so they play indefinitely.
	for path: String in _INGAME_PATHS:
		var stream := load(path) as AudioStreamOggVorbis
		if stream != null:
			stream.loop = true
		_streams[path] = stream

	# Two AudioStreamPlayers used alternately for seamless segment chaining
	# and crossfade-based ingame progress BGM.
	for i: int in 2:
		var p := AudioStreamPlayer.new()
		add_child(p)
		p.finished.connect(_on_player_finished.bind(i))
		_players.append(p)


func _process(delta: float) -> void:
	# BGMSequencer 再実装: タイトル中（_ingame_active == false）のみ no_input_time を加算
	if not _ingame_active:
		_no_input_time += delta

	if not _fading:
		return

	_fade_elapsed += delta
	var t := minf(_fade_elapsed / _FADE_DURATION, 1.0)
	if _muted:
		_players[_fade_in_idx].volume_db = -80.0
		_players[_fade_out_idx].volume_db = -80.0
	else:
		var base_db := _BASE_VOLUME_DB + _volume_offset_db
		var amp_in  := sin(t * PI / 2.0)
		var amp_out := cos(t * PI / 2.0)
		_players[_fade_in_idx].volume_db  = base_db + linear_to_db(amp_in)
		_players[_fade_out_idx].volume_db = base_db + linear_to_db(amp_out)
	if t >= 1.0:
		_players[_fade_out_idx].stop()
		_fading = false


# ---------- Public API ----------

## Update match accuracy. Clamped to [0.0, 1.0].
func set_match_rate(v: float) -> void:
	match_rate = clampf(v, 0.0, 1.0)


## Drive ingame progress BGM. progress is 0.0–100.0 (same scale as current_circularity).
## No-op when _ingame_active is false. Crossfades over 1 s when the track zone changes.
func update_ingame_progress(progress: float) -> void:
	if not _ingame_active:
		return
	_current_progress = progress
	var path := _progress_to_ingame_path(progress)
	if path == _current_ingame_path:
		return
	_crossfade_to(path)


## Notify whether the demo screen has been reached.
## Affects transitions out of PHASE_00 and PHASE_JOIN_LONG.
func set_demo_reached(value: bool = true) -> void:
	_demo_reached = value


## Notify that all stages have been cleared.  # BGMSequencer 再実装
func set_all_cleared(value: bool = true) -> void:
	_all_cleared = value


## Notify of user input on the title screen; resets the no_input_time counter.
## BGMSequencer 再実装
func notify_input() -> void:
	_no_input_time = 0.0


## Start playback from the very beginning of the title flow (KATADRAW_00).
func play_title() -> void:
	_stop_all()
	_ingame_active = false
	_active_player = 0
	_play_on_active(_sequencer.start_title())


## Start ingame BGM immediately on the track matching the current progress.
## Skips KATADRAW_Join — 01-05 tracks begin at once.
## No-op when ingame is already active — prevents interrupting ongoing BGM.
func play_ingame() -> void:
	if _ingame_active:
		return  # インゲーム進行中は割り込み禁止
	_stop_all()
	_active_player = 0
	_ingame_active = true
	var path := _progress_to_ingame_path(_current_progress)
	_current_ingame_path = path
	_play_on_active(path)


## Stop all playback immediately and reset ingame state.
func stop() -> void:
	_stop_all()
	_ingame_active = false
	_current_ingame_path = ""
	_current_progress = 0.0


## Mute or unmute BGM (mirrors BGM_TEMPORARILY_SILENT in game.gd).
func set_mute(muted: bool) -> void:
	_muted = muted
	_sync_volume()


## Set volume offset in dB (derived from bgm_volume level in game.gd).
func set_volume_db(offset_db: float) -> void:
	_volume_offset_db = offset_db
	_sync_volume()


# ---------- Private helpers ----------

func _on_player_finished(player_index: int) -> void:
	# Ignore stale callbacks from the idle player.
	if player_index != _active_player:
		return

	if _ingame_active:
		# Progress tracks have loop=true and should not emit finished.
		# Edge-case fallback: restart the current track to avoid silence.
		if not _current_ingame_path.is_empty():
			_play_on_active(_current_ingame_path)
		return

	# BGMSequencer 再実装: 新しい引数セットで advance を呼ぶ
	var next: String = _sequencer.advance(
			match_rate,
			_demo_reached,
			_all_cleared,
			_no_input_time)
	if next.is_empty():
		return

	# Switch to the other player and start the next segment.
	_active_player = 1 - _active_player
	_play_on_active(next)


func _progress_to_ingame_path(progress: float) -> String:
	if progress >= 100.0: return "res://assets/sounds/0105/01-05_Clear.ogg"
	if progress < 10.0:   return "res://assets/sounds/0105/01-05_00.ogg"
	if progress < 30.0:   return "res://assets/sounds/0105/01-05_10.ogg"
	if progress < 40.0:   return "res://assets/sounds/0105/01-05_20.ogg"
	if progress < 50.0:   return "res://assets/sounds/0105/01-05_30.ogg"
	if progress < 60.0:   return "res://assets/sounds/0105/01-05_40.ogg"
	if progress < 70.0:   return "res://assets/sounds/0105/01-05_50.ogg"
	if progress < 80.0:   return "res://assets/sounds/0105/01-05_60.ogg"
	if progress < 90.0:   return "res://assets/sounds/0105/01-05_70.ogg"
	return "res://assets/sounds/0105/01-05_80.ogg"


func _crossfade_to(new_path: String) -> void:
	# Resolve any in-progress fade before starting a new one.
	if _fading:
		var cur_t := minf(_fade_elapsed / _FADE_DURATION, 1.0)
		if _muted:
			_players[_fade_in_idx].volume_db = -80.0
		else:
			var base := _BASE_VOLUME_DB + _volume_offset_db
			_players[_fade_in_idx].volume_db = base + linear_to_db(sin(cur_t * PI / 2.0))
		_players[_fade_out_idx].stop()
		_active_player = _fade_in_idx
		_fading = false

	var new_idx := 1 - _active_player
	var stream: AudioStream = _streams.get(new_path)
	if stream == null:
		push_error("BGMManager: ingame stream not found: %s" % new_path)
		return

	_players[new_idx].stream = stream
	_players[new_idx].volume_db = -80.0
	_fade_out_idx = _active_player
	var sync_pos := _players[_fade_out_idx].get_playback_position()
	_players[new_idx].play(sync_pos)

	_current_ingame_path = new_path
	_fading = true
	_fade_elapsed = 0.0
	_fade_in_idx = new_idx
	_active_player = new_idx


func _play_on_active(path: String) -> void:
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		push_error("BGMManager: stream not found for path '%s'" % path)
		return
	var p := _players[_active_player]
	p.stream = stream
	p.volume_db = -80.0 if _muted else _BASE_VOLUME_DB + _volume_offset_db
	p.play()


func _stop_all() -> void:
	_fading = false
	for p: AudioStreamPlayer in _players:
		p.stop()


func _sync_volume() -> void:
	if _fading:
		return  # _process applies correct per-player volumes each frame
	var db: float = -80.0 if _muted else _BASE_VOLUME_DB + _volume_offset_db
	for p: AudioStreamPlayer in _players:
		if p.playing:
			p.volume_db = db
