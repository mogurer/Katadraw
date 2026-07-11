# KATADRAW ステージセレクト 修正指示（まとめ）

現行仕様書（`ステージセレクト仕様.md`）および新仕様書（`ステージセレクト新仕様.md`）を参照しながら、以下の修正を順番に実施すること。

---

## 修正A：ステージ全リセット後の初期フォーカス位置

**対象ファイル**: `scripts/StageSelectManager.gd`

### A-1. 変数の追加

`pending_stage_id` の宣言の直下に追加する。

```gdscript
# ステージセレクトに戻ったときのフォーカス位置（最後にプレイしたステージID）
var last_played_stage_id: int = -1
```

### A-2. `_save_states()` への追加

`data["unlocked_bgms"] = _unlocked_bgms` の直後に追加する。

```gdscript
data["last_played_stage_id"] = last_played_stage_id
```

### A-3. `_load_states()` への追加

`_load_states()` 末尾の `unlocked_bgms` 読み込みブロックの直後に追加する。

```gdscript
last_played_stage_id = int(d.get("last_played_stage_id", -1))
```

### A-4. `reset_all()` への追加

`_best_move_counts.clear()` の直後に追加する。

```gdscript
last_played_stage_id = -1
```

---

**対象ファイル**: `scripts/game.gd`

### A-5. `_start_game_from_stage_select()` の修正

`StageSelectManager.pending_stage_id = -1` の直前に追加する。

```gdscript
StageSelectManager.last_played_stage_id = sid
```

---

**対象ファイル**: `scenes/stage_select.gd`

### A-6. `_ready()` の初期フォーカス位置を修正

以下の既存コードを：

```gdscript
# アバター初期位置をワールド座標のステージ0に設定
var _start: Vector2 = StageSelectManager.get_world_pos(0)
_char_pos = _start
_char_target = _start
_camera.position = _start
```

以下に置き換える：

```gdscript
# アバター初期位置: 最後にプレイしたステージがあればそこへ、なければステージ0
var _focus_id: int = StageSelectManager.last_played_stage_id
if _focus_id < 0 or _focus_id >= StageSelectManager.STAGE_COUNT:
    _focus_id = 0
var _start: Vector2 = StageSelectManager.get_world_pos(_focus_id)
_char_pos = _start
_char_target = _start
_camera.position = _start
```

---

## 修正B：チュートリアル三角形の天頂初期位置

**対象ファイル**: `scripts/stage_manager.gd`

`_rebuild_initial_points_hud_triangle_bottom_snap()` 内の以下の行を：

```gdscript
point_positions.append(center)  # KATA 0: 頂上（自由）
```

以下に置き換える：

```gdscript
# KATA 0: 頂上（center→天頂を3等分して天頂寄り2/3の位置からスタート）
var apex: Vector2 = center + Vector2(0.0, -1.0) * r
point_positions.append(center.lerp(apex, 2.0 / 3.0))
```

---

## 修正C：未開放ステージの非表示・移動範囲の制限

**対象ファイル**: `scenes/stage_select.gd`

### C-1. LOCKEDドットを描画しない

`_draw()` 内のステージドット描画ループを修正する。

以下の既存コードを：

```gdscript
for i in range(StageSelectManager.STAGE_COUNT):
    var state: int = StageSelectManager.get_state(i)
    var pos: Vector2 = _dot_pos(i)
    var is_near: bool = (i == _nearest and _popup_stage < 0 and not _esc_popup)
    match state:
        StageSelectManager.StageState.LOCKED:
            draw_circle(pos, _DOT_RADIUS, _LOCKED_COLOR)
        StageSelectManager.StageState.UNLOCKED:
            draw_circle(pos, _DOT_RADIUS, _HOVER_COLOR if is_near else _UNLOCKED_COLOR)
        StageSelectManager.StageState.CLEARED:
            draw_circle(pos, _DOT_RADIUS, _HOVER_COLOR if is_near else _CLEARED_COLOR)
            draw_circle(pos, _DOT_RADIUS * 0.35, Color.WHITE)
```

