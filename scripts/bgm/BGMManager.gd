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
const _BASE_VOLUME_DB: float = -16.5


func _ready() -> void:
	_sequencer = BGMSequencer.new()
	# BGMSequencer 再実装: PHASE_JOIN 遷移時に _ingame_active を true にする
	_sequencer.join_started.connect(func(): _ingame_active = true)

	# Preload all segment streams so _on_finished → play is essentially hitless.
	for path: String in BGMSequencer.PATHS.values():
		_streams[path] = load(path)

	# Two AudioStreamPlayers used alternately for seamless segment chaining.
	for i: int in 2:
		var p := AudioStreamPlayer.new()
		add_child(p)
		p.finished.connect(_on_player_finished.bind(i))
		_players.append(p)


func _process(delta: float) -> void:
	# BGMSequencer 再実装: タイトル中（_ingame_active == false）のみ no_input_time を加算
	if not _ingame_active:
		_no_input_time += delta


# ---------- Public API ----------

## Update match accuracy. Clamped to [0.0, 1.0].
func set_match_rate(v: float) -> void:
	match_rate = clampf(v, 0.0, 1.0)


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


## Start the ingame flow (plays KATADRAW_Join).
## No-op when ingame is already active — prevents interrupting ongoing BGM.
func play_ingame() -> void:
	if _ingame_active:
		return  # インゲーム進行中は割り込み禁止
	_stop_all()
	_active_player = 0
	# start_ingame() emits join_started → lambda sets _ingame_active = true.
	_play_on_active(_sequencer.start_ingame())


## Stop all playback immediately.
func stop() -> void:
	_stop_all()
	_ingame_active = false


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
	for p: AudioStreamPlayer in _players:
		p.stop()


func _sync_volume() -> void:
	var db: float = -80.0 if _muted else _BASE_VOLUME_DB + _volume_offset_db
	for p: AudioStreamPlayer in _players:
		p.volume_db = db
