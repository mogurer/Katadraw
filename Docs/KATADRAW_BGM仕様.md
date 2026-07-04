# KATADRAW BGM仕様

**対象ファイル**: `scripts/bgm/BGMManager.gd`

---

## トラック一覧

| インデックス | BGM ID | 初期状態 | 解放条件 |
|------------|--------|---------|---------|
| 0 | `01-05` | 選択可能（デフォルト） | — |
| 1 | `01-06` | ロック | BGMゾーン1完成 |
| 2 | `01-08` | ロック | BGMゾーン2完成 |
| 3 | `02-03` | ロック | BGMゾーン3完成 |
| 4 | `02-09` | ロック | BGMゾーン4完成 |
| 5 | タイトル | タイトル専用 | — |

各トラックは `intro`（`_0000.ogg`）と複数の `motifs`（`_0010`, `_0020` …）で構成される。

---

## 音量制御

| 定数 | 値 | 説明 |
|------|-----|------|
| `_BASE_VOLUME_DB` | −8.5 dB | 基準音量 |
| `_CLEAR_VOLUME_BOOST_DB` | +3.0 dB | クリア演出時のブースト |
| `_COUNTDOWN_VOLUME_REDUCE_DB` | −3.0 dB | カウントダウン中の低減 |
| `_FADE_DURATION` | 1.0 s | クロスフェード時間 |

実際の再生音量 = `_BASE_VOLUME_DB + _volume_offset_db + boost + countdown_reduction`

`_volume_offset_db` はコンフィグ画面の BGM 音量スライダー（0〜10）から変換して設定される。

---

## 再生ステートマシン

BGMManager は内部状態を持ち、以下の条件でモチーフ遷移を管理する。

### 通常フロー

```
play_ingame() または play_title()
  └─ イントロ（_0000）再生
        └─ 自然終了 → モチーフ01（_0010）へ
              └─ 自然終了 → 次のモチーフへ（ループ）
```

### ステージ開始フロー

```
start_first_stage()   ← ステージセレクト → ゲーム1面目
  └─ BGM停止・無音待機
        └─ begin_countdown() → 無音のままカウントダウン
              └─ resume_ingame() → 1秒後に play_ingame() → イントロ再生
```

### クリア後「次へ」フロー

```
begin_pre_countdown()   ← クリア後「次へ」押下（guide_info 開始時）
  └─ モチーフ残り < 1s → _0000 へクロスフェード（_waiting_for_resume = true）
     それ以外 → モチーフを継続再生

begin_countdown()   ← guide_info → guide_countdown 遷移時
  └─ BGM音量 -3dB 低減

resume_ingame()   ← カウントダウン完了時
  └─ _0000 → 保存モチーフへクロスフェード（1秒後に音量復帰）
```

### 状態フラグ一覧

| フラグ | 意味 |
|--------|------|
| `_in_intro` | イントロ（_0000）を再生中 |
| `_in_pre_countdown` | プリカウントダウン状態中 |
| `_waiting_for_resume` | `resume_ingame()` 待ち（_0000 ループ待機） |
| `_countdown_active` | カウントダウン中（音量低減中） |
| `_first_stage_pending` | 1面目の無音待機中 |
| `_clear_boost_active` | クリアブースト中 |

---

## 公開 API

| 関数 | タイミング・用途 |
|------|----------------|
| `play_title()` | タイトル画面 BGM 開始 |
| `play_ingame()` | インゲーム BGM 開始（イントロから） |
| `start_first_stage()` | ステージ1開始時の無音待機モード |
| `begin_pre_countdown()` | クリア後「次へ」押下時 |
| `begin_countdown()` | カウントダウン開始時 |
| `resume_ingame()` | カウントダウン完了・ゲーム開始時 |
| `play_clear()` | クリア演出開始時（+3dB ブースト） |
| `resume_stage_select()` | ステージセレクト復帰時の状態リセット |
| `stop()` | BGM全停止・全フラグリセット |
| `select_next_bgm()` | 次のインゲームトラックへ切り替え |
| `select_prev_bgm()` | 前のインゲームトラックへ切り替え |
| `set_unlocked_bgm_ids(ids)` | ステージセレクト起動時に解放済み ID をセット |
| `unlock_bgm(bgm_id)` | BGM ゾーン完成時に1トラック解放・即切り替え |
| `get_unlocked_track_count()` | 解放済みトラック数（矢印表示制御用） |
| `set_mute(muted)` | ミュート切り替え |
| `set_volume_db(offset_db)` | 音量オフセット設定（コンフィグから） |

---

## BGM 解放ゾーン

詳細は [KATADRAW_ステージセレクト仕様.md](KATADRAW_ステージセレクト仕様.md#bgm-解禁ゾーン青い点線) を参照。

| BGM ID | 解放トリガー |
|--------|------------|
| `01-06` | ゾーン1（ステージ 8, 9, 13, 14, 17, 18 全クリア） |
| `01-08` | ゾーン2（ステージ 11, 12, 15, 16, 21, 22 全クリア） |
| `02-03` | ゾーン3（ステージ 27, 28, 31, 32, 35, 36 全クリア） |
| `02-09` | ゾーン4（ステージ 39, 40, 43, 44, 47, 48 全クリア） |

---

## ステージセレクトでの BGM 選択 UI

| 機能 | 詳細 |
|------|------|
| 小表示 | 常時右下に表示。BGM名ラベル + 前/次ボタン |
| 前ボタン | `◀[Q]`（KBM） / `◀[L]`（コントローラ） |
| 次ボタン | `[E]▶`（KBM） / `[R]▶`（コントローラ） |
| 解放済み1種のみ | 前後ボタン非表示 |
| 拡大パネル | 右クリック保持 / X ボタン保持で展開（画面中央） |
| 拡大アニメーション | 0.15s（scale 0.25→1.0 + alpha 0→1、TRANS_QUAD/EASE_OUT） |
| 収納アニメーション | 0.15s（逆再生、EASE_IN） |
| L/R 操作後の拡大 | 0.5s 表示してから自動収納（押すたびにリセット） |

---

## Zou ステージ BGM

- カウントダウン完了時：`BGMManager.play_title()` でタイトル BGM に切り替え
- クリア時：`BGMManager.stop()` で停止
