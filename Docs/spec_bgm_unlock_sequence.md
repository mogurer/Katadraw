# BGM 解禁演出 仕様書

作成日：2026-07-05

---

## 対象変更

1. **拡大パネル位置バグ修正**（前回実装に混入）
2. **BGM 解禁演出シーケンス**（新規）

---

## 修正1：拡大パネルが画面中央に表示されない

### 原因

`_bgm_expanded_panel.resized` シグナル内で `position = -size / 2.0` をセットしているが、アンカーが `0.5`・`GROW_DIRECTION_BOTH` の場合、Godot が中央配置をすでに計算済み。この代入が中央からずれた位置を上書きしている。

### 修正内容

`resized` コールバックから `position` の代入を削除し、`pivot_offset` の更新のみ残す。

```gdscript
# 変更前
_bgm_expanded_panel.resized.connect(func() -> void:
    _bgm_expanded_panel.pivot_offset = _bgm_expanded_panel.size / 2.0
    _bgm_expanded_panel.position = -_bgm_expanded_panel.size / 2.0  # ← 削除
)

# 変更後
_bgm_expanded_panel.resized.connect(func() -> void:
    _bgm_expanded_panel.pivot_offset = _bgm_expanded_panel.size / 2.0
)
```

---

## 修正2：BGM 解禁演出シーケンス

### 概要

BGM ゾーンが完成したとき（6ステージ全クリア）、ステージセレクトに戻った直後に以下の演出を再生する。

### トリガー

`_ready()` 内で `check_bgm_unlocks()` が新解放 BGM を返したとき。ただし、**既存のステージ解放フォーカス演出（`start_unlock_focus()`）が完了した後に開始する**。

| 条件 | BGM演出の開始タイミング |
|------|----------------------|
| 新規解放ステージあり | `_is_focusing` が `false` に戻った瞬間（`_process_focus()` 終了検出） |
| 新規解放ステージなし | `_ready()` の末尾（即時開始） |

### シーケンスステップ

| ステップ | 内容 | 時間 |
|---------|------|------|
| 1 | カメラが青点位置へスライド | 0.5s（TRANS_QUAD / EASE_OUT） |
| 2 | 青点位置でパーティクル発生 | 即時（発生後は放置） |
| 3 | BGM 拡大 UI を画面中央に展開 | 0.15s（既存 `_bgm_do_expand()` と同じ） |
| 4 | BGM を新トラックへ切り替え（UI ラベルも連動） | 即時 |
| 5 | 0.5s 待機 | 0.5s |
| 6 | BGM 拡大 UI を右下へ収納 | 0.15s（既存 `_bgm_do_collapse()` と同じ） |

合計所要時間（スキップなし）：約 1.3s

### スキップ

演出中（ステップ1〜6のいずれの段階でも）、以下のいずれかの入力が **合計2回** 行われたら演出をスキップする。

| 入力 | カウント対象 |
|------|------------|
| コントローラ A ボタン押下 | 1回としてカウント |
| コントローラ X ボタン押下 | 1回としてカウント |
| マウス左クリック | 1回としてカウント |
| マウス右クリック | 1回としてカウント |

- 同じ入力の連打も有効（左クリック2回で OK）
- 2回に達した瞬間、全アニメーションを即座に終了し、終了状態へジャンプする

**スキップ後の状態：**
- カメラ位置：青点位置（ステップ1の目標地点）
- BGM：新トラックに切り替え済み
- 拡大 UI：非表示（収納済み）

### パーティクル変更

現在の実装（`amount = 60`）を **3倍の `amount = 180`** に変更する。

---

## 実装設計

### 新規追加 変数（`scenes/stage_select.gd`）

```gdscript
# BGM 解禁演出
var _bgm_unlock_directing: bool = false       # 演出中フラグ
var _bgm_unlock_phase: int = 0               # 0=inactive, 1=cam移動, 2=パーティクル+UI展開, 3=待機, 4=UI収納
var _bgm_unlock_elapsed: float = 0.0         # 各フェーズの経過時間
var _bgm_unlock_zone_center: Vector2 = Vector2.ZERO  # カメラ目標座標（青点位置）
var _bgm_unlock_bgm_id: String = ""          # 解放するBGM ID
var _bgm_unlock_skip_count: int = 0          # スキップ入力カウント（2で発動）
var _bgm_unlock_cam_start: Vector2 = Vector2.ZERO    # カメラ移動開始位置
```

### トリガーフロー

**`_ready()` 内：**
```gdscript
BGMManager.set_unlocked_bgm_ids(StageSelectManager.get_unlocked_bgm_ids())
var newly: Array[String] = StageSelectManager.check_bgm_unlocks()
if newly.size() > 0:
    var bgm_id: String = newly[0]  # Q4より同時完成は発生しないため[0]固定
    var zone_idx: int = _get_zone_idx_for_bgm(bgm_id)
    if zone_idx >= 0:
        var centers := StageSelectManager.get_bgm_zone_centers()
        _bgm_unlock_zone_center = centers[zone_idx]
        _bgm_unlock_bgm_id = bgm_id
        if _is_focusing:
            # フォーカス演出が終わったら演出を開始するフラグだけ立てる
            _bgm_unlock_pending = true
        else:
            _start_bgm_unlock_sequence()
```

