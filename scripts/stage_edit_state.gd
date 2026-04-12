class_name StageEditState
extends RefCounted

var stage_id: String = "new_stage"
var meta_preserve: Dictionary = {}
var type_idx: int = 0
var include_fish_shape: bool = true
var text_line: int = 0
var last_error: String = ""

var canvas_vertices: Array[Vector2] = []
var canvas_edges: Array[Dictionary] = []
var canvas_hover_edge: int = -1
var canvas_drag_idx: int = -1
var canvas_drag_norm_offset: Vector2 = Vector2.ZERO
var canvas_right_drag_idx: int = -1
var canvas_right_down_pos: Vector2 = Vector2.ZERO
var canvas_right_drag_norm_offset: Vector2 = Vector2.ZERO
var canvas_right_drag_committed: bool = false

var undo_stack: Array = []
var redo_stack: Array = []
var mirror_preview: Array[bool] = [false, false, false, false]


func _reset_common() -> void:
	include_fish_shape = true
	text_line = 0
	last_error = ""
	canvas_vertices.clear()
	canvas_edges.clear()
	canvas_hover_edge = -1
	canvas_drag_idx = -1
	canvas_drag_norm_offset = Vector2.ZERO
	canvas_right_drag_idx = -1
	canvas_right_down_pos = Vector2.ZERO
	canvas_right_drag_norm_offset = Vector2.ZERO
	canvas_right_drag_committed = false
	undo_stack.clear()
	redo_stack.clear()
	mirror_preview = [false, false, false, false]


func reset_new() -> void:
	stage_id = "new_stage"
	meta_preserve = {}
	type_idx = 0
	_reset_common()


func reset_from_raw(stage_id_in: String, meta_preserve_in: Dictionary, type_idx_in: int) -> void:
	stage_id = stage_id_in
	meta_preserve = meta_preserve_in.duplicate(true)
	type_idx = type_idx_in
	_reset_common()


func clear_error() -> void:
	last_error = ""
