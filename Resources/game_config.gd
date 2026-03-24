# =============================================================================
# GameConfig - ゲーム設定
# =============================================================================
# 体験版/製品版の切り替え、ヒントタイミング、その他定数を集約する。

class_name GameConfig

# --- 体験版 / 製品版 ---
# true: 体験版（3ステージ）、false: 製品版（全ステージ）
const EXPERIENCE_VERSION := false

static func get_max_stage_index() -> int:
	var stages: Array = StageData.get_stages()
	if EXPERIENCE_VERSION:
		return mini(2, stages.size() - 1)  # 0,1,2 = 3ステージ
	return stages.size() - 1

static func get_stage_count() -> int:
	return get_max_stage_index() + 1

# --- レイアウト ---
# 左側UIパネルの幅（画面幅に対する比率 0.0〜1.0）。0=パネルなし
const UI_WIDTH_RATIO := 0.0

# --- ヒント ---
const HINT_TIMES := [60.0, 90.0]
const HINT_DURATIONS := [0.1, 0.3]
const HINT_LOOP_START := 120.0
const HINT_LOOP_FADE := 1.0
const HINT_LOOP_HIDE := 3.0

# --- ロゴ ---
const LOGO_WAIT1 := 1.0
const LOGO_FADE_IN := 1.0
const LOGO_HOLD := 2.0
const LOGO_FADE_OUT := 1.0
const LOGO_WAIT2 := 1.0
const LOGO_TOTAL := 7.0
const TITLE_FADE_IN := 0.5
