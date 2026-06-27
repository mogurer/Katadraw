# KATADRAW ステージセレクト 仕様変更 実装指示

## 前提・参照ファイル

以下の2つの仕様書を必ず参照すること。

- `ステージセレクト仕様.md` — 現行仕様（変更しない項目の定義元）
- `ステージセレクト新仕様.md` — 新仕様（今回の変更内容の定義元）

対象ファイルは以下の2つ。

- `scenes/stage_select.gd`
- `scripts/StageSelectManager.gd`

---

## 実装方針

現行実装を**段階的に置き換える**形で進めること。  
変更しない項目（新仕様書「セクション7」に列挙）は既存コードを維持する。  
変更対象のみを以下の順序で実装すること。

---

## Step 1: manifest.json の作成

`res://data/manifest.json` を新規作成する。

### 構造

```json
{
  "stages": [
    { "id": 0,  "connections": [1],          "grid_pos": [1, 10], "y_offset": 0 },
    { "id": 1,  "connections": [2],          "grid_pos": [0, 11], "y_offset": 0 },
    { "id": 2,  "connections": [3],          "grid_pos": [0,  9], "y_offset": 0 },
    { "id": 3,  "connections": [4, 5],       "grid_pos": [0,  7], "y_offset": 0 },
    { "id": 4,  "connections": [3, 5, 6],    "grid_pos": [0,  5], "y_offset": 0 },
    { "id": 5,  "connections": [4, 6, 7, 8], "grid_pos": [1,  6], "y_offset": 0 },
    { "id": 6,  "connections": [5, 8, 9],    "grid_pos": [1,  4], "y_offset": 0 },
    { "id": 7,  "connections": [5, 8, 12, 13],  "grid_pos": [2,  7], "y_offset": 0 },
    { "id": 8,  "connections": [6, 7, 9, 13],   "grid_pos": [2,  5], "y_offset": 0 },
    { "id": 9,  "connections": [6, 8, 14],       "grid_pos": [2,  3], "y_offset": 0 },
    { "id": 10, "connections": [11, 15],          "grid_pos": [3, 12], "y_offset": 0 },
    { "id": 11, "connections": [10, 12, 15],      "grid_pos": [3, 10], "y_offset": 0 },
    { "id": 12, "connections": [11, 13, 16],      "grid_pos": [3,  8], "y_offset": 0 },
    { "id": 13, "connections": [7, 12, 16, 17],   "grid_pos": [3,  6], "y_offset": 0 },
    { "id": 14, "connections": [9, 18, 19],        "grid_pos": [3,  2], "y_offset": 0 },
    { "id": 15, "connections": [10, 11, 20, 21],   "grid_pos": [4, 11], "y_offset": 0 },
    { "id": 16, "connections": [12, 13, 17, 22, 23], "grid_pos": [4,  7], "y_offset": 0 },
    { "id": 17, "connections": [13, 16, 18, 23, 24], "grid_pos": [4,  5], "y_offset": 0 },
    { "id": 18, "connections": [14, 17, 19, 24, 25], "grid_pos": [4,  3], "y_offset": 0 },
    { "id": 19, "connections": [14, 18, 25],          "grid_pos": [4,  1], "y_offset": 0 },
    { "id": 20, "connections": [15, 21],              "grid_pos": [5, 12], "y_offset": 0 },
    { "id": 21, "connections": [20, 22, 26],          "grid_pos": [5, 10], "y_offset": 0 },
    { "id": 22, "connections": [21, 23, 26, 27],      "grid_pos": [5,  8], "y_offset": 0 },
    { "id": 23, "connections": [22, 24, 27, 28],      "grid_pos": [5,  6], "y_offset": 0 },
    { "id": 24, "connections": [23, 25, 28, 29],      "grid_pos": [5,  4], "y_offset": 0 },
    { "id": 25, "connections": [24, 29],              "grid_pos": [5,  2], "y_offset": 0 },
    { "id": 26, "connections": [21, 22, 27, 30, 31],  "grid_pos": [6,  9], "y_offset": 0 },
    { "id": 27, "connections": [22, 23, 26, 28, 31],  "grid_pos": [6,  7], "y_offset": 0 },
    { "id": 28, "connections": [23, 24, 27, 29, 32],  "grid_pos": [6,  5], "y_offset": 0 },
    { "id": 29, "connections": [24, 25, 28, 32, 33],  "grid_pos": [6,  3], "y_offset": 0 },
    { "id": 30, "connections": [26, 31, 34],           "grid_pos": [7, 10], "y_offset": 0 },
    { "id": 31, "connections": [26, 27, 30, 34, 35],   "grid_pos": [7,  8], "y_offset": 0 },
    { "id": 32, "connections": [28, 29, 33, 36, 37],   "grid_pos": [7,  4], "y_offset": 0 },
    { "id": 33, "connections": [29, 32, 37],            "grid_pos": [7,  2], "y_offset": 0 },
    { "id": 34, "connections": [30, 31, 35, 39, 40],   "grid_pos": [8,  9], "y_offset": 0 },
    { "id": 35, "connections": [31, 34, 36, 40, 41],   "grid_pos": [8,  7], "y_offset": 0 },
    { "id": 36, "connections": [32, 35, 37, 41, 42],   "grid_pos": [8,  5], "y_offset": 0 },
    { "id": 37, "connections": [32, 33, 36, 42],        "grid_pos": [8,  3], "y_offset": 0 },
    { "id": 38, "connections": [39, 43],                "grid_pos": [9, 12], "y_offset": 0 },
    { "id": 39, "connections": [38, 40, 43],            "grid_pos": [9, 10], "y_offset": 0 },
    { "id": 40, "connections": [34, 35, 39, 41, 44],   "grid_pos": [9,  8], "y_offset": 0 },
    { "id": 41, "connections": [35, 36, 40, 42, 44, 45], "grid_pos": [9,  6], "y_offset": 0 },
    { "id": 42, "connections": [36, 37, 41, 45],        "grid_pos": [9,  4], "y_offset": 0 },
    { "id": 43, "connections": [38, 39, 46, 47],        "grid_pos": [10, 11], "y_offset": 0 },
    { "id": 44, "connections": [40, 41, 45, 48, 49],   "grid_pos": [10,  7], "y_offset": 0 },
    { "id": 45, "connections": [41, 42, 44, 49],        "grid_pos": [10,  5], "y_offset": 0 },
    { "id": 46, "connections": [43, 47],                "grid_pos": [11, 12], "y_offset": 0 },
    { "id": 47, "connections": [43, 46, 48],            "grid_pos": [11, 10], "y_offset": 0 },
    { "id": 48, "connections": [44, 47, 49],            "grid_pos": [11,  8], "y_offset": 0 },
    { "id": 49, "connections": [44, 45, 48],            "grid_pos": [11,  6], "y_offset": 0 }
  ],
  "bgm_unlock_zones": [
    { "required_stages": [8, 9, 13, 14, 17, 18], "unlocks_bgm": "BGM_TBD_1" },
    { "required_stages": [11, 12, 15, 16, 21, 22], "unlocks_bgm": "BGM_TBD_2" },
    { "required_stages": [27, 28, 31, 32, 35, 36], "unlocks_bgm": "BGM_TBD_3" },
    { "required_stages": [39, 40, 43, 44, 47, 48], "unlocks_bgm": "BGM_TBD_4" }
  ]
}
```

