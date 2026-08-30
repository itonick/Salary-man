# 通勤退魔録 — Phase 1

満員電車を1号車から15号車まで駆け抜ける、強制横スクロールアクション。
これは **Phase 1（手触り検証プロトタイプ）** で、確かめたいのは一点だけです。

> 片手で、気持ちよく走れるか。

気持ちよく走れなければ企画ごと捨てる、という前提で作ってあります。
一般客・迷惑度メーター・ボス・スキンは Phase 2 以降で、ここには入っていません。

## 遊び方

前進は自動。操作は3つだけです。

| 入力 | 動作 | 対応する相手 |
| --- | --- | --- |
| タップ | 薙ぐ | 音漏れ番長（正面） |
| 上フリック | 吊り革ジャンプ | キャリーバッグ（足元） |
| 下フリック | かがむ | リュック魔人（頭上） |

デスクトップでは `スペース` / `↑` / `↓` でも操作できます。

体幹が尽きると転倒し、起き上がるまで3秒を失います。死にません。失うのは時間だけです。
次の駅に着くまでに何号車まで行けたかがスコアになります。

## 動かす

Flutter SDK が必要です（未インストールなら下の「環境構築」へ）。

```bash
cd C:/Users/iszem/Apps/tsukin-taimaroku && flutter pub get && flutter run
```

Windows デスクトップで動かす場合:

```bash
cd C:/Users/iszem/Apps/tsukin-taimaroku && flutter run -d windows
```

Android 実機（USB デバッグを有効にして接続）:

```bash
cd C:/Users/iszem/Apps/tsukin-taimaroku && flutter run -d android
```

実機に置いて通勤で試すための APK:

```bash
cd C:/Users/iszem/Apps/tsukin-taimaroku && flutter build apk --debug
```

## 手触りを詰める

**触るのは `lib/game/tuning.dart` だけ**です。手触りに効く数値は全部そこに集めてあります。
`flutter run` 中に値を書き換えて `r` を押せば即座に反映されます。

最初に疑うべき3つ:

- `targetReactionSec` — 敵が見えてから届くまでの秒数。難易度の本体。
  画面幅から表示倍率を逆算しているので、どの端末でもこの秒数は一定になります。
- `flickThresholdPx` — フリックが確定する指の移動量。小さいほど反応が速く、誤爆も増える。
- `jumpSec` / `crouchSec` — 避けている時間の長さ。長いと安全になりすぎ、短いと理不尽になる。

## 構成

```
lib/
  main.dart                入力（フリックは離す前に確定させる）とアプリ起動
  game/
    tuning.dart            手触りの定数。触るのはここだけ
    palette.dart           色は3つ。黄＝自分 / 赤＝敵 / 青＝殴ってはいけない相手
    skeleton.dart          棒人間。関節座標から線を引くだけ。画像は使わない
                           転倒時のラグドール（Verlet）もここ
    entities.dart          妖怪カタログと1両ぶんの配置。Phase 2 で JSON 化する
    player.dart            走る・薙ぐ・飛ぶ・かがむ・転ぶ の状態機械
    taimaroku_game.dart    スクロール、当たり判定、車内の描画、HUD
```

### 設計上の決めごと

- **画像を1枚も使わない。** 棒人間は関節座標から線を引くだけ。
  敵を増やすときはプロップを1つ描く関数を足すだけで済みます。
- **当たり判定は「上・中・下の3レーン × 進行方向の距離」だけ。**
  細い線に厳密な判定を付けると「避けたのに当たった」が頻発するので、
  見た目と判定は最初から切り離してあります。
- **表示倍率は画面幅から逆算する。** 端末が変わっても反応時間が変わらないようにするため。
- **体幹はゲージより先に姿勢で見せる。** 減るほど棒人間が前のめりになります。

## 環境構築（Flutter SDK 未インストールの場合）

```powershell
git clone --depth 1 -b stable https://github.com/flutter/flutter.git C:\src\flutter
```

そのうえで `C:\src\flutter\bin` を PATH に通し、`flutter doctor` を実行してください。
Android の実機ビルドには追加で Android Studio（Android SDK と JDK）が要ります。
Windows デスクトップで動かすだけなら Visual Studio の
「C++ によるデスクトップ開発」ワークロードが必要です。

## 次にやること

Phase 1 のゴールは、実際の通勤中にこれを触って
「片手で気持ちよく走れるか」を判断することです。
判断がついたら Phase 2（一般客と迷惑度メーター、cars.json によるステージ定義、
15両の号車ごとの性格）に進みます。
