class_name StageSession
extends RefCounted

var stage_times: Array[float] = []
var stage_move_counts: Array[int] = []
var stage_result_shapes: Array = []

var debug_test_mode: bool = false
var debug_test_seed: int = 0
var debug_test_restart_cfg: Dictionary = {}
var debug_test_meta_stage_name: String = ""


func clear_results() -> void:
	stage_times.clear()
	stage_move_counts.clear()
	stage_result_shapes.clear()


func append_result(clear_time: float, move_count: int, shape_snapshot: Dictionary) -> void:
	stage_times.append(clear_time)
	stage_move_counts.append(move_count)
	stage_result_shapes.append(shape_snapshot)


func fill_dummy_results(slot_count: int) -> void:
	clear_results()
	for _i in range(slot_count):
		stage_times.append(randf_range(1.0, 999.0))
		stage_move_counts.append(randi_range(10, 500))
		stage_result_shapes.append({})


func start_debug_test(cfg: Dictionary, meta_stage_name: String = "") -> int:
	debug_test_mode = true
	debug_test_restart_cfg = cfg.duplicate(true)
	debug_test_seed = randi()
	debug_test_meta_stage_name = meta_stage_name
	return debug_test_seed


func clear_debug_test() -> void:
	debug_test_mode = false
	debug_test_seed = 0
	debug_test_restart_cfg.clear()
	debug_test_meta_stage_name = ""
