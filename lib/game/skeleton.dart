import 'dart:math' as math;
import 'dart:ui';

/// 棒人間の骨格。
///
/// 座標はすべて「メートル・足元が原点・+y が上」のローカル空間で持つ。
/// 画像は一切使わず、関節座標から線を引くだけで描く。
/// 敵を増やすときも、この骨格に持ち物（プロップ）を1つ足すだけで済む。
class Pose {
  Offset head = Offset.zero;
  Offset neck = Offset.zero;
  Offset hip = Offset.zero;
  Offset elbowF = Offset.zero;
  Offset handF = Offset.zero;
  Offset elbowB = Offset.zero;
  Offset handB = Offset.zero;
  Offset kneeF = Offset.zero;
  Offset footF = Offset.zero;
  Offset kneeB = Offset.zero;
  Offset footB = Offset.zero;

  double headR = 0.135;

  /// 吊り革を掴んでいる間だけ true。掴んでいる吊り革も一緒に描く。
  bool gripStrap = false;

  /// 前傾角（ラジアン）。腰を軸に体幹の残量ぶん前へ倒す。
  double lean = 0.0;
}

/// 骨格の基準寸法（メートル）。
class _Body {
  static const double hipY = 0.92;
  static const double neckY = 1.42;
  static const double headY = 1.585;
  static const double armReach = 0.52;
}

/// 各状態のポーズを組み立てる。
class Poses {
  /// 走り。[phase] は歩幅の位相（ラジアン）。
  static Pose run(double phase) {
    final p = Pose();
    // 上下の揺れ。1歩ごとに1回沈む。
    final bob = math.sin(phase * 2) * 0.022;
    p.hip = Offset(0, _Body.hipY + bob);
    p.neck = Offset(0.02, _Body.neckY + bob);
    p.head = Offset(0.05, _Body.headY + bob);

    _legs(p, phase);
    _armsSwing(p, phase);
    return p;
  }

  /// 立ち。敵の基本姿勢。[bob] は呼吸ぶんの上下（ラジアン）。
  /// 全員がこの同じ骨格を使い、差分は持ち物だけにする。
  static Pose stand(double bob) {
    final p = Pose();
    final b = math.sin(bob) * 0.012;
    p.hip = Offset(0, _Body.hipY + b);
    p.neck = Offset(0, _Body.neckY + b);
    p.head = Offset(0, _Body.headY + b);
    p.kneeF = p.hip + const Offset(0.09, -0.44);
    p.footF = p.hip + const Offset(0.14, -_Body.hipY);
    p.kneeB = p.hip + const Offset(-0.09, -0.44);
    p.footB = p.hip + const Offset(-0.14, -_Body.hipY);
    p.handF = p.neck + const Offset(0.20, -0.44);
    p.handB = p.neck + const Offset(-0.20, -0.44);
    p.elbowF = p.neck + const Offset(0.14, -0.24);
    p.elbowB = p.neck + const Offset(-0.14, -0.24);
    return p;
  }

  /// 吊り革ジャンプ。[t] は 0→1 の進行度。
  /// 体全体を持ち上げるのは呼び出し側（描画時のyオフセット）。
  static Pose jump(double t) {
    final p = Pose();
    // 飛び出しで体を伸ばし、頂点で足を畳む。
    final tuck = math.sin(math.pi * t.clamp(0.0, 1.0));
    p.hip = Offset(0, _Body.hipY + 0.06 * tuck);
    p.neck = Offset(0, _Body.neckY + 0.06 * tuck);
    p.head = Offset(0, _Body.headY + 0.06 * tuck);

    // 両腕を上へ。吊り革を掴んでいる。
    p.handF = p.neck + const Offset(0.13, 0.40);
    p.handB = p.neck + const Offset(-0.07, 0.42);
    p.elbowF = Offset.lerp(p.neck, p.handF, 0.5)! + const Offset(0.07, -0.02);
    p.elbowB = Offset.lerp(p.neck, p.handB, 0.5)! + const Offset(-0.08, -0.02);
    p.gripStrap = true;

    // 足を畳む。
    p.kneeF = p.hip + Offset(0.20, -0.30 + 0.10 * tuck);
    p.footF = p.kneeF + Offset(0.02, -0.26 + 0.16 * tuck);
    p.kneeB = p.hip + Offset(-0.16, -0.32 + 0.10 * tuck);
    p.footB = p.kneeB + Offset(-0.10, -0.28 + 0.14 * tuck);
    return p;
  }