以下に置き換える：

```gdscript
for i in range(StageSelectManager.STAGE_COUNT):
    var state: int = StageSelectManager.get_state(i)
    if state == StageSelectManager.StageState.LOCKED:
        continue  # LOCKEDは描画しない
    var pos: Vector2 = _dot_pos(i)
    var is_near: bool = (i == _nearest and _popup_stage < 0 and not _esc_popup)
    match state:
        StageSelectManager.StageState.UNLOCKED:
            draw_circle(pos, _DOT_RADIUS, _HOVER_COLOR if is_near else _UNLOCKED_COLOR)
        StageSelectManager.StageState.CLEARED:
            draw_circle(pos, _DOT_RADIUS, _HOVER_COLOR if is_near else _CLEARED_COLOR)
            draw_circle(pos, _DOT_RADIUS * 0.35, Color.WHITE)
```

### C-2. 接続ラインもLOCKED側は描画しない（既存のまま維持）

接続ライン描画ループは既に両端LOCKEDをスキップする処理が入っているため変更不要。

### C-3. 移動範囲をUNLOCKED/CLEAREDノードの範囲に制限

`_calc_world_bounds()` 関数を以下に置き換える。
この関数が存在しない場合は新規追加する。

```gdscript
func _calc_world_bounds() -> Rect2:
    var min_x: float = INF
    var min_y: float = INF
    var max_x: float = -INF
    var max_y: float = -INF
    var found: bool = false
    for i in range(StageSelectManager.STAGE_COUNT):
        if StageSelectManager.get_state(i) == StageSelectManager.StageState.LOCKED:
            continue
        var pos: Vector2 = StageSelectManager.get_world_pos(i)
        min_x = minf(min_x, pos.x)
        min_y = minf(min_y, pos.y)
        max_x = maxf(max_x, pos.x)
        max_y = maxf(max_y, pos.y)
        found = true
    if not found:
        return Rect2(Vector2.ZERO, Vector2(1920.0, 1080.0))
    var margin: float = 200.0
    return Rect2(min_x - margin, min_y - margin,
                 max_x - min_x + margin * 2.0,
                 max_y - min_y + margin * 2.0)
```

アバター移動のクランプ処理でこの関数を使用していない場合は、`_process()` または `_update_camera()` 内でアバター座標のクランプに `_calc_world_bounds()` の返す `Rect2` を使うよう修正すること。

---

## 修正D：ステージ解放演出

**対象ファイル**: `scenes/stage_select.gd`

### D-1. 変数の追加

既存の `_focus_queue` / `_is_focusing` / `_focus_elapsed` の宣言の近くに追加する。

```gdscript
var _focus_return_id: int = -1          # 演出終了後に戻るステージID
var _unlock_anim_stage: int = -1        # 現在ぼよよん演出中のステージID
var _unlock_anim_elapsed: float = 0.0   # ぼよよん演出の経過時間
var _unlock_anim_particles_spawned: bool = false  # パーティクル生成済みフラグ
const UNLOCK_ANIM_DURATION: float = 0.5           # ぼよよん演出の長さ（秒）
const FOCUS_MOVE_SPEED: float = 1200.0            # カメラ移動速度（px/s）
```

### D-2. `start_unlock_focus()` の修正

既存の `start_unlock_focus()` を以下に置き換える。

