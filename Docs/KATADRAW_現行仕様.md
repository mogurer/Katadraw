# KATA-DRAW 現行ゲーム仕様書

> **作成日**: 2026-05-24  
> **出典**: リポジトリ内のスクリプト・リソース（`Docs/` 内の旧ドキュメントは参照していません）  
> **エンジン**: Godot 4.6  
> **ビルド設定の基準**: `Resources/game_config.gd` の現行値（`EXPERIENCE_VERSION = false`, `IS_DEMO = false`）

---

## 目次

1. [概要](#1-概要)
2. [ゲームフロー](#2-ゲームフロー)
3. [コアゲームプレイ](#3-コアゲームプレイ)
4. [入力・操作](#4-入力操作)
5. [ステージシステム](#5-ステージシステム)
6. [UI / HUD](#6-ui--hud)
7. [オーディオ](#7-オーディオ)
8. [設定・セーブデータ](#8-設定セーブデータ)
9. [デバッグ機能](#9-デバッグ機能)
10. [Steam 連携](#10-steam-連携)
11. [ビルドバリアント](#11-ビルドバリアント)
12. [主要定数一覧](#12-主要定数一覧)

---

## 1. 概要

**KATA-DRAW** は、画面上の **KATA**（複数の頂点を結んだ閉曲線）を操作し、目標図形（ガイド輪郭）に一致させる形状合わせパズルゲームです。

- プレイヤーは **自キャラ（円）** を動かし、各頂点に **引力** または **斥力** を与えて KATA の形を変形する
- **一致度** がステージごとのクリア閾値（`clear_pct`）以上になるとクリア
- 組み込みステージは JSON で管理され、マニフェストに **62 面** 定義されている
- 製品版の本編進行は **最大 50 面**（ステージセレクト 10×5 グリッド）

### プロジェクト構成（主要）

| 項目 | 値 |
|------|-----|
| メインシーン | `res://scenes/game.tscn` |
| AutoLoad | `BGMManager`, `SteamManager`, `StageSelectManager` |
| 内部解像度 | 1920×1080 固定 |
| デフォルト言語 | 日本語（`Resources/Translation/Translation.csv`） |

---

## 2. ゲームフロー

### 2.1 ゲーム状態（`game_state`）

| 状態 | 説明 |
|------|------|
| `logo` | 起動ロゴ（全長 **7.0 秒**、任意キーでスキップ可） |
| `title_intro` | K 字イントロアニメーション（全長 **10.1 秒**、スキップ時 **1.0 秒** フェード） |
| `title` | タイトル画面 |
| `menu` | メインメニュー（0=ゲーム開始 / 1=コンフィグ / 2=終了） |
| `config` | 設定画面 |
| `rules` | 操作チュートリアル（ひし形 4 点デモ） |
| `guide_info` | ステージ開始前ガイド（STAGE 番号・図形名・見本） |
| `guide_countdown` | **3→2→1** カウントダウン |
| `playing` | 本編プレイ |
| `cleared` | ステージクリア演出 |
| `results` | 全ステージクリア後リザルト |
| `stage_debug` | F2 ステージデバッグ（エディタ実行時のみ） |
| `play_balance_debug` | プレイ中 **S** バランス調整 |
| `stage_edit` | カスタムステージ図形エディタ |

### 2.2 製品版フロー（`IS_DEMO = false`、現行ビルド）

```
起動
  → logo（7秒）
  → title_intro（10.1秒）
  → title
  → menu
       ├─ 初回「ゲーム開始」& tutorial_shown=false
       │     → rules（チュートリアル）→ ステージ 0 開始
       └─ 2回目以降「ゲーム開始」
             → BGM ingame 開始 → stage_select.tscn
                  → ステージ選択・確認
                  → game.tscn（pending_stage_id）
                       → guide_info → guide_countdown（3秒）
                       → playing → cleared
                       → ステージセレクトへ戻る
```

- 初回プレイ時: `StageSelectManager.tutorial_shown = true` を保存し、`BGMManager.start_first_stage()`（**無音**）ののちステージ 0 を開始
- 2 回目以降: インゲーム BGM を開始してステージセレクト画面へ遷移

### 2.3 デモ版フロー（`IS_DEMO = true` 時）

- タイトル → メニュー → **直接** ステージ 0 開始（ステージセレクトなし）
- クリア後「次へ」で **連続** 次ステージ。最終面後 `results`
- ポーズ「ステージをやめる」→ タイトルへ
- クリア記録は `StageSelectManager` に保存しない

### 2.4 ステージ内の遷移

1. **guide_info**: クリック / Enter / A で `guide_countdown` へ（`BGMManager.begin_countdown()` で **-3 dB**）
2. **guide_countdown**: **3.0 秒**（ポーズからのやりなおし時は **3 倍速** = 実時間 1 秒）。`se_count.wav` を 1/2/3 で再生
3. **playing**: 開始 **0.5 秒** のステージイントロ中は入力不可（`STAGE_INTRO_DURATION`）
4. タイマーはカウントダウン終了時点 + イントロ時間から計測開始

### 2.5 ポーズ

| 項目 | 内容 |
|------|------|
| 呼び出し | **Esc** / ゲームパッド **Start** |
| 項目 | 0=閉じる / 1=やりなおし / 2=ステージをやめる |
| やりなおし | `guide_info` へ戻る（経過タイマーは保持、カウントダウン 3 倍速） |
| やめる（製品版） | ステージセレクトへ |
| やめる（デモ版） | タイトルへ |

### 2.6 ロゴ・タイトル演出

| 定数 | 値 | 参照 |
|------|-----|------|
| `LOGO_TOTAL` | 7.0 秒 | `game_config.gd` |
| `LOGO_WAIT1` / `FADE_IN` / `HOLD` / `FADE_OUT` / `WAIT2` | 1.0 / 1.0 / 2.0 / 1.0 / 1.0 秒 | 同上 |
| `TITLE_FADE_IN` | 0.5 秒 | 同上 |
| `TI_TOTAL_DUR` | 10.1 秒 | `title_intro_animation.gd` |
| `TITLE_INTRO_SKIP_FADE` | 1.0 秒 | 同上 |

---

## 3. コアゲームプレイ

### 3.1 KATA と自キャラ

- **KATA**: `num_points` 個の頂点（`point_positions`）を閉曲線として結ぶ
- **自キャラ**: 半径 **16 px**（`InputHandler.PLAYER_RADIUS`）、各頂点に引力/斥力を与える
- 頂点はドラッグ物理 + ガイド輪郭へのスナップ（辺 **26 px** / 頂点 **16 px** 等）
- 自キャラの力の影響半径: **128 px**（`PLAYER_FORCE_RADIUS`）

### 3.2 一致度（スコアリング）

**評価方式（全 shape_type 共通）**:

- **弧誤差のみ**、**回転非対応**
- HUD モード（`USE_SCREEN_HUD_GUIDE = true`）: 画面固定ガイド輪郭との距離で評価
- 複合スコア: 平均 **70%** + 最大 **30%**（`ARC_ERROR_AVG_WEIGHT` / `ARC_ERROR_MAX_WEIGHT`）
- 辺ごと Hausdorff 距離（`USE_PER_EDGE_HAUSDORFF = true`）
- Hausdorff 計算は **10 フレームに 1 回**（`HAUSDORFF_THROTTLE_EVERY = 10`）
- メトリクスは頂点静止 **0.15 秒** 後に更新（`_METRICS_SETTLE_DELAY`）

**クリア条件**:

```
current_circularity >= clear_pct
```

- `current_circularity = 100 - circ_err`（%）
- 例: `clear_pct: 99.0` → **99% 以上**でクリア

**表示用実現率（HUD）**:

- `display_rate_min_pct`（デフォルト **50%**）以下 → **0%** 表示
- `min_pct`〜`clear_pct` を 0〜100% に線形マップ
- 小数 **1 桁切り捨て**（99.95 → 99.9、未クリアで 100.0% 表示を防止）

### 3.3 移動回数（`stage_move_count`）

- つかみ（grab）終了ごとに +1（有効トラック時）
- つかみ中、KATA 重心が **22 px** 以上動くとトラック有効（`STAGE_MOVE_COUNT_PIXEL_THRESHOLD`）

### 3.4 ヒント

| タイミング | 動作 |
|------------|------|
| **60 秒** | **0.1 秒** 表示 |
| **90 秒** | **0.3 秒** 表示 |
| **120 秒〜** | **1 秒** フェードイン → **3 秒** 非表示をループ |
| デバッグモード | 常時 α=0.8 |

※ `USE_SCREEN_HUD_GUIDE = true` のため、プレイ中のヒント描画はオフ（定数は残存）

### 3.5 形状タイプ

`StageConfig.KNOWN_SHAPE_TYPES` で定義:

```
triangle, square, rhombus, hexagon, circle, star,
cat_face, fish, heptagram, heptagram_silhouette, rugby_ball
```

- JSON の `shape.polygon_vertices` / `shape.arc_controls` でカスタム輪郭を定義可能
- 弧セグメントの一致度緩和係数: **0.6**（`ARC_SEGMENT_MATCH_LENIENCY_MUL`）
- 先端（鋭角）ペナルティ重み: **0.3**（`VERTEX_TIP_WEIGHT`）

### 3.6 HUD ガイド配置

| 定数 | 値 | 説明 |
|------|-----|------|
| `HUD_GUIDE_MARGIN_FRAC` | 0.15 | プレイフィールド左右マージン |
| `HUD_INITIAL_RING_SCALE_MUL` | 1.48 | KATA 初期円半径の倍率 |
| `HUD_SPAWN_ELLIPSE_VERTICAL_FRAC` | 0.58 | 楕円周配置の縦半軸比 |
| スロット 0 の Y オフセット | +100 px | 1 面目のみプレイフィールド基準点を下げる |
| `SPAWN_EDGE_BAND_PX` | 200 px | 画面端からの初期配置バンド |
| `SPAWN_GUIDE_MIN_DIST_PX` | 100 px | ガイド輪郭からの最小距離 |

---

## 4. 入力・操作

### 4.1 マウス

| 操作 | 効果 |
|------|------|
| 左クリック押下 | **斥力**（repel） |
| 右クリック押下 | **引力**（attract） |
| 左+右同時 | **A+X 均等化**（頂点間斥力のみ、自キャラ力オフ） |
| マウス移動 | 自キャラ位置（lerp **10.0**） |
| 頂点クリック | 選択・ドラッグ（ヒット半径 **30 px**） |
| 矩形選択 | 複数選択 → BB 変形（Shift で移動 **1/3**） |

- プレイ中: パッド入力後はマウス移動が自キャラを動かさない（`playing_mouse_steers_player`）
- カーソル: **2.5 秒** アイドルで非表示、パッド入力で再表示

### 4.2 ゲームパッド

| 入力 | 効果 |
|------|------|
| 左スティック / D-pad | 自キャラ移動（速度 **600 px/s** 基準、加速ランプ **960 ms**） |
| **A** | 斥力 |
| **X** | 引力 |
| **A+X 同時** | 頂点間均等化斥力（**500 ms** 以上の長押しで効果開始、最大 **3 秒** で頭打ち） |
| **B** | 力リセット |
| **LB/RB** | 閉路頂点の前/次選択（ポリゴンリング巡回） |
| 右スティック | 頂点選択・ドラッグ |
| **Start** | ポーズ |
| **Esc**（キーボード） | ポーズ / UI 戻る |

### 4.3 UI ナビゲーション

- メニュー・コンフィグ: 左スティック + D-pad（`_process` でポーリング）
- スティックデッドゾーン: **0.35**
- リピート: 初回 **0.35 秒**、以降 **0.12 秒** 間隔

### 4.4 特殊操作

- **A+X / マウス左右同時**: 多角形周上の隣接頂点ペアに追加斥力（最大強さ **2 倍**）
- **静止長押し**: 引力/斥力の影響半径が段階的に拡大（最大 **22 段** × **200 ms**）
- **辺交差解消**: 未ロック頂点を半径 **64 px** の円周に等間隔配置

---

## 5. ステージシステム

### 5.1 マニフェスト

- パス: `Resources/Stagedata/builtin/manifest.json`
- `schema_version: 1`
- **62 面** 定義（`tutorial_triangle.json` 〜 `umbrella.json`）
- 読み込み: `StageData.get_stages()` → `CustomStageFile.parse_file()` 経由

### 5.2 ステージ JSON 形式

```json
{
  "schema_version": 1,
  "kind": "katadraw_custom_stage",
  "meta": {
    "stage_name": "三角形",
    "locale_key": "STAGE_TUTORIAL_TRIANGLE",
    "description": ""
  },
  "config": {
    "type": "tutorial_triangle",
    "shape_type": "triangle",
    "num_points": 3,
    "min_radius": 162.0,
    "max_radius": 234.0,
    "clear_pct": 99.0,
    "display_rate_min_pct": 50.0,
    "variance": 0.2,
    "zigzag": 0.08,
    "vertex_range": [3, 3],
    "guide_follows_player_radius": 0,
    "hud_guide_layout_scale_mul": 0.8
  },
  "shape": {
    "polygon_vertices": [[x, y], ...],
    "arc_controls": { "5": [x, y] }
  }
}
```

- `config.type`: ステージ ID（ファイル名のベース名と一致）
- `config.shape_type`: 図形タイプ（`KNOWN_SHAPE_TYPES` のいずれか）
- カスタムステージ: `user://custom_stages/*.json`（ファイル名 `[a-z0-9_]+` のみ）

### 5.3 プレイ可能面数

| 条件 | 最大面数 |
|------|----------|
| `EXPERIENCE_VERSION = true`（体験版） | **3 面**（index 0〜2） |
| `EXPERIENCE_VERSION = false`（製品版、現行） | **50 面**（index 0〜49） |
| マニフェスト定義総数 | **62 面**（index 50〜61 は現状セレクト未使用） |

### 5.4 ステージセレクト

- グリッド: **10 列 × 5 行 = 50 スロット**
- 状態: `LOCKED` / `UNLOCKED` / `CLEARED`
- 永続化: `user://stage_select_state.json`
- 初期: ステージ 0 のみ `UNLOCKED`
- クリア時: 自身を `CLEARED` + 上下左右隣接を `UNLOCKED`
- 自キャラ接近 **140 px** で吹き出しプレビュー
- 決定で確認ポップアップ → `pending_stage_id` 設定 → `game.tscn` へ

### 5.5 組み込みステージ一覧（manifest 順）

| # | ファイル | # | ファイル |
|---|----------|---|----------|
| 0 | tutorial_triangle.json | 31 | hexagon.json |
| 1 | test_square.json | 32 | hourglass.json |
| 2 | hexagon_6.json | 33 | keitora.json |
| 3 | circle_14.json | 34 | key.json |
| 4 | star_10.json | 35 | king.json |
| 5 | cat_face_18.json | 36 | milk_carton.json |
| 6 | rugby_ball.json | 37 | mount_fuji.json |
| 7 | home.json | 38 | mushrooms.json |
| 8 | ocarina.json | 39 | one_quarter.json |
| 9 | mug.json | 40 | onion.json |
| 10 | acoustic_guitar.json | 41 | paramecium.json |
| 11 | airship.json | 42 | pen.json |
| 12 | arrow.json | 43 | penguin.json |
| 13 | banana.json | 44 | pentagon.json |
| 14 | bed.json | 45 | pot.json |
| 15 | book.json | 46 | rabbit.json |
| 16 | bottle_s.json | 47 | rainbow.json |
| 17 | butterfly.json | 48 | shark.json |
| 18 | cactus.json | 49 | ship_m.json |
| 19 | cap.json | 50 | shuriken.json |
| 20 | cicada.json | 51 | small_bird.json |
| 21 | cows_face.json | 52 | sorbet.json |
| 22 | cross.json | 53 | tears.json |
| 23 | cupcake.json | 54 | television.json |
| 24 | dent.json | 55 | treasure_chest.json |
| 25 | folding_fan.json | 56 | waning_moon.json |
| 26 | frog.json | 57 | wrench.json |
| 27 | ghost.json | 58 | crab.json |
| 28 | gift_box.json | 59 | three_storied_pagoda.json |
| 29 | heart.json | 60 | tulip.json |
| 30 | heptagramsil_j.json | 61 | umbrella.json |

※ 本編進行（ステージセレクト）は index **0〜49** の 50 面まで

---

## 6. UI / HUD

### 6.1 表示設定

| 項目 | 値 |
|------|-----|
| 内部ビューポート | 1920×1080 固定 |
| ウィンドウモード | 1920×1080 / 1280×720 / フルスクリーン |
| 左 UI パネル | なし（`UI_WIDTH_RATIO = 0.0`） |
| 背景色 | `#FFF0E3` 相当（`BG_COLOR`） |
| アクセント色 | 赤系（`#F23052` 相当） |

### 6.2 プレイ中 HUD

- **右上（または自キャラ回避で左上）**: 経過時間 `9999.99` 形式（等幅 7 文字、`font_din`）
- **自キャラ付近**: 実現率 `%.1f%%`（掴み中 or 直後アニメ）
- **画面固定ガイド輪郭**（赤系、近接で頂点開示）
- **左下**: コントローラ操作ヒント画像（`assets/UI/con_bt_*.png`）
- square/hex ステージ: A 斥力/X 引力のループデモ円（周期 **3.0 秒**）

### 6.3 クリア画面

- タイトル「CLEAR」、クリア時間、移動回数
- 「次へ」→ 製品版はステージセレクト / デモ版は次ステージ or リザルト

### 6.4 リザルト画面

- 全ステージの時間・移動回数・形状サムネイル
- アクション: **スクリーンショット** / **X（Twitter）共有** / **次へ**
- スクリーンショット保存先: `Pictures/KATA-DRAW/KATA-DRAW_YYYYMMDD_HHMMSS.png`
- Twitter 共有文: `Resources/Text/Twitter.txt`（既定 `#KATADRAW`）

### 6.5 コンフィグ項目

| # | 項目 |
|---|------|
| 0 | 表示モード（1080p / 720p / フルスクリーン） |
| 1 | マウスウィンドウ内閉じ込め ON/OFF |
| 2 | 言語（ja / en） |
| 3 | BGM 音量 0〜10（5=0 dB、0=ミュート） |
| 4 | SE 音量 0〜10 |
| 5 | チュートリアル再表示 |
| 6 | 戻る |
| 右下 | **RESET**（進行データ全消去） |

---

## 7. オーディオ

### 7.1 BGM（`BGMManager` AutoLoad）

| トラック | 内容 |
|----------|------|
| 0 ingame | intro `01-05_0000.ogg` + モチーフ 15 本（0010〜0150） |
| 1 title | intro `KATADRAW_Title_0000.ogg` + モチーフ 5 本 |

| 定数 | 値 |
|------|-----|
| 基準音量 | **-8.5 dB** |
| クロスフェード | **1.0 秒** |
| クリア時 | **+3 dB** |
| カウントダウン中 | **-3 dB** |
| 初回ステージ | 無音 → `resume_ingame()` **1 秒後** に ingame 開始 |

### 7.2 SE（基準 **-14.5 dB** + SE 音量オフセット）

| ファイル | 用途 |
|----------|------|
| `se_count.wav` | カウントダウン |
| `se_match.mp3` | クリア合致 |
| `se_on.wav` | UI |
| `se_point.wav` | ポイント |
| `se_motion.mp3` | タイトルイントロ |
| `katadraw_stagestart.wav` | ステージ開始 |
| `se_click.wav` | クリック |
| `se_window_open.wav` / `se_window_close.wav` | ウィンドウ |
| `se_catch.wav` | つかみ |
| `se_move`（ループ） | 操作中 |
| `se_stageclear.wav` / `se_stageclear02.wav` | クリア |

---

## 8. 設定・セーブデータ

| ファイル | 内容 |
|----------|------|
| `user://stage_select_state.json` | ステージ解放状態、`tutorial_shown` |
| `user://KATA-DRAW-log/progress_dwell_log.txt` | クリア時の実現率帯別滞在時間ログ |
| `user://custom_stages/*.json` | デバッグ/エディタで作成したカスタムステージ |

**RESET 操作**: ステージ 0 のみ `UNLOCKED`、`tutorial_shown = false` にリセット

---

## 9. デバッグ機能

**有効条件**: `OS.has_feature("editor")` または `Engine.is_editor_hint()`（エクスポート版では無効）

| 操作 | 機能 |
|------|------|
| タイトル **F2** | ステージデバッグ画面 |
| タイトル **S** | リザルト画面プレビュー（ダミーデータ 10 スロット） |
| プレイ中 **S** | バランス調整（PBD）パネル |

### ステージデバッグ（F2）

- 組み込み 62 面 + `user://custom_stages/*.json` 一覧
- 編集フィールド: `type`, `num_points`, `min/max_radius`, `variance`, `zigzag`, `display_rate_min_pct`, `clear_pct`, `guide_follows_player_radius`, `group_sizes`, `stage_name`, `description`
- テストプレイ / 保存 / 図形編集（`stage_edit` 状態）

### バランス調整（PBD）

- 現ステージの 6 パラメータを編集 → テスト → JSON 保存 / 図形編集
- フィールド: ポイント数、クリア一致度、最小/最大半径、バラツキ、最低表示率

### その他

- `DEBUG_PLAY_SINGLE_MASTER_INDEX`: 単一面ループ試行（現行 **-1** = 無効）
- `DebugInputRecorder`: デバッグテストモード時の入力記録

---

## 10. Steam 連携

- AutoLoad: `SteamManager`（`steam_manager.gd`）
- 起動時: `Steam.steamInitEx()`、失敗時は print
- 毎フレーム: `Steam.run_callbacks()`
- `project.godot`: GodotSteam プラグイン有効、`app_id=0`、`initialize_on_startup=false`
- **実績・リーダーボード等のゲームロジック連携は現時点で未実装**（初期化 + コールバックのみ）

---

## 11. ビルドバリアント

| 定数 | 製品版（現行） | 体験版（demo ブランチ） | デモ版 |
|------|---------------|----------------------|--------|
| `EXPERIENCE_VERSION` | `false` | `true` | — |
| `IS_DEMO` | `false` | `false` | `true` |
| ステージ数上限 | 50 面 | 3 面 | 設定依存 |
| ステージセレクト | あり | あり | なし |
| クリア記録 | 保存 | 保存 | 保存しない |

ブランチ運用は `WORKFLOW.md` を参照（`main` = 製品版、`demo` = 体験版）。

---

## 12. 主要定数一覧

| 項目 | 値 | 参照ファイル |
|------|-----|-------------|
| マニフェスト面数 | 62 | `manifest.json` |
| 本編最大面数 | 50 | `game_config.gd` |
| 体験版面数 | 3 | `game_config.gd` |
| クリア閾値 | JSON `clear_pct` | 各 stage JSON |
| メトリクス静止待ち | 0.15 s | `game.gd` |
| カウントダウン | 3.0 s | `game.gd` |
| ステージイントロ | 0.5 s | `ui_renderer.gd` |
| 自キャラ半径 | 16 px | `input_handler.gd` |
| 移動カウント閾値 | 22 px | `game.gd` |
| Hausdorff 間引き | 10 フレームに 1 回 | `stage_manager.gd` |
| 弧エッジ緩和係数 | 0.6 | `stage_manager.gd` |
| 先端ペナルティ重み | 0.3 | `stage_manager.gd` |

---

## 参照ソース（主要ファイル）

| ファイル | 役割 |
|----------|------|
| `scripts/game.gd` | メインゲームロジック・状態遷移 |
| `scripts/input_handler.gd` | 入力・物理操作 |
| `scripts/stage_manager.gd` | ステージ生成・メトリクス・クリア判定 |
| `scripts/ui_renderer.gd` | UI/HUD 描画 |
| `scripts/StageSelectManager.gd` | ステージセレクト状態管理 |
| `scenes/stage_select.gd` | ステージセレクト画面 |
| `Resources/game_config.gd` | ゲーム全体設定 |
| `Resources/stage_config.gd` | 形状タイプ定義 |
| `Resources/stage_data.gd` | ステージデータ読み込み |
| `scripts/custom_stage_file.gd` | ステージ JSON スキーマ |
| `scripts/bgm/BGMManager.gd` | BGM 制御 |
| `steam_manager.gd` | Steam API |