  /// かがむ。[t] は 0→1 の進行度。中間でいちばん低くなる。
  static Pose crouch(double t) {
    final p = Pose();
    final c = math.sin(math.pi * t.clamp(0.0, 1.0));
    final drop = 0.40 * c;

    p.hip = Offset(0.04 * c, _Body.hipY - drop);
    p.neck = Offset(0.10 * c, _Body.neckY - drop - 0.14 * c);
    p.head = Offset(0.14 * c, _Body.headY - drop - 0.20 * c);

    // 膝を畳んで踵を寄せる。
    p.kneeF = p.hip + Offset(0.26 + 0.06 * c, -0.24 + 0.10 * c);
    p.footF = p.kneeF + Offset(-0.06, -(p.kneeF.dy));
    p.kneeB = p.hip + Offset(-0.10, -0.28 + 0.12 * c);
    p.footB = p.kneeB + Offset(-0.14, -(p.kneeB.dy));

    // 腕は体の前で抱える。
    p.handF = p.neck + const Offset(0.30, -0.16);
    p.handB = p.neck + const Offset(-0.16, -0.22);
    p.elbowF = Offset.lerp(p.neck, p.handF, 0.5)! + const Offset(0.02, -0.08);
    p.elbowB = Offset.lerp(p.neck, p.handB, 0.5)! + const Offset(-0.08, -0.04);
    return p;
  }

  /// 薙ぎ払いを既存のポーズに上書きする。[t] は 0→1。
  /// 後ろに引いた腕が前へ振り抜ける。カバンは手に追従する。
  static void applySwing(Pose p, double t) {
    final e = _easeOutCubic(t.clamp(0.0, 1.0));
    // 角度は +x を0として反時計回り。後ろ上 → 前下 へ。
    final a = _lerp(2.45, -0.25, e);
    p.handF = p.neck + Offset(math.cos(a) * _Body.armReach, math.sin(a) * _Body.armReach);
    p.elbowF = p.neck +
        Offset(math.cos(a + 0.35) * _Body.armReach * 0.52,
            math.sin(a + 0.35) * _Body.armReach * 0.52);
  }

  static void _legs(Pose p, double phase) {
    // 足先を楕円軌道に乗せる。持ち上げは前半だけ。
    Offset foot(double ph) {
      final x = math.cos(ph) * 0.30;
      final lift = math.max(0.0, math.sin(ph)) * 0.20;
      return Offset(x, lift);
    }

    p.footF = foot(phase);
    p.footB = foot(phase + math.pi);
    // 膝は腰と足の中間をやや前に押し出す。
    p.kneeF = Offset.lerp(p.hip, p.footF, 0.5)! + const Offset(0.09, 0.015);
    p.kneeB = Offset.lerp(p.hip, p.footB, 0.5)! + const Offset(0.07, 0.015);
  }

  static void _armsSwing(Pose p, double phase) {
    // 腕は脚と逆位相。
    final a = phase + math.pi;
    p.handF = p.neck + Offset(math.cos(a) * 0.22 + 0.06, -0.34 + math.sin(a) * 0.05);
    p.handB = p.neck + Offset(math.cos(phase) * 0.22 - 0.02, -0.34 + math.sin(phase) * 0.05);
    p.elbowF = Offset.lerp(p.neck, p.handF, 0.55)! + const Offset(0.03, -0.02);
    p.elbowB = Offset.lerp(p.neck, p.handB, 0.55)! + const Offset(-0.04, -0.02);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
  static double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
}

/// 骨格をキャンバスに描く。
///
/// [origin] は足元の画面座標、[ppm] は 1メートルあたりのピクセル数。
class StickPainter {
  static void draw(
    Canvas canvas,
    Pose pose,
    Offset origin,
    double ppm, {
    required Color color,
    double strokeScale = 1.0,
    bool withBag = false,
  }) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = math.max(2.0, ppm * 0.036 * strokeScale)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final solid = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // メートル → 画面座標。腰を軸に lean ぶん前へ倒す。
    final pivot = pose.hip;
    final cosL = math.cos(-pose.lean);
    final sinL = math.sin(-pose.lean);
    Offset s(Offset m) {
      final d = m - pivot;
      final rx = d.dx * cosL - d.dy * sinL;
      final ry = d.dx * sinL + d.dy * cosL;
      final w = pivot + Offset(rx, ry);
      return Offset(origin.dx + w.dx * ppm, origin.dy - w.dy * ppm);
    }

    void line(Offset a, Offset b) => canvas.drawLine(s(a), s(b), stroke);

