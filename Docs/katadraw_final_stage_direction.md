# KATADRAW 最終ステージ演出 実装指示

## 概要

全50ステージクリア時に発動する「最終ステージ演出」を実装する。  
演出はステージセレクト画面上で行われ、完了後にステージ「zou」が開始される。  
**既存の動作を壊さないよう、追加・変更は最小限にとどめること。**

---

## タスク1: 全クリア判定フラグの追加（StageSelectManager.gd）

`tutorial_shown` と同じパターンで `all_cleared: bool` を追加する。

```gdscript
# 変数宣言
var all_cleared: bool = false

# _save_states() に追加
data["all_cleared"] = all_cleared

# _load_states() に追加
all_cleared = bool(d.get("all_cleared", false))

# reset_all() に追加
all_cleared = false
```

全クリア判定関数を追加する：

```gdscript
func is_all_cleared() -> bool:
    return _states.all(func(s): return s == STATE_CLEARED)
```

`mark_cleared(id)` の末尾に以下を追加する：

```gdscript
if not all_cleared and is_all_cleared():
    all_cleared = true
    _save_states()
```

---

## タスク2: zouステージの起動条件変更（StageSelectManager.gd）

- 現在 `_is_debug()` 限定になっている `_zou_stage_idx` の設定を、`all_cleared == true` のときに有効化するよう変更する
- デバッグ用のステージセレクト左上●は削除する

---

## タスク3: 最終ステージ演出（stage_select.gd）

### トリガー条件

ステージセレクト画面の `_ready()` または遷移復帰処理の末尾で以下を判定する：

- `StageSelectManager.all_cleared == true`
- かつセッション中フラグ `_final_direction_played: bool = false`

条件を満たす場合、`_play_final_direction()` を呼び出す。  
`_final_direction_played` は演出開始時に `true` にセットし、セーブはしない（セッション中のみ有効）。

### 演出フロー

#### Prologue: 背景暗転（3秒）

- `ColorRect`（全画面・黒・初期alpha=0）を `CanvasLayer` 上に生成し `add_child()` する
- `Tween` で alpha を `0.0 → 0.7` に3秒かけてフェードイン（`TRANS_SINE` / `EASE_IN_OUT`）
- 暗転と同時に、現在再生中のBGMを3秒かけて音量フェードダウンし、音量ゼロになったら再生停止する
- 暗転中はステージ●への入力を無効化する
- 暗転完了後、Phase 1へ進む（以降Phase 2終了までBGMなし）

#### Phase 1: スパーク伝播＋カメラ追従（約5秒）

**ポイント座標の収集**

各ステージ●の座標（ワールド座標）を `Array[Vector2]` として収集する。  
座標計算式は既存の生成ロジックと同じ：

```
X = col × 200.0 × 1.7320508
Y = row × 200.0 + y_offset
```

**輪の接続順の確定**

`game.gd` の `rebuild_polygon_walk_order_centroid_angular()` および `polygon_walk_order` は `stage_select.gd` から直接参照できない。  
**この問題の解決方法（関数の移動・共通化・複製等）はClaude Codeが判断して提案・実装してよい。**

確定した `polygon_walk_order` をもとに、`last_played_stage_id` に対応するポイントを起点として時計回り方向を特定する。

**スパーク伝播ループ**

1エッジあたり `0.1秒` で以下を繰り返す（全50エッジ、合計約5秒）：

- 現在のエッジ（起点→終点）を `draw_line()` で白色描画（既存の `_draw()` に組み込むか、`queue_redraw()` を呼ぶ）
- 起点側に半径8pxの白い円をフラッシュ（0.1秒でalpha 1.0→0.0にフェード）
- カメラを次のポイント座標へ移動（`Tween` で0.1秒 `TRANS_QUAD` / `EASE_OUT`）

**残り10エッジでズームアウト開始**

40エッジ完了時点（残り10エッジ）から、カメラの追従と並行してズームアウトを開始する：

- zoom目標値: `Vector2(0.5, 0.5)`
- position目標値: 全ステージ●座標のAABB中心
- 所要時間: 残り10エッジ分 = 1.0秒
- `Tween` で `TRANS_CUBIC` / `EASE_IN_OUT`
- ズームアウト中、各ステージ●の描画半径をzoomの逆数で補正し、画面上のサイズを維持する：  
  `display_radius = _DOT_RADIUS / camera.zoom.x`

全50エッジの描画完了と同時に全体像が見えた状態になる。

#### Phase 2: ウェイト（3秒）

```gdscript
await get_tree().create_timer(3.0).timeout
```

#### Phase 3: ステージ開始画面

通常のステージ開始フローと同様に zou のタイトルを表示し、「TAP TO START」を表示して入力待ちにする。  
入力後、通常のインゲームと同様にカウントダウンを開始する。  
カウントダウン完了・ゲーム開始のタイミングで、タイトル画面と同じ方式でBGM「Title」を再生開始する。  
その後、以下でzouを開始する：

```gdscript
StageSelectManager.pending_stage_id = StageSelectManager._zou_stage_idx
play_triangle()  # 通常ステージと同一フロー
```

> **注意**: BGM「Title」の再生方式はタイトル画面（`title.gd` 等）での実装を参照し、同じ形式で呼び出すこと。効果音は現時点では追加しない。

---

## タスク4: zouクリア後の挙動（game.gd）

`_return_to_stage_select_preserve_bgm()` の先頭に以下を追加する：

```gdscript
if StageSelectManager.last_played_stage_id == StageSelectManager._zou_stage_idx:
    get_tree().change_scene_to_file("res://scenes/title.tscn")
    return
```

---

## 注意事項

- `_draw()` を使っている既存の描画ループを壊さないこと
- 演出中（Prologue〜Phase 2）はステージ●への入力を無効化すること
- 演出中は既存のBGMをそのまま継続すること（BGM変更しない）
- 暗転用 `ColorRect` は演出完了後（zou開始前）に破棄すること
