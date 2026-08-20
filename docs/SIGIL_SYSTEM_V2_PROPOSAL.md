# Sigil Factory — シジルシステム V2 提案

作成日: 2026-08-20

この文書は、現行シジルを「工場で読める記号」であるだけでなく、完成時に眺めて満足できる魔法陣へ発展させるための設計提案である。

本提案は、添付された単純な円・三角・星形の魔法陣と、放射反復・同心配置・規則的な入れ子を持つ複雑な幾何図形を参考にしている。ただし、画像をそのまま再現したり、実在の魔術記号を流用したりはしない。

---

## 1. 結論

現行の `Primitive / Transform / 二項Combine` を装飾だけで磨くのではなく、以下の**放射幾何文法**をシジル構築の中心へ置く。

```text
SigilProgram =
  Motif(id, orientation, ink)
  | Orbit(child, count, phase, facing)
  | Boundary(shape, child)
  | Compose(core, field)
  | Circuit(child, target_group_key, center_anchor_key, topology, step)
  | Concentric(child, count, scale_step, phase_step)
```

- `Motif`: 欠け環、牙、枝などの基本紋様
- `Orbit`: 子紋様を円周上へ規則的に反復
- `Boundary`: 円、三角、菱形などの意味ある外周
- `Compose`: 中心と外周を役割付きで構成
- `Circuit`: Orbit等が作ったanchorを隣接線、スポーク、星形で結ぶ
- `Concentric`: 子構造を有界回数だけ縮小・回転しながら同心反復する

自由移動・自由拡縮を主要操作から外し、中心、軌道、外周の離散スロットへ自動配置する。同じ入力と設定は必ず同じ形になり、設備アイコンと中間出力を見れば結果を予測できる状態を目指す。

低位シジルは少数要素と強い外周で明快にし、高位シジルは放射反復、Circuit、同心反復を段階的に加える。線を無作為に増やして複雑に見せない。`Circuit` と `Concentric` は参考画像2の密度へ到達する後期演算であり、MVPの学習語彙へ同時投入しない。

---

## 2. 現行方式の問題

現行 `GlyphModel` は、Primitiveの最終状態と二項Combine階層を保持し、描画時にCombineごとの円と接続線を自動生成している。

この方式には以下の限界がある。

- 小さな記号を別々の円で囲うため、一枚の統一された魔法陣より構造図に見えやすい
- 3・4・6・8回対称、正多角形、星形、花状反復を自然に表現できない
- 同位置の子を結ぶ方向の一部がcanonical文字列から決まり、工場操作から予測できない
- 反復をPrimitive複製で表すと、データ量と32秒予測の計算量が増える
- 同じ見た目でもCombineの括弧が違うと不一致になり得る
- 完成時の美しさを上げるほど、合成円と補助線が増えて読みづらくなる

したがって、現在のCombine円を増やす方向ではなく、外周・中心・反復・接続規則を第一級データへする。

---

## 3. 魔法陣の視覚文法

### 3.1 5つの層

完成シジルは次の層で構成する。

1. **外周印** — シジル全体を一枚にまとめる円・三角・菱形
2. **骨格** — 対称軸、スポーク、正多角形、星形の規則的な接続
3. **紋様場** — 円周上または同心円上へ反復したMotif
4. **中心核** — 召喚獣系統や進化元を示す中心のMotif / 下位シジル
5. **属性表現** — 色と色覚非依存pattern、弱い発光

強い線の差には必ず意味を持たせる。意味のない細密線は完成演出用の弱い補助に限定し、一致判定へ含めない。

### 3.2 意味の固定

- Motif種類 = 召喚獣の役割・系統
- 色 / pattern = 属性
- Boundary形 = 行動様式または戦術系統
- Orbit回数 = 規模・テンポ・陣形
- phase / orientation = 派生方向
- 見える構造層の追加 = 進化段階の手掛かり

具体的なゲーム効果との対応はプレイテストで決めるが、一度決めた対応は全シジルで共通にする。不可視の演算履歴や括弧の深さにはゲーム意味を持たせない。

### 3.3 読みやすさの制約

- 強い外周は原則1つ。内側の補助環は最大2つ
- Orbit回数はMVPで3または4、拡張後も2・3・4・6を基本とする
- 自由座標を使わず、中心帯・軌道帯・外周帯へ自動配置する
- 規則的な交差だけを許可し、交差部は自動的に小さなgapを入れる
- 収まらない設定は実行後に崩すのではなく、選択前に無効化する

