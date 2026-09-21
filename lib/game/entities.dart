import 'dart:math' as math;
import 'dart:ui';

import 'skeleton.dart';
import 'tuning.dart';

/// 来る高さ。プレイヤーの取るべき行動と1対1で対応する。
enum Lane { high, mid, low }

/// 正解の操作。
enum Counter { swing, jump, crouch }

/// 妖怪／障害の種類。
///
/// Phase 2 で JSON 化する前提なので、ここは「後で外に出せる形」で持っておく。
/// 全員が同じ骨格を使い、差分は [draw] のプロップ1つだけ。
class Kind {
  final String id;
  final String label;
  final Lane lane;
  final Counter counter;

  /// 薙いで倒せるか。倒せない相手は避けるしかない。
  final bool attackable;

  /// 当たり判定の半幅（メートル）。見た目の線とは切り離す。
  final double halfWidthM;

  final void Function(Canvas canvas, Offset origin, double ppm, Color color, double t)
      draw;

  const Kind({
    required this.id,
    required this.label,
    required this.lane,
    required this.counter,
    required this.attackable,
    required this.halfWidthM,
    required this.draw,
  });
}

/// ステージ上に置かれた1体。
class StageEntity {
  final Kind kind;

  /// 車両の先頭からの距離（メートル）。
  final double distM;

  bool dead = false;

  /// 殴られた／ぶつかった直後の点滅用。
  double flash = 0;

  /// 個体ごとの揺れの位相。全員が同じ動きに見えないように。
  final double phase;

  StageEntity(this.kind, this.distM, this.phase);
}

// ── 妖怪カタログ ──────────────────────────────────────

/// 音漏れ番長。正面に立ちはだかる。タップで薙ぐ。
final Kind audioBoss = Kind(
  id: 'audio_boss',
  label: '音漏れ番長',
  lane: Lane.mid,
  counter: Counter.swing,
  attackable: true,
  halfWidthM: 0.34,
  draw: (canvas, origin, ppm, color, t) {
    final p = Poses.stand(t * 2.2);
    StickPainter.draw(canvas, p, origin, ppm, color: color);

    final stroke = Paint()
      ..color = color
      ..strokeWidth = math.max(1.6, ppm * 0.026)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final head = Offset(origin.dx + p.head.dx * ppm, origin.dy - p.head.dy * ppm);

    // ヘッドバンド
    canvas.drawArc(
      Rect.fromCenter(center: head, width: ppm * 0.40, height: ppm * 0.40),
      math.pi, math.pi, false, stroke,
    );
    // イヤーカップ
    for (final sx in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: head + Offset(sx * ppm * 0.20, ppm * 0.02),
            width: ppm * 0.10,
            height: ppm * 0.16,
          ),
          Radius.circular(ppm * 0.04),
        ),
        stroke,
      );
    }
    // 音波。周りの敵を強化している、という記号。
    final pulse = 0.6 + 0.4 * math.sin(t * 6);
    for (var i = 1; i <= 2; i++) {
      final w = ppm * (0.34 + i * 0.22) * pulse;
      for (final sx in [-1.0, 1.0]) {
        canvas.drawArc(
          Rect.fromCenter(
            center: head + Offset(sx * ppm * 0.24, 0),
            width: w, height: w * 1.5,
          ),
          sx > 0 ? -math.pi / 2.4 : math.pi - math.pi / 1.7,
          math.pi / 1.2, false, stroke,
        );
      }
    }
  },
);

/// リュック魔人。頭の高さを横薙ぎしてくる。かがんでやり過ごす。
final Kind backpackMajin = Kind(
  id: 'backpack_majin',
  label: 'リュック魔人',
  lane: Lane.high,
  counter: Counter.crouch,
  attackable: false,
  halfWidthM: 0.14,
  draw: (canvas, origin, ppm, color, t) {
    final p = Poses.stand(t * 1.8);
    // 振り向きざまの横薙ぎ。腕が頭の高さを通る。
    final sweep = math.sin(t * 3.0);
    p.handF = p.neck + Offset(0.10 + 0.42 * sweep, 0.10);
    p.elbowF = Offset.lerp(p.neck, p.handF, 0.5)! + const Offset(0, 0.06);
    StickPainter.draw(canvas, p, origin, ppm, color: color);

    final stroke = Paint()
      ..color = color
      ..strokeWidth = math.max(2.0, ppm * 0.034)
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    Offset s(Offset m) => Offset(origin.dx + m.dx * ppm, origin.dy - m.dy * ppm);

    // 背中の箱。これがシルエットの目印。
    final box = Rect.fromLTRB(
      s(const Offset(-0.60, 0)).dx, s(const Offset(0, 1.30)).dy,
      s(const Offset(-0.06, 0)).dx, s(const Offset(0, 0.72)).dy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(ppm * 0.06)),
      stroke,
    );
    // 肩ひも
    canvas.drawLine(s(const Offset(-0.06, 1.24)), s(const Offset(0.05, 1.36)), stroke);
    canvas.drawLine(s(const Offset(-0.06, 0.86)), s(const Offset(0.05, 0.92)), stroke);
  },
);

