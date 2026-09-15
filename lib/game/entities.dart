import 'dart:math' as math;
import 'dart:ui';

import 'skeleton.dart';

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

/// 全カタログ。
final List<Kind> allKinds = [audioBoss, backpackMajin, carryCase];

// ── 1両ぶんの配置 ────────────────────────────────────

/// 1両（20m）ぶんのスポーンテーブルを作る。
///
/// Phase 1 は手書きの1両を繰り返すだけ。号車が進むほど密度を上げる。
/// Phase 2 でここを cars.json に外出しする。
List<StageEntity> buildCar(int carNo, double carLengthM) {
  final rnd = math.Random(carNo * 7919 + 13);
  final out = <StageEntity>[];

  // 基本の並び。3つの操作をひと通り使わせる。
  final base = <(double, Kind)>[
    (4.0, carryCase),
    (9.0, backpackMajin),
    (13.5, audioBoss),
    (17.0, carryCase),
  ];
  for (final (d, k) in base) {
    out.add(StageEntity(k, d + rnd.nextDouble() * 0.8 - 0.4, rnd.nextDouble() * 6.28));
  }

  // 号車が進むほど1体ずつ増やす。ただし詰まりすぎないよう間隔を確保する。
  final extra = math.min(4, (carNo - 1) ~/ 2);
  for (var i = 0; i < extra; i++) {
    final kind = allKinds[rnd.nextInt(allKinds.length)];
    var d = 2.0 + rnd.nextDouble() * (carLengthM - 4.0);
    // 既存の敵と 2.2m 以上あける。反応時間を確保するための最低間隔。
    var tries = 0;
    while (out.any((e) => (e.distM - d).abs() < 2.2) && tries < 12) {
      d = 2.0 + rnd.nextDouble() * (carLengthM - 4.0);
      tries++;
    }
    if (tries < 12) {
      out.add(StageEntity(kind, d, rnd.nextDouble() * 6.28));
    }
  }

  out.sort((a, b) => a.distM.compareTo(b.distM));
  return out;
}
