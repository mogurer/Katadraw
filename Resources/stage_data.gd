# =============================================================================
# StageData - ステージ定義
# =============================================================================
# ステージの追加・並び替え・バランス調整はこのファイルで実施する。
# 各ステージはオーバーライドのみ記述。デフォルトは StageConfig.TYPE_DEFAULTS を参照。
# 例: {"type": "circle", "num_points": 14} で他はデフォルトを使用。
# 体験版と製品版の切り替えは GameConfig.get_max_stage_index() で行う。

class_name StageData

const _StageConfigScript = preload("res://Resources/stage_config.gd")
const MBUS_STAGE_JSON := "res://Resources/Stagedata/mbus.json"
const MUG_STAGE_JSON := "res://Resources/Stagedata/mug.json"
const HEPTAGRAM_STAGE_JSON := "res://Resources/Stagedata/heptagram_m.json"
const HEPTAGRAM_SILHOUETTE_STAGE_JSON := "res://Resources/Stagedata/heptagramsil_j.json"

static var _mbus_master_row: Dictionary = {}
static var _mug_master_row: Dictionary = {}
static var _heptagram_master_row: Dictionary = {}
static var _heptagram_silhouette_master_row: Dictionary = {}


static func _load_custom_stage_master_row(
	path: String,
	fallback_partial: Dictionary,
	guide_label: String,
	forced_shape_type: String = "",
	forced_stage_id: String = ""
) -> Dictionary:
	var pr: Dictionary = CustomStageFile.parse_file(path)
	if not pr.get("ok", false):
		push_error("StageData: %s を読めません: %s" % [path.get_file(), str(pr.get("error", ""))])
		var fallback_cfg: Dictionary = _StageConfigScript.build_effective_config(fallback_partial)
		fallback_cfg["guide_type_label"] = guide_label
		return fallback_cfg
	var raw: Dictionary = (pr["raw"] as Dictionary).duplicate(true)
	if raw.has("config") and typeof(raw["config"]) == TYPE_DICTIONARY:
		var raw_cfg: Dictionary = (raw["config"] as Dictionary).duplicate(true)
		if forced_stage_id != "":
			raw_cfg["type"] = forced_stage_id
		if forced_shape_type != "":
			raw_cfg["shape_type"] = forced_shape_type
		raw["config"] = raw_cfg
	var play_err: String = CustomStageFile.validate_for_play(raw)
	if play_err != "":
		push_error("StageData: %s が無効です: %s" % [path.get_file(), play_err])
		var fallback_cfg2: Dictionary = _StageConfigScript.build_effective_config(fallback_partial)
		fallback_cfg2["guide_type_label"] = guide_label
		return fallback_cfg2
	var cfg: Dictionary = CustomStageFile.effective_config_with_shape(raw)
	if forced_stage_id != "" and str(cfg.get("stage_id", "")).strip_edges() == "":
		cfg["stage_id"] = forced_stage_id
	cfg["guide_type_label"] = guide_label
	return cfg

## Resources/Stagedata/mbus.json をマスタ1行分に変換（キャッシュ）
static func _mbus_row() -> Dictionary:
	if not _mbus_master_row.is_empty():
		return _mbus_master_row.duplicate(true)
	_mbus_master_row = _load_custom_stage_master_row(
		MBUS_STAGE_JSON,
		{"type": "fish", "stage_id": "mbus", "num_points": 20, "min_radius": 320.0, "max_radius": 560.0, "variance": 0.15, "display_rate_min_pct": 75.0, "clear_pct": 95.0, "guide_follows_player_radius": 1},
		"メビウス"
	)
	return _mbus_master_row.duplicate(true)


## Resources/Stagedata/mug.json をマスタ1行分に変換（キャッシュ）
static func _mug_row() -> Dictionary:
	if not _mug_master_row.is_empty():
		return _mug_master_row.duplicate(true)
	_mug_master_row = _load_custom_stage_master_row(
		MUG_STAGE_JSON,
		{"type": "fish", "stage_id": "mug", "num_points": 12, "min_radius": 200.0, "max_radius": 400.0, "variance": 0.15, "display_rate_min_pct": 80.0, "clear_pct": 99.0, "guide_follows_player_radius": 0},
		"マグカップ"
	)
	return _mug_master_row.duplicate(true)


