# KATADRAW ステージセレクト 修正指示（ステージ解放演出 修正D）

## 修正の概要

ステージクリア後にステージセレクトへ戻ったとき、新たに解放されたステージを
順番にフォーカスしながら出現演出を行う。

修正は以下の3ファイルにまたがる。

1. `scripts/StageSelectManager.gd` — 解放IDの橋渡し変数を追加
2. `scripts/game.gd` — 解放IDを記録する処理を追加
3. `scenes/stage_select.gd` — 演出の全実装

---

## 修正1: `scripts/StageSelectManager.gd`

### 1-1. 橋渡し変数の追加

`last_played_stage_id` の宣言の直下に追加する：

```gdscript
# 直前クリアで新たに解放されたステージIDの一時保持（ステージセレクト画面が読み取り次第クリア）
var last_unlocked_ids: Array[int] = []
```

### 1-2. `mark_cleared()` で解放IDを記録する

以下の既存コードを：

```gdscript
func mark_cleared(stage_id: int) -> void:
	if stage_id < 0 or stage_id >= STAGE_COUNT:
		return
	_states[stage_id] = StageState.CLEARED
	# 一本道ゾーンは専用リスト、それ以外は接続リストを使う
	var unlock_targets: Array = _LINEAR_ZONE.get(stage_id, _connections.get(stage_id, []))
	for nb_id in unlock_targets:
		if nb_id >= 0 and nb_id < _states.size() and _states[nb_id] == StageState.LOCKED:
			_states[nb_id] = StageState.UNLOCKED
	_save_states()
```

以下に置き換える：

```gdscript
func mark_cleared(stage_id: int) -> void:
	if stage_id < 0 or stage_id >= STAGE_COUNT:
		return
	_states[stage_id] = StageState.CLEARED
	# 一本道ゾーンは専用リスト、それ以外は接続リストを使う
	var unlock_targets: Array = _LINEAR_ZONE.get(stage_id, _connections.get(stage_id, []))
	last_unlocked_ids.clear()
	for nb_id in unlock_targets:
		if nb_id >= 0 and nb_id < _states.size() and _states[nb_id] == StageState.LOCKED:
			_states[nb_id] = StageState.UNLOCKED
			last_unlocked_ids.append(nb_id)
	_save_states()
```

---

## 修正2: `scripts/game.gd`

変更不要。`mark_cleared()` の呼び出しはそのまま維持する。

---

## 修正3: `scenes/stage_select.gd`

### 3-1. 定数の追加

既存の `FOCUS_DURATION` / `FOCUS_LERP` の近くに追加する：

```gdscript
const FOCUS_MOVE_SPEED: float = 1200.0    # カメラ移動速度（px/s、リニア）
const UNLOCK_ANIM_DURATION: float = 0.5   # ぼよよん演出の長さ（秒）
const UNLOCK_LINE_FADE_DURATION: float = 0.3  # 接続ライン出現フェードイン時間（秒）
```

### 3-2. 変数の追加

既存の `_focus_return_id` の近くに追加する：

```gdscript
# --- ステージ解放演出 ---
var _unlock_anim_stage: int = -1              # 現在ぼよよん演出中のステージID
var _unlock_anim_elapsed: float = 0.0         # ぼよよん演出の経過時間
var _unlock_source_stage: int = -1            # 解放元（クリアした）ステージID
# 接続ライン出現演出: { [min_id, max_id] -> elapsed }
var _line_fade_progress: Dictionary = {}
```

### 3-3. `_ready()` に解放演出の起動を追加

`_ready()` 内の末尾（`_start_bgm_label_anim.call_deferred()` の直前）に追加する：

```gdscript
	# 直前クリアで解放されたステージがあれば演出を開始する
	var unlocked: Array[int] = StageSelectManager.last_unlocked_ids.duplicate()
	StageSelectManager.last_unlocked_ids.clear()
	var return_id: int = StageSelectManager.last_played_stage_id
	_unlock_source_stage = return_id
	start_unlock_focus(unlocked, return_id)
```

