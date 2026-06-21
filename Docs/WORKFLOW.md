# KATA-DRAW 開発ワークフロー

## ブランチ構成

| ブランチ | 役割 |
|---|---|
| `main` | **製品版**の開発幹。製品版ビルドはここから書き出す |
| `demo` | **体験版**の保守・アップデート専用 |

両ブランチは同じコミットから分岐しており、コアロジックを共有しています。

---

## 初期セットアップ（一度だけ実施）

`demo` ブランチで `EXPERIENCE_VERSION` フラグを永続的に `true` にします。

1. GitHub Desktop で `demo` ブランチに切り替える
2. `Resources/game_config.gd` の以下の行を変更してコミットする

```gdscript
# 変更前
const EXPERIENCE_VERSION := false

# 変更後
const EXPERIENCE_VERSION := true
```

これにより：
- `demo` ブランチからビルド → 自動的に体験版（3ステージ制限）
- `main` ブランチからビルド → 自動的に製品版（全ステージ）

---

## 日常の作業フロー

### 製品版の新機能・改修

```
main ブランチで作業 → コミット → origin/main に push
```

体験版には影響しません。

### 体験版のバグ修正（製品版にも反映したい場合）

```
demo ブランチで修正 → コミット → cherry-pick で main にも取り込む
```

手順（GitHub Desktop の場合）:

1. `demo` ブランチで修正してコミットする
2. GitHub Desktop で `main` ブランチに切り替える
3. 左サイドバー「History」で `demo` ブランチの対象コミットを右クリック
4. 「Cherry-pick commit」を選択
5. `main` に push する

コマンドラインの場合:

```
git checkout main
git cherry-pick <コミットハッシュ>
git push origin main
```

### 製品版のバグ修正（体験版にも反映したい場合）

上記と逆方向で同様の手順。`main` でコミットし、`demo` へ cherry-pick します。

### 体験版**限定**の修正・調整

```
demo ブランチのみで作業 → コミット → main には取り込まない
```

例：体験版専用の UI メッセージ、ステージ数制限の変更、など。

---

## ビルド手順

### 製品版ビルド

1. GitHub Desktop で `main` ブランチに切り替える
2. `Resources/game_config.gd` で `EXPERIENCE_VERSION := false` を確認
3. Godot エディタでプロジェクトを開き、通常通り Export する

### 体験版ビルド

1. GitHub Desktop で `demo` ブランチに切り替える
2. `Resources/game_config.gd` で `EXPERIENCE_VERSION := true` を確認（初期セットアップ済みなら自動）
3. Godot エディタでプロジェクトを開き、通常通り Export する

> **注意**: `EXPERIENCE_VERSION` の変更は **コミット済みの状態を維持**してください。
> ビルドのたびに手動で変更する運用は、commitし忘れた際にバグの原因になります。

---

## 体験版の制限パラメータ

`Resources/game_config.gd` で管理しています。

```gdscript
const EXPERIENCE_VERSION := true  # demo ブランチでは true

# 体験版で遊べるステージ数の上限（0始まりインデックス）
# 現在は get_max_stage_index() 内で mini(2, ...) → ステージ0〜2の3面
```

ステージ数の上限を変える場合は `get_max_stage_index()` の `mini(2, ...)` の数値を修正します。

将来スキル・セーブ機能を実装する際は、同ファイルに定数を追加して参照します（後述）。

---

## cherry-pick を使う際の注意点

- **1コミット1修正**を心がけると cherry-pick が楽になります
- 複数ファイルにまたがる大きな変更は、ひとつのコミットにまとめておきます
- cherry-pick 後にコンフリクトが出た場合は、手動で解消してから `git cherry-pick --continue`
