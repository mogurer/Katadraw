# =============================================================================
# StageConfig - ステージパラメータのデフォルトとマージ
# =============================================================================
# 図形タイプごとのデフォルト値を一元管理。stage_data は差分（オーバーライド）のみ記述する。

class_name StageConfig

## 図形タイプごとのデフォルト値。新規タイプ追加時はここにエントリを追加する。
const TYPE_DEFAULTS: Dictionary = {
	"triangle": {
		"num_points": 3,
		"min_radius": 180.0,
		"max_radius": 260.0,
		"vertex_range": [3, 3],
		"variance": 0.20,
		"zigzag": 0.08,
		"clear_pct": 98.0,
		"display_rate_min_pct": 50.0,
		"guide_follows_player_radius": 0,
	},
	"square": {
		"num_points": 4,
		"min_radius": 180.0,
		"max_radius": 260.0,
		"vertex_range": [4, 4],
		"variance": 0.20,
		"zigzag": 0.08,
		"clear_pct": 98.0,
		"display_rate_min_pct": 50.0,
		"guide_follows_player_radius": 0,
		"hud_guide_layout_scale_mul": 0.5,
	},
	"hexagon": {
		"num_points": 6,
		"min_radius": 180.0,
		"max_radius": 260.0,
		"vertex_range": [6, 6],
		"variance": 0.20,
		"zigzag": 0.08,
		"clear_pct": 98.0,
		"display_rate_min_pct": 50.0,
		"guide_follows_player_radius": 0,
		"hud_guide_layout_scale_mul": 0.5,
	},
	"circle": {
		"num_points": 12,
		"min_radius": 200.0,
		"max_radius": 300.0,
		"vertex_range": [5, 7],
		"variance": 0.35,
		"zigzag": 0.15,
		"clear_pct": 97.0,
		"display_rate_min_pct": 50.0,
		"guide_follows_player_radius": 0,
	},
	"star": {
		"num_points": 10,
		"min_radius": 128.0,
		"max_radius": 420.0,
		"vertex_range": [3, 5],
		"variance": 0.55,
		"zigzag": 0.35,
		"clear_pct": 93.0,
		"display_rate_min_pct": 50.0,
		"guide_follows_player_radius": 0,
	},
	"cat_face": {
		"num_points": 18,
		"min_radius": 160.0,
		"max_radius": 280.0,
		"variance": 0.15,
		"clear_pct": 95.0,
		"display_rate_min_pct": 50.0,
		"guide_follows_player_radius": 0,
	},
	"fish": {
		"num_points": 16,
		"min_radius": 320.0,
		"max_radius": 560.0,
		"variance": 0.15,
		"clear_pct": 95.0,
		"display_rate_min_pct": 75.0,
		"guide_follows_player_radius": 1,
	},
	"heptagram": {
		"num_points": 7,
		"min_radius": 128.0,
		"max_radius": 420.0,
		"vertex_range": [3, 5],
		"variance": 0.55,
		"zigzag": 0.35,
		"clear_pct": 98.0,
		"display_rate_min_pct": 50.0,
		"guide_follows_player_radius": 0,
	},
	"heptagram_silhouette": {
		"num_points": 14,
		"min_radius": 128.0,
		"max_radius": 420.0,
		"variance": 0.15,
		"clear_pct": 97.0,
		"display_rate_min_pct": 80.0,
		"guide_follows_player_radius": 0,
	},
}


## ガイド表示・メトリクス: 0=固定ガイド寄り、1=プレイヤー代表半径に追従（細長シルエット向け）。
## cfg にキーが無いときは従来互換で fish のみ true。
static func resolve_guide_follows_player_radius(cfg: Dictionary, stage_type_str: String) -> bool:
	if cfg.has("guide_follows_player_radius"):
		var v: Variant = cfg["guide_follows_player_radius"]
		if typeof(v) == TYPE_BOOL:
			return v
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			return int(v) != 0
		if typeof(v) == TYPE_STRING:
			var s: String = str(v).strip_edges().to_lower()
			return s == "1" or s == "true" or s == "yes"
		return false
	return stage_type_str == "fish"


## デフォルトにオーバーライドをマージして完全な設定を返す。
## overrides には type が必須。それ以外は差分のみ指定すればよい。
## display_rate_min_pct: 実現率表示の下限。未指定時は50。
static func merge_config(overrides: Dictionary) -> Dictionary:
	var type: String = overrides.get("type", "circle")
	if not TYPE_DEFAULTS.has(type):
		push_warning("StageConfig: 未知の type '%s'、circle として扱います" % type)
		type = "circle"
	var cfg: Dictionary = TYPE_DEFAULTS[type].duplicate()
	for k in overrides:
		cfg[k] = overrides[k]
	if not cfg.has("display_rate_min_pct"):
		cfg["display_rate_min_pct"] = 50.0
	return cfg


## 「最終的にプレイへ渡す cfg」を 1 本化して生成する。
## built-in: partial.type が図形キー。
## custom: config.type が stage_id、config.shape_type が図形キー。
static func build_effective_config(partial: Dictionary, shape: Dictionary = {}) -> Dictionary:
	var source: Dictionary = partial.duplicate(true)
	var raw_type: String = str(source.get("type", "circle"))
	var shape_type: String = str(source.get("shape_type", "")).strip_edges()
	var resolved_type: String = shape_type if shape_type != "" else raw_type
	var stage_id: String = str(source.get("stage_id", "")).strip_edges()
	if stage_id.is_empty():
		stage_id = raw_type
	var merge_in: Dictionary = {}
	for k in source:
		if k == "shape_type":
			continue
		if k == "type" and shape_type != "":
			continue
		merge_in[k] = source[k]
	merge_in["type"] = resolved_type
	var cfg: Dictionary = merge_config(merge_in)
	cfg["shape_type"] = resolved_type
	cfg["stage_id"] = stage_id
	if not shape.is_empty():
		if shape.has("polygon_vertices"):
			cfg["shape_polygon_vertices"] = shape["polygon_vertices"]
		if shape.has("arc_controls"):
			cfg["shape_arc_controls"] = shape["arc_controls"]
	return cfg