---

## Step 2: StageSelectManager.gd の変更

### 2-1. manifest.json の読み込み

起動時に `res://data/manifest.json` を読み込み、以下のデータを内部に保持する。

- `_connections: Dictionary` — `{ id: [隣接id, ...] }` の形式
- `_grid_pos: Dictionary` — `{ id: Vector2i(col, row) }` の形式
- `_y_offset: Dictionary` — `{ id: float }` の形式
- `_bgm_zones: Array` — BGM解禁ゾーンの配列

### 2-2. ノード座標の計算

以下の定数と計算式でワールド座標を算出する。

```gdscript
const X_PITCH: float = 200.0  # 調整可能な定数
const SQRT3: float = 1.7320508

func get_world_pos(stage_id: int) -> Vector2:
    var gp: Vector2i = _grid_pos[stage_id]
    var x: float = gp.x * X_PITCH
    var y: float = gp.y * X_PITCH * SQRT3
    y += _y_offset[stage_id]
    return Vector2(x, y)
```

### 2-3. 解放ロジックの変更

現行の「上下左右4方向グリッド解放」を廃止し、以下に置き換える。

```gdscript
func mark_cleared(stage_id: int) -> void:
    _states[stage_id] = CLEARED
    for nb_id in _connections[stage_id]:
        if _states.get(nb_id, LOCKED) == LOCKED:
            _states[nb_id] = UNLOCKED
    _save()
```