**`_process_focus()` のフォーカス終了箇所に追加：**
```gdscript
# フォーカス終了後のチェック
if _bgm_unlock_pending:
    _bgm_unlock_pending = false
    _start_bgm_unlock_sequence()
```

### フェーズ制御（`_process()` 内）

```gdscript
if _bgm_unlock_directing:
    _bgm_unlock_elapsed += delta
    match _bgm_unlock_phase:
        1:  # カメラスライド（0.5s）
            var t: float = minf(_bgm_unlock_elapsed / 0.5, 1.0)
            var ease_t: float = 1.0 - pow(1.0 - t, 2.0)  # EASE_OUT QUAD
            _camera.position = _bgm_unlock_cam_start.lerp(_bgm_unlock_zone_center, ease_t)
            if t >= 1.0:
                _bgm_unlock_phase = 2
                _bgm_unlock_elapsed = 0.0
                _spawn_bgm_unlock_particles(_bgm_unlock_zone_center)
                _bgm_do_expand()
                BGMManager.unlock_bgm(_bgm_unlock_bgm_id)
                _bgm_update_expanded_label()
                _update_bgm_button_labels()
        2:  # パーティクル + UI展開 (expand アニメーション 0.15s を待つ)
            if _bgm_unlock_elapsed >= 0.15:
                _bgm_unlock_phase = 3
                _bgm_unlock_elapsed = 0.0
        3:  # 待機（0.5s）
            if _bgm_unlock_elapsed >= 0.5:
                _bgm_unlock_phase = 4
                _bgm_unlock_elapsed = 0.0
                _bgm_do_collapse()
        4:  # UI収納アニメーション（0.15s）
            if _bgm_unlock_elapsed >= 0.15:
                _bgm_unlock_directing = false
                _bgm_unlock_phase = 0
                _char_pos = _camera.position
                _char_target = _camera.position
    queue_redraw()
    return  # 演出中は通常処理をスキップ
```

### スキップ処理（`_input()` 内）

```gdscript
if _bgm_unlock_directing:
    var is_skip_input: bool = (
        (event is InputEventMouseButton and event.pressed and
            (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT))
        or (event is InputEventJoypadButton and event.pressed and
            (event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_X))
    )
    if is_skip_input:
        _bgm_unlock_skip_count += 1
        if _bgm_unlock_skip_count >= 2:
            _bgm_unlock_skip()
    return
```

```gdscript
func _bgm_unlock_skip() -> void:
    _bgm_unlock_directing = false
    _bgm_unlock_phase = 0
    _camera.position = _bgm_unlock_zone_center
    _char_pos = _camera.position
    _char_target = _camera.position
    BGMManager.unlock_bgm(_bgm_unlock_bgm_id)
    _update_bgm_button_labels()
    if _bgm_expanded:
        if _bgm_expand_tween:
            _bgm_expand_tween.kill()
        _bgm_expanded = false
        _bgm_expanded_panel.visible = false
```

### `_start_bgm_unlock_sequence()` 関数

```gdscript
func _start_bgm_unlock_sequence() -> void:
    _bgm_unlock_directing = true
    _bgm_unlock_phase = 1
    _bgm_unlock_elapsed = 0.0
    _bgm_unlock_skip_count = 0
    _bgm_unlock_cam_start = _camera.position
```

---

## 影響ファイル

| ファイル | 変更内容 |
|---------|---------|
| `scenes/stage_select.gd` | バグ修正（position削除）・演出変数追加・`_start_bgm_unlock_sequence()`・`_bgm_unlock_skip()`・`_process()` フェーズ制御・`_input()` スキップ処理・`_ready()` トリガー変更・`_process_focus()` 終了検出・パーティクル amount=180 |

---

## チェックリスト（実装後確認）

### バグ修正
- [ ] 右クリック保持で BGM 拡大 UI が画面中央に表示される
- [ ] X ボタン保持で BGM 拡大 UI が画面中央に表示される

### BGM 解禁演出：基本動作
- [ ] ステージ解放フォーカス演出の後に BGM 解禁演出が開始する
- [ ] 新規解放ステージがない場合、`_ready()` 直後に BGM 解禁演出が開始する
- [ ] カメラが 0.5s でスムーズに青点位置へ移動する
- [ ] 移動後、青点位置でパーティクルが発生する（大量・青色）
- [ ] BGM 拡大 UI が画面中央に展開する
- [ ] BGM が新トラックへ切り替わり、UI ラベルが連動して更新される
- [ ] 0.5s 後に BGM 拡大 UI が右下へ収納される

### BGM 解禁演出：スキップ
- [ ] フェーズ1（カメラ移動中）にスキップ入力2回で演出が終了する
- [ ] フェーズ3（待機中）にスキップ入力2回で演出が終了する
- [ ] スキップ後、カメラが青点位置にある
- [ ] スキップ後、BGM が新トラックに切り替わっている
- [ ] スキップ後、BGM 拡大 UI が非表示になっている
- [ ] A・X・左クリック・右クリックを組み合わせてカウント2でスキップできる

### パーティクル
- [ ] パーティクルの量が以前より増えている（180粒子）