```gdscript
func start_unlock_focus(unlocked_ids: Array, return_stage_id: int = -1) -> void:
    _focus_return_id = return_stage_id

    if unlocked_ids.is_empty():
        # 解放なし → 直前ステージへ即フォーカス
        if return_stage_id >= 0:
            _camera.position = StageSelectManager.get_world_pos(return_stage_id)
            _char_pos = _camera.position
            _char_target = _camera.position
        return

    # 時計回りにソート（return_stage_idを中心とした角度順）
    var center: Vector2 = Vector2.ZERO
    if return_stage_id >= 0:
        center = StageSelectManager.get_world_pos(return_stage_id)
    var sorted_ids: Array = unlocked_ids.duplicate()
    sorted_ids.sort_custom(func(a: int, b: int) -> bool:
        var pa: Vector2 = StageSelectManager.get_world_pos(a) - center
        var pb: Vector2 = StageSelectManager.get_world_pos(b) - center
        return -pa.angle() < -pb.angle()
    )

    _focus_queue = sorted_ids
    _is_focusing = true
    _focus_elapsed = 0.0
    _unlock_anim_stage = -1
```

### D-3. `_process_focus()` の修正

既存の `_process_focus()` を以下に置き換える。

```gdscript
func _process_focus(delta: float) -> void:
    # ぼよよん演出中
    if _unlock_anim_stage >= 0:
        _unlock_anim_elapsed += delta
        if not _unlock_anim_particles_spawned:
            _spawn_unlock_particles(StageSelectManager.get_world_pos(_unlock_anim_stage))
            _unlock_anim_particles_spawned = true
        if _unlock_anim_elapsed >= UNLOCK_ANIM_DURATION:
            _unlock_anim_stage = -1
            _unlock_anim_elapsed = 0.0
            _unlock_anim_particles_spawned = false
        queue_redraw()
        return

    if not _is_focusing or _focus_queue.is_empty():
        _is_focusing = false
        # 全ノードを巡り終えたら直前ステージへ戻る
        if _focus_return_id >= 0:
            var return_pos: Vector2 = StageSelectManager.get_world_pos(_focus_return_id)
            _camera.position = return_pos
            _char_pos = return_pos
            _char_target = return_pos
            _focus_return_id = -1
        return

    # カメラをリニア移動（lerp ではなく move_toward）
    var target_pos: Vector2 = StageSelectManager.get_world_pos(_focus_queue[0])
    _camera.position = _camera.position.move_toward(target_pos, FOCUS_MOVE_SPEED * delta)

    if _camera.position.distance_to(target_pos) < 2.0:
        # 到着 → ぼよよん演出開始
        _unlock_anim_stage = _focus_queue[0]
        _unlock_anim_elapsed = 0.0
        _unlock_anim_particles_spawned = false
        _focus_queue.pop_front()
        if _focus_queue.is_empty():
            _is_focusing = false
```

### D-4. ぼよよん演出の描画

`_draw()` 内のステージドット描画ループ内、各ドットを描画する直前に以下を追加する。

ステージドット描画ループ（`for i in range(...)`）内の `match state:` ブロックを以下のように修正する。

```gdscript
# ぼよよんアニメーション中のドット半径を計算
var draw_radius: float = _DOT_RADIUS
if i == _unlock_anim_stage and _unlock_anim_stage >= 0:
    var t: float = _unlock_anim_elapsed / UNLOCK_ANIM_DURATION
    # ぼよよん: 大→小→大（さっきより小さく）→小（さっきより大きく）
    var bounce: float
    if t < 0.25:
        bounce = lerp(1.0, 1.6, t / 0.25)
    elif t < 0.5:
        bounce = lerp(1.6, 0.8, (t - 0.25) / 0.25)
    elif t < 0.75:
        bounce = lerp(0.8, 1.2, (t - 0.5) / 0.25)
    else:
        bounce = lerp(1.2, 1.0, (t - 0.75) / 0.25)
    draw_radius = _DOT_RADIUS * bounce

match state:
    StageSelectManager.StageState.UNLOCKED:
        draw_circle(pos, draw_radius, _HOVER_COLOR if is_near else _UNLOCKED_COLOR)
    StageSelectManager.StageState.CLEARED:
        draw_circle(pos, draw_radius, _HOVER_COLOR if is_near else _CLEARED_COLOR)
        draw_circle(pos, draw_radius * 0.35, Color.WHITE)
```

### D-5. パーティクル生成関数の追加

