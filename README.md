# Sigil Factory

Godot 4とGDScriptで開発している、シジル生産工場を中心としたゲームプロジェクトです。

現在の開発対象は、遊びの核となる工場とシジル編集です。旧来のルート選択、戦闘、報酬を含む進行実装は削除しています。

## 現在の開発対象

- ノード接続による自由なシジル構築
- Primitiveの移動、回転、拡縮、放射配置、合成
- 決定的な固定tick工場シミュレーション
- 工場グラフの検証、Undo、非破壊予測
- Glyphの正規化、一致判定、共通描画
- シジルを作成・書き出しできるSigil Lab

## 仕様書

- [`docs/FACTORY_PROTOTYPE.md`](docs/FACTORY_PROTOTYPE.md) — 現在のSigil Labを基礎にした工場プロトタイプ
- [`docs/FACTORY_SPEC.md`](docs/FACTORY_SPEC.md) — 工場設備、配線、物流、編集
- [`docs/SIGIL_SPEC.md`](docs/SIGIL_SPEC.md) — Glyph構造、変形、合成、正規化、一致判定
- [`docs/SIGIL_VISUAL_SPEC.md`](docs/SIGIL_VISUAL_SPEC.md) — シジルと工場の視覚仕様

## 起動

Godot 4.7.1でプロジェクトを実行するとメインメニューが開き、工場プロトタイプとSigil Labを選択できます。

```powershell
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --path .
```

## テスト

シジルラボ:

```powershell
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tests/run_sigil_lab_tests.gd
```

工場プロトタイプとメニュー:

```powershell
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tests/run_factory_prototype_tests.gd
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tests/run_main_menu_tests.gd
```

Glyph・工場ドメイン:

```powershell
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tests/run_tests.gd
```

## 開発方針

工場でGlyphを作る操作自体が、理解でき、予測でき、見ていて満足できることを開発方針とします。戦闘やローグライト進行は現在の仕様範囲に含めません。
