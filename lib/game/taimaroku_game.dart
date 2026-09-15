import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'entities.dart';
import 'palette.dart';
import 'player.dart';
import 'skeleton.dart';
import 'tuning.dart';

enum GameState { ready, running, finished }

/// 通勤退魔録 Phase 1。
///
/// 1両（20m）を繰り返し生成し、到着までに何号車まで行けるかを競う。
/// 検証したいのは「片手で気持ちよく走れるか」だけなので、
/// 一般客・迷惑度・ボスは入れていない（Phase 2）。
class TaimarokuGame extends FlameGame {
  final Player player = Player();

  GameState state = GameState.ready;

  /// 車両の先頭から数えた累計距離（メートル）。
  double distanceM = 0;

  double timeLeft = Tuning.timeLimitSec;

  /// 生成済みの車両番号（1始まり）。
  int generatedCars = 0;
  final List<Placed> entities = [];

  /// 到達した最高号車。
  int bestCar = 1;

  double _shake = 0;
  double _clock = 0;

  /// 1メートルあたりのピクセル数。画面幅から逆算するので、
  /// どの端末でも「敵が見えてから届くまでの秒数」が一定になる。
  double ppm = 60;

  int get carNo => (distanceM / Tuning.carLengthM).floor() + 1;
  double get carProgress => (distanceM % Tuning.carLengthM) / Tuning.carLengthM;

  double get _playerX => size.x * Tuning.playerXRatio;
  double get _groundY => size.y * Tuning.groundYRatio;