ただし **一本道ゾーン（id: 0〜3）** は以下の制約を追加する。

- id=0 クリア時: id=1 のみ解放（接続リストの他のノードは解放しない）
- id=1 クリア時: id=2 のみ解放
- id=2 クリア時: id=3 のみ解放
- id=3 以降: 通常の接続リストに従う

```gdscript
const _LINEAR_ZONE: Dictionary = { 0: [1], 1: [2], 2: [3] }

func mark_cleared(stage_id: int) -> void:
    _states[stage_id] = CLEARED
    var unlock_targets: Array = _linear_zone.get(stage_id, _connections[stage_id])
    for nb_id in unlock_targets:
        if _states.get(nb_id, LOCKED) == LOCKED:
            _states[nb_id] = UNLOCKED
    _save()
```

### 2-4. get_connections() の変更

```gdscript
func get_connections() -> Array:
    # [[a, b], ...] 形式の隣接ペア一覧を返す（重複なし）
    var result: Array = []
    var seen: Dictionary = {}
    for id in _connections:
        for nb in _connections[id]:
            var key = [min(id, nb), max(id, nb)]
            var key_str = "%d_%d" % [key[0], key[1]]
            if not seen.has(key_str):
                seen[key_str] = true
                result.append(key)
    return result
```

### 2-5. BGM解禁チェックの追加

```gdscript
func check_bgm_unlocks() -> Array:
    # 新たに解禁されたBGM名の配列を返す
    var newly_unlocked: Array = []
    for zone in _bgm_zones:
        var bgm_name: String = zone["unlocks_bgm"]
        if _unlocked_bgms.has(bgm_name):
            continue
        var all_cleared: bool = true
        for sid in zone["required_stages"]:
            if _states.get(sid, LOCKED) != CLEARED:
                all_cleared = false
                break
        if all_cleared:
            _unlocked_bgms.append(bgm_name)
            newly_unlocked.append(bgm_name)
    if newly_unlocked.size() > 0:
        _save()
    return newly_unlocked
```

`_unlocked_bgms` は `stage_select_state.json` に `"unlocked_bgms": ["BGM_TBD_1", ...]` として永続化する。

---

## Step 3: stage_select.gd の変更

### 3-1. ワールド座標系への移行

現行の画面座標直接描画をやめ、**ワールド座標系** でノードを管理する。  
Godot の `Camera2D` ノードをシーンに追加し、以下の設定を行う。

- `Camera2D.zoom` の初期値: `Vector2(0.25, 0.25)`（実装後に調整）
- `Camera2D.position_smoothing_enabled`: `false`（スクロールは手動制御）

### 3-2. グリッド構成の廃止

現行の以下の定数・変数を削除する。

```gdscript
# 削除対象
const COLS = 10
const ROWS = 5
var _positions: Array  # 旧グリッド座標
```

代わりに `StageSelectManager.get_world_pos(id)` を使用してノード座標を取得する。

### 3-3. カメラ追従の実装

`_process(delta)` 内に以下のカメラ追従ロジックを追加する。

```gdscript
const SCROLL_MARGIN: float = 0.20  # 画面端20%
const SCROLL_SPEED: float = 800.0  # px/s（調整可能）

func _update_camera(delta: float) -> void:
    var cam: Camera2D = $Camera2D
    var viewport_size: Vector2 = get_viewport_rect().size
    var cam_zoom: Vector2 = cam.zoom
    # ワールド座標でのビューポート半サイズ
    var half_view: Vector2 = viewport_size / 2.0 / cam_zoom
    var margin: Vector2 = half_view * 2.0 * SCROLL_MARGIN

    # アバターのワールド座標
    var avatar_world: Vector2 = _char_pos

    # カメラ座標系でのアバター相対位置
    var rel: Vector2 = avatar_world - cam.position
    var scroll: Vector2 = Vector2.ZERO

    if rel.x < -half_view.x + margin.x:
        scroll.x = -1.0
    elif rel.x > half_view.x - margin.x:
        scroll.x = 1.0
    if rel.y < -half_view.y + margin.y:
        scroll.y = -1.0
    elif rel.y > half_view.y - margin.y:
        scroll.y = 1.0

    if scroll != Vector2.ZERO:
        cam.position += scroll.normalized() * SCROLL_SPEED * delta
```

