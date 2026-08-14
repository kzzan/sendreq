import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 代码、JSON 与协议时间线共用的可配置等宽文字基线。
@immutable
class CodeTextTheme extends ThemeExtension<CodeTextTheme> {
  const CodeTextTheme({required this.fontFamily, required this.fontSize});

  final String? fontFamily;
  final double fontSize;

  TextStyle style({Color? color, double? size, double height = 1.45}) =>
      TextStyle(
        color: color,
        fontFamily: fontFamily,
        fontSize: size ?? fontSize,
        height: height,
        letterSpacing: 0,
      );

  @override
  CodeTextTheme copyWith({String? fontFamily, double? fontSize}) =>
      CodeTextTheme(
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
      );

  @override
  CodeTextTheme lerp(covariant CodeTextTheme? other, double t) => other == null
      ? this
      : CodeTextTheme(
          fontFamily: t < .5 ? fontFamily : other.fontFamily,
          fontSize: lerpDouble(fontSize, other.fontSize, t) ?? fontSize,
        );
}
