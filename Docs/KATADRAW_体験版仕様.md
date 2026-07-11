# KATADRAW 体験版仕様

> 最終更新: 2026-07-05

---

## 1. 概要

体験版は製品版とは別の動作モードであり、単一のフラグで切り替える。
ステージセレクト画面を持たず、設計者が選んだ10ステージを固定順でプレイする形式。

```gdscript
# Resources/game_config.gd
const IS_TRIAL := false   # true = 体験版
```

**廃止するフラグ（実装時に削除する）:**
- `EXPERIENCE_VERSION` — 旧・ステージ本数制限フラグ
- `IS_DEMO` — 旧・デモ版ループフラグ

---

## 2. ゲームフロー

```
ロゴ → タイトル → START
  → チュートリアル（毎回表示）← _trial_stage_ids[0] のステージを開始
  → 体験版ステージ 1/10
  → クリア → クリアカード（タイム・手数）
  → 閉じる → 体験版ステージ 2/10
  → ...
  → 体験版ステージ 10/10
  → クリア → クリアカード（タイム・手数）
  → game_state = "results"（全10ステージ結果 + Twitter/X 共有ボタン）← 体験版専用パスで遷移
  → タイトルへ戻る
```

- ステージ1〜9クリア後：クリアカードを閉じると即・次の体験版ステージへ進む
- ステージ10クリア後：クリアカードの後に `results` 画面へ遷移し、Twitter共有 → タイトルへ
- 1〜9と10のクリアカード自体の見た目は同一
- `results` 画面（全ステージ結果 + Twitter共有）は現状**体験版フローでしか使用されない**

---

## 3. ステージリスト管理

### 3-1. manifest_ex.json

体験版で使用するステージを `data/manifest_ex.json` に定義する。
配列の順番がプレイ順になる。

```json
{
  "trial_stages": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
}
```

ステージの選定・並び順の変更はこのファイルのみ編集すれば済む。
stage_id は `data/manifest.json`（StageData）に存在するものを指定する必要がある。

### 3-2. game_config.gd での読み込み

`GameConfig` がこのファイルを読み込み、配列として返す関数を持つ。

```gdscript
# 追加する関数（案）
static func get_trial_stage_ids() -> Array[int]:
    var f := FileAccess.open("res://data/manifest_ex.json", FileAccess.READ)
    if f == null:
        return []
    var data: Dictionary = JSON.parse_string(f.get_as_text())
    return Array(data.get("trial_stages", []), TYPE_INT, "", null)
```

### 3-3. ゲーム側での進行管理

`game.gd` 内に体験版専用の進行インデックスを持つ。

```gdscript
var _trial_stage_ids: Array[int] = []   # manifest_ex.json から読んだリスト
var _trial_idx: int = 0                 # 現在何番目か（0〜9）
```

`IS_TRIAL=true` で起動時に `GameConfig.get_trial_stage_ids()` を呼んで初期化し、
`_advance_stage()` では `_trial_idx` をインクリメントして次のstage_idを取り出す。

**`_trial_idx` のリセットタイミング：`_start_game()` の先頭で必ず 0 にリセットする。**
これにより、ポーズ中断・完走後・再プレイのすべてのケースを一元的にカバーする。

---

## 4. 各システムの挙動

### 4-1. タイトルからの起動

IS_TRIAL=true の場合、ロゴ → タイトル → START のフローは製品版と同じ。
`StageSelectManager.pending_stage_id` は使用しない。

### 4-2. チュートリアル

毎回表示する（`tutorial_shown` フラグを書き込まない・`_save_states()` を呼ばない）。
チュートリアル完了後（`_rules_proceed()`）は **`_start_stage(_trial_stage_ids[0])`** を呼ぶ。
`_start_stage(0)` 固定ではなく、必ずリストの先頭を参照する。

### 4-3. クリア保存

`mark_cleared()` / `update_best()` を呼ばない。
クリア情報はセッション内のみ保持され、終了時に消える。
`user://stage_select_state.json` への書き込みは一切行わない。

### 4-4. ステージ進行（`_advance_stage()`）

IS_TRIAL=true のとき：

```
_trial_idx < 9（ステージ1〜9のクリア後）
  → _trial_idx += 1
  → _start_stage(_trial_stage_ids[_trial_idx])

_trial_idx == 9（ステージ10のクリア後）
  → game_state = "results"（全10ステージ結果画面）
```

この分岐は `_advance_stage()` 内の IS_TRIAL ブロックとして新規実装する。

### 4-5. BGM

| 場面 | BGM |
|------|-----|
| ステージセレクト | なし（画面が存在しない） |
| インゲーム | 「01-05」固定（全10ステージ共通） |
| クリア演出 | 製品版と同じ clear BGM |

BGM 解禁ゾーン・BGM 選択 UI は体験版では使用しない。

### 4-6. ポーズ「ステージをやめる」

「タイトルへ戻りますか？」確認ポップアップを表示する（製品版のポーズ確認ダイアログを流用）。
「はい」→ タイトルへ戻る（`_trial_idx` は次回 `_start_game()` 先頭でリセットされる）。

### 4-7. guide_info 中の ESC / Start ボタン

「タイトルへ戻りますか？」確認ポップアップを表示する。
既存の `pause_confirm_title` 機構を流用して実現する。

### 4-8. ステージセレクト

表示しない。体験版のフロー上でステージセレクト画面には遷移しない。

### 4-9. Zou ステージ処理

体験版ステージリストに Zou は含まれない前提のため、Zou 分岐コードは体験版では到達しない。

---

## 5. 実装時に変更が必要なファイルと内容

| ファイル | 変更内容 |
|---------|---------|
| `Resources/game_config.gd` | `EXPERIENCE_VERSION` / `IS_DEMO` を削除、`IS_TRIAL` 追加、`get_trial_stage_ids()` 追加 |
| `scripts/game.gd` | IS_DEMO 参照（9箇所）を IS_TRIAL に置き換え・削除。`_trial_stage_ids` / `_trial_idx` 追加。`_start_game()` / `_advance_stage()` / `_rules_proceed()` の体験版分岐を実装 |
| `data/manifest_ex.json` | 新規作成（体験版ステージリスト） |

StageSelectManager・stage_select.gd・BGMManager は**変更不要**。
体験版フローからこれらへの参照が発生しないため。

---

## 6. 未決定・追って確認する事項

### 6-1. 「体験版」であることの UI 表示

タイトル画面や画面隅への「体験版」表示については追って検討する。
現仕様ではプレイヤーが体験版であることを認識できるUIは存在しない。

### 6-2. 体験版ビルドの手順

実装完了後：
1. `Resources/game_config.gd` の `IS_TRIAL := false` を `true` に変更
2. `data/manifest_ex.json` の `trial_stages` を確認
3. エクスポートする
