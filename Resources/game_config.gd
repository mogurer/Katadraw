# =============================================================================
# GameConfig - ゲーム設定
# =============================================================================
# 体験版/製品版の切り替え、ヒントタイミング、その他定数を集約する。

class_name GameConfig

# --- ブランドカラー ---
## ゲーム内の「インク色」（濃い紫）の正規定数。頂点・辺・自キャラ・UI 枠など全域で参照する。
const INK_COLOR := Color("#433647")

# --- 体験版 ---
# true: 体験版（manifest_ex.json の10ステージをループなしで固定順プレイ）
const IS_TRIAL := false

## 体験版の実績API名（体験版内のプレイ順=何番目にクリアしたかに対応。要Steamworks側に事前登録）
## 添字は game.gd の _trial_idx（0始まり）にそのまま対応する。
const TRIAL_STAGE_ACHIEVEMENTS: Array[String] = [
	"ACVT_STGCLR_01", "ACVT_STGCLR_02", "ACVT_STGCLR_03", "ACVT_STGCLR_04", "ACVT_STGCLR_05",
	"ACVT_STGCLR_06", "ACVT_STGCLR_07", "ACVT_STGCLR_08", "ACVT_STGCLR_09", "ACVT_STGCLR_10",
]
## 体験版限定の隠し実績（A+X同時押し / マウス左右同時押しでのネコアニメーション発火）
const TRIAL_SECRET_CAT_ACHIEVEMENT := "ACVT_MESEEDCAT"

## 本編を「1 面だけ」繰り返しプレイするときのマスタ行インデックス（manifest / StageData.get_stages() の 0 始まり）。
## -1 で無効（通常は全ステージを順にプレイ）。例: 星 10 点のみ試すなら 3（star_10.json の並び）
## 有効時は get_play_stage_rows() が stage_index を 0 に固定するため、進行スロットだけでは HUD 基準点（Y オフセット）が本番と一致しない。
## game.gd の hud_layout_slot が、単面本番試行中だけこの値をレイアウト用スロットに使う（F2 ステージデバッグ起動時は行インデックスのまま）。
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
	return mini(50, rows.size() - 1)


static func get_stage_count() -> int:
	return get_max_stage_index() + 1


static func get_trial_stage_ids() -> Array[int]:
	var f := FileAccess.open("res://data/manifest_ex.json", FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return []
	var raw: Array = data.get("trial_stages", [])
	var result: Array[int] = []
	for v in raw:
		result.append(int(v))
	return result

# --- レイアウト ---
# 左側UIパネルの幅（画面幅に対する比率 0.0〜1.0）。0=パネルなし
const UI_WIDTH_RATIO := 0.0
## プレイ中 HUD ガイドと start_stage のレイアウトで共通の基準点。play_stage_slot が 0 のときだけ ui_renderer._draw_game と同様に Y を 100px 下げる。
static func hud_playfield_shape_center(vp: Vector2, play_stage_slot: int) -> Vector2:
	var sc := Vector2(
		vp.x * UI_WIDTH_RATIO + (vp.x - vp.x * UI_WIDTH_RATIO) * 0.5,
		vp.y * 0.5
	)
	if play_stage_slot == 0:
		sc.y += 100.0
	return sc


# Playing guide: margin on each side of playfield; shape fits in inner (1-2*M) box, centered.
const HUD_GUIDE_MARGIN_FRAC := 0.15
# Guide drawn as fixed HUD; scoring uses the same on-screen outline (world px).
const USE_SCREEN_HUD_GUIDE := true
## HUD ガイドの幾何重心を基準にした KATA 初期円の半径にかける倍率（ガイドと即一致しないよう大きめ）
const HUD_INITIAL_RING_SCALE_MUL := 1.48
## 三角形・星など「円形デフォルト配置」以外: 楕円周上の縦半軸 = 横方向の基準半径 × この値（1 未満で横長のなめらかな楕円）
const HUD_SPAWN_ELLIPSE_VERTICAL_FRAC := 0.58

# --- ヒント ---
const HINT_TIMES := [60.0, 90.0]
const HINT_DURATIONS := [0.1, 0.3]
const HINT_LOOP_START := 120.0
const HINT_LOOP_FADE := 1.0
const HINT_LOOP_HIDE := 3.0

# タイムアタック対象ステージ数（ZOUを除く50ステージ）。StageSelectManager.STAGE_COUNT と同じ値。
const STAGE_COUNT_FOR_TA := 50

# --- ロゴ ---
const LOGO_WAIT1 := 1.0
const LOGO_FADE_IN := 1.0
const LOGO_HOLD := 2.0
const LOGO_FADE_OUT := 1.0
const LOGO_WAIT2 := 1.0
const LOGO_TOTAL := 7.0
const TITLE_FADE_IN := 0.5

# --- Twitter / X 共有（結果画面アイコン）---
## 編集用テキスト（UTF-8）。ビルドに同梱される。
const TWITTER_SHARE_TEXT_PATH := "res://Resources/Text/Twitter.txt"
## ファイル未同梱・読み取り失敗時に使う既定文（Twitter.txt と揃えること）
const TWITTER_SHARE_TEXT_DEFAULT := "#KATADRAW"
const TWITTER_INTENT_URL := "https://twitter.com/intent/tweet"

# --- SE音量 ---
## SE音量レベル（0〜10）から dB オフセットを返す共通ヘルパー。
## 各 AudioStreamPlayer の volume_db = 基準dB + se_volume_offset_db(level) で統一する。
## 0=ミュート(-80dB)、1〜10: -20dB〜+15dB（5で0dB）
static func se_volume_offset_db(level: int) -> float:
	if level <= 0:
		return -80.0
	return (level - 5) * 3.0
