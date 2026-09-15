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
/// 操作は3通りの経路で同じ動作に届く。
/// - 画面下の3つのボタン（スマホでいちばん確実）
/// - 画面のどこでも：タップ＝薙ぐ、上下スワイプ＝吊り革／かがむ
/// - キーボード：スペース／↑／↓
///
/// どれも「押した瞬間」に発火させる。離すのを待つと1テンポ遅れて、
/// 避けられたはずのものに当たる。
class GameSurface extends StatefulWidget {
  const GameSurface({super.key});

  @override
  State<GameSurface> createState() => _GameSurfaceState();
}

class _GameSurfaceState extends State<GameSurface> {
  final TaimarokuGame game = TaimarokuGame();
  final FocusNode _focus = FocusNode(debugLabel: 'game');

  Offset _dragStart = Offset.zero;
  bool _flickFired = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// 画面に触れたらキーボードの入力先をゲームに戻す。
  /// Web ではページをクリックするまでキー入力が届かないことがあるため。
  void _grabFocus() {
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  void _onPanStart(DragStartDetails d) {
    _grabFocus();
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
    final screen = MediaQuery.sizeOf(context);
    final padH = (screen.height * Tuning.padHeightRatio).clamp(64.0, 120.0);

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _grabFocus(),
              onTapUp: (_) => game.onTap(),
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: GameWidget(game: game),
            ),
          ),
          // 親指の届く画面下に、押せるボタンを3つ並べる。
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                height: padH,
                child: Row(
                  children: [
                    Expanded(
                      child: _PadButton(
                        glyph: '↑',
                        label: '吊り革',
                        color: Palette.you,
                        onPress: () {
                          _grabFocus();
                          game.onFlickUp();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PadButton(
                        glyph: '薙',
                        label: '薙ぐ',
                        color: Palette.enemy,
                        onPress: () {
                          _grabFocus();
                          game.onTap();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PadButton(
                        glyph: '↓',
                        label: 'かがむ',
                        color: Palette.safe,
                        onPress: () {
                          _grabFocus();
                          game.onFlickDown();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 押した瞬間に反応するボタン。
///
/// onTap は指を離したときに発火するので、アクションゲームには遅い。
/// ポインタが触れた瞬間（onPointerDown）で動作させる。
class _PadButton extends StatefulWidget {
  final String glyph;
  final String label;
  final Color color;
  final VoidCallback onPress;

  const _PadButton({
    required this.glyph,
    required this.label,
    required this.color,
    required this.onPress,
  });

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          _set(true);
          widget.onPress();
        },
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          decoration: BoxDecoration(
            color: _down ? widget.color.withValues(alpha: 0.28) : Palette.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _down ? widget.color : Palette.rule,
              width: _down ? 2 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.glyph,
                style: TextStyle(
                  fontFamily: 'DotGothic16',
                  fontSize: 28,
                  height: 1.0,
                  color: widget.color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: 'DotGothic16',
                  fontSize: 13,
                  height: 1.0,
                  color: Palette.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
