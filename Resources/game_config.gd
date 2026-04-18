# =============================================================================
# GameConfig - ゲーム設定
# =============================================================================
# 体験版/製品版の切り替え、ヒントタイミング、その他定数を集約する。

class_name GameConfig

# --- 体験版 / 製品版 ---
# true: 体験版（3ステージ）、false: 製品版（全ステージ）
const EXPERIENCE_VERSION := false

## 本編を「1 面だけ」繰り返しプレイするときのマスタ行インデックス（manifest / StageData.get_stages() の 0 始まり）。
## -1 で無効（通常は全ステージを順にプレイ）。例: 星 10 点のみ試すなら 3（star_10.json の並び）
const DEBUG_PLAY_SINGLE_MASTER_INDEX := -1


static func get_play_stage_rows() -> Array:
	var all: Array = StageData.get_stages()
	var lock_i: int = DEBUG_PLAY_SINGLE_MASTER_INDEX
	if lock_i < 0 or lock_i >= all.size():
		return all
	var one: Dictionary = (all[lock_i] as Dictionary).duplicate(true)
	one["stage_index"] = 0
	return [one]


## 本編の進行スロット（0〜）から、マスタ JSON 行インデックスを得る（単一面モードでは常に DEBUG_PLAY_SINGLE_MASTER_INDEX）
static func resolve_play_stage_to_master_index(play_slot_index: int) -> int:
	var lock_i: int = DEBUG_PLAY_SINGLE_MASTER_INDEX
	if lock_i >= 0:
		return lock_i
	return play_slot_index


static func get_max_stage_index() -> int:
	var rows: Array = get_play_stage_rows()
	if rows.is_empty():
		return -1
	if EXPERIENCE_VERSION:
		return mini(2, rows.size() - 1)
	return rows.size() - 1


static func get_stage_count() -> int:
	return get_max_stage_index() + 1

# --- レイアウト ---
# 左側UIパネルの幅（画面幅に対する比率 0.0〜1.0）。0=パネルなし
const UI_WIDTH_RATIO := 0.0
# Playing guide: margin on each side of playfield; shape fits in inner (1-2*M) box, centered.
const HUD_GUIDE_MARGIN_FRAC := 0.15
# Guide drawn as fixed HUD; scoring uses the same on-screen outline (world px).
const USE_SCREEN_HUD_GUIDE := true
## HUD ガイドの幾何重心を基準にした KATA 初期円の半径にかける倍率（ガイドと即一致しないよう大きめ）
const HUD_INITIAL_RING_SCALE_MUL := 1.48

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