### 3-4. `start_unlock_focus()` の修正

以下の既存関数を置き換える：

```gdscript
func start_unlock_focus(unlocked_ids: Array, return_stage_id: int = -1) -> void:
	_focus_return_id = return_stage_id
	if unlocked_ids.is_empty():
		if return_stage_id >= 0:
			_camera.position = StageSelectManager.get_world_pos(return_stage_id)
			_char_pos = _camera.position
			_char_target = _camera.position
		return
	# 時計回りにソート（直前ステージを中心とした角度順）
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
```

以下に置き換える：

```gdscript
func start_unlock_focus(unlocked_ids: Array, return_stage_id: int = -1) -> void:
	_focus_return_id = return_stage_id
	if unlocked_ids.is_empty():
		return

	# 時計回りにソート（直前ステージを中心とした角度順）
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
	_unlock_anim_elapsed = 0.0
```

### 3-5. `_process_focus()` の全面置き換え

以下の既存関数を置き換える：

```gdscript
func _process_focus(delta: float) -> void:
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
	_focus_elapsed += delta
	var target_pos: Vector2 = StageSelectManager.get_world_pos(_focus_queue[0])
	_camera.position = _camera.position.lerp(target_pos, FOCUS_LERP * delta)
	if _focus_elapsed >= FOCUS_DURATION or _camera.position.distance_to(target_pos) < 5.0:
		_focus_queue.pop_front()
		_focus_elapsed = 0.0
		if _focus_queue.is_empty():
			_is_focusing = false
```

以下に置き換える：

```gdscript
func _process_focus(delta: float) -> void:
	# ── フェーズ1: ぼよよん演出中 ──
	if _unlock_anim_stage >= 0:
		_unlock_anim_elapsed += delta

		# 接続ラインのフェードイン進行
		var keys_to_remove: Array = []
		for key in _line_fade_progress:
			_line_fade_progress[key] += delta / UNLOCK_LINE_FADE_DURATION
			if _line_fade_progress[key] >= 1.0:
				_line_fade_progress[key] = 1.0
				keys_to_remove.append(key)
		for key in keys_to_remove:
			_line_fade_progress.erase(key)

		if _unlock_anim_elapsed >= UNLOCK_ANIM_DURATION:
			# ぼよよん終了 → 次のステージへ
			_unlock_anim_stage = -1
			_unlock_anim_elapsed = 0.0
			_focus_elapsed = 0.0
		queue_redraw()
		return

	# ── フェーズ2: キュー終了チェック ──
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

	# ── フェーズ3: カメラ移動（リニア） ──
	var target_id: int = _focus_queue[0]
	var target_pos: Vector2 = StageSelectManager.get_world_pos(target_id)
	_camera.position = _camera.position.move_toward(target_pos, FOCUS_MOVE_SPEED * delta)

	if _camera.position.distance_to(target_pos) < 2.0:
		# 到着 → ぼよよん演出開始
		_camera.position = target_pos
		_focus_queue.pop_front()
		_unlock_anim_stage = target_id
		_unlock_anim_elapsed = 0.0

		# 接続ラインのフェードイン登録
		# 解放元ステージ(_unlock_source_stage)との接続ラインを登録
		if _unlock_source_stage >= 0:
			var key: String = "%d_%d" % [mini(_unlock_source_stage, target_id),
										  maxi(_unlock_source_stage, target_id)]
			_line_fade_progress[key] = 0.0

		# パーティクル生成
		_spawn_unlock_particles(target_pos)

		if _focus_queue.is_empty():
			_is_focusing = false

	queue_redraw()
```

### 3-6. `_spawn_unlock_particles()` 関数を追加

`_spawn_bgm_particle()` 関数の直後に追加する：

```gdscript
func _spawn_unlock_particles(world_pos: Vector2) -> void:
	var screen_pos: Vector2 = get_canvas_transform() * world_pos
	var p := CPUParticles2D.new()
	_bgm_canvas.add_child(p)
	p.position = screen_pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.7
	p.spread = 180.0
	p.gravity = Vector2(0.0, 80.0)
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = Color(0.95, 0.19, 0.32, 1.0)
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)
```

