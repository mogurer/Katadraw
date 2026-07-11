# StageSelectManager — AutoLoad singleton for stage select state.
# Tracks LOCKED / UNLOCKED / CLEARED per stage, persists to user://stage_select_state.json.
# Node positions are defined in res://data/manifest.json (honeycomb grid).

extends Node

enum StageState { LOCKED, UNLOCKED, CLEARED }

const STAGE_COUNT := 50
const _SAVE_PATH    := "user://stage_select_state.json"
const _MANIFEST_PATH := "res://data/stage_select_manifest.json"

const X_PITCH: float = 200.0  # ワールド座標のグリッドピッチ（調整可能）
const SQRT3: float = 1.7320508

# 一本道ゾーン: このIDをクリアしたとき、接続リストではなくここで定義した相手のみを解放する
const _LINEAR_ZONE: Dictionary = { 0: [1], 1: [2], 2: [3] }

# Which stage_id to start when transitioning to game.tscn. -1 = not set.
var pending_stage_id: int = -1
# ステージセレクトに戻ったときのフォーカス位置（最後にプレイしたステージID）
var last_played_stage_id: int = -1
# 直前クリアで新たに解放されたステージIDの一時保持（ステージセレクト画面が読み取り次第クリア）
var last_unlocked_ids: Array[int] = []

# チュートリアル済みフラグ（保存あり）
var tutorial_shown: bool = false

# 全ステージクリア済みフラグ（保存あり）
var all_cleared: bool = false

# ZOU クリア済みフラグ（保存あり）
var zou_cleared: bool = false

# zou.json のステージインデックス（stage_select.gd が ready で設定する）
var _zou_stage_idx: int = -1

# チュートリアルの戻り先（保存なし・セッションのみ）
var tutorial_return_to: String = ""

# manifest から読み込むデータ
var _connections: Dictionary = {}   # { id: [隣接id, ...] }
var _grid_pos: Dictionary = {}      # { id: Vector2i(col, row) }
var _y_offset: Dictionary = {}      # { id: float }
var _bgm_zones: Array = []          # BGM解禁ゾーン定義
var _bgm_zone_centers: Array[Vector2] = []  # 各ゾーン中心のワールド座標

# 進行状態
var _states: Array[int] = []
var _stage_names: Array[String] = []
var _stage_locale_keys: Array[String] = []
var _best_times: Dictionary = {}
var _best_move_counts: Dictionary = {}
var _unlocked_bgms: Array[String] = []


func _ready() -> void:
	_states.resize(STAGE_COUNT)
	_states.fill(StageState.LOCKED)
	_states[0] = StageState.UNLOCKED
	_load_manifest()
	_load_states()
	_load_stage_names()