    // 吊り革（掴んでいるときだけ）
    if (pose.gripStrap) {
      final grip = Offset.lerp(pose.handF, pose.handB, 0.5)!;
      final loop = grip + const Offset(0, 0.10);
      canvas.drawLine(s(loop), s(loop + const Offset(0, 0.16)), stroke);
      canvas.drawOval(
        Rect.fromCenter(
          center: s(loop),
          width: ppm * 0.19,
          height: ppm * 0.17,
        ),
        stroke,
      );
    }

    // 胴・脚・腕
    line(pose.neck, pose.hip);
    line(pose.hip, pose.kneeF);
    line(pose.kneeF, pose.footF);
    line(pose.hip, pose.kneeB);
    line(pose.kneeB, pose.footB);
    line(pose.neck, pose.elbowB);
    line(pose.elbowB, pose.handB);
    line(pose.neck, pose.elbowF);
    line(pose.elbowF, pose.handF);

    // 頭は塗りつぶし。小さくても輪郭より読みやすい。
    canvas.drawCircle(s(pose.head), pose.headR * ppm, solid);

    // 通勤カバン。前の手にぶら下がる。
    if (withBag) {
      final c = s(pose.handF + const Offset(0.02, -0.14));
      final r = Rect.fromCenter(center: c, width: ppm * 0.30, height: ppm * 0.22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(ppm * 0.03)),
        stroke,
      );
    }
  }
}

/// 転倒したときのラグドール。
///
/// 棒人間は関節が10個ほどしかないので、素朴なVerlet積分で十分に崩れる。
/// 負けた瞬間がいちばん面白い、を成立させるためだけの仕組み。
class Ragdoll {
  final List<Offset> pos = [];
  final List<Offset> prev = [];
  final List<_Link> _links = [];

  static const double _gravity = -11.0; // m/s^2（誇張してある）
  static const double _floorFriction = 0.72;

  /// 転倒直前のポーズから初期化する。[forward] は進行方向の速さ(m/s)。
  Ragdoll.fromPose(Pose p, double forward) {
    final pts = <Offset>[
      p.head, p.neck, p.hip, //
      p.elbowF, p.handF, p.elbowB, p.handB, //
      p.kneeF, p.footF, p.kneeB, p.footB,
    ];
    final rnd = math.Random(7);
    for (final pt in pts) {
      pos.add(pt);
      // 前へつんのめる初速。上半身ほど強く飛ぶ。
      final v = Offset(
        forward * 0.9 + rnd.nextDouble() * 0.6,
        1.4 + pt.dy * 0.9 + rnd.nextDouble() * 0.5,
      );
      prev.add(pt - v * (1 / 60));
    }
    void link(int a, int b) => _links.add(_Link(a, b, (pts[a] - pts[b]).distance));
    link(0, 1); // 頭-首
    link(1, 2); // 首-腰
    link(1, 3); link(3, 4); // 前腕
    link(1, 5); link(5, 6); // 後腕
    link(2, 7); link(7, 8); // 前脚
    link(2, 9); link(9, 10); // 後脚
    link(0, 2); // 頭-腰（胴が折れすぎないように）
  }

  void update(double dt) {
    for (var i = 0; i < pos.length; i++) {
      final v = (pos[i] - prev[i]) * 0.99;
      prev[i] = pos[i];
      pos[i] = pos[i] + v + const Offset(0, _gravity) * (dt * dt);
    }
    for (var k = 0; k < 6; k++) {
      for (final l in _links) {
        final d = pos[l.b] - pos[l.a];
        final dist = d.distance;
        if (dist == 0) continue;
        final corr = d * ((dist - l.len) / dist * 0.5);
        pos[l.a] = pos[l.a] + corr;
        pos[l.b] = pos[l.b] - corr;
      }
      // 床。めり込んだら押し戻して横に滑らせる。
      for (var i = 0; i < pos.length; i++) {
        if (pos[i].dy < 0) {
          pos[i] = Offset(pos[i].dx, 0);
          prev[i] = Offset(
            pos[i].dx + (prev[i].dx - pos[i].dx) * _floorFriction,
            0,
          );
        }
      }
    }
  }

  void draw(Canvas canvas, Offset origin, double ppm, Color color) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = math.max(2.0, ppm * 0.036)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    Offset s(Offset m) => Offset(origin.dx + m.dx * ppm, origin.dy - m.dy * ppm);
    for (final l in _links) {
      if (l.a == 0 && l.b == 2) continue; // 補助リンクは描かない
      canvas.drawLine(s(pos[l.a]), s(pos[l.b]), stroke);
    }
    canvas.drawCircle(s(pos[0]), 0.135 * ppm, Paint()..color = color);
  }
}

class _Link {
  final int a;
  final int b;
  final double len;
  const _Link(this.a, this.b, this.len);
}
