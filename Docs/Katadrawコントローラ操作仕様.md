# Katadraw コントローラ操作仕様（現行）

実装の一次情報は `scripts/input_handler.gd`。以下はその整理である。

---

## 1. 前提

| 項目 | 内容 |
|------|------|
| 対象ゲーム状態 | **playing** または **rules**（一部は rules 内の UI フォーカスでパッド処理を止める） |
| 選択 | パッド操作時は **常に 1 点選択**。未選択なら `_ensure_pad_selection` でカーソル最寄り等を選択 |
| 処理順 | **LB/RB のレイ束巡回**は **`_input` の `handle_pad_button` では行わず**、**`process_pad` 内**でレイ束を組んだ直後に実行（`_process` と `_input` の順序差で自動レイが上書きしないため） |

---

## 2. 主な定数（抜粋）

| 名前 | 値 | 意味 |
|------|-----|------|
| `PAD_RIGHT_STICK_DEADZONE` | 0.5 | 右スティック「倒している」判定（ベクトル長） |
| `PAD_LEFT_STICK_NEUTRAL_DEADZONE` | 0.15 | 左スティック「ニュートラル」 |
| `RIGHT_STICK_REDETECT_ANGLE_DEG` | 5° | 左スティック KATA 時の右スティック方向「再検出」、および自動レイの物理方向再検出 |
| `RIGHT_STICK_RAY_PIN_BREAK_ANGLE_DEG` | 15° | レイピン維持の許容／KATA・L/R ロック解除の角度目安 |
| `RIGHT_STICK_RAY_SHOULDER_CONE_HALF_ANGLE_DEG` | 22° | L/R 候補コリドーの半角（`ray_shoulder_corridor_max_perp_px`） |
| `RIGHT_STICK_RAY_SHOULDER_MIN_PERP_PX` | 4 | コリドー幅の下限（レイ近傍でゼロ幅にならない） |
| `PAD_RIGHT_STICK_SPEED` | 400 | A＋左スティックの移動速度係数（× スティック量 × delta） |
| `PAD_A_DPAD_SPEED` | 266.67 | A または右スティック＋十字の連続移動 |
| `PAD_CURSOR_SPEED` | 600 | パッドカーソル移動（他処理と併用） |

---

## 3. 右スティック（レイ選択）

### 3.1 基本

- **アクティブ**: `right_vec.length() >= PAD_RIGHT_STICK_DEADZONE`
- **レイ**: 全アンロック点の **重心** を原点に、**実効方向** `dir_for_ray` へ半直線
- **自動選択** `_select_point_by_direction_line`: 半直線の **手前側**（`along >= 0`）で **垂線距離最小** の点（同率は沿方向優先）
- **レイ束（L/R 用）** `_finalize_shoulder_ray_bundle` → `_collect_all_indices_in_ray_shoulder_corridor`: **`_point_is_in_ray_shoulder_corridor`** を満たす**全頂点**を集め、**沿距離昇順**。多角形の辺でつながらない頂点も含める（可視ガイドと一致）

### 3.2 倒しっぱなし：自動レイは「成功時 1 回」

- **`_right_stick_ray_auto_select_done`**: この倒しの間に自動レイが成功したら `true`
- 以降のフレームは **`hold_grab_only`** に相当し、**毎フレーム `select_line` は呼ばない**（つかみ維持のみ）
- **再び**自動レイが必要な例: 物理スティックが前回から **約 5° 以上**変化、**ピン解除**、`_clear_right_stick_ray_state`、左スティック KATA 由来の **direction_changed** 等

### 3.3 ピン（レイ方向固定）

- KATA 中・L/R 後・DPad 連続移動中などで **`_right_stick_ray_pinned`** が立つことがある
- ピン中は **`dir_for_ray`** が **ロック方向**（物理が大きく動くまで）
- 物理がロック方向から **15° 超**でピン解除し、**`_right_stick_ray_auto_select_done` も false** に戻す場合あり

### 3.4 つかみ

- 右スティック **アクティブ中**は毎フレーム **`pad_grabbing` / `is_dragging` / `_grabbing_from_right_stick`** を維持

---

## 4. LB / RB（レイ延長線上／付近の候補のみ）

候補は **`_collect_all_indices_in_ray_shoulder_corridor`** で全頂点を走査し、**`_point_is_in_ray_shoulder_corridor`** を満たすものだけを束に入れる。**(1) along≥0**、**(2) レイへの垂線距離が `ray_shoulder_corridor_max_perp_px(along)` 以下** — 半角 `RIGHT_STICK_RAY_SHOULDER_CONE_HALF_ANGLE_DEG` の円錐に近いが、近傍は **`RIGHT_STICK_RAY_SHOULDER_MIN_PERP_PX`** を下限とし、**重心からレイ沿いに離れるほど許容幅が広がる**。右スティック可視化時は **`_draw_right_stick_shoulder_corridor_guide`** でその扇形を薄い赤で表示する。

最終的に重心からの半直線方向への **沿距離（along）で昇順**（内側→外側）に並べ、**その列の中だけ**を LB/RB で移動する。