func _load_manifest() -> void:
	var f: FileAccess = FileAccess.open(_MANIFEST_PATH, FileAccess.READ)
	if f == null:
		push_error("StageSelectManager: manifest.json not found at " + _MANIFEST_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("StageSelectManager: manifest.json parse error")
		return
	var d: Dictionary = parsed as Dictionary
	for entry in d.get("stages", []):
		var id: int = int(entry["id"])
		var conns: Array = entry.get("connections", [])
		_connections[id] = conns
		var gp: Array = entry.get("grid_pos", [0, 0])
		_grid_pos[id] = Vector2i(int(gp[0]), int(gp[1]))
		_y_offset[id] = float(entry.get("y_offset", 0))
	_bgm_zones = d.get("bgm_unlock_zones", [])
	_bgm_zone_centers.clear()
	for zone in _bgm_zones:
		var cgp: Array = zone.get("center_grid_pos", [0, 0])
		_bgm_zone_centers.append(get_grid_world_pos(int(cgp[0]), int(cgp[1])))


func _load_stage_names() -> void:
	_stage_names.resize(STAGE_COUNT)
	_stage_names.fill("")
	_stage_locale_keys.resize(STAGE_COUNT)
	_stage_locale_keys.fill("")
	var stages: Array = StageData.get_stages()
	for i in range(mini(stages.size(), STAGE_COUNT)):
		_stage_names[i] = str(stages[i].get("guide_type_label", ""))
		_stage_locale_keys[i] = str(stages[i].get("locale_key", ""))


## グリッド座標からワールド座標を返す
func get_grid_world_pos(col: int, row: int, y_offset: float = 0.0) -> Vector2:
	return Vector2(col * X_PITCH * SQRT3, row * X_PITCH + y_offset)


## BGM解禁ゾーンの中心ワールド座標一覧を返す
func get_bgm_zone_centers() -> Array[Vector2]:
	return _bgm_zone_centers


## 解放済みBGM ID一覧を返す（複製）
func get_unlocked_bgm_ids() -> Array:
	return _unlocked_bgms.duplicate()


## ステージのワールド座標を返す（ぷるぷるアニメーション適用前の基準座標）
func get_world_pos(stage_id: int) -> Vector2:
	if not _grid_pos.has(stage_id):
		return Vector2.ZERO
	var gp: Vector2i = _grid_pos[stage_id]
	var x: float = gp.x * X_PITCH * SQRT3
	var y: float = gp.y * X_PITCH
	y += _y_offset.get(stage_id, 0.0)
	return Vector2(x, y)


func get_stage_name(stage_id: int) -> String:
	if stage_id < 0 or stage_id >= _stage_names.size():
		return ""
	var lk: String = _stage_locale_keys[stage_id] if stage_id < _stage_locale_keys.size() else ""
	if not lk.is_empty():
		return tr(lk)
	return _stage_names[stage_id]


func is_all_cleared() -> bool:
	return _states.all(func(s: int) -> bool: return s == StageState.CLEARED)


func get_state(stage_id: int) -> int:
	if stage_id < 0 or stage_id >= STAGE_COUNT:
		return StageState.LOCKED
	return _states[stage_id]


func mark_zou_cleared() -> void:
	zou_cleared = true
	_save_states()


func reset_zou_cleared() -> void:
	zou_cleared = false
	_save_states()


func mark_cleared(stage_id: int) -> void:
	if stage_id < 0 or stage_id >= STAGE_COUNT:
		return
	_states[stage_id] = StageState.CLEARED
	# 一本道ゾーンは専用リスト、それ以外は接続リストを使う
	var unlock_targets: Array = _LINEAR_ZONE.get(stage_id, _connections.get(stage_id, []))
	last_unlocked_ids.clear()
	for nb_id in unlock_targets:
		if nb_id >= 0 and nb_id < _states.size() and _states[nb_id] == StageState.LOCKED:
			_states[nb_id] = StageState.UNLOCKED
			last_unlocked_ids.append(nb_id)
	_save_states()
	if not all_cleared and is_all_cleared():
		all_cleared = true
		_save_states()


## [[a, b], ...] 形式の隣接ペア一覧を返す（重複なし）
func get_connections() -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for id in _connections:
		for nb in _connections[id]:
			var key_str: String = "%d_%d" % [mini(id, nb), maxi(id, nb)]
			if not seen.has(key_str):
				seen[key_str] = true
				result.append([mini(id, nb), maxi(id, nb)])
	return result


## 新たに解禁されたBGM名の配列を返す。解禁があれば保存も行う。
func check_bgm_unlocks() -> Array[String]:
	var newly_unlocked: Array[String] = []
	for zone in _bgm_zones:
		var bgm_name: String = str(zone.get("unlocks_bgm", ""))
		if bgm_name.is_empty() or _unlocked_bgms.has(bgm_name):
			continue
		var all_cleared: bool = true
		for sid in zone.get("required_stages", []):
			var sid_int: int = int(sid)
			if sid_int < 0 or sid_int >= _states.size() or _states[sid_int] != StageState.CLEARED:
				all_cleared = false
				break
		if all_cleared:
			_unlocked_bgms.append(bgm_name)
			newly_unlocked.append(bgm_name)
	if newly_unlocked.size() > 0:
		_save_states()
	return newly_unlocked


func update_best(stage_id: int, time: float, moves: int) -> Dictionary:
	var time_updated: bool = false
	var moves_updated: bool = false
	if not _best_times.has(stage_id) or time < float(_best_times[stage_id]):
		_best_times[stage_id] = time
		time_updated = true
	if not _best_move_counts.has(stage_id) or moves < int(_best_move_counts[stage_id]):
		_best_move_counts[stage_id] = moves
		moves_updated = true
	if time_updated or moves_updated:
		_save_states()
	return {time = time_updated, moves = moves_updated}


func get_best_time(stage_id: int) -> float:
	return float(_best_times[stage_id]) if _best_times.has(stage_id) else -1.0


func get_best_move_count(stage_id: int) -> int:
	return int(_best_move_counts[stage_id]) if _best_move_counts.has(stage_id) else -1


## プレイ履歴を全て初期化する。ステージ0のみ UNLOCKED、tutorial_shown=false。
func reset_all() -> void:
	_states.fill(StageState.LOCKED)
	_states[0] = StageState.UNLOCKED
	tutorial_shown = false
	all_cleared = false
	zou_cleared = false
	pending_stage_id = -1
	_best_times.clear()
	_best_move_counts.clear()
	_unlocked_bgms.clear()
	last_played_stage_id = -1
	_save_states()


func _save_states() -> void:
	var data: Dictionary = {}
	for i in range(STAGE_COUNT):
		data[str(i)] = _states[i]
	data["tutorial_shown"] = tutorial_shown
	data["all_cleared"] = all_cleared
	data["zou_cleared"] = zou_cleared
	var best_t: Dictionary = {}
	for k in _best_times:
		best_t[str(k)] = _best_times[k]
	data["best_times"] = best_t
	var best_m: Dictionary = {}
	for k in _best_move_counts:
		best_m[str(k)] = _best_move_counts[k]
	data["best_moves"] = best_m
	data["unlocked_bgms"] = _unlocked_bgms
	data["last_played_stage_id"] = last_played_stage_id
	var f: FileAccess = FileAccess.open(_SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


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
	all_cleared = bool(d.get("all_cleared", false))
	zou_cleared = bool(d.get("zou_cleared", false))
	if d.has("best_times"):
		var bt: Dictionary = d["best_times"] as Dictionary
		for k in bt:
			_best_times[int(k)] = float(bt[k])
	if d.has("best_moves"):
		var bm: Dictionary = d["best_moves"] as Dictionary
		for k in bm:
			_best_move_counts[int(k)] = int(bm[k])
	if d.has("unlocked_bgms"):
		for bgm in d["unlocked_bgms"]:
			_unlocked_bgms.append(str(bgm))
	last_played_stage_id = int(d.get("last_played_stage_id", -1))
