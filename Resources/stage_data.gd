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

static var _mbus_master_row: Dictionary = {}

## Resources/Stagedata/mbus.json をマスタ1行分に変換（キャッシュ）
static func _mbus_row() -> Dictionary:
	if not _mbus_master_row.is_empty():
		return _mbus_master_row.duplicate(true)
	var pr: Dictionary = CustomStageFile.parse_file(MBUS_STAGE_JSON)
	if not pr.get("ok", false):
		push_error("StageData: mbus.json を読めません: %s" % str(pr.get("error", "")))
		_mbus_master_row = _StageConfigScript.merge_config({"type": "fish", "num_points": 20, "min_radius": 320.0, "max_radius": 560.0, "variance": 0.15, "display_rate_min_pct": 75.0, "clear_pct": 95.0, "guide_follows_player_radius": 1})
		_mbus_master_row["guide_type_label"] = "メビウス"
		return _mbus_master_row.duplicate(true)
	var raw: Dictionary = pr["raw"] as Dictionary
	var play_err: String = CustomStageFile.validate_for_play(raw)
	if play_err != "":
		push_error("StageData: mbus.json が無効です: %s" % play_err)
		_mbus_master_row = _StageConfigScript.merge_config({"type": "fish", "num_points": 20, "min_radius": 320.0, "max_radius": 560.0, "variance": 0.15, "display_rate_min_pct": 75.0, "clear_pct": 95.0, "guide_follows_player_radius": 1})
		_mbus_master_row["guide_type_label"] = "メビウス"
		return _mbus_master_row.duplicate(true)
	var cfg: Dictionary = CustomStageFile.effective_config_with_shape(raw)
	cfg["guide_type_label"] = "メビウス"
	_mbus_master_row = cfg
	return _mbus_master_row.duplicate(true)


static func get_stages() -> Array:
	var overrides_list: Array = [
		# チュートリアル: 正三角形（3頂点）
		{"type": "triangle", "num_points": 3, "min_radius": 180.0, "max_radius": 260.0, "vertex_range": [3, 3], "variance": 0.20, "zigzag": 0.08, "clear_pct": 98.5},
		# テスト: 正方形（点対応・弧対応の判定を試す）
		{"type": "square", "num_points": 12, "min_radius": 180.0, "max_radius": 260.0, "variance": 0.20, "clear_pct": 97.5},
		# circle: 14点、難易度2
		{"type": "circle", "num_points": 14, "min_radius": 195.0, "max_radius": 360.0, "vertex_range": [4, 6], "variance": 0.45, "zigzag": 0.22, "clear_pct": 93.0},
		# メビウス（Stagedata/mbus.json の形状・パラメータ）
		_mbus_row(),
		# star: 20点
		{"type": "star", "num_points": 10, "min_radius": 128.0, "max_radius": 420.0, "vertex_range": [3, 5], "variance": 0.55, "zigzag": 0.35, "clear_pct": 98.0},
		# テスト: さかな（細長いシルエットのため、同じ半径でも他図形より小さく見えやすい → 半径レンジを広めに）
		{"type": "fish", "num_points": 7, "min_radius": 320.0, "max_radius": 560.0, "variance": 0.30, "display_rate_min_pct": 82.0, "clear_pct": 99.0},
		# テスト: ねこの顔（16～20点）
		{"type": "cat_face", "num_points": 18, "min_radius": 160.0, "max_radius": 280.0, "variance": 0.15, "display_rate_min_pct": 80.0, "clear_pct": 97.2},
		# heptagram_silhouette: 七芒星シルエット 
		{"type": "heptagram_silhouette", "num_points": 14, "min_radius": 128.0, "max_radius": 420.0, "variance": 0.15, "display_rate_min_pct": 80.0, "clear_pct": 97.0},
		# heptagram: 七芒星
		{"type": "heptagram", "num_points": 7, "min_radius": 128.0, "max_radius": 420.0, "vertex_range": [3, 5], "variance": 0.55, "zigzag": 0.35, "clear_pct": 98.0},
	]
	var result: Array = []
	for ov in overrides_list:
		result.append(_StageConfigScript.merge_config(ov))
	return result