例: **A（内）・B・C（外）** が同一束にあるとき、

- **RB**: **…→C→B→A→C→…**（外に向かって進み、最も内側の次は最も外側へループ）
- **LB**: **…→B→C→A→B→…**（内に向かって進み、ループ）

- **束が 1 点だけ**のときは **移動なし**（多角形全体には飛ばない）

### 4.1 `process_pad` 内（本流・右スティック アクティブ時）

1. 重心・`dir_for_ray` から **`_right_stick_ray_bundle` を構築**
2. **ショルダーの押し始めエッジ**で **`_cycle_ray_bundle(1)`（LB）** / **`_cycle_ray_bundle(-1)`（RB）**（内部は `_cycle_ray_bundle_core`）
3. **`_apply_ray_selection` + L/R 選択ロック**（`_rs_lr_selection_lock`）。**ref の参照は実効レイ** `dir_for_ray` と揃える
4. **同一フレームでショルダーが押されている場合**は **L/R ロック解除を実行しない**
5. **ロック解除**（ショルダー非エッジ時）: 実効レイと ref の **dot ＜ cos(15°)** なら解除

### 4.2 `handle_pad_button`（補助）

- **右スティック中の LB/RB は `process_pad` のみ**（上記）
- **`use_ray_bundle_for_shoulder` でない**かつ **右スティック文脈でない**とき: まず **`_try_shoulder_cycle_ray_bundle_from_saved_ray`**（`_right_stick_last_effective_ray_dir` が残っていれば同じ束定義で巡回）。**レイ情報が無い**ときだけ **`_cycle_polygon_ring_adjacent`**（多角形の前後）にフォールバック
- **右スティック文脈**では **`handle_pad_button` からは巡回しない**（`select_line` がレイ最良点へ戻す不具合を防ぐ）

---

## 5. ロック（自動レイを上書きしない）

| フラグ | 目的 | 解除の目安（概要） |
|--------|------|-------------------|
| `_rs_kata_grab_lock` | KATA 後、左・十字ニュートラルかつ右スティックが ref から 15° 超動くまで **自動レイで掴みを変えない** | `right_active` 内の条件、または **右スティック非アクティブ時に毎フレーム false**（離し後の残留防止） |
| `_rs_lr_selection_lock` | L/R 後、実効レイが 15° 動くか次の L/R まで **自動レイで選択を変えない** | `process_pad` 内の dot 条件、**右スティック離し後 2 フレーム経過で false**（短いデッドゾーン抜け対策） |

**`block_auto`** = 上記いずれかが true のとき、**自動レイ**・**ピン同期**のうち **自動レイはスキップ**（`pass`）。**`_cycle_ray_bundle` は `block_auto` より前に実行**される。

---

## 6. 右スティックを離したあと（`elif _right_stick_was_active`）

`right_active` が false だが、直前まで右スティックを使っていた場合。

| タイミング | 処理 |
|------------|------|
| 毎フレーム（非アクティブ） | `_rs_kata_grab_lock = false`、`debug_right_stick_active = false`、リリースカウンタ加算 |
| 2 フレーム経過 | `_rs_lr_selection_lock = false` |
| 4 フレーム経過 | `_right_stick_was_active` 解除、`_clear_right_stick_ray_state()`、条件付きでつかみ解除 |

短いデッドゾーン抜けでは 4 フレームに達しにくく、**完全クリア**まで待てる。

---

## 7. その他の入力

| 操作 | 内容 |
|------|------|
| **A ＋左スティック**（`pad_grabbing_modifier` かつ左入力） | 選択点を **KATA 変形**（連続移動）。右スティック掴み中に KATA するとレイピン・KATA ロックの更新あり |
| **A または右スティック ＋十字** | 十字方向へ **連続移動**（`PAD_A_DPAD_SPEED`）。右スティック＋十字でも KATA ロック条件が似た流れで更新される |
| **十字のみ**（つかみ修飾なし） | 多角形の接続に沿い、**入力方向に最も近い辺**へ `_cycle_pad_point_direction` |
| **左のみ**（A/右スティックなし） | **中立→傾き**の一度だけ、カーディナル方向へ `_cycle_pad_point_direction` |

**`grab_input_active`**: `pad_grabbing_modifier`（A または右スティックアクティブ）またはマウスドラッグ等、実装末尾で更新。

---

## 8. デバッグ

- `DEBUG_PAD_RAY_LR` を `true` にすると **`[PadRayLR]`** ログ（レイ束・`branch`・ショルダーエッジ等）
- 調査後は **`false`** 推奨

**ログの読み方（例）**

- `branch=select_line` … そのフレーム `_select_point_by_direction_line` が動いた  
- `branch=hold_grab_only` … 倒しっぱなしで既に自動レイ済み、つかみのみ  
- `branch=block_auto` … KATA または L/R ロックで自動レイスキップ  
- `shL` / `shR` … そのフレームのショルダー **押し始めエッジ**

---

## 9. 変更履歴メモ（仕様としての注意）

- 実装・数値は `input_handler.gd` が正。本ドキュメントは追従用に過ぎない。