### 3-4. ステージ解放演出（カメラフォーカス）の実装

ステージクリア後、以下のシーケンスを実行する。

```gdscript
var _focus_queue: Array = []      # フォーカスするステージIDのキュー
var _is_focusing: bool = false    # フォーカス演出中フラグ
const FOCUS_DURATION: float = 0.8  # 1ノードあたりのフォーカス時間（秒）
const FOCUS_LERP: float = 5.0      # カメラ移動の補間係数

func start_unlock_focus(unlocked_ids: Array) -> void:
    _focus_queue = unlocked_ids.duplicate()
    _is_focusing = true

func _process_focus(delta: float) -> void:
    if not _is_focusing or _focus_queue.is_empty():
        _is_focusing = false
        return

    var target_id: int = _focus_queue[0]
    var target_pos: Vector2 = StageSelectManager.get_world_pos(target_id)
    var cam: Camera2D = $Camera2D
    cam.position = cam.position.lerp(target_pos, FOCUS_LERP * delta)

    if cam.position.distance_to(target_pos) < 5.0:
        _focus_queue.pop_front()
        if _focus_queue.is_empty():
            # 全ノードを巡り終わった → アバター位置に戻る
            _is_focusing = false
```

`_process()` 内で `_is_focusing` が `true` の間はカメラ追従を無効にし、`_process_focus()` を呼ぶ。

### 3-5. 描画の変更

`_draw()` 内の座標取得を以下に変更する。

```gdscript
# 旧: _positions[i] で直接座標取得
# 新: StageSelectManager.get_world_pos(i) で取得

func _get_dot_draw_pos(stage_id: int) -> Vector2:
    var base: Vector2 = StageSelectManager.get_world_pos(stage_id)
    # ぷるぷるアニメーション（現行のサイン波ロジックをそのまま維持）
    base.y += sin(_elapsed * _anim_freq[stage_id] + _anim_phase[stage_id]) * _anim_amp[stage_id]
    return base
```

接続ラインの描画も `get_connections()` の返却値をそのまま使用する（現行と同様）。

### 3-6. アバターの移動クランプ範囲の変更

現行の画面範囲クランプをワールド座標範囲に変更する。  
クランプ範囲はノードの最小・最大ワールド座標から自動計算する。

```gdscript
func _calc_world_bounds() -> Rect2:
    var min_x: float = INF
    var min_y: float = INF
    var max_x: float = -INF
    var max_y: float = -INF
    for i in range(50):
        var pos: Vector2 = StageSelectManager.get_world_pos(i)
        min_x = min(min_x, pos.x)
        min_y = min(min_y, pos.y)
        max_x = max(max_x, pos.x)
        max_y = max(max_y, pos.y)
    var margin: float = 200.0
    return Rect2(min_x - margin, min_y - margin,
                 max_x - min_x + margin * 2,
                 max_y - min_y + margin * 2)
```

---

## Step 4: 変更しない項目の確認

以下は**一切変更しないこと**。既存コードをそのまま維持する。

- 背景色・接続ライン色・接続ライン幅
- ステージドットの色定義（LOCKED / UNLOCKED / CLEARED / HOVER）・半径
- ドットのぷるぷるアニメーション（パラメータ含む）
- 「STAGE / SELECT」ロゴの描画（ただしワールド座標ではなく画面固定で描画を維持）
- 自キャラの外見・移動操作（速度・補間係数含む）
- 入力操作全般
- 近接判定・吹き出し（バブル）の全仕様
- 確認ポップアップ・ESCポップアップの全仕様
- BGM切り替えUI・テキスト演出
- SE仕様（音量含む）
- `StageSelectManager` 公開APIのシグネチャ（内部実装は変更する）
- デバッグ機能（ゾウドット・SE選択パネル）
- 描画順序

---

## 注意事項

- `X_PITCH = 200.0` は仮の値。実装後にズーム倍率と合わせて調整すること。
- `Camera2D.zoom` の初期値も実装後に調整すること。目安は「画面に3列×5行程度が見える状態」。
- `manifest.json` の `y_offset` は現時点では全て `0`。実装後に視覚確認しながら調整する。
- BGMゾーンの `unlocks_bgm` の値（`"BGM_TBD_1"` 等）は後日確定する。現時点では定義のみ行い、解禁チェックロジックのみ実装すること。
- エクストラステージ（id: 50）は今回の実装対象外。
EOF
