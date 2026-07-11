# ステージセレクト改修チェックリスト

実装日：2026-07-05  
対象ブランチ：pin

---

## 変更1：Zou ステージ配置 [1, 8]

### data/manifest.json · data/stage_select_manifest.json
- [ ] `bgm_unlock_zones[0].unlocks_bgm` が `"01-06"` になっている
- [ ] `bgm_unlock_zones[1].unlocks_bgm` が `"01-08"` になっている
- [ ] `bgm_unlock_zones[2].unlocks_bgm` が `"02-03"` になっている
- [ ] `bgm_unlock_zones[3].unlocks_bgm` が `"02-09"` になっている
- [ ] 各ゾーンに `center_grid_pos` が追加されている（`[3,4]` / `[4,9]` / `[7,6]` / `[10,9]`）
- [ ] manifest.json と stage_select_manifest.json の内容が一致している

### scripts/StageSelectManager.gd
- [ ] `get_grid_world_pos(col, row, y_offset)` 関数が追加されている
- [ ] `_bgm_zone_centers: Array[Vector2]` 変数が追加されている
- [ ] `_load_manifest()` 内で `_bgm_zone_centers` が `center_grid_pos` から構築される
- [ ] `get_bgm_zone_centers()` 関数が追加されている
- [ ] `get_unlocked_bgm_ids()` 関数が追加されている

### scenes/stage_select.gd
- [ ] `_zou_world_pos` の計算が `get_grid_world_pos(1, 8)` に変更されている（旧: stage 28 と 35 の中点）
- [ ] Zou ドットがマップ上の正しい位置（00・02・03・05・07 に囲まれた中心付近）に表示される
- [ ] `zou_cleared` 状態でステージセレクトに入ったとき、キャラが Zou 位置に配置される

---

## 変更2：BGM 解放ゾーン（青い点・線・パーティクル）

### scripts/bgm/BGMManager.gd
- [ ] `_BGM_ID_TO_TRACK_IDX` 定数が追加されている（`"01-06":1` / `"01-08":2` / `"02-03":3` / `"02-09":4`）
- [ ] `_unlocked_track_indices: PackedInt32Array` 変数が追加され、初期値が `[0]`
- [ ] `set_unlocked_bgm_ids(ids)` 関数：渡された ID リストに対応するインデックスのみ有効にする
- [ ] `set_unlocked_bgm_ids()` 呼び出し後、現在のトラックが解放済みでなければ 0 にリセットされる
- [ ] `unlock_bgm(bgm_id)` 関数：新トラックを解放し、即座にそのトラックで再生する
- [ ] `get_unlocked_track_count()` 関数：解放済みトラック数を返す
- [ ] `select_next_bgm()` が解放済みトラックのみをサイクルする
- [ ] `select_prev_bgm()` が解放済みトラックのみをサイクルする

### scenes/stage_select.gd
- [ ] `_BGM_ZONE_COLOR = Color("#4477CC")` 定数が追加されている
- [ ] `_BGM_ZONE_DOT_RADIUS = _DOT_RADIUS * 1.5` 定数が追加されている
- [ ] `_draw()` のワールド座標レイヤーで青い点が4ヶ所に描画される（常時表示）
- [ ] クリア済みステージから青点中心への青い線が描画される（CLEARED になるたびに増える）
- [ ] `_ready()` で `BGMManager.set_unlocked_bgm_ids()` が呼ばれ BGM 状態が同期される
- [ ] `_ready()` で `check_bgm_unlocks()` を呼び、新たに解放されたゾーンがあればパーティクルが発生する
- [ ] `_ready()` で `BGMManager.unlock_bgm()` が呼ばれ即座に新トラックへ切り替わる
- [ ] `_spawn_bgm_unlock_particles(world_pos)` 関数が追加されている（青色・60粒子・1.2s）
- [ ] `_get_zone_idx_for_bgm(bgm_id)` ヘルパーが追加されている

### 動作確認（BGM 解放）
- [ ] ゲーム開始直後は BGM が 01-05 のみ選択可能（矢印ボタンが非表示）
- [ ] ゾーン1の6ステージ（8,9,13,14,17,18）をすべてクリアすると 01-06 が解放される
- [ ] ゾーン2の6ステージ（11,12,15,16,21,22）をすべてクリアすると 01-08 が解放される
- [ ] ゾーン3の6ステージ（27,28,31,32,35,36）をすべてクリアすると 02-03 が解放される
- [ ] ゾーン4の6ステージ（39,40,43,44,47,48）をすべてクリアすると 02-09 が解放される
- [ ] ゾーン完成時にパーティクルが青点位置で発生する
- [ ] ゾーン完成時に即座に新トラックへ切り替わる
- [ ] 解放状態はセーブ/ロードをまたいで維持される
- [ ] ゲーム再起動後も解放済みトラックのみ選択可能になっている
- [ ] ゾーンをスキップして完成させた場合（例：ゾーン3が先）でも正しく動作する