---

## 4. 工場設備との対応

設備は「何をする装置か」と「通過後にどの図形になるか」が同じ視覚語彙で読める必要がある。

| 設備 | 演算 | 主な設定 |
|---|---|---|
| 紋源 | `Motif` | 欠け環 / 牙 / 枝 |
| 位相器 | orientation / phase | 離散方向 / 半位相 |
| 染色器 | ink | 白 / 青 / 赤 |
| 環列器 | `Orbit` | 3回 / 4回 |
| 境界器 | `Boundary` | 円 / 三角 |
| 構成器 | `Compose` | 中心port + 外周port |
| 結線器 | `Circuit` | 隣接 / スポーク / 星形 |
| 重環器 | `Concentric` | 2重 / 3重、縮小・位相 |
| 召喚器 | CanonicalSeal照合 | なし |

`Compose` は現行Combineと異なり非可換とする。入力portを点形の中心portと環形の外周portに描き分け、どちらが中央に置かれるかを接続前に理解できるようにする。

`Circuit` は子が公開する正規化anchor集合だけを接続する。Motifは定義済みの端点、Orbitは角度tick順の各配置中心、正多角形Boundaryは頂点、Composeは中心anchorとfield側anchorを公開する。円Boundaryは単独では任意anchorを作らない。anchor IDはprogram pathへ依存せず、semantic role、座標、角度tickの順で正規化する。anchor不足、同一点接続、範囲外stepは操作前に拒否する。`Concentric` は2重または3重の有界反復だけを扱い、汎用再帰にはしない。

anchorはvisible commandから導く `group_key / lane_id / cyclic_index / fixed_position` を持つ。隣接・星形Circuitは正確に1つのcyclic group、スポークは1つのcenter anchorと1つのcyclic groupだけを対象にする。Composeはgroup関係を保ち、Concentricは反復laneごとに別groupを作る。複数groupがある場合は設定hoverで対象環を強調して明示選択し、列挙indexではなくcanonicalな`target_group_key`をSigilProgramへ保存する。スポークは`center_anchor_key`も保存する。対象が消失した場合は別groupへ自動変更せず、操作全体をinvalidとしてatomicに拒否する。

現行の非破壊設定ホバーを継続し、候補選択中は以下を同時に表示する。

- 選択設備の直後の出力
- 下流設備の予測出力
- 最終シジル候補
- 32秒生産予測

未確定候補に正解チェック、目標との差分、必要設備を出さず、中立の点線で反実仮想だけを見せる既存契約は維持する。目標は「何を作るか」を示すが、工場では同じSealへ至る複数配置と速度・仕掛品のトレードオフを残す。

各設備は、パレット、盤面role mark、設定popup、候補previewで同じ演算記号を使う。

- Orbit 3 / 4 = 円周上の3点 / 4点
- Boundary = 実際の円 / 三角外周
- Compose = 中心点 + 外周環
- Circuit = 隣接辺 / 中心スポーク / skip付き星形
- Concentric = 大小2枚の同心図形

Composeへ配線する前のhoverでは中心laneと外周laneの空silhouetteだけを表示し、完成形や正解portを自動選択しない。

---

## 5. データモデルと一致判定

### 5.1 正本と描画結果を分ける

- `SigilProgram`: 工場が構築する不変の演算木
- `CanonicalSeal`: 描画とレシピ一致に使う正規化済みの有限な意味command集合

工場演算は副作用のない `apply(program, config) -> Result` とし、設定ホバー、32秒予測、確定生産が同じ関数を使う。

`CanonicalSeal` は、許可された形状と配置規則を示す意味commandだけで構成する。任意の描画segment集合ではない。

```text
SealCommand {
  command_kind
  integer_parameters
  fixed_transform
  ink_id
  semantic_role
}
```

任意の線分を自由に引く設備は用意しない。同じ円はCircle command、同じ星形はCircuit commandという唯一の表現へ正規化する。Painterは意味commandからstrokeへ展開し、画像の近似一致は行わない。FX commandは別配列に分離し、一致対象へ含めない。

`Compose` はcoreを中心lane、fieldを軌道laneへ必ず配置し、役割差を見える座標差へする。異なる入力を逆接続した場合は生成される意味commandも見た目も変わる。同じ入力を両portへ入れて逆接続しても幾何が同一になる場合は、別レシピではなく同じ結果として扱う。