  @override
  Color backgroundColor() => Palette.night;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    ppm = (size.x * (1 - Tuning.playerXRatio)) /
        (Tuning.runSpeedMps * Tuning.targetReactionSec);
  }

  // ── 入力 ────────────────────────────────────────────

  void onTap() {
    if (state == GameState.ready) {
      state = GameState.running;
      return;
    }
    if (state == GameState.finished) {
      restart();
      return;
    }
    player.tap();
  }

  void onFlickUp() {
    if (state != GameState.running) return onTap();
    player.flickUp();
  }

  void onFlickDown() {
    if (state != GameState.running) return onTap();
    player.flickDown();
  }

  void restart() {
    player.reset();
    distanceM = 0;
    timeLeft = Tuning.timeLimitSec;
    generatedCars = 0;
    entities.clear();
    bestCar = 1;
    _shake = 0;
    state = GameState.running;
  }

  // ── 更新 ────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    if (_shake > 0) _shake -= dt;
    if (state != GameState.running) return;

    // 進む。かがむと減速し、転倒中は止まる。
    final moved = Tuning.runSpeedMps * player.speedFactor * dt;
    distanceM += moved;
    player.update(dt, moved);

    timeLeft -= dt;
    if (timeLeft <= 0) {
      timeLeft = 0;
      state = GameState.finished;
      return;
    }

    bestCar = math.max(bestCar, carNo);
    _ensureCarsGenerated();
    _resolveSwing();
    _resolveCollisions();

    for (final p in entities) {
      if (p.e.flash > 0) p.e.flash -= dt;
    }

    // 通り過ぎたものは捨てる。
    entities.removeWhere((e) => e.absDistM < distanceM - 3.0);
  }

  void _ensureCarsGenerated() {
    // 画面に入る手前まで先に作っておく。
    final needUpTo = ((distanceM + Tuning.carLengthM * 1.5) / Tuning.carLengthM).ceil();
    while (generatedCars < needUpTo) {
      generatedCars++;
      final base = (generatedCars - 1) * Tuning.carLengthM;
      for (final e in buildCar(generatedCars, Tuning.carLengthM)) {
        entities.add(Placed(e, base + e.distM));
      }
    }
  }

  /// 薙ぎの判定。届く範囲の「倒せる相手」だけを吹き飛ばす。
  void _resolveSwing() {
    if (!player.swingActive) return;
    for (final p in entities) {
      if (p.e.dead || !p.e.kind.attackable) continue;
      final d = p.absDistM - distanceM;
      if (d >= -0.2 && d <= Tuning.swingReachM) {
        p.e.dead = true;
        p.e.flash = 0.28;
        _shake = 0.10;
      }
    }
  }

  /// 当たり判定は「上・中・下の3レーン × 進行方向の距離」だけで持つ。
  /// 棒人間の細い線に厳密な判定を付けると「避けたのに当たった」が頻発するため、
  /// 見た目の線と判定は最初から切り離してある。
  void _resolveCollisions() {
    const playerHalfM = 0.22;
    for (final p in entities) {
      if (p.e.dead) continue;
      final gap = (p.absDistM - distanceM).abs();
      if (gap > p.e.kind.halfWidthM + playerHalfM) continue;

      final avoided = switch (p.e.kind.lane) {
        Lane.low => player.clearsLow,
        Lane.high => player.duckingHigh,
        Lane.mid => false,
      };
      if (avoided) continue;

      // ぶつかった。押しのけて先へ進めるが、体幹を持っていかれる。
      p.e.dead = true;
      p.e.flash = 0.35;
      player.takeHit();
      _shake = 0.22;
    }
  }

  // ── 描画 ────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    if (_shake > 0) {
      final s = _shake * 26;
      canvas.translate(
        (math.Random().nextDouble() - 0.5) * s,
        (math.Random().nextDouble() - 0.5) * s,
      );
    }

    _drawCarInterior(canvas);
    _drawEntities(canvas);
    _drawPlayer(canvas);
    canvas.restore();

    _drawHud(canvas);
    if (state == GameState.ready) _drawReady(canvas);
    if (state == GameState.finished) _drawResult(canvas);
  }

  /// 画面座標に変換する。ワールドは「距離(m)」の1次元。
  double _sx(double worldM) => _playerX + (worldM - distanceM) * ppm;

  void _drawCarInterior(Canvas canvas) {
    final bandTop = size.y * Tuning.bandTopRatio;

    // 天井側のわずかな明るさ。窓の外は暗い。
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.x, _groundY),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.nightUp, Palette.night],
        ).createShader(Rect.fromLTWH(0, 0, size.x, _groundY)),
    );

    final thin = Paint()
      ..color = Palette.rule
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 窓。2.6mごとに流れる。
    const winPitch = 2.6;
    final firstWin = (distanceM / winPitch).floor() - 1;
    for (var i = firstWin; i < firstWin + 12; i++) {
      final x = _sx(i * winPitch);
      if (x > size.x + 60 || x < -160) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, bandTop + ppm * 0.30, ppm * 1.55, ppm * 0.90),
          const Radius.circular(2),
        ),
        thin,
      );
    }

    // 吊り革。0.9mごと。
    const strapPitch = 0.9;
    final firstStrap = (distanceM / strapPitch).floor() - 1;
    for (var i = firstStrap; i < firstStrap + 30; i++) {
      final x = _sx(i * strapPitch);
      if (x > size.x + 20 || x < -20) continue;
      canvas.drawLine(Offset(x, bandTop - ppm * 0.34), Offset(x, bandTop - ppm * 0.10), thin);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, bandTop), width: ppm * 0.20, height: ppm * 0.22),
        thin,
      );
    }

    // 床。
    canvas.drawLine(
      Offset(0, _groundY),
      Offset(size.x, _groundY),
      Paint()
        ..color = Palette.rule
        ..strokeWidth = 2,
    );

    // 連結部のドア。ここがチェックポイント。
    for (var n = carNo - 1; n <= carNo + 2; n++) {
      final x = _sx(n * Tuning.carLengthM);
      if (x > size.x + 80 || x < -80) continue;
      final w = ppm * 0.9;
      final h = ppm * 1.95;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x - w / 2, _groundY - h, w, h),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        Paint()
          ..color = Palette.dim
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
      _text(canvas, '${n + 1}号車', Offset(x, _groundY - h - ppm * 0.34),
          color: Palette.dim, size: ppm * 0.16, center: true);
    }
  }

  void _drawEntities(Canvas canvas) {
    for (final p in entities) {
      final x = _sx(p.absDistM);
      if (x > size.x + 120 || x < -120) continue;

      if (p.e.dead) {
        // 吹き飛んだ／押しのけた直後だけ、薄く残す。
        if (p.e.flash <= 0) continue;
        final a = (p.e.flash / 0.35).clamp(0.0, 1.0);
        p.e.kind.draw(canvas, Offset(x + (1 - a) * ppm * 0.6, _groundY), ppm,
            Palette.enemy.withValues(alpha: a * 0.5), _clock + p.e.phase);
        continue;
      }

      p.e.kind.draw(
        canvas,
        Offset(x, _groundY),
        ppm,
        Palette.enemy,
        _clock + p.e.phase,
      );

      // 何をすればいいかのラベル。Phase 1 は検証用に常時出す。
      final hint = switch (p.e.kind.counter) {
        Counter.swing => '薙ぐ',
        Counter.jump => '↑',
        Counter.crouch => '↓',
      };
      _text(canvas, hint, Offset(x, _groundY + ppm * 0.20),
          color: Palette.enemy.withValues(alpha: 0.7), size: ppm * 0.15, center: true);
    }
  }

  void _drawPlayer(Canvas canvas) {
    final origin = Offset(_playerX, _groundY - player.liftM * ppm);

    if (player.isFallen && player.ragdoll != null) {
      player.ragdoll!.draw(canvas, Offset(_playerX, _groundY), ppm, Palette.you);
      _text(canvas, '起き上がり中 ${player.fallT.toStringAsFixed(1)}',
          Offset(_playerX, _groundY + ppm * 0.30),
          color: Palette.you, size: ppm * 0.17, center: true);
      return;
    }

    StickPainter.draw(
      canvas,
      player.buildPose(),
      origin,
      ppm,
      color: Palette.you,
      withBag: true,
    );
  }

  // ── HUD ─────────────────────────────────────────────

  void _drawHud(Canvas canvas) {
    final pad = size.x * 0.05;
    final panelH = size.y * 0.115;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, panelH),
      Paint()..color = Palette.panel,
    );
    canvas.drawLine(Offset(0, panelH), Offset(size.x, panelH),
        Paint()..color = Palette.rule..strokeWidth = 1);

    final top = panelH * 0.28;
    _text(canvas, '$carNo号車 ／ 15', Offset(pad, top),
        color: Palette.you, size: size.x * 0.038);
    _text(canvas, '次は 新橋', Offset(size.x / 2, top),
        color: Palette.text, size: size.x * 0.034, center: true);
    final t = timeLeft;
    _text(canvas, '残り ${_mmss(t)}', Offset(size.x - pad, top),
        color: t < 15 ? Palette.enemy : Palette.text, size: size.x * 0.038, right: true);

    // 15両ぶんの進捗。
    final barY = panelH * 0.68;
    final barW = (size.x - pad * 2 - 14 * 3) / 15;
    for (var i = 0; i < 15; i++) {
      final x = pad + i * (barW + 3);
      final done = i + 1 < carNo;
      final here = i + 1 == carNo;
      canvas.drawRect(
        Rect.fromLTWH(x, barY, here ? barW * carProgress.clamp(0.05, 1.0) : barW, 5),
        Paint()
          ..color = here
              ? const Color(0xFFFFFFFF)
              : (done ? Palette.you : Palette.rule),
      );
      if (here) {
        canvas.drawRect(
          Rect.fromLTWH(x, barY, barW, 5),
          Paint()
            ..color = Palette.rule
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
      }
    }

    // 体幹ゲージ。棒人間の傾きが本体で、これは補助。
    final gy = size.y * Tuning.gaugeYRatio;
    _text(canvas, '体幹', Offset(pad, gy - size.x * 0.048),
        color: Palette.text, size: size.x * 0.032);
    final gw = size.x - pad * 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(pad, gy, gw, 9), const Radius.circular(4)),
      Paint()..color = Palette.rule,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pad, gy, gw * (player.stance / Tuning.stanceMax), 9),
        const Radius.circular(4),
      ),
      Paint()..color = player.stance < 30 ? Palette.enemy : Palette.stance,
    );

    // 検証用の数字。操作の説明は画面下のボタンが兼ねる。
    _text(
      canvas,
      '被弾 ${player.hits}   転倒 ${player.falls}',
      Offset(size.x / 2, gy + size.y * 0.025),
      color: Palette.dim,
      size: size.x * 0.030,
      center: true,
    );
  }

  void _drawReady(Canvas canvas) {
    _veil(canvas);
    _text(canvas, '通勤退魔録', Offset(size.x / 2, size.y * 0.40),
        color: Palette.you, size: size.x * 0.10, center: true);
    _text(canvas, '階段は15号車の前寄りにある。', Offset(size.x / 2, size.y * 0.50),
        color: Palette.text, size: size.x * 0.040, center: true);
    _text(canvas, 'タップで発車', Offset(size.x / 2, size.y * 0.58),
        color: Palette.dim, size: size.x * 0.042, center: true);
  }

  void _drawResult(Canvas canvas) {
    _veil(canvas);
    final ok = bestCar >= 15;
    _text(canvas, ok ? '間に合った' : '到着', Offset(size.x / 2, size.y * 0.34),
        color: ok ? Palette.you : Palette.text, size: size.x * 0.075, center: true);
    _text(canvas, '$bestCar号車まで', Offset(size.x / 2, size.y * 0.45),
        color: Palette.you, size: size.x * 0.13, center: true);
    _text(
      canvas,
      ok ? 'ドアの目の前が階段。' : 'ホームを${15 - bestCar}両ぶん歩くことになった。',
      Offset(size.x / 2, size.y * 0.55),
      color: Palette.text,
      size: size.x * 0.038,
      center: true,
    );
    _text(canvas, '被弾 ${player.hits}   転倒 ${player.falls}',
        Offset(size.x / 2, size.y * 0.62),
        color: Palette.dim, size: size.x * 0.034, center: true);
    _text(canvas, 'タップでもう一本', Offset(size.x / 2, size.y * 0.72),
        color: Palette.dim, size: size.x * 0.042, center: true);
  }

  void _veil(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Palette.night.withValues(alpha: 0.86),
    );
  }

  String _mmss(double s) {
    final m = s ~/ 60;
    final r = (s % 60).floor();
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    required Color color,
    required double size,
    bool center = false,
    bool right = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          height: 1.2,
          fontFamily: 'DotGothic16',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? at.dx - tp.width / 2 : (right ? at.dx - tp.width : at.dx);
    tp.paint(canvas, Offset(dx, at.dy));
  }
}

/// ワールド上の絶対距離に置かれた1体。
class Placed {
  final StageEntity e;
  final double absDistM;
  const Placed(this.e, this.absDistM);
}