`_spawn_bgm_particle()` の近くに以下を追加する。

```gdscript
func _spawn_unlock_particles(world_pos: Vector2) -> void:
    # ワールド座標をスクリーン座標に変換してパーティクルを生成
    var screen_pos: Vector2 = get_canvas_transform() * world_pos
    var p := CPUParticles2D.new()
    _bgm_canvas.add_child(p)
    p.position = screen_pos
    p.emitting = true
    p.one_shot = true
    p.explosiveness = 1.0
    p.amount = 12
    p.lifetime = 0.6
    p.spread = 180.0
    p.gravity = Vector2(0.0, 100.0)
    p.initial_velocity_min = 80.0
    p.initial_velocity_max = 180.0
    p.scale_amount_min = 3.0
    p.scale_amount_max = 6.0
    p.color = Color(0.95, 0.19, 0.32, 1.0)
    get_tree().create_timer(1.2).timeout.connect(func() -> void:
        if is_instance_valid(p):
            p.queue_free()
    )
```

### D-6. `start_unlock_focus()` の呼び出し元に `return_stage_id` を渡す

`start_unlock_focus()` が呼ばれている箇所を全て探し、第2引数に `StageSelectManager.last_played_stage_id` を渡すよう修正する。

### D-7. クリア後の接続ラインを即時反映

ステージが解放されると `get_connections()` の返す内容が変わるため、`_draw()` の接続ライン描画はそのままで動作する（追加実装不要）。

---

## 修正E：SE選択パネルをCtrl+クリック専用にする

**対象ファイル**: `scenes/stage_select.gd`

### E-1. クリック判定の修正

`_input()` 内の以下の既存コードを：

```gdscript
if _is_debug() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
    if _handle_dbg_sfx_click(event.position):
        return
```

以下に置き換える：

```gdscript
if _is_debug() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
    # SE選択パネルはCtrl+クリックのみ受け付ける
    if event.ctrl_pressed and _handle_dbg_sfx_click(event.position):
        return
```

### E-2. パネルにCtrl+クリックのガイドを表示

`_draw_dbg_sfx_panel()` 内、パネルのヘッダー描画の直後に以下を追加する。

```gdscript
# Ctrl+クリックのガイドテキストをパネル下部に表示
var pr: Rect2 = _dbg_panel_rect()
draw_string(_font, Vector2(pr.position.x + 4.0, pr.end.y - 4.0),
    "Ctrl+Click", HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 8.0, 10,
    Color(0.45, 0.72, 0.80, 0.8))
```

---

## 修正F：確認ポップアップ表示中に自キャラを非表示にする

**対象ファイル**: `scenes/stage_select.gd`

`_draw()` 内の自キャラ描画部分を以下に修正する。

```gdscript
# 自キャラ（ワールド座標・最前面）- ポップアップ表示中は非表示
if _popup_stage < 0 and not _esc_popup:
    draw_circle(_char_pos, _CHAR_RADIUS, _CHAR_COLOR)
    draw_circle(_char_pos, _CHAR_RADIUS * 0.55, _BG_COLOR)
```

---

## 注意事項

- 上記以外のコードは一切変更しないこと。
- 修正後に以下を目視確認すること：
  1. **A**: 進行リセット後はステージ00にフォーカス。クリア後に戻るとクリアしたステージにフォーカス
  2. **B**: チュートリアル三角形の天頂頂点が、ガイドの赤い点がギリギリ見える位置からスタートする
  3. **C**: LOCKEDステージが非表示。アバターがUNLOCKED/CLEAREDノードの範囲外に移動できない
  4. **D**: ステージクリア後、解放ノードへカメラがリニアに移動し、ぼよよん＋パーティクル演出が再生され、全ノード巡回後に直前ステージへ戻る
  5. **E**: SE選択パネルがCtrl+クリックでのみ操作でき、パネルにガイドが表示される
  6. **F**: 確認ポップアップ表示中に自キャラが非表示になる