`semantic_role` は中心lane、軌道lane、外周、骨格など、実際の配置または線種へ現れる役割だけを保持する。描画へ現れない加工履歴や設備名はCanonicalSealへ残さない。

compilerはCircuit用の正規化anchor metadataをCanonicalSealと一体で生成する。anchorはvisible SealCommandのparameterだけから純粋導出し、`group key / lane / cyclic index / source command key / fixed position`でsort / dedupeする。同一CanonicalSeal bytesならanchor集合も必ず同一でなければならない。Circuitが生成したedgeは正規化済み両端の組としてsort / dedupeし、別のtopology名やstepが同じedge集合を作る場合は同じCanonicalSealへ畳む。groupの列挙順はedge集合へ影響せず、Circuitは選択groupを越えて接続しない。

### 5.2 一致規則

- 工場の操作履歴ではなく、プレイヤーに実際に見える正規化SealCommandを比較する
- 可換な子集合だけをflattenし、子を安定順でsortする
- 完全に同一の意味commandはdedupeする
- hashは索引にだけ使い、最終一致はcanonical bytesで確認する
- 生産履歴は一致対象に含めない
- 不可視の括弧だけで不一致にしない

これにより、見た目が同じなのに構築順だけで失敗する状態を避けられる。一方、Boundary、Orbit回数、位相、Circuit、色など、見える差は必ず一致差になる。LOD後の簡略描画結果は一致判定へ使わない。

### 5.3 決定性と上限

- canonicalデータにfloatを保存しない
- 角度は1周120tick、座標は1/256 grid、倍率は定義済み有理段階を使う
- 固定整数LUTと丸め規則をnormalization versionごとに固定する
- AST深度6、raw node 48、可換子fanout 8を上限とする
- 1回の反復は2..12、repeat nestingは3、展開後SealCommandは192を上限とする
- Motif pathは64点、総描画segmentは2048、canonical bytesは32KiB、compile workは4096を上限とする
- 上限超過は途中まで生成せず、操作全体を拒否する
- 展開前にchecked multiplicationとiterative preflightを行い、循環と上限超過を検出する
- serialization headerへschema versionとnormalization versionを記録する
- 可変長fieldはlength frameし、full canonical bytesを安定sortする
- 汎用L-system、無制限再帰、ランダム生成は採用しない
- 螺旋などが必要になった場合は、固定上限を持つ専用演算として後から追加する

---

## 6. 表示モードとLOD

同じCanonicalSealから、用途に応じて密度だけを変える。ゲーム中のLODは意味差を消さず、詳細strokeを一意な代理記号へ置き換える。

- **32–48px**: 外周、中心核、主骨格、Orbit count / phaseの代理tickを必ず表示
- **49–112px**: 全ての意味strokeと主要な反復を表示
- **113px以上**: 弱い補助環、刻み、発光を追加

Orbit 3 / 4は3本 / 4本の主要spokeまたは外周tickを残し、phaseはtick位置の半step差を残す。Composeは中心と外周の二領域を残す。同時に選択可能なレシピは、ゲーム中の最小表示でも同じsilhouetteへ潰れてはならない。

装飾は編集時に薄くし、完成・召喚成功・大判プレビュー時にだけ展開する。

線の優先順位は次とする。

```text
Motif / Boundary > Skeleton > Group Guide > FX
```

色だけに依存せず、外周の属性registerへpatternを併用する。白は中空tick、青は塗りtick、赤は二重または斜切りtickとし、細いMotif線そのものへ斜線を重ねない。invalidは閉じない外周や切断tickでも表現する。

### 6.1 完成演出

大判表示と召喚成功時に限り、約1秒で次の順に描く。

```text
中心核 → Motif → 外周/Orbit → 接続骨格 → 弱い発光
```

設定ホバーを高速に移動している間は意味strokeだけを即時更新し、装飾アニメーションは静止後に始める。比較操作を演出で遅くしない。

---

## 7. MVPコンテンツ

最初の縦切りは次へ限定する。

- Motif 3種: 欠け環 / 牙 / 枝
- 色: 白 / 青 / 赤
- Boundary 2種: 円 / 三角
- Orbit: 3回 / 4回
- phase: 0 / 半位相
- Compose: 中心 + 外周
- MVP AST深度4、repeat nesting 1、展開Motif最大7
- 完成シジル9種

