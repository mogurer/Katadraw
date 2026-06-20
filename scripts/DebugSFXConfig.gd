class_name DebugSFXConfig
extends RefCounted

static var in_idx: int = 0
static var out_idx: int = 0
static var in_count: int = 0
static var out_count: int = 0
static var _counted: bool = false


static func ensure_counted() -> void:
	if _counted:
		return
	_counted = true
	while in_count < 10:
		if not FileAccess.file_exists("res://assets/sounds/ui_in_%02d.wav" % (in_count + 1)):
			break
		in_count += 1
	while out_count < 10:
		if not FileAccess.file_exists("res://assets/sounds/ui_out_%02d.wav" % (out_count + 1)):
			break
		out_count += 1


static func in_path(idx: int) -> String:
	return "res://assets/sounds/ui_in_%02d.wav" % (idx + 1)


static func out_path(idx: int) -> String:
	return "res://assets/sounds/ui_out_%02d.wav" % (idx + 1)
