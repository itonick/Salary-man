import 'package:flutter_test/flutter_test.dart';
import 'package:tsukin_taimaroku/game/player.dart';
import 'package:tsukin_taimaroku/game/tuning.dart';

void _step(Player p, double sec) {
  const dt = 1 / 60;
  for (var t = 0.0; t < sec; t += dt) {
    p.update(dt, Tuning.runSpeedMps * p.speedFactor * dt);
  }
}

void main() {
  test('着地の直前に押した↓は、着地後に出る', () {
    final p = Player()..flickUp();
    expect(p.state, PlayerState.jumping);
    _step(p, Tuning.jumpSec - 0.05); // 着地の少し前
    p.flickDown(); // この時点では出せない
    expect(p.state, PlayerState.jumping);
    _step(p, 0.05 + Tuning.jumpLandingLagSec + 0.02);
    expect(p.state, PlayerState.crouching);
  });

  test('預かった入力は時間が過ぎたら捨てる', () {
    final p = Player()..flickUp();
    p.flickDown(); // ジャンプ直後に押す。着地まで 0.66秒あるので預かり切れない
    _step(p, Tuning.jumpSec + Tuning.jumpLandingLagSec + 0.05);
    expect(p.state, PlayerState.running);
  });

  test('薙いでいる最中のタップは、振り終わりにつながる', () {
    final p = Player()..tap();
    _step(p, Tuning.swingSec - 0.05);
    final hitsBefore = p.stance;
    p.tap();
    _step(p, 0.05 + Tuning.swingCooldownSec + 0.02);
    expect(p.swingT, greaterThanOrEqualTo(0)); // 2振り目が始まっている
    expect(p.stance, lessThan(hitsBefore));
  });

  test('かがむと速度はなめらかに落ちる', () {
    final p = Player()..flickDown();
    _step(p, 1 / 60);
    expect(p.speedFactor, lessThan(1.0));
    expect(p.speedFactor, greaterThan(Tuning.crouchSpeedFactor));
  });
}
