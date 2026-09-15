import 'package:flutter_test/flutter_test.dart';
import 'package:tsukin_taimaroku/game/entities.dart';
import 'package:tsukin_taimaroku/game/taimaroku_game.dart';

/// 敵が [triggerM] 先まで来た瞬間に [input] を1回だけ出したとき、
/// 被弾せずに通過できるか。
bool _survives(Kind kind, double triggerM, void Function(TaimarokuGame g) input) {
  final g = TaimarokuGame()
    ..state = GameState.running
    ..generatedCars = 1 << 20; // 自動生成を止め、この1体だけにする
  const placedAt = 8.0;
  g.entities.add(Placed(StageEntity(kind, placedAt, 0), placedAt));

  var fired = false;
  const dt = 1 / 60;
  for (var i = 0; i < 60 * 8; i++) {
    if (!fired && placedAt - g.distanceM <= triggerM) {
      input(g);
      fired = true;
    }
    g.update(dt);
    if (g.player.hits > 0) return false;
    if (g.distanceM > placedAt + 2) break;
  }
  return true;
}

/// 避けられる入力タイミングの幅を秒で返す（2.6m/s 換算、0.01m 刻み）。
double _windowSec(Kind kind, void Function(TaimarokuGame g) input) {
  var ok = 0;
  for (var cm = 5; cm <= 300; cm++) {
    if (_survives(kind, cm / 100, input)) ok++;
  }
  return ok * 0.01 / 2.6;
}

void main() {
  test('キャリーバッグは吊り革ジャンプで越えられる', () {
    final w = _windowSec(carryCase, (g) => g.onFlickUp());
    // ignore: avoid_print
    print('キャリーバッグ 入力猶予 ${w.toStringAsFixed(3)} 秒');
    expect(w, greaterThan(0.15));
  });

  test('リュック魔人はかがんでやり過ごせる', () {
    final w = _windowSec(backpackMajin, (g) => g.onFlickDown());
    // ignore: avoid_print
    print('リュック魔人 入力猶予 ${w.toStringAsFixed(3)} 秒');
    expect(w, greaterThan(0.10));
  });

  test('音漏れ番長は薙いで倒せる', () {
    final w = _windowSec(audioBoss, (g) => g.onTap());
    // ignore: avoid_print
    print('音漏れ番長 入力猶予 ${w.toStringAsFixed(3)} 秒');
    expect(w, greaterThan(0.15));
  });

  test('何もしなければ3種とも被弾する', () {
    for (final k in allKinds) {
      expect(_survives(k, 0, (_) {}), isFalse, reason: k.label);
    }
  });
}
