# KATADRAW セーブ・進行管理仕様

**対象ファイル**: `scripts/StageSelectManager.gd`

---

## セーブファイル

| 項目 | 値 |
|------|-----|
| パス | `user://stage_select_state.json` |
| フォーマット | JSON |
| 保存タイミング | ステージクリア時・BGM解放時・フラグ変更時（都度保存） |

---

## セーブデータ構造

```json
{
  "0": 2,           // ステージ0の状態（0=LOCKED, 1=UNLOCKED, 2=CLEARED）
  "1": 2,           // ...
  "49": 1,
  "tutorial_shown": true,
  "all_cleared": false,
  "zou_cleared": false,
  "best_times": {
    "0": 12.345,    // ベストタイム（秒・float）
    "1": 9.87
  },
  "best_moves": {
    "0": 3,         // ベストムーブ数（整数）
    "1": 5
  },
  "unlocked_bgms": ["01-06", "01-08"],  // 解放済みBGM IDの配列
  "last_played_stage_id": 3             // 最後にプレイしたステージID
}
```

---

## ステージ状態

| 値 | 定数 | 意味 |
|-----|------|------|
| 0 | `LOCKED` | 解放前（ドット非表示） |
| 1 | `UNLOCKED` | 解放済み・未クリア（赤ドット） |
| 2 | `CLEARED` | クリア済み（薄赤ドット・内側白丸） |

初期状態：ステージ 0 のみ `UNLOCKED`、他は全て `LOCKED`。

---

## ステージ解放ロジック

`mark_cleared(stage_id)` 呼び出し時：

1. `_states[stage_id] = CLEARED`
2. 解放対象を決定：
   - ステージ 0〜3 は一本道ゾーン（`_LINEAR_ZONE = {0:[1], 1:[2], 2:[3]}`）
   - それ以外は `manifest.json` の `connections` リスト
3. 対象ステージが `LOCKED` なら `UNLOCKED` に更新し `last_unlocked_ids` に記録
4. 全ステージ CLEARED なら `all_cleared = true` にして保存

---

## 進行フラグ

| フラグ | 型 | 保存 | 説明 |
|--------|-----|------|------|
| `tutorial_shown` | bool | ◎ | チュートリアル表示済みかどうか |
| `all_cleared` | bool | ◎ | 通常ステージ（0〜49）全クリア済み |
| `zou_cleared` | bool | ◎ | Zou ステージクリア済み |
| `last_played_stage_id` | int | ◎ | 直前プレイしたステージID（カメラ復帰用） |
| `last_unlocked_ids` | Array[int] | ✕ | クリア直後に新解放されたステージID一時保持 |
| `pending_stage_id` | int | ✕ | ゲームシーンに渡す次のステージID |
| `tutorial_return_to` | String | ✕ | チュートリアル完了後の戻り先（セッションのみ） |

---

## BGM 解放管理

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `_unlocked_bgms` | Array[String] | 解放済み BGM ID（例：`["01-06"]`） |

`check_bgm_unlocks()` を呼ぶと、`_bgm_zones` の各ゾーンを確認し、未解放かつ全必要ステージが CLEARED のゾーンを新規解放として返す。解放があれば保存も行う。

---

## ベスト記録

| 関数 | 動作 |
|------|------|
| `update_best(stage_id, time, moves)` | タイム・ムーブ数の双方向ベスト比較・更新。更新があれば保存。`{time: bool, moves: bool}` を返す |
| `get_best_time(stage_id)` | ベストタイム（未記録なら -1.0） |
| `get_best_move_count(stage_id)` | ベストムーブ数（未記録なら -1） |

---

## リセット

`reset_all()` を呼ぶと：

- 全ステージ → `LOCKED`（ステージ 0 のみ `UNLOCKED`）
- `tutorial_shown = false`
- `all_cleared = false`
- `zou_cleared = false`
- `_best_times`, `_best_move_counts` クリア
- `_unlocked_bgms` クリア
- `last_played_stage_id = -1`
- `_save_states()` 実行

---

## マニフェスト読み込み

`_MANIFEST_PATH = "res://data/stage_select_manifest.json"` から読み込む。

読み込む情報：

| フィールド | 内容 |
|-----------|------|
| `stages[].id` | ステージID |
| `stages[].grid_pos` | グリッド座標 `[col, row]` |
| `stages[].y_offset` | 個別垂直オフセット |
| `stages[].connections` | 隣接ステージID配列 |
| `bgm_unlock_zones` | BGM解禁ゾーン定義配列 |

`data/manifest.json` と `data/stage_select_manifest.json` は同一内容。
