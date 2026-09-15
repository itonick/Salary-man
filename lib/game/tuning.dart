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

  // ── ステージ ───────────────────────────────────────
  /// 1両の長さ。実車と同じ20m。
  static const double carLengthM = 20.0;

  /// 次の駅に着くまでの持ち時間。これが尽きたら踏破終了。
  /// 15号車の入口(280m)まで全力で108秒。かがみと転倒の分を見込んで130秒。
  static const double timeLimitSec = 130.0;

  // ── 吊り革ジャンプ（上フリック） ─────────────────────
  static const double jumpSec = 0.66;
  static const double jumpHeightM = 1.15;

  /// この高さを超えている間は、足元の障害を越えていると判定する。
  static const double jumpClearHeightM = 0.30;

  /// 着地硬直。この間は無防備 ── 連続ジャンプ逃げを封じる。
  static const double jumpLandingLagSec = 0.10;

  // ── かがむ（下フリック） ────────────────────────────
  static const double crouchSec = 0.66;

  /// かがみ始めてから頭上を避けられるようになるまで。
  static const double crouchStartupSec = 0.04;

  /// かがんでいる間の減速率。避けるたびに時間を失う。
  static const double crouchSpeedFactor = 0.85;

  // ── 薙ぐ（タップ） ─────────────────────────────────
  static const double swingSec = 0.30;

  /// 判定が出ている区間（swingSec に対する秒数）。
  static const double swingHitFromSec = 0.06;
  static const double swingHitToSec = 0.20;

  /// カバンの届く距離。
  static const double swingReachM = 1.2;

  static const double swingCooldownSec = 0.12;

  // ── 体幹 ───────────────────────────────────────────
  static const double stanceMax = 100.0;
  static const double stanceRegenPerSec = 7.0;
  static const double stanceCostSwing = 7.0;
  static const double stanceCostHit = 26.0;

  /// 転倒から起き上がったときの残量。
  static const double stanceAfterFall = 55.0;

  /// 体幹が減るほど棒人間が前のめりになる。最大の傾き（ラジアン）。
  /// ゲージを見なくても残量が分かるようにするための演出。
  static const double maxLeanRad = 0.22;

  // ── 転倒 ───────────────────────────────────────────
  /// 起き上がるまでの秒数。失うのは命ではなく時間。
  static const double fallSec = 3.0;

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
