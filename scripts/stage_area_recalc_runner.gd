# CLI 用ランナー（エディタ外・headless 可）:
#   godot --headless --path . --script res://scripts/stage_area_recalc_runner.gd
extends SceneTree

const _Debug = preload("res://scripts/stage_area_recalc_debug.gd")


func _initialize() -> void:
	_Debug.run_and_print()
	quit()