学習順は一度に新しい軸を1つだけ増やす。

1. Motif単体を覚える
2. BoundaryまたはOrbitを1回適用する
3. 中心と外周をComposeする
4. 既知の低位シジルを中心へ残し、外側へ新構造を追加する

例:

```text
欠け環 → 円境界
  = 低位守護

牙 → 3回環列
  = 三連攻撃

中心: 欠け環 + 円境界
外周: 牙 + 3回環列
中心/外周を構成 → 三角境界
  = 高位突撃陣
```

低位では参考画像1の明快さを保ち、高位では同じ規則を重ねて参考画像2の対称密度へ発展させる。

---

## 8. 実装フェーズ

### Phase 0 — Seal Lab

工場へ接続する前に、独立した比較画面でMVP 9種と高密度hero seal 1種を描く。

- 32 / 80 / 256px
- operational / editing / ceremonial
- current / hypothetical
- 白黒 / 色付き
- 参考画像2相当の星形または花状反復を含む256px hero seal 1種

ここで「魔法陣らしさ」と小サイズ可読性を確認する。hero sealがCircuit / Concentricの明示規則だけで成立しない場合は、V2データモデルを固定しない。

### Phase 1 — V2基盤

- immutable `SigilProgram`
- compiler / normalization / limits
- `CanonicalSeal` matcher
- V1 compiler / dual matcherとgolden test
- schema / normalization tag
- compiled result cache

既存レシピ、保存状態、召喚結果を壊さない状態を先に作る。

### Phase 2 — 基本図形

- PainterをCanonicalSeal描画へ一本化
- Motif / Boundary / Compose
- 円・三角・正多角形・星形の描画command

### Phase 3 — 反復

- Orbit
- Circuit
- 有界なConcentric
- 工場設備、設定ホバー、Undo、32秒予測へ接続

### Phase 4 — コンテンツ移行

- 既存3レシピに対応するV2版をversioned recipe keyで再設計
- 新規6レシピを追加
- プレイテスト後にV1互換経路を撤去

### Phase 5 — 完成演出

- LOD
- stroke-onアニメーション
- 交差gap
- 控えめな発光

---

## 9. 受入基準

### 予測可能性

- 3つの練習後、未見の入力と設備設定の結果を80%以上予測できる
- Composeの中心 / 外周を逆にした2案を90%以上見分けられる
- 同じ入力と同じ設定から、常に同じRenderPlanが生成される
- 目標との差分を、Motif / Boundary / Orbit / phase / colorの設備語彙で説明できる
- 同一Sealへ2つ以上の有効な配置または速度トレードオフを持つ課題がある

### 可読性

- 32pxでMotif種類を識別できる
- 48pxでBoundaryとOrbit回数を識別できる
- 80pxで中心と外周の所属を識別できる
- 同時に選択可能な全レシピ対をゲーム中の最小サイズで識別できる
- グレースケール化しても主要な意味を失わない
- 全許可組み合わせでframe外、完全重複、最小線間隔違反が発生しない

### 満足感

- 現行版とのブラインド比較で「魔法陣らしい」を70%以上が選ぶ
- 「完成時に大きく表示して眺めたい」を70%以上が選ぶ
- 256px hero sealの絶対評価「眺めたい」が5段階中4以上になる
- 低位 / 高位の進化順を80%以上が正しく並べられる
- 同じ参加者が同じSealについて美観と操作予測を評価し、どちらかが基準未満なら不合格とする
- 装飾線をゲーム上の部品と誤認する割合が10%未満
- 発光を消しても外周・中心・反復規則が読める
- 装飾OFF / ONでSealの意味解釈が変わらない

### 正しさ

- V1 recipe / saveのfrozen compiler / matcher golden testが通る
- normalizeが冪等である
- Preview / hover / commit / Undo / cancelでCanonicalSealが食い違わない
- Circuitのtarget group / center anchorがpreview / commit / Undo / save reloadで一致する
- 上限超過、循環、不正値をatomicに拒否し、入力状態を変更しない
- hash衝突時もcanonical bytesの比較で誤一致しない
- 同一CanonicalSeal bytesから常に同じ正規化anchor集合が得られる
- anchor groupの列挙順を変えてもedge集合が不変で、Circuitが別groupを横断しない
- 同じSealMatchKeyへ異なるRecipeRef / 召喚結果を登録するとloadが失敗する
- MVP 9レシピ全てがAST深度4 / repeat nesting 1のpreflightを通る
- 192 commandの最大Glyphを複数WIPで160tick予測して性能予算内に収まる

