# 一時デバッグ: 実描画ロジック（ideal_outline + recompute_hud_guide_layout）からステージ面積を再計算する。
# エディタ実行中に game.gd の [F9]、または Godot CLI:
#   godot --headless --path . --script res://scripts/stage_area_recalc_runner.gd
class_name StageAreaRecalcDebug
extends RefCounted

const REF_VIEWPORT := Vector2(1920, 1080)
const EXCLUDED_SHAPE_TYPES: Array[String] = [
	"triangle", "square", "rhombus", "hexagon", "circle",
]


static func _avail_area_at_viewport(vp: Vector2) -> float:
	var play_w: float = vp.x * (1.0 - GameConfig.UI_WIDTH_RATIO)
	var play_h: float = vp.y
	var margin: float = GameConfig.HUD_GUIDE_MARGIN_FRAC
	var inner_w: float = play_w * (1.0 - 2.0 * margin)
	var inner_h: float = play_h * (1.0 - 2.0 * margin)
	return inner_w * inner_h


static func _stage_display_name(cfg: Dictionary) -> String:
	var label: String = str(cfg.get("guide_type_label", "")).strip_edges()
	if not label.is_empty():
		return label
	return str(cfg.get("stage_id", cfg.get("type", "?")))


static func run_and_print() -> void:
	var stages: Array = StageData.get_stages()
	var rows: Array[Dictionary] = []
	var vp: Vector2 = REF_VIEWPORT
	var shape_center: Vector2 = GameConfig.hud_playfield_shape_center(vp, 0)
	var avail_area: float = _avail_area_at_viewport(vp)
	var play_w: float = vp.x * (1.0 - GameConfig.UI_WIDTH_RATIO)
	var play_h: float = vp.y
	var margin: float = GameConfig.HUD_GUIDE_MARGIN_FRAC
	var inner_w: float = play_w * (1.0 - 2.0 * margin)
	var inner_h: float = play_h * (1.0 - 2.0 * margin)
	var threshold_ratio: float = GameConfig.HUD_SPAWN_INSIDE_AREA_THRESHOLD_RATIO

	for idx in range(stages.size()):
		var cfg: Dictionary = StageDebugOverrides.build_config_for_index(idx)
		if cfg.is_empty():
			continue
		var shape_type: String = str(cfg.get("shape_type", cfg.get("type", "")))
		if shape_type in EXCLUDED_SHAPE_TYPES:
			continue

		var sm := StageManager.new()
		var point_positions: Array[Vector2] = []
		sm.start_stage_with_config(idx, cfg, shape_center, vp, point_positions)

		var outline: Array = sm.hud_guide_outline_world
		var area_px: float = StageManager._shoelace_area_world(outline)
		var area_ratio: float = sm.hud_guide_area_ratio
		var inside: bool = area_ratio >= threshold_ratio
		var stage_id: String = str(cfg.get("stage_id", ""))
		rows.append({
			"name": _stage_display_name(cfg),
			"file": str(cfg.get("_source_file", stage_id + ".json")),
			"stage_id": stage_id,
			"shape_type": shape_type,
			"area_px2": area_px,
			"area_ratio": area_ratio,
			"inside": inside,
			"outline_pts": outline.size(),
		})

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["area_px2"]) > float(b["area_px2"])
	)

	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== Stage HUD outline area (1920x1080, descending) ===")
	lines.append("Excluded shape_type: %s" % ", ".join(EXCLUDED_SHAPE_TYPES))
	lines.append(
		"inner_w=%.1f inner_h=%.1f avail=%.1f px²" % [inner_w, inner_h, avail_area]
	)
	lines.append(
		"threshold_px@1080p=%.1f ratio=%.9f" % [
			GameConfig.HUD_SPAWN_INSIDE_AREA_THRESHOLD_PX_AT_1080P,
			threshold_ratio,
		]
	)
	lines.append("Count: %d" % rows.size())
	lines.append("")
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		lines.append(
			"%4d  %12.1f px²  ratio=%.6f  inside=%s  [%s]  %s  (%s)" % [
				i + 1,
				float(r["area_px2"]),
				float(r["area_ratio"]),
				"Y" if bool(r["inside"]) else "N",
				r["file"],
				r["name"],
				r["shape_type"],
			]
		)

	var inside_rows: Array[Dictionary] = []
	for r in rows:
		if bool(r["inside"]):
			inside_rows.append(r)

	lines.append("")
	lines.append("--- inside spawn stages (%d) ---" % inside_rows.size())
	for i in range(inside_rows.size()):
		var r: Dictionary = inside_rows[i]
		lines.append("%2d  [%s]  %s  %.1f px²" % [i + 1, r["file"], r["name"], float(r["area_px2"])])

	var report: String = "\n".join(lines)
	print(report)

	var out_path: String = "user://stage_area_report.txt"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(report)
		f.close()
		print("Wrote: %s" % ProjectSettings.globalize_path(out_path))
