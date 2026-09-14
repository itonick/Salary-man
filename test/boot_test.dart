import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsukin_taimaroku/game/taimaroku_game.dart';

void main() {
  testWidgets('起動して数フレーム描けること', (tester) async {
    final game = TaimarokuGame();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: GameWidget(game: game)),
      ),
    );
    // ready 画面
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);

    // 走り出してから数フレーム
    game.onTap();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    expect(game.distanceM, greaterThan(0));
  });

  testWidgets('転倒してラグドールが動くこと', (tester) async {
    final game = TaimarokuGame();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: GameWidget(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    game.onTap();
    await tester.pump(const Duration(milliseconds: 16));

    // 体幹を削り切って転倒させる
    for (var i = 0; i < 6; i++) {
      game.player.takeHit();
    }
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    expect(game.player.falls, greaterThan(0));
  });
}