### 3-7. `_draw()` のステージドット描画にぼよよんを追加

`_draw()` 内のステージドット描画ループを以下に修正する。

以下の既存コードを：

```gdscript
	# ステージドット（LOCKEDは描画しない）
	for i in range(StageSelectManager.STAGE_COUNT):
		var state: int = StageSelectManager.get_state(i)
		if state == StageSelectManager.StageState.LOCKED:
			continue
		var pos: Vector2 = _dot_pos(i)
		var is_near: bool = (i == _nearest and _popup_stage < 0 and not _esc_popup)
		match state:
			StageSelectManager.StageState.UNLOCKED:
				draw_circle(pos, _DOT_RADIUS, _HOVER_COLOR if is_near else _UNLOCKED_COLOR)
			StageSelectManager.StageState.CLEARED:
				draw_circle(pos, _DOT_RADIUS, _HOVER_COLOR if is_near else _CLEARED_COLOR)
				draw_circle(pos, _DOT_RADIUS * 0.35, Color.WHITE)
```

以下に置き換える：

```gdscript
	# ステージドット（LOCKEDは描画しない）
	for i in range(StageSelectManager.STAGE_COUNT):
		var state: int = StageSelectManager.get_state(i)
		if state == StageSelectManager.StageState.LOCKED:
			continue
		var pos: Vector2 = _dot_pos(i)
		var is_near: bool = (i == _nearest and _popup_stage < 0 and not _esc_popup)

		# ぼよよんアニメーション中の半径を計算
		var draw_radius: float = _DOT_RADIUS
		if i == _unlock_anim_stage and _unlock_anim_stage >= 0:
			var t: float = _unlock_anim_elapsed / UNLOCK_ANIM_DURATION
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

### 3-8. `_draw()` の接続ライン描画にフェードインを追加

`_draw()` 内の接続ライン描画ループを以下に修正する。

以下の既存コードを：

```gdscript
	# 接続ライン
	for conn in StageSelectManager.get_connections():
		var a: int = conn[0]
		var b: int = conn[1]
		if StageSelectManager.get_state(a) == StageSelectManager.StageState.LOCKED:
			continue
		if StageSelectManager.get_state(b) == StageSelectManager.StageState.LOCKED:
			continue
		draw_line(_dot_pos(a), _dot_pos(b), _LINE_COLOR, _LINE_WIDTH)
```

以下に置き換える：

```gdscript
	# 接続ライン
	for conn in StageSelectManager.get_connections():
		var a: int = conn[0]
		var b: int = conn[1]
		if StageSelectManager.get_state(a) == StageSelectManager.StageState.LOCKED:
			continue
		if StageSelectManager.get_state(b) == StageSelectManager.StageState.LOCKED:
			continue
		# フェードイン中のラインはアルファを補間して描画
		var key: String = "%d_%d" % [mini(a, b), maxi(a, b)]
		var line_alpha: float = 1.0
		if _line_fade_progress.has(key):
			line_alpha = _line_fade_progress[key]
		var line_color: Color = Color(_LINE_COLOR.r, _LINE_COLOR.g, _LINE_COLOR.b,
									  _LINE_COLOR.a * line_alpha)
		draw_line(_dot_pos(a), _dot_pos(b), line_color, _LINE_WIDTH)
```

---

## 注意事項

- 上記以外は一切変更しないこと。
- 修正後に以下を確認すること：
  1. ステージクリア後にステージセレクトへ戻ると、解放ステージへカメラがリニアに移動する
  2. 到着後にぼよよんアニメーションとパーティクルが再生される
  3. 接続ラインが0.3秒かけてフェードインする
  4. 複数ステージが解放された場合、時計回りに順番に巡回する
  5. 全演出終了後、クリアしたステージへカメラが戻る
  6. 解放ステージがない場合は演出が発生しない
