# KATADRAW コンフィグ仕様

**対象ファイル**: `scripts/game.gd`（コンフィグ処理）、`scripts/ui_renderer.gd`（コンフィグ UI 描画）

---

## コンフィグ項目

| 項目 | 変数名 | 型 | 範囲 | デフォルト |
|------|--------|-----|------|-----------|
| BGM 音量 | `bgm_volume` | int | 0〜10 | 5 |
| SE 音量 | `se_volume` | int | 0〜10 | 5 |
| マウスの閉じ込め | `mouse_confine_to_window` | bool | ON / OFF | OFF |

---

## 音量変換

音量スライダー値（0〜10 整数）から dB オフセットへの変換式：

```gdscript
func _volume_offset_db(v: int) -> float
```

- `v = 0` → ミュート（-80 dB）
- `v = 10` → 最大（実装依存の最大 dB）

変換結果は `BGMManager.set_volume_db(offset_db)` / SE AudioBus に反映される。

---

## マウスの閉じ込め（mouse_confine_to_window）

| 値 | 動作 |
|----|------|
| OFF | マウスはウィンドウ外へ移動可能 |
| ON | ウィンドウ非フルスクリーン時、マウスをウィンドウ内に拘束（`Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)`） |

フルスクリーン時は常にウィンドウ内に収まるため、本設定は非フルスクリーン時にのみ効果がある。

---

## コンフィグ画面の操作

| 操作 | 動作 |
|------|------|
| ◀ / ▶ ボタン | 値を変更（音量は 0〜10 でクランプ、閉じ込めは ON/OFF 反転） |
| L/R ボタン（コントローラ） | ◀ / ▶ と同等 |
| ESC / B ボタン | コンフィグを閉じてメニューへ戻る |
| 「チュートリアルを見る」 | ルール画面を開く（`tutorial_return_to = "config"` で戻り先を設定） |

---

## セーブ

コンフィグ設定は現在セッションのみ保持され、**ゲーム終了時にリセットされる**。  
（BGM 音量・SE 音量・マウス閉じ込め設定はセーブファイルに書き込まれない。）

---

## GameConfig クラス（コード定数）

`Resources/game_config.gd` に定義されるビルド時定数。コンフィグ画面からは変更不可。

| 定数 | デフォルト | 説明 |
|------|-----------|------|
| `EXPERIENCE_VERSION` | `false` | 体験版（3ステージ）モード |
| `IS_DEMO` | `false` | デモ版（タイトルから直接ゲーム）モード |
| `DEBUG_PLAY_SINGLE_MASTER_INDEX` | −1 | 単一ステージ繰り返しモード（−1 = 無効） |
| `UI_WIDTH_RATIO` | 0.0 | 左UIパネル幅の比率（0 = パネルなし） |
| `HUD_GUIDE_MARGIN_FRAC` | 0.15 | ガイドのビューポート内マージン比率 |
| `HUD_INITIAL_RING_SCALE_MUL` | 1.48 | KATA初期円のガイドに対するスケール倍率 |
| `HINT_TIMES` | [60.0, 90.0] s | ヒント表示タイミング |
| `LOGO_TOTAL` | 7.0 s | ロゴ演出の総時間 |