/// キャリーバッグ。床に置きっぱなし。吊り革ジャンプで飛び越える。
final Kind carryCase = Kind(
  id: 'carry_case',
  label: 'キャリーバッグ',
  lane: Lane.low,
  counter: Counter.jump,
  attackable: false,
  halfWidthM: 0.14,
  draw: (canvas, origin, ppm, color, t) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = math.max(2.0, ppm * 0.034)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    Offset s(Offset m) => Offset(origin.dx + m.dx * ppm, origin.dy - m.dy * ppm);

    final body = Rect.fromLTRB(
      s(const Offset(-0.28, 0)).dx, s(const Offset(0, 0.62)).dy,
      s(const Offset(0.28, 0)).dx, s(const Offset(0, 0.09)).dy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(ppm * 0.05)),
      stroke,
    );
    // 引き手
    canvas.drawLine(s(const Offset(0.10, 0.62)), s(const Offset(0.10, 1.00)), stroke);
    canvas.drawLine(s(const Offset(0.10, 1.00)), s(const Offset(0.34, 1.00)), stroke);
    // 車輪
    for (final x in [-0.17, 0.17]) {
      canvas.drawCircle(s(Offset(x, 0.06)), ppm * 0.06, stroke);
    }
  },
);

/// スマホゾンビ。画面を見たまま逆走してくる。タップで押しのける。
final Kind phoneZombie = Kind(
  id: 'phone_zombie',
  label: 'スマホゾンビ',
  lane: Lane.mid,
  counter: Counter.swing,
  attackable: true,
  halfWidthM: 0.30,
  draw: (canvas, origin, ppm, color, t) {
    final p = Poses.stand(t * 1.6);
    // うつむいて、両腕を前に出している。
    p.head = p.head + const Offset(0.06, -0.10);
    p.handF = p.neck + const Offset(0.26, -0.30);
    p.handB = p.neck + const Offset(0.16, -0.32);
    p.elbowF = p.neck + const Offset(0.16, -0.18);
    p.elbowB = p.neck + const Offset(0.08, -0.20);
    StickPainter.draw(canvas, p, origin, ppm, color: color);

    final stroke = Paint()
      ..color = color
      ..strokeWidth = math.max(1.8, ppm * 0.028)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    Offset s(Offset m) => Offset(origin.dx + m.dx * ppm, origin.dy - m.dy * ppm);

    // 光る板。これが目印。
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          s(const Offset(0.13, 0)).dx, s(const Offset(0, 1.20)).dy,
          s(const Offset(0.35, 0)).dx, s(const Offset(0, 1.02)).dy,
        ),
        Radius.circular(ppm * 0.03),
      ),
      stroke,
    );
    // 画面から漏れる光
    final glow = 0.6 + 0.4 * math.sin(t * 7);
    for (final dx in [0.14, 0.24, 0.34]) {
      canvas.drawLine(
        s(Offset(dx, 1.24)),
        s(Offset(dx + 0.03, 1.24 + 0.12 * glow)),
        stroke,
      );
    }
  },
);

/// 傘の刃。濡れた折りたたみ傘が水平に突き出ている。飛び越える。
final Kind umbrellaBlade = Kind(
  id: 'umbrella_blade',
  label: '傘の刃',
  lane: Lane.low,
  counter: Counter.jump,
  attackable: false,
  halfWidthM: 0.12,
  draw: (canvas, origin, ppm, color, t) {
    final p = Poses.stand(t * 1.4);
    p.handF = p.neck + const Offset(0.22, -0.72);
    p.elbowF = p.neck + const Offset(0.18, -0.38);
    StickPainter.draw(canvas, p, origin, ppm, color: color);

    final stroke = Paint()
      ..color = color
      ..strokeWidth = math.max(2.0, ppm * 0.032)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    Offset s(Offset m) => Offset(origin.dx + m.dx * ppm, origin.dy - m.dy * ppm);

    // 水平に伸びた1本線。判定は細いが、足を引っかける。
    final sway = math.sin(t * 2.2) * 0.03;
    canvas.drawLine(
        s(Offset(-0.62, 0.70 + sway)), s(const Offset(0.30, 0.70)), stroke);
    canvas.drawLine(
      s(Offset(-0.62, 0.70 + sway)),
      s(Offset(-0.74, 0.62 + sway)),
      stroke,
    );
  },
);

/// ゲホ坊。正面にいるが倒せない。かがんで飛沫をやり過ごす。
final Kind coughBozu = Kind(
  id: 'cough_bozu',
  label: 'ゲホ坊',
  lane: Lane.high,
  counter: Counter.crouch,
  attackable: false,
  halfWidthM: 0.16,
  draw: (canvas, origin, ppm, color, t) {
    final p = Poses.stand(t * 2.6);
    // 口元に手をやる。
    p.handF = p.neck + const Offset(0.12, -0.10);
    p.elbowF = p.neck + const Offset(0.24, -0.30);
    StickPainter.draw(canvas, p, origin, ppm, color: color);

    final dot = Paint()..color = color;
    Offset s(Offset m) => Offset(origin.dx + m.dx * ppm, origin.dy - m.dy * ppm);

    // 飛沫。頭の高さに飛ぶので、かがめば当たらない。
    final phase = (t * 1.4) % 1.0;
    for (var i = 0; i < 5; i++) {
      final d = 0.22 + phase * 0.5 + i * 0.16;
      final y = 1.52 - i * 0.04 + math.sin(t * 9 + i) * 0.03;
      canvas.drawCircle(s(Offset(-d, y)), ppm * (0.035 - i * 0.004), dot);
    }
  },
);

