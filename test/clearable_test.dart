import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tsukin_taimaroku/game/entities.dart';
import 'package:tsukin_taimaroku/game/taimaroku_game.dart';
import 'package:tsukin_taimaroku/game/tuning.dart';

/// 1回の走行結果。
class Run {
  final int car;
  final int hits;
  final int falls;
  final double timeLeft;
  final List<String> notes;
  const Run(this.car, this.hits, this.falls, this.timeLeft, this.notes);

  bool get cleared => car >= 15;

  @override
  String toString() => '到達 $car号車 / 被弾 $hits / 転倒 $falls / '
      '残り ${timeLeft.toStringAsFixed(1)}秒';
}

/// 手で遊ぶ代わりのボット。
///
/// [latenessSec] は反応の遅れ。0 なら理論上の最適タイミングで入力する。
/// 人間の腕前の差を、この1つの数字で表す。
Run playBot(double latenessSec) {
  final g = TaimarokuGame()..state = GameState.running;
  final handled = <Placed>{};
  final notes = <String>[];
  const dt = 1 / 60;

  // ジャンプが必要な高さまで上がるのにかかる時間。
  final tRise = math.asin(Tuning.jumpClearHeightM / Tuning.jumpHeightM) /
      math.pi *
      Tuning.jumpSec;

  for (var i = 0; i < 60 * 200; i++) {
    final speed = Tuning.runSpeedFor(g.carNo);

    // 転んでいる間は何も出せない。起き上がったら覚え直す。
    if (g.player.isFallen) {
      handled.clear();
      g.update(dt);
      continue;
    }

    // いちばん近い、まだ片付けていない敵だけを見る。
    Placed? target;
    var best = double.infinity;
    for (final p in g.entities) {
      if (p.e.dead || handled.contains(p)) continue;
      final gap = p.absDistM - g.distanceM;
      if (gap < -1 || gap >= best) continue;
      best = gap;
      target = p;
    }

    if (target != null) {
      final p = target;
      final gap = best;
      final half = p.e.kind.halfWidthM + 0.22;
      final trigger = switch (p.e.kind.counter) {
        // カバンが届く距離に入る少し前に振る。
        Counter.swing => Tuning.swingReachM + speed * 0.13,
        // 重なる手前で、必要な高さまで上がり切っているように飛ぶ。
        Counter.jump => half + speed * (tRise + 0.05),
        // 重なる手前で、かがみ切っているようにしゃがむ。
        Counter.crouch => half + speed * (Tuning.crouchStartupSec + 0.06),
      };
      if (gap <= trigger - speed * latenessSec) {
        switch (p.e.kind.counter) {
          case Counter.swing:
            // 振り損ねたら、届くうちに振り直す。
            if (g.player.swingT < 0 && g.player.swingCooldown <= 0) g.onTap();
            if (gap < 0.6) handled.add(p);
          case Counter.jump:
            g.onFlickUp();
            handled.add(p);
          case Counter.crouch:
            g.onFlickDown();
            handled.add(p);
        }
      }
    }

    final before = g.player.hits;
    g.update(dt);
    if (g.player.hits > before) {
      // ぶつかった相手は、このフレームで消えた敵。
      final victim = g.entities.where((p) => p.e.dead && p.e.flash > 0.30);
      for (final v in victim) {
        notes.add('${g.carNo}号車 ${v.e.kind.label}（${v.e.kind.counter.name}）'
            'に接触 状態=${g.player.state.name} '
            '次の敵まで${best.toStringAsFixed(2)}m');
      }
    }
    if (g.state == GameState.finished) break;
    if (g.carNo >= 15) break;
  }

  return Run(g.bestCar, g.player.hits, g.player.falls, g.timeLeft, notes);
}

void main() {
  test('最適に操作すればクリアできる（ただし余裕はほとんどない）', () {
    final r = playBot(0);
    // ignore: avoid_print
    print('最適  : $r');
    // ignore: avoid_print
    if (r.notes.isNotEmpty) print('被弾した場面:\n  ${r.notes.join("\n  ")}');
    expect(r.hits, 0, reason: '最適に操作しても避けられない配置がある');
    expect(r.cleared, isTrue, reason: '最適に操作してもクリアできない＝難しすぎる');
    expect(r.timeLeft, lessThan(20),
        reason: '最適でこれだけ余るなら、まだ簡単すぎる');
  });

  test('反応が少しでも鈍るとクリアできない', () {
    final rows = <String>[];
    for (final late in [0.04, 0.06, 0.08, 0.12]) {
      final r = playBot(late);
      rows.add('遅れ ${late.toStringAsFixed(2)}秒 : $r');
    }
    // ignore: avoid_print
    print(rows.join('\n'));

    // 0.08秒（約5フレーム）遅れる程度でクリアできてしまうなら緩すぎる。
    expect(playBot(0.08).cleared, isFalse);
  });

  test('号車ごとの厳しさ', () {
    final rows = <String>[];
    for (final car in [1, 5, 10, 15]) {
      rows.add('$car号車  速度 ×${Tuning.speedMulFor(car).toStringAsFixed(2)}  '
          '見えてから届くまで '
          '${(Tuning.targetReactionSec / Tuning.speedMulFor(car)).toStringAsFixed(2)}秒  '
          '敵 ${Tuning.enemyCountFor(car)}体  '
          '最小間隔 ${Tuning.minGapSecFor(car).toStringAsFixed(2)}秒');
    }
    // ignore: avoid_print
    print(rows.join('\n'));

    // かがみ終わる前に次が来る配置は作らない。
    for (var car = 1; car <= 20; car++) {
      expect(Tuning.minGapSecFor(car), greaterThan(Tuning.crouchSec),
          reason: '$car号車 の間隔がかがみより短い');
    }
  });
}
