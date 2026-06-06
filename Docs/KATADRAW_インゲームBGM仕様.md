# KATA-DRAW インゲーム BGM 仕様

> **作成日**: 2026-05-24  
> **出典**: `scripts/bgm/BGMManager.gd`、`scripts/game.gd`（`Docs/` 内の旧ドキュメントは未参照）  
> **対象**: インゲーム BGM（`TRACKS[0]` / `play_ingame` 系）。タイトル BGM は末尾に参考のみ記載。

---

## 目次

1. [概要](#1-概要)
2. [音源構成](#2-音源構成)
3. [再生エンジン](#3-再生エンジン)
4. [音量](#4-音量)
5. [状態とライフサイクル](#5-状態とライフサイクル)
6. [ゲームフローとの対応](#6-ゲームフローとの対応)
7. [公開 API 一覧](#7-公開-api-一覧)
8. [実装ファイル](#8-実装ファイル)

---

## 1. 概要

インゲーム BGM は **AutoLoad シングルトン `BGMManager`**（`scripts/bgm/BGMManager.gd`）が一元管理する。

- **1 本のイントロ** + **15 本のモチーフ** を順に再生する構成
- `AudioStreamPlayer` を **2 系統** 用意し、曲切り替え時は **1.0 秒のクロスフェード**
- シーン遷移（`game.tscn` ↔ `stage_select.tscn`）後も AutoLoad のため **BGM は途切れない**（`stop()` を呼ばない限り継続）
- ステージのガイド表示・カウントダウン・クリア演出に合わせて **音量と曲構成を段階的に切り替える**

---

## 2. 音源構成

### 2.1 トラック定義

| 項目 | 値 |
|------|-----|
| トラック index | `0`（ingame） |
| イントロ | `res://assets/sounds/01-05/01-05_0000.ogg` |
| モチーフ数 | **15** 本（`_0010` 〜 `_0150`） |
| ループ | 各 Ogg は **`loop = false`**（終端で次曲へ手動遷移） |

### 2.2 モチーフ一覧（再生順）

| index | ファイル |
|-------|----------|
| 0 | `01-05_0010.ogg` |
| 1 | `01-05_0020.ogg` |
| 2 | `01-05_0030.ogg` |
| 3 | `01-05_0040.ogg` |
| 4 | `01-05_0050.ogg` |
| 5 | `01-05_0060.ogg` |
| 6 | `01-05_0070.ogg` |
| 7 | `01-05_0080.ogg` |
| 8 | `01-05_0090.ogg` |
| 9 | `01-05_0100.ogg` |
| 10 | `01-05_0110.ogg` |
| 11 | `01-05_0120.ogg` |
| 12 | `01-05_0130.ogg` |
| 13 | `01-05_0140.ogg` |
| 14 | `01-05_0150.ogg` |

### 2.3 基本再生サイクル

```
_0000（イントロ）
  → _0010 → _0020 → … → _0150
  → _0010 → …（モチーフは (_motif_idx + 1) % 15 で循環）
```

イントロ `_0000` は **ループしない**。ステージ間の「待機用」としても使われる（後述）。

---

## 3. 再生エンジン

### 3.1 デュアルプレイヤー

- `AudioStreamPlayer` × 2 を子ノードとして保持
- クロスフェード中は `_process` で毎フレーム音量を更新
  - フェードイン側: `sin(t * π/2)` に基づく dB カーブ
  - フェードアウト側: `cos(t * π/2)` に基づく dB カーブ
- フェード完了後、旧プレイヤーを `stop()`

### 3.2 曲終了時の自動遷移（`_on_player_finished`）

| 現在の状態 | 終了した曲 | 次の動作 |
|------------|------------|----------|
| イントロ中（通常） | `_0000` | モチーフ 0（`_0010`）へ |
| イントロ中 + `_waiting_for_resume` | `_0000` | イントロ先頭から再再生（待機継続） |
| モチーフ中（通常） | モチーフ N | モチーフ N+1（15 で 0 に戻る） |
| プリカウントダウン中 | モチーフ N | **N+1 をスキップ**し `_0000` へ（`_waiting_for_resume = true`） |

### 3.3 仮想タイムライン

イントロ再生中（`_in_intro == true`）は `_virtual_pos` / `_virtual_elapsed` を進め、モチーフ長を超えたら `_virtual_pos` を 0 にリセットする（内部タイミング管理用）。

---

## 4. 音量

### 4.1 基準値（BGMManager 内）

| 定数 | 値 | 説明 |
|------|-----|------|
| `_BASE_VOLUME_DB` | **-8.5 dB** | インゲーム基準音量 |
| `_FADE_DURATION` | **1.0 秒** | クロスフェード時間 |
| `_CLEAR_VOLUME_BOOST_DB` | **+3.0 dB** | クリア演出時のブースト |
| `_COUNTDOWN_VOLUME_REDUCE_DB` | **-3.0 dB** | カウントダウン中の低下 |

### 4.2 実効音量の計算（`_base_db()`）

```
実効 dB = _BASE_VOLUME_DB
        + _volume_offset_db   （コンフィグ由来）
        + クリアブースト      （+3 dB または 0）
        + カウントダウン低下  （-3 dB または 0）
```

ミュート時（`set_mute(true)` またはコンフィグ 0）は **-80 dB**。

### 4.3 コンフィグ連携（`game.gd`）

| 項目 | 値 |
|------|-----|
| `bgm_volume` | 0〜10、デフォルト **5** |
| 0 | ミュート（-80 dB オフセット） |
| 5 | オフセット **0 dB**（基準） |
| 1〜10 | `(level - 5) * 3.0` dB（1=-12dB、10=+15dB） |
| 反映 | `_apply_bgm_volume()` → `BGMManager.set_volume_db()` |
| 開発用ミュート | `BGM_TEMPORARILY_SILENT`（現行 **false**） |

※ SE 音量とは独立。SE 基準は -14.5 dB（別管理）。

---

## 5. 状態とライフサイクル

### 5.1 内部フラグ

| フラグ | 意味 |
|--------|------|
| `_track_idx` | 0 = ingame |
| `_motif_idx` | 現在のモチーフ index（0〜14） |
| `_in_intro` | イントロ `_0000` 再生中 |
| `_waiting_for_resume` | カウントダウン終了待ちでイントロをループ |
| `_in_pre_countdown` | クリア後〜カウントダウン開始前のプリカウントダウン |
| `_pre_countdown_motif_idx` | プリカウントダウン突入時のモチーフ index（復帰用） |
| `_countdown_active` | `guide_countdown` 中（音量 -3 dB） |
| `_first_stage_pending` | 初回ステージ前の無音待機（デモ／チュートリアル後） |
| `_clear_boost_active` | クリア演出の音量ブースト |

### 5.2 ステージ単位の BGM フェーズ

```
[ステージ開始]
  begin_pre_countdown()     … ガイド表示（guide_info）前
       │
       ├─ モチーフ残り < 1秒 → _0000 へクロスフェード
       └─ それ以外 → モチーフ継続（プリカウントダウン状態）

[ガイド確定]
  begin_countdown()         … guide_info → guide_countdown
       │
       └─ 音量 -3 dB（_countdown_active）

[カウントダウン終了]
  resume_ingame()           … guide_countdown → playing
       │
       ├─ 初回無音待機中 → 1秒後に play_ingame()（_0000 から）
       ├─ プリカウントダウン + イントロ中 → 保存モチーフへクロスフェード
       └─ 1秒後にカウントダウン音量低下を解除

[クリア]
  play_clear()              … +3 dB（イントロ中は無効）

[ステージセレクトへ]
  resume_stage_select()     … ブースト/プリカウントダウン/カウントダウン旗を解除、再生継続
```

---

## 6. ゲームフローとの対応

### 6.1 製品版（`IS_DEMO = false`）

| タイミング | 呼び出し | BGM の動き |
|------------|----------|------------|
| 2 回目以降「ゲーム開始」 | `play_ingame()` | `_0000` から開始 → ステージセレクトへ遷移（BGM 継続） |
| ステージセレクトでステージ選択 | （変更なし） | ステージセレクト中もインゲーム BGM が流れ続ける |
| ステージ開始（`_start_stage`） | `begin_pre_countdown()` | プリカウントダウン状態へ |
| ガイド確定 | `begin_countdown()` | 音量 -3 dB |
| カウントダウン終了 | `resume_ingame()` | モチーフ復帰、音量正常化（1 秒後） |
| ステージクリア | `play_clear()` | +3 dB |
| クリア後「次へ」 | `resume_stage_select()` | 演出音量解除、ステージセレクトへ（**再生継続**） |
| ポーズ「やめる」／ガイドキャンセル | `resume_stage_select()` | 同上（**再生継続**） |

### 6.2 初回チュートリアル → ステージ 0

| タイミング | 呼び出し | BGM の動き |
|------------|----------|------------|
| チュートリアル完了（`_rules_proceed`） | `start_first_stage()` | **全停止・無音**（`_first_stage_pending`） |
| ガイド〜カウントダウン | `begin_pre_countdown()` / `begin_countdown()` | 無音のまま（`first_stage_pending` ガード） |
| カウントダウン終了 | `resume_ingame()` | **1 秒後**に `play_ingame()` → `_0000` から開始 |

### 6.3 デモ版（`IS_DEMO = true`）

| タイミング | 呼び出し | BGM の動き |
|------------|----------|------------|
| メニュー「ゲーム開始」 | `start_first_stage()` | 初回と同様、無音待機 |
| 連続クリアで次ステージ | `begin_pre_countdown()` | 通常のプリカウントダウン |

### 6.4 インゲーム BGM が止まる主なケース

`BGMManager.stop()` が呼ばれると **全停止・状態リセット**。

| 状況 | 呼び出し元 |
|------|------------|
| タイトルへ戻る（メニュー、デモのポーズやめる等） | `game.gd` |
| ステージセレクトで「タイトルへ戻る」確定 | `stage_select.gd` |
| デバッグ画面（F2、リザルトプレビュー等） | `game.gd` |
| リザルト「次へ」（デバッグ経路等） | `game.gd` |

---

## 7. 公開 API 一覧

インゲーム BGM に関係する `BGMManager` のメソッド。

| メソッド | 用途 |
|----------|------|
| `play_ingame()` | インゲーム BGM を `_0000` から新規開始（既存を全停止） |
| `start_first_stage()` | 無音待機モード（初回ステージ前） |
| `begin_pre_countdown()` | ステージ開始前のプリカウントダウン |
| `begin_countdown()` | カウントダウン開始（音量 -3 dB） |
| `resume_ingame()` | カウントダウン終了後の復帰 |
| `play_clear()` | クリア演出（+3 dB） |
| `resume_stage_select()` | ステージセレクト戻り（旗リセット、**再生継続**） |
| `stop()` | 全停止 |
| `set_mute(muted)` | ミュート |
| `set_volume_db(offset_db)` | コンフィグ音量オフセット |

### `game.gd` からの呼び出し箇所（インゲーム関連）

| 関数 / 状態 | API |
|-------------|-----|
| `_start_stage()` | `begin_pre_countdown()` |
| `guide_info` → `guide_countdown` | `begin_countdown()` |
| `guide_countdown` → `playing`（`_process`） | `resume_ingame()` |
| `_check_clear()` | `play_clear()` |
| `_advance_stage()`（製品版） | `resume_stage_select()` |
| `_return_to_stage_select_preserve_bgm()` | `resume_stage_select()` |
| `_start_game()`（2 回目以降） | `play_ingame()` |
| `_rules_proceed()` / デモ `_start_game()` | `start_first_stage()` |

---

## 8. 実装ファイル

| ファイル | 役割 |
|----------|------|
| `scripts/bgm/BGMManager.gd` | BGM 再生・状態管理の本体 |
| `scripts/game.gd` | ゲーム状態に応じた API 呼び出し、音量スライダー |
| `scenes/stage_select.gd` | タイトル戻り時の `stop()` |
| `project.godot` | AutoLoad 登録 `BGMManager` |
| `assets/sounds/01-05/*.ogg` | インゲーム音源 |

---

## 参考: タイトル BGM（別トラック）

同一 `BGMManager` が `TRACKS[1]` でタイトル BGM も管理する（本ドキュメントの主対象外）。

| 項目 | 値 |
|------|-----|
| イントロ | `KATADRAW_Title_0000.ogg` |
| モチーフ | 5 本（`0010` 〜 `0050`） |
| 開始 | `play_title()`（タイトル画面） |

`play_ingame()` / `play_title()` は互いに `_stop_all()` してから切り替えるため、**インゲームとタイトルは同時再生されない**。
