class_name DebugSFXConfig
extends RefCounted

static var in_idx: int = 0
static var out_idx: int = 0
static var in_count: int = 0
static var out_count: int = 0
static var _counted: bool = false

const _SAVE_PATH := "user://settings.cfg"
const _SECTION := "se"


static func ensure_counted() -> void:
	if _counted:
		return
	_counted = true
	while in_count < 10:
		if not FileAccess.file_exists("res://assets/sounds/SE/ui_in_%02d.wav" % (in_count + 1)):
			break
		in_count += 1
	while out_count < 10:
		if not FileAccess.file_exists("res://assets/sounds/SE/ui_out_%02d.wav" % (out_count + 1)):
			break
		out_count += 1


static func in_path(idx: int) -> String:
	return "res://assets/sounds/SE/ui_in_%02d.wav" % (idx + 1)


static func out_path(idx: int) -> String:
	return "res://assets/sounds/SE/ui_out_%02d.wav" % (idx + 1)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_SAVE_PATH)
	cfg.set_value(_SECTION, "in_idx", in_idx)
	cfg.set_value(_SECTION, "out_idx", out_idx)
	cfg.save(_SAVE_PATH)


static func load_saved() -> void:
	ensure_counted()
	var cfg := ConfigFile.new()
	if cfg.load(_SAVE_PATH) != OK:
		return
	in_idx = clampi(int(cfg.get_value(_SECTION, "in_idx", 0)), 0, maxi(0, in_count - 1))
	out_idx = clampi(int(cfg.get_value(_SECTION, "out_idx", 0)), 0, maxi(0, out_count - 1))
