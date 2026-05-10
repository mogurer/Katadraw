# StageSelectManager — AutoLoad singleton for stage select state.
# Tracks LOCKED / UNLOCKED / CLEARED per stage, persists to user://stage_select_state.json.
# Provides grid positions (placeholder 10×5) for the stage select screen.

extends Node

enum StageState { LOCKED, UNLOCKED, CLEARED }

const STAGE_COUNT := 50
const COLS := 10
const ROWS := 5

const _SAVE_PATH := "user://stage_select_state.json"

# Placeholder grid positions: 10 columns × 5 rows across 1920×1080.
# X: 200–1720 (step ≈169), Y: 250–830 (step = 145).
# Replace with exact coordinates once the layout is decided.
const STAGE_POSITIONS: Array[Vector2] = [
	# Row 0
	Vector2(200, 250), Vector2(369, 250), Vector2(538, 250), Vector2(707, 250), Vector2(876, 250),
	Vector2(1045, 250), Vector2(1214, 250), Vector2(1383, 250), Vector2(1552, 250), Vector2(1720, 250),
	# Row 1
	Vector2(200, 395), Vector2(369, 395), Vector2(538, 395), Vector2(707, 395), Vector2(876, 395),
	Vector2(1045, 395), Vector2(1214, 395), Vector2(1383, 395), Vector2(1552, 395), Vector2(1720, 395),
	# Row 2
	Vector2(200, 540), Vector2(369, 540), Vector2(538, 540), Vector2(707, 540), Vector2(876, 540),
	Vector2(1045, 540), Vector2(1214, 540), Vector2(1383, 540), Vector2(1552, 540), Vector2(1720, 540),
	# Row 3
	Vector2(200, 685), Vector2(369, 685), Vector2(538, 685), Vector2(707, 685), Vector2(876, 685),
	Vector2(1045, 685), Vector2(1214, 685), Vector2(1383, 685), Vector2(1552, 685), Vector2(1720, 685),
	# Row 4
	Vector2(200, 830), Vector2(369, 830), Vector2(538, 830), Vector2(707, 830), Vector2(876, 830),
	Vector2(1045, 830), Vector2(1214, 830), Vector2(1383, 830), Vector2(1552, 830), Vector2(1720, 830),
]

# Which stage_id to start when transitioning to game.tscn. -1 = not set.
var pending_stage_id: int = -1

# チュートリアル済みフラグ（保存あり）。
var tutorial_shown: bool = false

# チュートリアルの戻り先。"stage1"=ゲーム開始、"config"=コンフィグへ戻る。（保存なし・セッションのみ）
var tutorial_return_to: String = ""

var _states: Array[int] = []


func _ready() -> void:
	_states.resize(STAGE_COUNT)
	_states.fill(StageState.LOCKED)
	_states[0] = StageState.UNLOCKED
	_load_states()


func get_state(stage_id: int) -> int:
	if stage_id < 0 or stage_id >= STAGE_COUNT:
		return StageState.LOCKED
	return _states[stage_id]


func mark_cleared(stage_id: int) -> void:
	if stage_id < 0 or stage_id >= STAGE_COUNT:
		return
	_states[stage_id] = StageState.CLEARED
	for adj in _get_adjacent(stage_id):
		if _states[adj] == StageState.LOCKED:
			_states[adj] = StageState.UNLOCKED
	_save_states()


## Returns [[a, b], ...] index pairs for all grid edges.
func get_connections() -> Array:
	var conns: Array = []
	for row in range(ROWS):
		for col in range(COLS):
			var idx: int = row * COLS + col
			if col < COLS - 1:
				conns.append([idx, idx + 1])
			if row < ROWS - 1:
				conns.append([idx, idx + COLS])
	return conns


func _get_adjacent(stage_id: int) -> Array[int]:
	var col: int = stage_id % COLS
	var row: int = stage_id / COLS
	var adj: Array[int] = []
	if col > 0:
		adj.append(row * COLS + col - 1)
	if col < COLS - 1:
		adj.append(row * COLS + col + 1)
	if row > 0:
		adj.append((row - 1) * COLS + col)
	if row < ROWS - 1:
		adj.append((row + 1) * COLS + col)
	return adj


func _save_states() -> void:
	var data: Dictionary = {}
	for i in range(STAGE_COUNT):
		data[str(i)] = _states[i]
	data["tutorial_shown"] = tutorial_shown
	var f: FileAccess = FileAccess.open(_SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


## プレイ履歴を全て初期化する。ステージ0のみ UNLOCKED、tutorial_shown=false。
func reset_all() -> void:
	_states.fill(StageState.LOCKED)
	_states[0] = StageState.UNLOCKED
	tutorial_shown = false
	pending_stage_id = -1
	_save_states()


func _load_states() -> void:
	if not FileAccess.file_exists(_SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed as Dictionary
	for i in range(STAGE_COUNT):
		var k: String = str(i)
		if d.has(k):
			_states[i] = int(d[k])
	if d.has("tutorial_shown"):
		tutorial_shown = bool(d["tutorial_shown"])
