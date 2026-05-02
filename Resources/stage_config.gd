# =============================================================================
# StageConfig - ステージパラメータ補助
# =============================================================================
# 有効な shape_type 一覧と、エディタ新規ステージ作成用テンプレートを管理する。
# 各ステージの runtime パラメータは builtin JSON に記述する。

class_name StageConfig

## 有効な shape_type 一覧。バリデーションと UI 選択肢に使用する。
const KNOWN_SHAPE_TYPES: PackedStringArray = [
	"triangle", "square", "rhombus", "hexagon", "circle",
	"star", "cat_face", "fish", "heptagram", "heptagram_silhouette", "rugby_ball",
]

## エディタ新規ステージ作成時の初期値テンプレート（shape_type ごと）。
## runtime パラメータ（min/max_radius, display_rate_min_pct, guide_follows_player_radius,
## clear_pct）はゲーム側で明示的に設定するため含めない。
const EDITOR_NEW_STAGE_DEFAULTS: Dictionary = {
	"triangle":  { "num_points": 3,  "variance": 0.20, "vertex_range": [3, 3], "zigzag": 0.08, "hud_guide_layout_scale_mul": 0.8 },
	"square":    { "num_points": 4,  "variance": 0.20, "vertex_range": [4, 4], "zigzag": 0.08, "hud_guide_layout_scale_mul": 0.75 },
	"rhombus":   { "num_points": 4,  "variance": 0.0,  "rhombus_vertical_half": 0.5, "hud_guide_layout_scale_mul": 0.5 },
	"hexagon":   { "num_points": 6,  "variance": 0.20, "vertex_range": [6, 6], "zigzag": 0.08, "hud_guide_layout_scale_mul": 0.5 },
	"circle":    { "num_points": 12, "variance": 0.35, "vertex_range": [5, 7], "zigzag": 0.15 },
	"star":      { "num_points": 10, "variance": 0.55, "vertex_range": [3, 5], "zigzag": 0.35 },
	"cat_face":  { "num_points": 18, "variance": 0.15 },
	"fish":      { "num_points": 16, "variance": 0.15 },
	"heptagram": { "num_points": 7,  "variance": 0.55, "vertex_range": [3, 5], "zigzag": 0.35 },
	"heptagram_silhouette": { "num_points": 14, "variance": 0.15 },
	"rugby_ball": { "num_points": 24, "variance": 0.15, "hud_guide_layout_scale_mul": 0.80 },
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


## config から runtime 用の有効な設定 Dictionary を返す。
## shape_type / type フィールドを正規化し、shape ブロックのデータを組み込む。
static func build_effective_config(partial: Dictionary, shape: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = partial.duplicate(true)
	var raw_type: String = str(cfg.get("type", ""))
	var shape_type: String = str(cfg.get("shape_type", "")).strip_edges()
	var resolved_type: String = shape_type if shape_type != "" else raw_type
	var stage_id: String = str(cfg.get("stage_id", "")).strip_edges()
	if stage_id.is_empty():
		stage_id = raw_type
	cfg["type"] = resolved_type
	cfg["shape_type"] = resolved_type
	cfg["stage_id"] = stage_id
	if not shape.is_empty():
		if shape.has("polygon_vertices"):
			cfg["shape_polygon_vertices"] = shape["polygon_vertices"]
		if shape.has("arc_controls"):
			cfg["shape_arc_controls"] = shape["arc_controls"]
	return cfg