### 9.1 V1 / V2移行契約

- `GlyphSchemaRef = (schema_version, normalization_version)` とし、全SigilProgramとWIP / line payloadへ保持する
- `RecipeRef = (recipe_id, recipe_revision, schema_version, normalization_version)` とする
- `SealMatchKey = (schema_version, normalization_version, canonical bytes)` とし、RecipeRefから分離する
- GlyphSchemaRefでschema dispatchを先に行い、各matcherは1つのSealMatchKeyを単一のRecipeRef / 召喚結果へだけ対応させる
- 同じSealMatchKeyへの複数RecipeRef登録は、召喚結果が同じでもcontent loadを拒否する
- RecipeRefはrecipe definition、取得済みregistry、plan、選択目標、save内の選択状態、summon / failure event、production snapshotへ保持する
- 中間Glyph payloadはRecipeRefを持たず、召喚成功時にSealMatchKeyからRecipeRefを得る
- 互換期間中は旧recipe IDの意味を凍結し、V1 / V2をdual-readする
- 現行Painterの円・接続方向を再現するfrozen `LegacyV1` compiler / matcherを残す
- recipe、RecipeRef、node input / processing / output、line payload、committed / preview simulation、Undo snapshotを一括preflightする
- 全変換成功時だけ新状態へswapし、1件でも失敗したら元saveを変更しない
- より低リスクな初期移行では、active edit、WIP、Undoが空の境界でだけV2 writeへ切り替える
- 旧recipe IDだけから最新revisionを暗黙選択せず、目標・plan・eventが保持するRecipeRefを優先する
- V1互換経路は旧save読込率、変換失敗率、golden差分が基準内になった後にだけ撤去する

### 9.2 共有と性能

- compiled SigilProgram / CanonicalSealはimmutable共有し、ProductionContextだけをWIPごとに保持する
- cache keyはschema、normalization、program canonical bytes / digestとする
- normalization version変更時にcacheを全失効する
- recipe registryはdigest bucketからcanonical bytesを比較する
- node apply成功時に一度だけcompileし、描画・一致・previewのたびに再compileしない
- cacheは256 entryまたは32MiBの早い方を上限とするLRUにし、設定hover連打でも無制限に増やさない
- work meterはAST visit、repeat instance、command emit、sort comparison、anchor edge生成、segment emitを各1 workとして数える
- Circuit edgeはcount / stepからO(n)で生成し、全anchor pair探索を行わない
- Godot 4.7.1の開発PCで、最大Seal単体compileをDebug p95 5ms以内、160tick最大WIP previewをDebug p95 100ms以内とする
- 同じpreviewをRelease buildではp95 33ms以内、一時allocation 4MiB以内とする
- 性能計測は固定fixture、固定seed、warm cache / cold cacheを分けてCI artifactへ残す

---

## 10. 採用しない案

- hashから強い装飾をランダム風に生成し、それを完成形の主役にする
- 汎用L-systemや無制限再帰をプレイヤーへ直接与える
- 自由描画や自由座標で、読めない配置をプレイヤー責任にする
- 装飾を一致判定から外したまま、見た目の大部分を装飾へ任せる
- 高密度シジルをそのまま32pxの工場Glyphへ描く
- 全レシピを一度に移行して既存MVPを壊す
- 任意Overlay設備で同じ座標へ無制限に重ねる

---

## 11. 最初に確認する判断

実装前に、まずSeal Labで次の10案を並べて比較する。

- Motif単体 3種
- Motif + Boundary 3種
- core + Orbit field + Boundary 3種
- Circuit / Concentricで作るhero seal 1種

この比較で以下を確認する。

1. 3種のMotifが小サイズで区別できるか
2. 円 / 三角Boundaryに一貫した意味を与えられるか
3. Orbit 3 / 4の違いを文字なしで読めるか
4. 低位シジルが簡素すぎず、高位シジルが過密でないか
5. 工場設備へ接続する前に、完成形そのものを見て満足できるか
6. hero sealがランダム装飾や不可視ルールなしで再現できるか

この6点を満たした後に、工場データモデルと設備へ統合する。
