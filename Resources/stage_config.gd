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
	},
	"two_circles": {
		"num_points": 24,
		"group_sizes": [12, 12],
		"min_radius": 120.0,
		"max_radius": 240.0,
		"vertex_range": [4, 6],
		"variance": 0.50,
		"zigzag": 0.30,
		"clear_pct": 96.0,
		"display_rate_min_pct": 50.0,
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
	},
	"cat_face": {
		"num_points": 18,
		"min_radius": 160.0,
		"max_radius": 280.0,
		"variance": 0.15,
		"clear_pct": 95.0,
		"display_rate_min_pct": 50.0,
	},
	"fish": {
		"num_points": 16,
		"min_radius": 160.0,
		"max_radius": 280.0,
		"variance": 0.15,
		"clear_pct": 95.0,
		"display_rate_min_pct": 75.0,
	},
}


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
