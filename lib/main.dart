import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/palette.dart';
import 'game/taimaroku_game.dart';
import 'game/tuning.dart';

/// 画面の向きと没入モードは Android / iOS でしか意味がなく、
/// Web やデスクトップで呼ぶとアサーションで落ちる。
bool get _isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_isMobile) {
    // 片手・縦持ちが前提。横向きにはしない。
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(const TaimarokuApp());
}

class TaimarokuApp extends StatelessWidget {
  const TaimarokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Palette.night,
        body: GameSurface(),
      ),
    );
  }
}

/// 入力の受け口。
///
/// フリックは「指を離したとき」ではなく「しきい値を超えた瞬間」に確定させる。
/// 離すのを待つと1テンポ遅れて、避けられたはずのものに当たる。
/// Phase 1 でいちばん手触りを左右するのがここ。
class GameSurface extends StatefulWidget {
  const GameSurface({super.key});

  @override
  State<GameSurface> createState() => _GameSurfaceState();
}

class _GameSurfaceState extends State<GameSurface> {
  final TaimarokuGame game = TaimarokuGame();

  Offset _dragStart = Offset.zero;
  bool _flickFired = false;

  void _onPanStart(DragStartDetails d) {
    _dragStart = d.localPosition;
    _flickFired = false;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_flickFired) return;
    final dy = d.localPosition.dy - _dragStart.dy;
    if (dy <= -Tuning.flickThresholdPx) {
      _flickFired = true;
      game.onFlickUp();
    } else if (dy >= Tuning.flickThresholdPx) {
      _flickFired = true;
      game.onFlickDown();
    }
  }

  void _onPanEnd(DragEndDetails d) {
    // 縦にほとんど動かさずに離したらタップ扱い。
    // 揺れる車内では指がぶれるので、ぶれても薙げるようにしておく。
    if (!_flickFired) game.onTap();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) {
      game.onFlickUp();
    } else if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) {
      game.onFlickDown();
    } else if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
      game.onTap();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    // デスクトップで詰めるためのキーボード操作（↑ / ↓ / スペース）。
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (_) => game.onTap(),
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: GameWidget(game: game),
      ),
    );
  }
}
