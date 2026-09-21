import 'package:flutter_test/flutter_test.dart';
import 'package:tsukin_taimaroku/game/entities.dart';
import 'package:tsukin_taimaroku/game/taimaroku_game.dart';
import 'package:tsukin_taimaroku/game/tuning.dart';

/// [carNo] 号車で、敵が [triggerM] 先まで来た瞬間に入力を1回出したとき、
/// 被弾せずに通過できるか。
bool _survives(
  Kind kind,
  int carNo,
  double triggerM,
  void Function(TaimarokuGame g) input,
) {
  final base = (carNo - 1) * Tuning.carLengthM;
  final g = TaimarokuGame()
    ..state = GameState.running
    ..generatedCars = 1 << 20 // 自動生成を止め、この1体だけにする
    ..distanceM = base;
  final at = base + 8.0;
  g.entities.add(Placed(StageEntity(kind, 8.0, 0), at));

  var fired = false;
  const dt = 1 / 60;
  for (var i = 0; i < 60 * 10; i++) {
    if (!fired && at - g.distanceM <= triggerM) {
      input(g);
      fired = true;
    }
    g.update(dt);
    if (g.player.hits > 0) return false;
    if (g.distanceM > at + 2) break;
  }
  return true;
}

void Function(TaimarokuGame) _inputFor(Counter c) => switch (c) {
      Counter.swing => (g) => g.onTap(),
      Counter.jump => (g) => g.onFlickUp(),
      Counter.crouch => (g) => g.onFlickDown(),
    };

/// 避けられる入力タイミングの幅を秒で返す。
double _windowSec(Kind kind, int carNo) {
  final input = _inputFor(kind.counter);
  final speed = Tuning.runSpeedFor(carNo);
  var ok = 0;
  for (var cm = 5; cm <= 400; cm++) {
    if (_survives(kind, carNo, cm / 100, input)) ok++;
  }
  return ok * 0.01 / speed;
}

void main() {
  test('どの号車でも、すべての妖怪を正しい操作で避けられる', () {
    final rows = <String>[];
    for (final carNo in [1, 5, 10, 15]) {
      for (final k in kindsFor(carNo)) {
        final w = _windowSec(k, carNo);
        rows.add('$carNo号車 ${k.label.padRight(8)} 猶予 ${w.toStringAsFixed(3)}秒');
        expect(w, greaterThan(0.10), reason: '$carNo号車 の ${k.label} を避けられない');
      }
    }
    // ignore: avoid_print
    print(rows.join('\n'));
  });

  test('何もしなければ被弾する', () {
    for (final k in allKinds) {
      expect(_survives(k, 1, 0, (_) {}), isFalse, reason: k.label);
    }
  });

  test('号車が進むほど速くなり、上限で頭打ちになる', () {
    expect(Tuning.speedMulFor(1), 1.0);
    expect(Tuning.speedMulFor(8), greaterThan(Tuning.speedMulFor(4)));
    expect(Tuning.speedMulFor(30), Tuning.maxSpeedMul);
  });

  test('号車が進むほど敵が増え、新手が加わる', () {
    // 1号車はチュートリアルなので3体だけ。
    expect(buildCar(1, Tuning.carLengthM).length, 3);
    // 号車が進むほど、敵と敵の間隔（秒）が詰まる＝手数が増える。
    expect(Tuning.minGapSecFor(12), lessThan(Tuning.minGapSecFor(3)));
    expect(Tuning.enemyCountFor(12), greaterThan(Tuning.enemyCountFor(3)));
    for (var car = 2; car <= 20; car++) {
      expect(buildCar(car, Tuning.carLengthM).length, greaterThanOrEqualTo(4),
          reason: '$car号車 が空きすぎている');
    }
    expect(kindsFor(1).length, 3);
    expect(kindsFor(15).length, allKinds.length);
    expect(newKindAt(2)?.id, phoneZombie.id);
  });

  test('敵と敵の間隔は、捌ける時間を保っている', () {
    for (var carNo = 1; carNo <= 20; carNo++) {
      final car = buildCar(carNo, Tuning.carLengthM);
      final speed = Tuning.runSpeedFor(carNo);
      for (var i = 1; i < car.length; i++) {
        final gapSec = (car[i].distM - car[i - 1].distM) / speed;
        expect(gapSec, greaterThanOrEqualTo(0.55),
            reason: '$carNo号車 の $i体目と間隔が詰まりすぎている');
      }
    }
  });
}
