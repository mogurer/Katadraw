# KATADRAW インゲーム仕様

---

## KATAタイプ一覧

| タイプ | guide_type_label | 説明 |
|--------|-----------------|------|
| 円 | circle | 円形のガイドに合わせる |
| 星 | star | 星形のガイドに合わせる |
| 三角形 | triangle | 正三角形に合わせる |
| 四角形 | square | 正方形に合わせる |
| 六角形 | hexagon | 正六角形に合わせる |
| 魚 | fish | 自由曲線で構成された魚形 |
| 猫顔 | cat_face | 弧で構成された猫の顔形 |
| ラグビーボール | rugby_ball | 楕円系の特殊形 |

`fish`・`cat_face` は対応点ベースではなく輪郭ベースの判定を行う特殊タイプ。

---

## ステージ内状態遷移

```
guide_info
  │  ガイド名のタイプライター演出
  │  [任意入力 or タイプライター完了後の入力] → スキップ可
  ↓
guide_countdown
  │  3秒カウントダウン（BGM音量 -3dB 低下）
  │  カウントダウン完了で自動遷移
  ↓
playing
  │  KATA描画・一致率リアルタイム計算
  │  一致率 ≥ (100 - clear_threshold)% → 自動クリア
  ↓
cleared
  │  クリア演出（パーティクル・BGMブースト +3dB）
  │  クリアタイム・ムーブ数を確定・保存
  │  [次へ] → 次ステージの guide_info、または results（セッション末尾）
  │  [戻る] → ステージセレクトシーンへ遷移
  ↓
results（セッション末尾時）
     リザルト一覧（各ステージのガイド形状サムネイル表示）
```

---

## ガイド表示（guide_info フェーズ）

- 画面中央にガイド図形名をタイプライター演出で表示
- タイプライター完了後、任意の入力で `guide_countdown` へ遷移
- タイプライター中に入力した場合は即座にテキスト全表示（スキップ）

---

## カウントダウン（guide_countdown フェーズ）

- 3・2・1 の数字を画面中央に1秒ずつ表示
- `BGMManager.begin_countdown()` により BGM 音量を -3dB 低下
- カウントダウン完了時：
  - 通常ステージ：`BGMManager.resume_ingame()` で音量を元に戻す
  - Zou ステージ：`BGMManager.play_title()` でタイトルBGMへ切り替え

---

## プレイ（playing フェーズ）

### ポイント操作

- **つかむ**：ポイント付近でマウスボタン押下 / コントローラ A ボタン
- **動かす**：ドラッグ（マウス or 左スティック）
- **はなす**：ボタンリリース
- マルチ選択：選択矩形をドラッグして複数ポイントをまとめて移動可能

### ムーブカウント

「つかんだあと動かした」操作の回数を記録する（ベスト記録と比較）。  
移動量の累積が `STAGE_MOVE_COUNT_PIXEL_THRESHOLD`（22px）を超えるたびに1カウント加算。

### 一致率計算

| 指標 | 説明 |
|------|------|
| 真円度（circularity） | 頂点群が理想円にどれだけ近いか（circle タイプ） |
| 滑らかさ（smoothness） | 頂点間の角度変化が均一か |
| 再現率（reproduction_rate） | ガイドとの対応点ベース一致率（triangle/square 等） |

表示される「実現率」は `display_rate_min_pct`（デフォルト50%）以下を0%に丸め込み、目標値（`100 - clear_threshold`）を100%として正規化する。

### クリア判定

- `is_snap_clear()` が true になった瞬間に `game_state = "cleared"` へ遷移
- Zou ステージは `is_all_corners_occupied()` でも代替判定（複雑な魚形のため）
- クリア基準値：`clear_threshold` = 5.0（95%以上の一致率）
- ステージごとに `clear_pct` で個別上書き可能

---

## クリア（cleared フェーズ）

| 処理 | 内容 |
|------|------|
| タイムの確定 | `clear_time = 現在時刻 - start_time` |
| ムーブ数の確定 | `_finalize_move_count()` |
| ベスト更新チェック | `StageSelectManager.update_best()` で保存 |
| ステージ状態更新 | `StageSelectManager.mark_cleared(current_stage)` |
| BGM | 通常：`play_clear()`（+3dB ブースト）/ Zou：`stop()` |
| パーティクル | `ui_renderer.spawn_particles(current_centroid)` |
| SE | `sfx_clear` + `sfx_stageclear` |

### クリアカード表示

- クリアタイム・ムーブ数・ベスト記録の更新有無を表示
- 「NEW RECORD」アイコン（タイムまたはムーブ数が自己ベスト更新時）

---

## リザルト（results フェーズ）

- セッション内で連続してプレイした全ステージのサムネイルを一覧表示
- サムネイル：ガイド形状 + プレイヤーKATA輪郭の重ね描き
- 「戻る」でステージセレクトシーンへ遷移

---

## Zou ステージ特殊処理

| タイミング | 処理 |
|-----------|------|
| クリア時 | `BGMManager.stop()`（BGM停止） |
| クリア判定 | `is_all_corners_occupied()` で代替 |
| クリア後 | `StageSelectManager.zou_cleared = true` を保存し `title.tscn` へ遷移 |
| guide_countdown 完了時 | `BGMManager.play_title()` でタイトルBGM再生 |
