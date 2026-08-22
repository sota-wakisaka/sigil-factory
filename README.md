# Sigil Factory

Godot 4とGDScriptで開発している、ルーンを加工・合成して召喚する工場ゲームのプロジェクトです。

現在の開発対象は、遊びの核となるルーン工場です。旧来の幾何Glyph工場、ルート選択、戦闘、報酬を含む進行は現行プロトタイプの対象外です。

## 現在の開発対象

- 単一の菱形盤面に配置した、属性を持たない24種類のルーン素材
- 24ルーン、中央消滅マス、外周消滅環を使う予測可能な上下左右移動
- 通常マスでは別ルーンへ変換し、`×`へ入ったルーンだけが消滅する一括加工
- 内周・中周・外周の抽出と、最大8文字の合成（同じルーンの重複を保持）
- 中央召喚器へ向かう、距離と一定速度に基づく搬送
- 3入力それぞれのターゲットと、順序を無視した個数込みの完全一致

## 仕様書

- [`docs/FACTORY_PROTOTYPE.md`](docs/FACTORY_PROTOTYPE.md) — 現行ルーン工場の優先仕様
- [`docs/FACTORY_SPEC.md`](docs/FACTORY_SPEC.md) — 将来候補を含む工場・物流資料（矛盾時は上記を優先）

## 起動

Godot 4.7.1でプロジェクトを実行するとメインメニューが開き、ルーン工場プロトタイプを開始できます。

```powershell
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --path .
```

## テスト

ルーン工場とメニュー:

```powershell
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tests/run_rune_factory_tests.gd
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tests/run_main_menu_tests.gd
```

旧Glyph・工場ドメイン（回帰確認）:

```powershell
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tests/run_tests.gd
```

## 開発方針

完成ターゲットから必要なルーンを読み取れ、移動・消滅・環抽出・合成の結果を実行前に予測できることを最優先にします。そのうえで、素材源の距離、搬送時間、一括加工、分岐と再合流に複数の工場解を残します。