/// 寝落ち侍。もたれかかってくる。かがんですり抜ける。
final Kind sleeper = Kind(
  id: 'sleeper',
  label: '寝落ち侍',
  lane: Lane.high,
  counter: Counter.crouch,
  attackable: false,
  halfWidthM: 0.18,
  draw: (canvas, origin, ppm, color, t) {
    final p = Poses.stand(t * 0.9);
    // 頭が肩に傾いている。
    final tilt = 0.10 + math.sin(t * 0.8) * 0.03;
    p.head = p.head + Offset(-tilt * 2.2, -0.06);
    p.neck = p.neck + Offset(-tilt, 0);
    StickPainter.draw(canvas, p, origin, ppm, color: color);

    final stroke = Paint()
      ..color = color
      ..strokeWidth = math.max(1.6, ppm * 0.024)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    Offset s(Offset m) => Offset(origin.dx + m.dx * ppm, origin.dy - m.dy * ppm);

    // Z が浮かぶ。
    final float = (t * 0.6) % 1.0;
    for (var i = 0; i < 2; i++) {
      final y = 1.70 + i * 0.16 + float * 0.14;
      final x = -0.34 - i * 0.10;
      final w = 0.12 - i * 0.03;
      canvas.drawLine(s(Offset(x, y + w)), s(Offset(x + w, y + w)), stroke);
      canvas.drawLine(s(Offset(x + w, y + w)), s(Offset(x, y)), stroke);
      canvas.drawLine(s(Offset(x, y)), s(Offset(x + w, y)), stroke);
    }
  },
);

/// 全カタログ。
final List<Kind> allKinds = [
  audioBoss,
  backpackMajin,
  carryCase,
  phoneZombie,
  umbrellaBlade,
  coughBozu,
  sleeper,
];

/// 何号車から出てくるか。号車が進むごとに新手が加わる。
final Map<String, int> unlockCar = {
  carryCase.id: 1,
  backpackMajin.id: 1,
  audioBoss.id: 1,
  phoneZombie.id: 2,
  umbrellaBlade.id: 4,
  coughBozu.id: 6,
  sleeper.id: 8,
};

/// その号車で初めて出てくる妖怪（いなければ null）。
Kind? newKindAt(int carNo) {
  for (final k in allKinds) {
    if (unlockCar[k.id] == carNo && carNo > 1) return k;
  }
  return null;
}

/// その号車までに解禁されている妖怪。
List<Kind> kindsFor(int carNo) =>
    allKinds.where((k) => (unlockCar[k.id] ?? 1) <= carNo).toList();

// ── 1両ぶんの配置 ────────────────────────────────────

/// 1両（20m）ぶんのスポーンテーブルを作る。
///
/// Phase 1 は手書きの1両を繰り返すだけ。号車が進むほど密度を上げる。
/// Phase 2 でここを cars.json に外出しする。
List<StageEntity> buildCar(int carNo, double carLengthM) {
  final rnd = math.Random(carNo * 7919 + 13);
  final out = <StageEntity>[];

  // 1号車はチュートリアル。3つの操作を1回ずつ、順番に使わせる。
  if (carNo <= 1) {
    for (final (d, k) in <(double, Kind)>[
      (5.0, carryCase),
      (10.0, backpackMajin),
      (15.0, audioBoss),
    ]) {
      out.add(StageEntity(k, d, rnd.nextDouble() * 6.28));
    }
    return out;
  }

  final pool = kindsFor(carNo);

  // 号車が進むほど数が増える。
  final count = Tuning.enemyCountFor(carNo);

  // 間隔は「距離」ではなく「秒」で決める。速くなるほど実距離は広がるが、
  // 前の敵を捌いてから次に反応するまでの時間は号車が進むほど短くなる。
  final minGapM = Tuning.minGapSecFor(carNo) * Tuning.runSpeedFor(carNo);

  const first = 3.0;
  final last = carLengthM - 1.5;
  final step = (last - first) / math.max(1, count - 1);

  // その号車で初登場する妖怪は、必ず最初に単独で出す（見せ場を作る）。
  final debut = newKindAt(carNo);

  var prev = -99.0;
  for (var i = 0; i < count; i++) {
    var d = first + i * step + (rnd.nextDouble() - 0.5) * step * 0.4;
    if (d - prev < minGapM) d = prev + minGapM;
    if (d > last) break;

    final kind = (i == 0 && debut != null) ? debut : pool[rnd.nextInt(pool.length)];
    out.add(StageEntity(kind, d, rnd.nextDouble() * 6.28));
    prev = d;
  }

  return out;
}
