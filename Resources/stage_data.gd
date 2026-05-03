# =============================================================================
# StageData - ステージ定義
# =============================================================================
# 組み込みステージは Resources/Stagedata/builtin/ の JSON と manifest.json で管理する。
# 順序は manifest.json の "stages" 配列。本クラスはマニフェストを読み、各 JSON を
# CustomStageFile 経由でランタイム用 Dictionary に変換するだけ（インライン上書きは持たない）。
# 体験版と製品版の切り替えは GameConfig.get_max_stage_index() で行う。

class_name StageData

const BUILTIN_STAGEDATA_DIR := "res://Resources/Stagedata/builtin/"
const BUILTIN_MANIFEST_PATH := BUILTIN_STAGEDATA_DIR + "manifest.json"


static func _load_json_object_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("StageData: ファイルがありません: %s" % path)
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("StageData: 開けません: %s" % path)
		return {}
	var text: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("StageData: JSON 解析失敗: %s" % path)
		return {}
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("StageData: ルートはオブジェクトである必要があります: %s" % path)
		return {}
	return parsed as Dictionary


static func get_stages() -> Array:
	var mf: Dictionary = _load_json_object_from_path(BUILTIN_MANIFEST_PATH)
	if mf.is_empty():
		return []
	var schema_v: int = int(mf.get("schema_version", 0))
	if schema_v != 1:
		push_error("StageData: 未対応の manifest schema_version: %d" % schema_v)
		return []
	var filenames: Array = mf.get("stages", []) as Array
	var result: Array = []
	var stage_index: int = 0
	for fn_raw in filenames:
		var fn: String = str(fn_raw).strip_edges()
		if fn.is_empty():
			continue
		var path: String = BUILTIN_STAGEDATA_DIR + fn
		var pr: Dictionary = CustomStageFile.parse_file(path)
		if not pr.get("ok", false):
			push_error("StageData: %s — %s" % [fn, str(pr.get("error", ""))])
			continue
		var raw: Dictionary = (pr["raw"] as Dictionary).duplicate(true)
		var play_err: String = CustomStageFile.validate_for_play(raw)
		if play_err != "":
			push_error("StageData: %s が無効: %s" % [fn, play_err])
			continue
		var cfg: Dictionary = CustomStageFile.effective_config_with_shape(raw)
		if raw.has("meta") and typeof(raw["meta"]) == TYPE_DICTIONARY:
			var meta: Dictionary = raw["meta"] as Dictionary
			var sn: String = str(meta.get("stage_name", "")).strip_edges()
			if not sn.is_empty():
				cfg["guide_type_label"] = sn
			var lk: String = str(meta.get("locale_key", "")).strip_edges()
			if not lk.is_empty():
				cfg["locale_key"] = lk
		cfg["stage_index"] = stage_index
		stage_index += 1
		result.append(cfg)
	return result
