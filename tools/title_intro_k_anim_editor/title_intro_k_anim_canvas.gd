extends Control

func _draw() -> void:
	var ed: Node = get_parent().get_parent()
	if ed and ed.has_method("draw_canvas"):
		ed.call("draw_canvas", self)
