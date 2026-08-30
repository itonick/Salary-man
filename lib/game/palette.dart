import 'dart:ui';

/// 夜の車内。色は3つしか使わない。
/// 黄＝自分、赤＝敵、青＝殴ってはいけない相手。
/// 色の意味を固定しておくと、判断のルールを言葉で説明せずに済む。
class Palette {
  static const Color night = Color(0xFF0B1119);
  static const Color nightUp = Color(0xFF16202C);
  static const Color panel = Color(0xFF131C27);
  static const Color rule = Color(0xFF26303D);
  static const Color dim = Color(0xFF5D6D80);
  static const Color text = Color(0xFF93A2B4);

  static const Color you = Color(0xFFF0C04E);
  static const Color enemy = Color(0xFFFF7159);
  static const Color safe = Color(0xFF7FA9E0);
  static const Color stance = Color(0xFFE0A82E);
}