static func _heptagram_row() -> Dictionary:
	if not _heptagram_master_row.is_empty():
		return _heptagram_master_row.duplicate(true)
	_heptagram_master_row = _load_custom_stage_master_row(
		HEPTAGRAM_STAGE_JSON,
		{"type": "heptagram", "stage_id": "heptagram", "num_points": 7, "min_radius": 128.0, "max_radius": 420.0, "vertex_range": [3, 5], "variance": 0.55, "zigzag": 0.35, "clear_pct": 98.0},
		"七芒星",
		"heptagram",
		"heptagram"
	)
	return _heptagram_master_row.duplicate(true)


static func _heptagram_silhouette_row() -> Dictionary:
	if not _heptagram_silhouette_master_row.is_empty():
		return _heptagram_silhouette_master_row.duplicate(true)
	_heptagram_silhouette_master_row = _load_custom_stage_master_row(
		HEPTAGRAM_SILHOUETTE_STAGE_JSON,
		{"type": "heptagram_silhouette", "stage_id": "heptagram_silhouette", "num_points": 14, "min_radius": 128.0, "max_radius": 420.0, "variance": 0.15, "display_rate_min_pct": 80.0, "clear_pct": 97.0},
		"七芒星シルエット",
		"heptagram_silhouette",
		"heptagram_silhouette"
	)
	return _heptagram_silhouette_master_row.duplicate(true)


static func get_stages() -> Array:
	var overrides_list: Array = [
		# チュートリアル: 正三角形（3頂点）
		{"type": "triangle", "stage_id": "tutorial_triangle", "num_points": 3, "min_radius": 180.0, "max_radius": 260.0, "vertex_range": [3, 3], "variance": 0.20, "zigzag": 0.08, "clear_pct": 98.5},
		# テスト: 正方形（点対応・弧対応の判定を試す）
		{"type": "square", "stage_id": "test_square", "num_points": 12, "min_radius": 180.0, "max_radius": 260.0, "variance": 0.20, "clear_pct": 97.5},
		# circle: 14点、難易度2
		{"type": "circle", "stage_id": "circle_14", "num_points": 14, "min_radius": 195.0, "max_radius": 360.0, "vertex_range": [4, 6], "variance": 0.45, "zigzag": 0.22, "clear_pct": 93.0},
		# メビウス（Stagedata/mbus.json の形状・パラメータ）
		_mbus_row(),
		# star: 20点
		{"type": "star", "stage_id": "star_10", "num_points": 10, "min_radius": 128.0, "max_radius": 420.0, "vertex_range": [3, 5], "variance": 0.55, "zigzag": 0.35, "clear_pct": 98.0},
		# テスト: さかな（細長いシルエットのため、同じ半径でも他図形より小さく見えやすい → 半径レンジを広めに）
		{"type": "fish", "stage_id": "fish_7", "num_points": 7, "min_radius": 320.0, "max_radius": 560.0, "variance": 0.30, "display_rate_min_pct": 82.0, "clear_pct": 99.0},
		# テスト: ねこの顔（16～20点）
		{"type": "cat_face", "stage_id": "cat_face_18", "num_points": 18, "min_radius": 160.0, "max_radius": 280.0, "variance": 0.15, "display_rate_min_pct": 80.0, "clear_pct": 97.2},
		# マグカップ（Stagedata/mug.json）
		_mug_row(),
		# heptagram_silhouette: 七芒星シルエット
		_heptagram_silhouette_row(),
		# heptagram: 七芒星
		_heptagram_row(),
	]
	var result: Array = []
	for i in range(overrides_list.size()):
		var cfg: Dictionary = _StageConfigScript.build_effective_config(overrides_list[i])
		cfg["stage_index"] = i
		result.append(cfg)
	return result
