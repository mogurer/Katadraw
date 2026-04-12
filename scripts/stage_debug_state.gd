class_name StageDebugState
extends RefCounted

var scroll: float = 0.0
var scroll_vel: float = 0.0
var wheel_times: Array[float] = []
var scrollbar_drag: bool = false
var scrollbar_drag_thumb_rel_y: float = 0.0
var selected: int = 0
var pending: Dictionary = {}
var custom_paths: Array[String] = []
var custom_pending: Dictionary = {}
var field_buffers: Dictionary = {}
var field_focus_idx: int = -1
var edit_buffer: String = ""
var last_error: String = ""


func reset_for_screen(debug_tools_enabled: bool, field_keys: Array[String]) -> void:
	refresh_custom_paths(debug_tools_enabled)
	scroll = 0.0
	scroll_vel = 0.0
	wheel_times.clear()
	scrollbar_drag = false
	selected = 0
	field_focus_idx = -1
	edit_buffer = ""
	last_error = ""
	clamp_selection()
	sync_field_buffers(field_keys)


func refresh_custom_paths(debug_tools_enabled: bool) -> void:
	if not debug_tools_enabled:
		custom_paths.clear()
		return
	custom_paths = CustomStageFile.list_custom_stage_paths()


func master_count() -> int:
	return StageData.get_stages().size()


func total_rows() -> int:
	return master_count() + custom_paths.size()


func is_custom_row(row: int) -> bool:
	return row >= master_count() and row < total_rows()


func custom_path_at(row: int) -> String:
	return custom_paths[row - master_count()]


func clamp_selection() -> void:
	var n: int = total_rows()
	if n <= 0:
		selected = 0
		return
	if selected >= n:
		selected = n - 1
	if selected < 0:
		selected = 0


func custom_raw_merged(path: String) -> Dictionary:
	var pr: Dictionary = CustomStageFile.parse_file(path)
	if not pr.get("ok", false):
		return {}
	var raw: Dictionary = (pr["raw"] as Dictionary).duplicate(true)
	var pend: Dictionary = custom_pending.get(path, {})
	if pend.is_empty():
		return raw
	var cfg_partial: Dictionary = (raw["config"] as Dictionary).duplicate(true)
	var meta_partial: Dictionary = {}
	if raw.has("meta") and typeof(raw["meta"]) == TYPE_DICTIONARY:
		meta_partial = (raw["meta"] as Dictionary).duplicate(true)
	for k in pend:
		if k == "stage_name" or k == "description":
			var vs: String = str(pend[k]).strip_edges()
			if vs == "":
				meta_partial.erase(k)
			else:
				meta_partial[k] = vs
		else:
			cfg_partial[k] = pend[k]
	raw["config"] = cfg_partial
	if not meta_partial.is_empty():
		raw["meta"] = meta_partial
	elif raw.has("meta"):
		raw.erase("meta")
	return raw


func config_value_str_for_buffer(key: String, v: Variant) -> String:
	match key:
		"num_points", "guide_follows_player_radius":
			return str(int(v))
		_:
			return str(v)


func sync_field_buffers(field_keys: Array[String]) -> void:
	var cfg: Dictionary = {}
	var row: int = selected
	var raw_cfg: Dictionary = {}
	var meta_view: Dictionary = {}
	if is_custom_row(row):
		var path: String = custom_path_at(row)
		var raw: Dictionary = custom_raw_merged(path)
		if not raw.is_empty():
			cfg = CustomStageFile.effective_config_with_shape(raw)
			raw_cfg = raw["config"] as Dictionary
			if raw.has("meta") and typeof(raw["meta"]) == TYPE_DICTIONARY:
				meta_view = raw["meta"] as Dictionary
	else:
		cfg = StageDebugOverrides.build_config_for_index(row, pending.get(row, {}))
	field_buffers.clear()
	for key in field_keys:
		if key == "stage_name":
			field_buffers[key] = str(meta_view.get("stage_name", "")) if is_custom_row(row) else ""
			continue
		if key == "description":
			field_buffers[key] = str(meta_view.get("description", "")) if is_custom_row(row) else ""
			continue
		if key == "group_sizes" and cfg.has("group_sizes"):
			var gs: Array = cfg["group_sizes"] as Array
			field_buffers[key] = "%d,%d" % [int(gs[0]), int(gs[1])]
		elif is_custom_row(row) and key == "type":
			field_buffers[key] = str(raw_cfg.get("type", ""))
		elif cfg.has(key):
			field_buffers[key] = config_value_str_for_buffer(key, cfg[key])
		else:
			field_buffers[key] = ""
	if field_focus_idx >= 0 and field_focus_idx < field_keys.size():
		var fk: String = field_keys[field_focus_idx]
		edit_buffer = str(field_buffers.get(fk, ""))


func commit_focused_field_to_pending(field_keys: Array[String]) -> void:
	if field_focus_idx < 0 or field_focus_idx >= field_keys.size():
		return
	var fk: String = field_keys[field_focus_idx]
	last_error = apply_field_string_to_pending(fk, edit_buffer)
	sync_field_buffers(field_keys)