---

## 変更3：BGM 選択 UI（拡大パネル）

### scenes/stage_select.gd
- [ ] `_bgm_expanded_panel: PanelContainer` 変数が追加されている
- [ ] `_bgm_expanded_prev_btn / _bgm_expanded_next_btn / _bgm_expanded_name_label` 変数が追加されている
- [ ] `_bgm_right_click_held / _bgm_x_btn_held / _bgm_expanded / _bgm_expand_tween` 変数が追加されている
- [ ] `_bgm_lr_collapse_timer: float = -1.0` 変数が追加されている
- [ ] `_setup_bgm_ui()` 内で拡大パネルが画面中央に生成される（初期状態 `visible = false`）
- [ ] 拡大パネルの `resized` シグナルで `pivot_offset` と `position` が自動補正される
- [ ] `_bgm_do_expand()` 関数：0.15s スケール 0.25→1.0 + alpha 0→1 アニメーション
- [ ] `_bgm_do_collapse()` 関数：0.15s 逆アニメーション → `visible = false`
- [ ] `_bgm_update_expanded_label()` 関数：拡大パネルの曲名と矢印表示を更新

### 操作（拡大パネル）
- [ ] 右クリック保持中は拡大パネルが表示される
- [ ] 右クリックを離すと即座に収納される
- [ ] コントローラ X ボタン保持中は拡大パネルが表示される
- [ ] X ボタンを離すと即座に収納される
- [ ] L/R または Q/E 押下で 0.5s だけ拡大パネルが表示される
- [ ] L/R または Q/E を連打するたびにタイマーがリセットされる（最後の押下から 0.5s 後に収納）
- [ ] 右クリック保持中に L/R で BGM を変更できる
- [ ] 解放トラックが 1 種類だけの場合は右クリック・X ボタンで拡大しない
- [ ] 解放トラックが 1 種類だけの場合は矢印ボタンが非表示になる
- [ ] `_process()` の L/R タイマー処理が正常に動作している

---

## 変更4：入力モード自動切替

### scenes/stage_select.gd
- [ ] `_input_mode: int = 0`（0=KBM、1=コントローラ）変数が追加されている
- [ ] `_set_input_mode(mode)` 関数が追加されている（変化がなければ早期 return）
- [ ] `_update_bgm_button_labels()` 関数が追加されている
- [ ] `_input()` 冒頭でイベント型を見てモードが自動切替される
- [ ] Q/E キー押下で BGM prev/next が動作する（`_input()` 内）
- [ ] コントローラ Start ボタンで ESC ポップアップが開く（`_input()` 内）

### ガイドテキスト（左下）
- [ ] KBM モード時：`ESC: タイトルへ戻る`
- [ ] コントローラモード時：`Start: タイトルへ戻る`
- [ ] モード切替時に `queue_redraw()` が呼ばれ即座に更新される

### BGM ボタンラベル
- [ ] KBM モード時：`◀[Q]` / `[E]▶`
- [ ] コントローラモード時：`◀[L]` / `[R]▶`
- [ ] 初期状態（KBM モード）でボタンが `◀[Q]` / `[E]▶` になっている
- [ ] コントローラでボタン操作すると `◀[L]` / `[R]▶` に切り替わる
- [ ] 拡大パネルのボタンラベルも同期して切り替わる

### 動作確認（総合）
- [ ] マウスクリック → KBM モード → `ESC: タイトルへ戻る` + `◀[Q]` / `[E]▶`
- [ ] コントローラボタン → コントローラモード → `Start: タイトルへ戻る` + `◀[L]` / `[R]▶`
- [ ] Q キーで BGM が前へ変わる（01-06 以上解放済みの場合）
- [ ] E キーで BGM が次へ変わる（01-06 以上解放済みの場合）
- [ ] コントローラ Start ボタンで「タイトルへ戻る」確認ポップアップが開く
- [ ] Start → はい → タイトルへ遷移する
- [ ] Start → いいえ → ポップアップが閉じる
