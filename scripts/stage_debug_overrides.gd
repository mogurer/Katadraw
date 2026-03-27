# =============================================================================
# StageDebugOverrides - user:// のステージ別 JSON オーバーライド
# =============================================================================
# マスターは Resources/stage_data.gd（merge_config 済み行）。外部ファイルは差分のみ。

class_name StageDebugOverrides
extends RefCounted

const OVERRIDE_DIR := "user://debug_stage_overrides"
const SCHEMA_VERSION := 1


static func path_for_index(idx: int) -> String:
	return "%s/stage_%d.json" % [OVERRIDE_DIR, idx]


static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(OVERRIDE_DIR)


static func load_stage_file(idx: int) -> Dictionary:
	var p: String = path_for_index(idx)
	if not FileAccess.file_exists(p):
		return {}
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func overrides_from_file_payload(raw: Dictionary) -> Dictionary:
	if raw.has("overrides") and raw["overrides"] is Dictionary:
		return (raw["overrides"] as Dictionary).duplicate(true)
	var o: Dictionary = {}
	for k in raw:
		if str(k) in ["schema_version", "stage_index"]:
			continue
		o[k] = raw[k]
	return o


static func fill_missing_from_type_defaults(cfg: Dictionary) -> Dictionary:
	var t: String = str(cfg.get("type", "circle"))
	if not StageConfig.TYPE_DEFAULTS.has(t):
		return cfg
	var defs: Dictionary = StageConfig.TYPE_DEFAULTS[t]
	for k in defs:
		if not cfg.has(k):
			cfg[k] = defs[k]
	if not cfg.has("display_rate_min_pct"):
		cfg["display_rate_min_pct"] = 50.0
	return cfg


static func merge_with_master(master_row: Dictionary, file_raw: Dictionary) -> Dictionary:
	var cfg: Dictionary = master_row.duplicate(true)
	var ov: Dictionary = overrides_from_file_payload(file_raw)
	for k in ov:
		cfg[k] = ov[k]
	return fill_missing_from_type_defaults(cfg)


static func get_effective_stages() -> Array:
	var master: Array = StageData.get_stages()
	var out: Array = []
	for i in range(master.size()):
		var file_raw: Dictionary = load_stage_file(i)
		if file_raw.is_empty():
			out.append((master[i] as Dictionary).duplicate(true))
		else:
			out.append(merge_with_master((master[i] as Dictionary).duplicate(true), file_raw))
	return out


static func build_config_for_index(idx: int, pending: Dictionary = {}) -> Dictionary:
	var base: Dictionary = (StageData.get_stages()[idx] as Dictionary).duplicate(true)
	var file_raw: Dictionary = load_stage_file(idx)
	if not file_raw.is_empty():
		base = merge_with_master(base, file_raw)
	for k in pending:
		base[k] = pending[k]
	return fill_missing_from_type_defaults(base)


static func validate_effective_config(cfg: Dictionary) -> String:
	if not cfg.has("type"):
		return "type がありません"
	var t: String = str(cfg["type"])
	if not StageConfig.TYPE_DEFAULTS.has(t):
		return "未知の type: %s" % t
	if not cfg.has("num_points"):
		return "num_points がありません"
	var np: int = int(cfg["num_points"])
	if np < 1:
		return "num_points は 1 以上にしてください"
	if not cfg.has("min_radius") or not cfg.has("max_radius"):
		return "min_radius / max_radius が必要です"
	var mn: float = float(cfg["min_radius"])
	var mx: float = float(cfg["max_radius"])
	if mn < 0.0 or mx < 0.0:
		return "半径は 0 以上にしてください"
	if mn > mx:
		return "min_radius <= max_radius にしてください"
	if not cfg.has("clear_pct"):
		return "clear_pct がありません"
	var cp: float = float(cfg["clear_pct"])
	if cp <= 0.0 or cp > 100.0:
		return "clear_pct は (0, 100] にしてください"
	if cfg.has("display_rate_min_pct"):
		var dr: float = float(cfg["display_rate_min_pct"])
		if dr < 0.0 or dr > 100.0:
			return "display_rate_min_pct は [0, 100] にしてください"
	if cfg.has("vertex_range"):
		var vr: Variant = cfg["vertex_range"]
		if typeof(vr) != TYPE_ARRAY or (vr as Array).size() < 2:
			return "vertex_range は [int,int] 形式にしてください"
		var a: int = int((vr as Array)[0])
		var b: int = int((vr as Array)[1])
		if a < 1 or b < 1 or a > b:
			return "vertex_range が不正です"
	if t == "two_circles" and cfg.has("group_sizes"):
		var gs: Variant = cfg["group_sizes"]
		if typeof(gs) != TYPE_ARRAY or (gs as Array).size() < 2:
			return "group_sizes は [int,int] が必要です"
		var s0: int = int((gs as Array)[0])
		var s1: int = int((gs as Array)[1])
		if s0 + s1 != np:
			return "group_sizes の合計が num_points と一致しません"
	if cfg.has("guide_follows_player_radius"):
		var gv: Variant = cfg["guide_follows_player_radius"]
		if typeof(gv) == TYPE_BOOL:
			pass
		elif typeof(gv) == TYPE_INT or typeof(gv) == TYPE_FLOAT:
			var gi: int = int(gv)
			if gi != 0 and gi != 1:
				return "guide_follows_player_radius は 0 または 1"
		else:
			return "guide_follows_player_radius は 0 または 1"
	return ""


static func save_stage_override(idx: int, overrides: Dictionary) -> String:
	if overrides.is_empty():
		delete_stage_override(idx)
		return ""
	var err: String = validate_partial_with_master(idx, overrides)
	if err != "":
		return err
	ensure_dir()
	var payload: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"stage_index": idx,
		"overrides": overrides.duplicate(true),
	}
	var p: String = path_for_index(idx)
	var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return "保存に失敗しました: %s" % p
	f.store_string(JSON.stringify(payload))
	return ""


static func validate_partial_with_master(idx: int, overrides: Dictionary) -> String:
	var merged: Dictionary = build_config_for_index(idx, overrides)
	return validate_effective_config(merged)


static func delete_stage_override(idx: int) -> void:
	var p: String = path_for_index(idx)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


static func delete_all_overrides() -> void:
	ensure_dir()
	var da: DirAccess = DirAccess.open(OVERRIDE_DIR)
	if da == null:
		return
	da.list_dir_begin()
	var fn: String = da.get_next()
	while fn != "":
		if not da.current_is_dir() and fn.ends_with(".json"):
			da.remove(fn)
		fn = da.get_next()
