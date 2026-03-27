# =============================================================================
# CustomStageFile — Edit 保存 / ランタイム共有用の単一スキーマ（課題①）
# =============================================================================
# KatadrawShapeEditor 由来の操作で編集した結果は、この形式で保存する。
# config.type は Stage ID（ファイル名のベース名と同一であること。リネーム時は parse_file が type を揃えて保存）。
# user://custom_stages の *.json はファイル名が [a-z0-9_]+ のみ（拡張子除く）。それ以外は一覧に出さない。
# 図形の種類は config.shape_type（fish / triangle / … StageConfig.TYPE_DEFAULTS のキー）。
# 旧形式: config.type のみが図形キーだったファイルも読み込み可能（レガシー）。
# shape は頂点・弧など幾何のみ。未使用でも保存可。
#
# ファイル例（概略）:
# {
#   "schema_version": 1,
#   "kind": "katadraw_custom_stage",
#   "meta": { "stage_name": "日本語名（テストプレイの説明行に使用可）", "description": "制作者メモ" },
#   "config": { "type": "my_stage", "shape_type": "fish", "num_points": 9, "clear_pct": 98.0 },
#   "shape": {
#     "polygon_vertices": [[-0.97, 0.0], ...],
#     "arc_controls": { "5": [-0.56, 0.02] }
#   }
# }

class_name CustomStageFile
extends RefCounted

const SCHEMA_VERSION: int = 1
const KIND: String = "katadraw_custom_stage"
## Edit 産ステージの推奨保存先（②で一覧と連携）
const CUSTOM_STAGE_DIR: String = "user://custom_stages"

## config.type をファイル名に合わせて保存できなかったパス（リトライ抑制用）
static var _sync_type_save_failed: Dictionary = {}


## カスタムステージ JSON のファイル名（拡張子を除く）に使える文字: 小文字 a-z / 数字 / _
static func is_valid_custom_stage_filename_stem(stem: String) -> bool:
	if stem.is_empty() or stem.length() > 48:
		return false
	for i in range(stem.length()):
		var c: int = stem.unicode_at(i)
		if not ((c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95):
			return false
	return true


static func ensure_custom_stage_dir() -> void:
	DirAccess.make_dir_recursive_absolute(CUSTOM_STAGE_DIR)


## user://custom_stages 内の .json を名前順で列挙（② 一覧用）
static func list_custom_stage_paths() -> Array[String]:
	ensure_custom_stage_dir()
	var out: Array[String] = []
	var da: DirAccess = DirAccess.open(CUSTOM_STAGE_DIR)
	if da == null:
		return out
	da.list_dir_begin()
	var fn: String = da.get_next()
	while fn != "":
		if not da.current_is_dir() and fn.ends_with(".json"):
			var stem: String = fn.get_basename()
			if is_valid_custom_stage_filename_stem(stem):
				out.append("%s/%s" % [CUSTOM_STAGE_DIR, fn])
		fn = da.get_next()
	out.sort()
	return out


static func parse_json_string(text: String) -> Dictionary:
	"""成功: { "ok": true, "raw": Dictionary } 失敗: { "ok": false, "error": String }"""
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "JSON がオブジェクトではありません"}
	var raw: Dictionary = parsed as Dictionary
	var err: String = validate_root(raw)
	if err != "":
		return {"ok": false, "error": err}
	return {"ok": true, "raw": raw}


static func parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "ファイルがありません: %s" % path}
	var stem: String = path.get_file().get_basename()
	if not is_valid_custom_stage_filename_stem(stem):
		return {"ok": false, "error": "ファイル名は a〜z・0〜9・_ のみ（拡張子 .json）: %s" % path.get_file()}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "読み込み失敗: %s" % path}
	var pr: Dictionary = parse_json_string(f.get_as_text())
	if not pr.get("ok", false):
		return pr
	var raw: Dictionary = pr["raw"] as Dictionary
	var cfg: Dictionary = raw["config"] as Dictionary
	var cur_type: String = str(cfg.get("type", ""))
	if cur_type != stem:
		cfg["type"] = stem
		if not _sync_type_save_failed.has(path):
			var werr: String = save_to_path(path, raw)
			if werr != "":
				_sync_type_save_failed[path] = true
				pr["sync_warning"] = werr
			else:
				_sync_type_save_failed.erase(path)
		else:
			pr["sync_warning"] = "config.type をファイル名に合わせた保存に失敗したため、再試行をスキップしています（%s）" % path.get_file()
	return pr


## トップレベル必須: schema_version, kind, config
static func validate_root(raw: Dictionary) -> String:
	if not raw.has("schema_version"):
		return "schema_version がありません"
	var sv: int = int(raw["schema_version"])
	if sv != SCHEMA_VERSION:
		return "未対応の schema_version: %d（対応: %d）" % [sv, SCHEMA_VERSION]
	if str(raw.get("kind", "")) != KIND:
		return "kind は \"%s\" である必要があります" % KIND
	if not raw.has("config") or typeof(raw["config"]) != TYPE_DICTIONARY:
		return "config オブジェクトが必要です"
	var cfg: Dictionary = raw["config"] as Dictionary
	if not cfg.has("type") or str(cfg["type"]).is_empty():
		return "config.type が必要です"
	if raw.has("shape") and typeof(raw["shape"]) != TYPE_DICTIONARY:
		return "shape はオブジェクトである必要があります"
	if raw.has("shape"):
		var sh: Dictionary = raw["shape"] as Dictionary
		var es: String = validate_shape_block(sh)
		if es != "":
			return es
	if raw.has("meta") and typeof(raw["meta"]) != TYPE_DICTIONARY:
		return "meta はオブジェクトである必要があります"
	if raw.has("meta") and typeof(raw["meta"]) == TYPE_DICTIONARY:
		var meta: Dictionary = raw["meta"] as Dictionary
		for mk in meta:
			if typeof(meta[mk]) != TYPE_STRING:
				return "meta.%s は文字列である必要があります" % mk
	var id_str: String = str(cfg.get("type", ""))
	var shape_t: String = str(cfg.get("shape_type", ""))
	if shape_t.is_empty() and not StageConfig.TYPE_DEFAULTS.has(id_str):
		return "config.shape_type が必要です（図形タイプ: fish, triangle, …）。config.type は Stage ID（ユニーク）です"
	return ""


