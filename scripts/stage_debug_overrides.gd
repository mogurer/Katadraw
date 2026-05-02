# =============================================================================
# StageDebugOverrides - ステージ設定の検証とマスター行からのビルド
# =============================================================================
# マスターは StageData.get_stages()（builtin JSON をマージ済み）。セッション内の pending のみ差分適用。
# user:// の恒久的オーバーライドは廃止（builtin と二重管理で混乱するため）。

class_name StageDebugOverrides
extends RefCounted


static func build_config_for_index(idx: int, pending: Dictionary = {}) -> Dictionary:
	var master: Array = StageData.get_stages()
	if idx < 0 or idx >= master.size():
		push_error("StageDebugOverrides: 無効なステージ index %d" % idx)
		return {}
	var base: Dictionary = (master[idx] as Dictionary).duplicate(true)
	for k in pending:
		base[k] = pending[k]
	return StageConfig.build_effective_config(base)


static func validate_effective_config(cfg: Dictionary) -> String:
	if not cfg.has("type"):
		return "type がありません"
	var t: String = str(cfg["type"])
	if not StageConfig.KNOWN_SHAPE_TYPES.has(t):
		return "未知の type: %s" % t
	if not cfg.has("shape_type"):
		return "shape_type がありません"
	var st: String = str(cfg["shape_type"])
	if not StageConfig.KNOWN_SHAPE_TYPES.has(st):
		return "未知の shape_type: %s" % st
	if not cfg.has("stage_id") or str(cfg["stage_id"]).strip_edges() == "":
		return "stage_id がありません"
	if not cfg.has("num_points"):
		return "num_points がありません"
	var np: int = int(cfg["num_points"])
	if np < 1:
		return "num_points は 1 以上にしてください"
	if not cfg.has("min_radius") or not cfg.has("max_radius"):
		return "min_radius / max_radius が必要です"
	var mn: float = float(cfg["min_radius"])
	var mx: float = float(cfg["max_radius"])
	if mn < 0.0 or mx < 0.0:
		return "半径は 0 以上にしてください"
	if mn > mx:
		return "min_radius <= max_radius にしてください"
	if not cfg.has("clear_pct"):
		return "clear_pct がありません"
	var cp: float = float(cfg["clear_pct"])
	if cp <= 0.0 or cp > 100.0:
		return "clear_pct は (0, 100] にしてください"
	if cfg.has("display_rate_min_pct"):
		var dr: float = float(cfg["display_rate_min_pct"])
		if dr < 0.0 or dr > 100.0:
			return "display_rate_min_pct は [0, 100] にしてください"
	if cfg.has("vertex_range"):
		var vr: Variant = cfg["vertex_range"]
		if typeof(vr) != TYPE_ARRAY or (vr as Array).size() < 2:
			return "vertex_range は [int,int] 形式にしてください"
		var a: int = int((vr as Array)[0])
		var b: int = int((vr as Array)[1])
		if a < 1 or b < 1 or a > b:
			return "vertex_range が不正です"
	if cfg.has("guide_follows_player_radius"):
		var gv: Variant = cfg["guide_follows_player_radius"]
		if typeof(gv) == TYPE_BOOL:
			pass
		elif typeof(gv) == TYPE_INT or typeof(gv) == TYPE_FLOAT:
			var gi: int = int(gv)
			if gi != 0 and gi != 1:
				return "guide_follows_player_radius は 0 または 1"
		else:
			return "guide_follows_player_radius は 0 または 1"
	return ""


static func validate_partial_with_master(idx: int, overrides: Dictionary) -> String:
	var merged: Dictionary = build_config_for_index(idx, overrides)
	return validate_effective_config(merged)
