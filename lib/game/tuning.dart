import 'dart:math' as math;

/// 通勤退魔録 — 手触りの定数はすべてここに集約する。
///
/// Phase 1 の目的は「片手で気持ちよく走れるか」の一点だけなので、
/// 触るべき数値がこのファイル以外に散らないようにしてある。
/// ホットリロード（r）で即座に反映されるので、通勤中に詰めること。
class Tuning {
  // ── 走る ───────────────────────────────────────────
  /// 前進速度。実際の「人混みを押し分けて歩く」速さに寄せてある。
  static const double runSpeedMps = 2.6;

  /// 敵が画面右端に現れてから自分に届くまでの秒数。
  /// 端末の画面幅に関わらずこの秒数が一定になるよう、
  /// 表示倍率(pixelsPerMeter)を画面幅から逆算する。難易度の本体はこの値。
  static const double targetReactionSec = 1.6;

  /// プレイヤーの立ち位置（画面幅に対する比率）。
  static const double playerXRatio = 0.22;

  /// 棒人間の身長（メートル）。表示倍率の基準。
  static const double playerHeightM = 1.7;

  // ── 難易度の上がり方 ─────────────────────────────────
  /// 1両進むごとに増える速度の割合。
  /// 表示倍率は1号車の速度で決まっているので、速くなるほど
  /// 「敵が見えてから届くまでの時間」が実質的に短くなる。
  /// 1号車で1.60秒、15号車では0.78秒しかない。
  static const double speedGainPerCar = 0.075;

  /// 速度の上限（1号車比）。
  static const double maxSpeedMul = 2.1;

  /// 1両あたりの敵の数。
  static const int baseEnemiesPerCar = 4;
  static const int maxEnemiesPerCar = 12;

  /// [carNo] 号車に置く敵の数。
  static int enemyCountFor(int carNo) =>
      math.min(maxEnemiesPerCar, baseEnemiesPerCar + ((carNo - 1) * 0.9).floor());

  /// [carNo] 号車での速度倍率。
  static double speedMulFor(int carNo) =>
      (1 + speedGainPerCar * (carNo - 1)).clamp(1.0, maxSpeedMul);

  /// [carNo] 号車での実際の速度（m/s）。
  static double runSpeedFor(int carNo) => runSpeedMps * speedMulFor(carNo);

  /// [carNo] 号車での敵と敵の最小間隔（秒）。
  /// 前の敵を捌いてから次に反応するまでの余裕。
  /// 前の動作（最長はジャンプの0.56秒）が終わる前に次が来ると、
  /// 腕に関係なく当たってしまう。下限はそれより必ず長く取る。
  static double minGapSecFor(int carNo) =>
      math.max(0.66, 0.95 - 0.028 * (carNo - 1));

  /// 号車が変わったときの告知を出している時間。
  static const double bannerSec = 1.8;

  // ── ステージ ───────────────────────────────────────
  /// 1両の長さ。実車と同じ20m。
  static const double carLengthM = 20.0;

  /// 次の駅に着くまでの持ち時間。これが尽きたら踏破終了。
  /// 最適に操作して走り切って約76秒。余りは4秒しかない。
  /// 転倒1回が3.5秒なので、実質「一度も転ばずに、ほぼ最適で走る」ことがクリア条件。
  /// ここがクリア率を決める最大のつまみ。
  static const double timeLimitSec = 80.0;

  // ── 吊り革ジャンプ（上フリック） ─────────────────────
  static const double jumpSec = 0.56;
  static const double jumpHeightM = 1.15;

  /// この高さを超えている間は、足元の障害を越えていると判定する。
  static const double jumpClearHeightM = 0.34;

  /// 着地硬直。この間は無防備 ── 連続ジャンプ逃げを封じる。
  static const double jumpLandingLagSec = 0.10;

  // ── かがむ（下フリック） ────────────────────────────
  static const double crouchSec = 0.46;

  /// かがみ始めてから頭上を避けられるようになるまで。
  static const double crouchStartupSec = 0.04;

  /// かがんでいる間の減速率。避けるたびに時間を失う。
  static const double crouchSpeedFactor = 0.94;

  // ── 薙ぐ（タップ） ─────────────────────────────────
  static const double swingSec = 0.34;

  /// 判定が出ている区間（swingSec に対する秒数）。
  /// 速い号車では1フレームに進む距離が大きいので、ここが短いと
  /// 「振ったのに抜けられた」が起きる。
  static const double swingHitFromSec = 0.05;
  static const double swingHitToSec = 0.26;

  /// カバンの届く距離。
  static const double swingReachM = 1.2;

  static const double swingCooldownSec = 0.12;

  // ── 体幹 ───────────────────────────────────────────
  static const double stanceMax = 100.0;
  static const double stanceRegenPerSec = 5.0;
  static const double stanceCostSwing = 7.0;

  /// 被弾1回の消費。3回ぶつかれば転ぶ。
  static const double stanceCostHit = 34.0;

  /// 転倒から起き上がったときの残量。次の1回で また転ぶ位置から再開する。
  static const double stanceAfterFall = 45.0;

  /// 体幹が減るほど棒人間が前のめりになる。最大の傾き（ラジアン）。
  /// ゲージを見なくても残量が分かるようにするための演出。
  static const double maxLeanRad = 0.22;

  // ── 転倒 ───────────────────────────────────────────
  /// 起き上がるまでの秒数。失うのは命ではなく時間。
  static const double fallSec = 3.5;

  // ── 滑らかさ ─────────────────────────────────────────
  /// 動作中に押した入力を預かっておく時間。
  /// この間に動けるようになれば、その瞬間に出る。
  static const double inputBufferSec = 0.20;

  /// 動作が切り替わるときに姿勢を補間する時間。
  static const double poseBlendSec = 0.08;

  /// 転倒から立ち上がるときの補間時間。
  static const double getUpBlendSec = 0.35;

  /// 速度を目標値へ寄せる速さ（1秒あたり）。減速は速く、加速はやや緩やか。
  static const double speedEaseDown = 14.0;
  static const double speedEaseUp = 8.0;

  /// 1フレームで進める時間の上限。ブラウザが一瞬止まってもワープしない。
  static const double maxFrameSec = 1 / 30;

  // ── 入力 ───────────────────────────────────────────
  /// この距離を縦に動かした時点でフリック確定（離すのを待たない）。
  static const double flickThresholdPx = 26.0;

  /// この距離未満の移動ならタップ扱い。
  static const double tapMaxTravelPx = 18.0;

  // ── 画面レイアウト（画面高に対する比率） ──────────────
  /// 車内の帯の上端＝吊り革の高さ。
  static const double bandTopRatio = 0.20;

  /// 床のライン。棒人間はこの上に立つ。
  static const double groundYRatio = 0.66;

  /// 体幹ゲージの高さ。
  static const double gaugeYRatio = 0.76;

  /// 画面下の操作ボタンの高さ（64〜120px に収める）。
  static const double padHeightRatio = 0.11;
}