## 幾何ブロック（Edit 出力）。空でもよい。中身は②で消費予定。
static func validate_shape_block(shape: Dictionary) -> String:
	if shape.is_empty():
		return ""
	if shape.has("polygon_vertices"):
		var pv: Variant = shape["polygon_vertices"]
		if typeof(pv) != TYPE_ARRAY:
			return "shape.polygon_vertices は配列である必要があります"
		var arr: Array = pv as Array
		if arr.size() < 3:
			return "shape.polygon_vertices は少なくとも 3 頂点必要です"
		for i in range(arr.size()):
			var p: Variant = _parse_vec2(arr[i])
			if p == null:
				return "shape.polygon_vertices[%d] が不正です（[x,y] または {x,y}）" % i
	if shape.has("arc_controls"):
		var ac: Variant = shape["arc_controls"]
		if typeof(ac) != TYPE_DICTIONARY:
			return "shape.arc_controls はオブジェクトである必要があります"
		for k in ac as Dictionary:
			var p: Variant = _parse_vec2((ac as Dictionary)[k])
			if p == null:
				return "shape.arc_controls[%s] が不正です" % str(k)
	return ""


static func _parse_vec2(v: Variant) -> Variant:
	if typeof(v) == TYPE_VECTOR2:
		return v
	if typeof(v) == TYPE_ARRAY:
		var a: Array = v as Array
		if a.size() < 2:
			return null
		return Vector2(float(a[0]), float(a[1]))
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v as Dictionary
		if not d.has("x") or not d.has("y"):
			return null
		return Vector2(float(d["x"]), float(d["y"]))
	return null


## config 差分を StageConfig にマージした「ランタイム用 1 本分」
## エンジン用の cfg.type は図形キー。Stage ID は cfg.stage_id（新形式のみ）。
static func effective_config(raw: Dictionary) -> Dictionary:
	var partial: Dictionary = (raw["config"] as Dictionary).duplicate(true)
	var id_str: String = str(partial.get("type", ""))
	var shape_kind: String = str(partial.get("shape_type", ""))
	if shape_kind.is_empty() and StageConfig.TYPE_DEFAULTS.has(id_str):
		return StageConfig.merge_config(partial)
	if shape_kind.is_empty():
		shape_kind = "circle"
	var merge_in: Dictionary = {}
	for k in partial:
		if k == "type" or k == "shape_type":
			continue
		merge_in[k] = partial[k]
	merge_in["type"] = shape_kind
	var merged: Dictionary = StageConfig.merge_config(merge_in)
	merged["stage_id"] = id_str
	return merged


## shape ブロックを StageManager が読むキーへ写す（JSON 配列のまま渡し、Manager 側で Vector2 化）
static func effective_config_with_shape(raw: Dictionary) -> Dictionary:
	var cfg: Dictionary = effective_config(raw).duplicate(true)
	if raw.has("shape") and typeof(raw["shape"]) == TYPE_DICTIONARY:
		var sh: Dictionary = raw["shape"] as Dictionary
		if sh.has("polygon_vertices"):
			cfg["shape_polygon_vertices"] = sh["polygon_vertices"]
		if sh.has("arc_controls"):
			cfg["shape_arc_controls"] = sh["arc_controls"]
	return cfg


## ゲームプレイ用の検証（StageDebugOverrides と同じ基準）
static func validate_runtime_config(cfg: Dictionary) -> String:
	return StageDebugOverrides.validate_effective_config(cfg)


## ファイル全体がプレイ可能か（ルート + マージ後 config）
static func validate_for_play(raw: Dictionary) -> String:
	var e0: String = validate_root(raw)
	if e0 != "":
		return e0
	var cfg: Dictionary = effective_config(raw)
	return validate_runtime_config(cfg)


## 保存用ペイロードを組み立て（meta / config / shape）
static func build_payload(
	partial_config: Dictionary,
	shape: Dictionary = {},
	meta: Dictionary = {}
) -> Dictionary:
	var payload: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"kind": KIND,
		"config": partial_config.duplicate(true),
	}
	if not meta.is_empty():
		payload["meta"] = meta.duplicate(true)
	if not shape.is_empty():
		payload["shape"] = shape.duplicate(true)
	return payload


## res 同梱のサンプルから shape のみ取得（Edit v1: fish 雛形）
static func load_sample_fish_shape_from_res() -> Dictionary:
	var path: String = "res://samples/custom_stage.example.json"
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var sh: Variant = (parsed as Dictionary).get("shape", {})
	if typeof(sh) == TYPE_DICTIONARY:
		return (sh as Dictionary).duplicate(true)
	return {}


static func to_json_string(payload: Dictionary, indent: String = "\t") -> String:
	return JSON.stringify(payload, indent)


static func save_to_path(path: String, payload: Dictionary) -> String:
	var err: String = validate_root(payload)
	if err != "":
		return err
	var cfg: Dictionary = effective_config(payload)
	err = validate_runtime_config(cfg)
	if err != "":
		return "config がプレイ用として不正: %s" % err
	ensure_custom_stage_dir()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "保存に失敗しました: %s" % path
	f.store_string(to_json_string(payload))
	_sync_type_save_failed.erase(path)
	return ""