func validate_custom_stage_pending(path: String, partial: Dictionary) -> String:
	var pr: Dictionary = CustomStageFile.parse_file(path)
	if not pr.get("ok", false):
		return str(pr.get("error", "読み込み失敗"))
	var raw: Dictionary = (pr["raw"] as Dictionary).duplicate(true)
	var cfg_partial: Dictionary = (raw["config"] as Dictionary).duplicate(true)
	var meta_partial: Dictionary = {}
	if raw.has("meta") and typeof(raw["meta"]) == TYPE_DICTIONARY:
		meta_partial = (raw["meta"] as Dictionary).duplicate(true)
	for k in partial:
		if k == "stage_name" or k == "description":
			var vs: String = str(partial[k]).strip_edges()
			if vs == "":
				meta_partial.erase(k)
			else:
				meta_partial[k] = vs
		else:
			cfg_partial[k] = partial[k]
	raw["config"] = cfg_partial
	if not meta_partial.is_empty():
		raw["meta"] = meta_partial
	elif raw.has("meta"):
		raw.erase("meta")
	var vroot: String = CustomStageFile.validate_root(raw)
	if vroot != "":
		return vroot
	var cfg: Dictionary = CustomStageFile.effective_config_with_shape(raw)
	return StageDebugOverrides.validate_effective_config(cfg)


func apply_field_string_to_pending(key: String, text: String) -> String:
	var s: String = text.strip_edges()
	var row: int = selected
	if (key == "stage_name" or key == "description") and not is_custom_row(row):
		if s == "":
			return ""
		return "stage_name / description はカスタムステージ行のみ編集できます"
	if is_custom_row(row):
		var path: String = custom_path_at(row)
		var p: Dictionary = custom_pending.get(path, {}).duplicate(true)
		if s == "":
			if key == "stage_name" or key == "description":
				p[key] = ""
			else:
				p.erase(key)
		else:
			match key:
				"type":
					p["type"] = s
				"num_points":
					if not s.is_valid_int():
						return "num_points が整数ではありません"
					p["num_points"] = int(s)
				"min_radius", "max_radius", "variance", "zigzag", "display_rate_min_pct", "clear_pct":
					if not s.is_valid_float():
						return "%s が数値ではありません" % key
					p[key] = float(s)
				"guide_follows_player_radius":
					if s != "0" and s != "1":
						return "guide_follows_player_radius は 0 または 1"
					p[key] = int(s)
				"group_sizes":
					var parts: PackedStringArray = s.split(",")
					if parts.size() < 2:
						return "group_sizes は 12,12 の形式にしてください"
					if not parts[0].strip_edges().is_valid_int() or not parts[1].strip_edges().is_valid_int():
						return "group_sizes が不正です"
					p["group_sizes"] = [int(parts[0].strip_edges()), int(parts[1].strip_edges())]
				"stage_name", "description":
					p[key] = s
				_:
					p[key] = s
		var verr: String = validate_custom_stage_pending(path, p)
		if verr != "":
			return verr
		if p.is_empty():
			custom_pending.erase(path)
		else:
			custom_pending[path] = p
		return ""

	var idx: int = row
	var p2: Dictionary = pending.get(idx, {}).duplicate(true)
	if s == "":
		p2.erase(key)
	else:
		match key:
			"type":
				p2["type"] = s
			"num_points":
				if not s.is_valid_int():
					return "num_points が整数ではありません"
				p2["num_points"] = int(s)
			"min_radius", "max_radius", "variance", "zigzag", "display_rate_min_pct", "clear_pct":
				if not s.is_valid_float():
					return "%s が数値ではありません" % key
				p2[key] = float(s)
			"guide_follows_player_radius":
				if s != "0" and s != "1":
					return "guide_follows_player_radius は 0 または 1"
				p2[key] = int(s)
			"group_sizes":
				var parts: PackedStringArray = s.split(",")
				if parts.size() < 2:
					return "group_sizes は 12,12 の形式にしてください"
				if not parts[0].strip_edges().is_valid_int() or not parts[1].strip_edges().is_valid_int():
					return "group_sizes が不正です"
				p2["group_sizes"] = [int(parts[0].strip_edges()), int(parts[1].strip_edges())]
			_:
				p2[key] = s
	var verr2: String = StageDebugOverrides.validate_partial_with_master(idx, p2)
	if verr2 != "":
		return verr2
	if p2.is_empty():
		pending.erase(idx)
	else:
		pending[idx] = p2
	return ""


func list_row_label(row: int) -> String:
	if row < 0 or row >= total_rows():
		return "?"
	if row < master_count():
		var cfg: Dictionary = StageDebugOverrides.build_config_for_index(row, pending.get(row, {}))
		var gtl: String = str(cfg.get("guide_type_label", "")).strip_edges()
		if gtl != "":
			return gtl
		return str(cfg.get("type", "?"))
	var path: String = custom_path_at(row)
	var fn: String = path.get_file().get_basename()
	var raw: Dictionary = custom_raw_merged(path)
	if raw.is_empty():
		return "[C] %s" % fn
	var cfg_part: Dictionary = raw["config"] as Dictionary
	return "[C] %s" % str(cfg_part.get("type", fn))
