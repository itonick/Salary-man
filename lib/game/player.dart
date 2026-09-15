import 'dart:math' as math;

import 'skeleton.dart';
import 'tuning.dart';

enum PlayerState { running, jumping, crouching, fallen }

/// 棒人間のサラリーマン。
///
/// 前進は自動なので、この状態機械が受け取る入力は3つだけ。
/// タップ＝薙ぐ／上フリック＝吊り革ジャンプ／下フリック＝かがむ。
class Player {
  PlayerState state = PlayerState.running;

  double stance = Tuning.stanceMax;

  /// 歩幅の位相。進んだ距離から決まるので、減速すると歩調も落ちる。
  double runPhase = 0;

  /// 各アクションの経過秒。
  double jumpT = 0;
  double crouchT = 0;

  /// 薙ぎの経過秒。負なら振っていない。
  double swingT = -1;
  double swingCooldown = 0;

  /// 着地硬直。この間は次の行動を出せない＝無防備。
  double landingLag = 0;

  double fallT = 0;
  Ragdoll? ragdoll;

  /// 転倒回数と被弾回数。手触りの検証で見たい数字。
  int falls = 0;
  int hits = 0;

  /// 1歩の歩幅（メートル）。走りアニメの速さを距離に紐づける。
  static const double _strideM = 0.62;

  bool get isFallen => state == PlayerState.fallen;

  bool get _busy =>
      state == PlayerState.jumping ||
      state == PlayerState.crouching ||
      state == PlayerState.fallen ||
      landingLag > 0;

  /// 薙ぎの判定が出ている区間か。
  bool get swingActive =>
      swingT >= Tuning.swingHitFromSec && swingT <= Tuning.swingHitToSec;

  /// 進行速度の倍率。かがむと減速し、転倒中は止まる。
  double get speedFactor {
    if (state == PlayerState.fallen) return 0;
    if (state == PlayerState.crouching) return Tuning.crouchSpeedFactor;
    return 1.0;
  }

  /// 現在の浮き上がり高さ（メートル）。
  double get liftM => state == PlayerState.jumping
      ? math.sin(math.pi * jumpT.clamp(0.0, 1.0)) * Tuning.jumpHeightM
      : 0.0;

  /// 足元をすり抜けられるか（キャリーバッグ・傘を飛び越えられているか）。
  bool get clearsLow =>
      state == PlayerState.jumping && liftM > Tuning.jumpClearHeightM;

  /// 頭上をやり過ごせているか（リュック魔人の横薙ぎをかがんで避けられているか）。
  /// かがみ始めのごく短い間を除き、かがんでいる間はずっと有効。
  /// ここを中間だけに絞ると、敵と重なる時間を覆えず必ず被弾する。
  bool get duckingHigh =>
      state == PlayerState.crouching && crouchT > Tuning.crouchStartupSec;

  // ── 入力 ────────────────────────────────────────────

  void tap() {
    if (_busy || swingCooldown > 0 || swingT >= 0) return;
    swingT = 0;
    stance -= Tuning.stanceCostSwing;
  }

  void flickUp() {
    if (_busy) return;
    state = PlayerState.jumping;
    jumpT = 0;
    swingT = -1;
  }

  void flickDown() {
    if (_busy) return;
    state = PlayerState.crouching;
    crouchT = 0;
    swingT = -1;
  }

  // ── 更新 ────────────────────────────────────────────

  /// [movedM] はこのフレームで実際に進んだ距離（メートル）。
  void update(double dt, double movedM) {
    runPhase += (movedM / _strideM) * 2 * math.pi;

    if (swingCooldown > 0) swingCooldown -= dt;
    if (landingLag > 0) landingLag -= dt;

    if (swingT >= 0) {
      swingT += dt;
      if (swingT > Tuning.swingSec) {
        swingT = -1;
        swingCooldown = Tuning.swingCooldownSec;
      }
    }

    if (state == PlayerState.jumping) {
      jumpT += dt / Tuning.jumpSec;
      if (jumpT >= 1.0) {
        jumpT = 0;
        state = PlayerState.running;
        landingLag = Tuning.jumpLandingLagSec;
      }
    } else if (state == PlayerState.crouching) {
      crouchT += dt;
      if (crouchT >= Tuning.crouchSec) {
        crouchT = 0;
        state = PlayerState.running;
      }
    } else if (state == PlayerState.fallen) {
      fallT -= dt;
      ragdoll?.update(dt);
      if (fallT <= 0) {
        state = PlayerState.running;
        ragdoll = null;
        stance = Tuning.stanceAfterFall;
      }
    } else {
      stance += Tuning.stanceRegenPerSec * dt;
    }

    stance = stance.clamp(0.0, Tuning.stanceMax);
    if (stance <= 0 && state != PlayerState.fallen) {
      _fall();
    }
  }

  /// 被弾。命ではなく体幹を削る。
  void takeHit() {
    if (state == PlayerState.fallen) return;
    hits++;
    stance -= Tuning.stanceCostHit;
    if (stance <= 0) _fall();
  }

  void _fall() {
    falls++;
    stance = 0;
    ragdoll = Ragdoll.fromPose(buildPose(), Tuning.runSpeedMps);
    state = PlayerState.fallen;
    fallT = Tuning.fallSec;
    swingT = -1;
    jumpT = 0;
    crouchT = 0;
  }

  void reset() {
    state = PlayerState.running;
    stance = Tuning.stanceMax;
    runPhase = 0;
    jumpT = 0;
    crouchT = 0;
    swingT = -1;
    swingCooldown = 0;
    landingLag = 0;
    fallT = 0;
    ragdoll = null;
    falls = 0;
    hits = 0;
  }

  // ── 描画用ポーズ ─────────────────────────────────────

  Pose buildPose() {
    final Pose p;
    if (state == PlayerState.jumping) {
      p = Poses.jump(jumpT);
    } else if (state == PlayerState.crouching) {
      p = Poses.crouch(crouchT / Tuning.crouchSec);
    } else {
      p = Poses.run(runPhase);
    }
    // 薙ぎは走りにだけ重ねる。ジャンプ中・かがみ中は振れない。
    if (swingT >= 0 && state == PlayerState.running) {
      Poses.applySwing(p, swingT / Tuning.swingSec);
    }
    // 体幹が減るほど前のめりになる。ゲージを見なくても分かるように。
    p.lean = (1 - stance / Tuning.stanceMax) * Tuning.maxLeanRad;
    return p;
  }
}
