import 'package:flutter/material.dart';

/// Chakra UI v3-inspired semantic projection used by every application surface.
@immutable
class ChakraSemanticTokens extends ThemeExtension<ChakraSemanticTokens> {
  const ChakraSemanticTokens({
    required this.bg,
    required this.bgSubtle,
    required this.bgMuted,
    required this.bgEmphasized,
    required this.bgPanel,
    required this.fg,
    required this.fgMuted,
    required this.fgSubtle,
    required this.border,
    required this.borderEmphasized,
    required this.colorPaletteSolid,
    required this.colorPaletteContrast,
    required this.colorPaletteFg,
    required this.colorPaletteSubtle,
    required this.colorPaletteEmphasized,
    required this.colorPaletteFocusRing,
    required this.success,
    required this.warning,
    required this.error,
    required this.information,
    required this.inbound,
    required this.outbound,
    required this.disabled,
    required this.shadow,
    required this.methodGet,
    required this.methodPost,
    required this.methodPut,
    required this.methodDelete,
    required this.transparent,
  });

  static const light = ChakraSemanticTokens(
    bg: _ChakraRawColors.white,
    bgSubtle: _ChakraRawColors.gray50,
    bgMuted: _ChakraRawColors.gray100,
    bgEmphasized: _ChakraRawColors.gray200,
    bgPanel: _ChakraRawColors.white,
    fg: _ChakraRawColors.gray900,
    fgMuted: _ChakraRawColors.gray600,
    fgSubtle: _ChakraRawColors.gray500,
    border: _ChakraRawColors.gray200,
    borderEmphasized: _ChakraRawColors.gray300,
    colorPaletteSolid: _ChakraRawColors.teal600,
    colorPaletteContrast: _ChakraRawColors.white,
    colorPaletteFg: _ChakraRawColors.teal700,
    colorPaletteSubtle: _ChakraRawColors.teal100,
    colorPaletteEmphasized: _ChakraRawColors.teal200,
    colorPaletteFocusRing: _ChakraRawColors.teal500,
    success: _ChakraRawColors.green600,
    warning: _ChakraRawColors.orange600,
    error: _ChakraRawColors.red600,
    information: _ChakraRawColors.blue600,
    inbound: _ChakraRawColors.green600,
    outbound: _ChakraRawColors.blue600,
    disabled: _ChakraRawColors.gray400,
    shadow: _ChakraRawColors.black,
    methodGet: _ChakraRawColors.blue600,
    methodPost: _ChakraRawColors.green600,
    methodPut: _ChakraRawColors.purple600,
    methodDelete: _ChakraRawColors.red600,
    transparent: _ChakraRawColors.transparent,
  );

  static const dark = ChakraSemanticTokens(
    bg: _ChakraRawColors.gray950,
    bgSubtle: _ChakraRawColors.gray900,
    bgMuted: _ChakraRawColors.gray800,
    bgEmphasized: _ChakraRawColors.gray700,
    bgPanel: _ChakraRawColors.gray900,
    fg: _ChakraRawColors.gray50,
    fgMuted: _ChakraRawColors.gray300,
    fgSubtle: _ChakraRawColors.gray400,
    border: _ChakraRawColors.gray700,
    borderEmphasized: _ChakraRawColors.gray600,
    colorPaletteSolid: _ChakraRawColors.teal500,
    colorPaletteContrast: _ChakraRawColors.teal950,
    colorPaletteFg: _ChakraRawColors.teal300,
    colorPaletteSubtle: _ChakraRawColors.teal900,
    colorPaletteEmphasized: _ChakraRawColors.teal800,
    colorPaletteFocusRing: _ChakraRawColors.teal400,
    success: _ChakraRawColors.green400,
    warning: _ChakraRawColors.orange300,
    error: _ChakraRawColors.red400,
    information: _ChakraRawColors.blue400,
    inbound: _ChakraRawColors.green400,
    outbound: _ChakraRawColors.blue400,
    disabled: _ChakraRawColors.gray600,
    shadow: _ChakraRawColors.black,
    methodGet: _ChakraRawColors.blue400,
    methodPost: _ChakraRawColors.green400,
    methodPut: _ChakraRawColors.purple400,
    methodDelete: _ChakraRawColors.red400,
    transparent: _ChakraRawColors.transparent,
  );

  final Color bg;
  final Color bgSubtle;
  final Color bgMuted;
  final Color bgEmphasized;
  final Color bgPanel;
  final Color fg;
  final Color fgMuted;
  final Color fgSubtle;
  final Color border;
  final Color borderEmphasized;
  final Color colorPaletteSolid;
  final Color colorPaletteContrast;
  final Color colorPaletteFg;
  final Color colorPaletteSubtle;
  final Color colorPaletteEmphasized;
  final Color colorPaletteFocusRing;
  final Color success;
  final Color warning;
  final Color error;
  final Color information;
  final Color inbound;
  final Color outbound;
  final Color disabled;
  final Color shadow;
  final Color methodGet;
  final Color methodPost;
  final Color methodPut;
  final Color methodDelete;
  final Color transparent;

  @override
  ChakraSemanticTokens copyWith({
    Color? bg,
    Color? bgSubtle,
    Color? bgMuted,
    Color? bgEmphasized,
    Color? bgPanel,
    Color? fg,
    Color? fgMuted,
    Color? fgSubtle,
    Color? border,
    Color? borderEmphasized,
    Color? colorPaletteSolid,
    Color? colorPaletteContrast,
    Color? colorPaletteFg,
    Color? colorPaletteSubtle,
    Color? colorPaletteEmphasized,
    Color? colorPaletteFocusRing,
    Color? success,
    Color? warning,
    Color? error,
    Color? information,
    Color? inbound,
    Color? outbound,
    Color? disabled,
    Color? shadow,
    Color? methodGet,
    Color? methodPost,
    Color? methodPut,
    Color? methodDelete,
    Color? transparent,
  }) => ChakraSemanticTokens(
    bg: bg ?? this.bg,
    bgSubtle: bgSubtle ?? this.bgSubtle,
    bgMuted: bgMuted ?? this.bgMuted,
    bgEmphasized: bgEmphasized ?? this.bgEmphasized,
    bgPanel: bgPanel ?? this.bgPanel,
    fg: fg ?? this.fg,
    fgMuted: fgMuted ?? this.fgMuted,
    fgSubtle: fgSubtle ?? this.fgSubtle,
    border: border ?? this.border,
    borderEmphasized: borderEmphasized ?? this.borderEmphasized,
    colorPaletteSolid: colorPaletteSolid ?? this.colorPaletteSolid,
    colorPaletteContrast: colorPaletteContrast ?? this.colorPaletteContrast,
    colorPaletteFg: colorPaletteFg ?? this.colorPaletteFg,
    colorPaletteSubtle: colorPaletteSubtle ?? this.colorPaletteSubtle,
    colorPaletteEmphasized:
        colorPaletteEmphasized ?? this.colorPaletteEmphasized,
    colorPaletteFocusRing: colorPaletteFocusRing ?? this.colorPaletteFocusRing,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    information: information ?? this.information,
    inbound: inbound ?? this.inbound,
    outbound: outbound ?? this.outbound,
    disabled: disabled ?? this.disabled,
    shadow: shadow ?? this.shadow,
    methodGet: methodGet ?? this.methodGet,
    methodPost: methodPost ?? this.methodPost,
    methodPut: methodPut ?? this.methodPut,
    methodDelete: methodDelete ?? this.methodDelete,
    transparent: transparent ?? this.transparent,
  );

  @override
  ChakraSemanticTokens lerp(covariant ChakraSemanticTokens? other, double t) {
    if (other == null) return this;
    Color blend(Color a, Color b) => Color.lerp(a, b, t)!;
    return ChakraSemanticTokens(
      bg: blend(bg, other.bg),
      bgSubtle: blend(bgSubtle, other.bgSubtle),
      bgMuted: blend(bgMuted, other.bgMuted),
      bgEmphasized: blend(bgEmphasized, other.bgEmphasized),
      bgPanel: blend(bgPanel, other.bgPanel),
      fg: blend(fg, other.fg),
      fgMuted: blend(fgMuted, other.fgMuted),
      fgSubtle: blend(fgSubtle, other.fgSubtle),
      border: blend(border, other.border),
      borderEmphasized: blend(borderEmphasized, other.borderEmphasized),
      colorPaletteSolid: blend(colorPaletteSolid, other.colorPaletteSolid),
      colorPaletteContrast: blend(
        colorPaletteContrast,
        other.colorPaletteContrast,
      ),
      colorPaletteFg: blend(colorPaletteFg, other.colorPaletteFg),
      colorPaletteSubtle: blend(colorPaletteSubtle, other.colorPaletteSubtle),
      colorPaletteEmphasized: blend(
        colorPaletteEmphasized,
        other.colorPaletteEmphasized,
      ),
      colorPaletteFocusRing: blend(
        colorPaletteFocusRing,
        other.colorPaletteFocusRing,
      ),
      success: blend(success, other.success),
      warning: blend(warning, other.warning),
      error: blend(error, other.error),
      information: blend(information, other.information),
      inbound: blend(inbound, other.inbound),
      outbound: blend(outbound, other.outbound),
      disabled: blend(disabled, other.disabled),
      shadow: blend(shadow, other.shadow),
      methodGet: blend(methodGet, other.methodGet),
      methodPost: blend(methodPost, other.methodPost),
      methodPut: blend(methodPut, other.methodPut),
      methodDelete: blend(methodDelete, other.methodDelete),
      transparent: blend(transparent, other.transparent),
    );
  }
}

extension ChakraThemeContext on BuildContext {
  ChakraSemanticTokens get chakra =>
      Theme.of(this).extension<ChakraSemanticTokens>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? ChakraSemanticTokens.dark
          : ChakraSemanticTokens.light);
}

abstract final class ChakraRadii {
  static const Radius xs = Radius.circular(2);
  static const Radius sm = Radius.circular(4);
  static const Radius md = Radius.circular(6);
  static const Radius full = Radius.circular(999);
  static const BorderRadius control = BorderRadius.all(sm);
  static const BorderRadius panel = BorderRadius.all(md);
  static const BorderRadius pill = BorderRadius.all(full);
}

/// Raw values are private so feature code cannot bypass semantic meaning.
abstract final class _ChakraRawColors {
  static const transparent = Color(0x00000000);
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const gray50 = Color(0xFFFAFAFA);
  static const gray100 = Color(0xFFF4F4F5);
  static const gray200 = Color(0xFFE4E4E7);
  static const gray300 = Color(0xFFD4D4D8);
  static const gray400 = Color(0xFFA1A1AA);
  static const gray500 = Color(0xFF71717A);
  static const gray600 = Color(0xFF52525B);
  static const gray700 = Color(0xFF3F3F46);
  static const gray800 = Color(0xFF27272A);
  static const gray900 = Color(0xFF18181B);
  static const gray950 = Color(0xFF111111);
  static const teal100 = Color(0xFFCCFBF1);
  static const teal200 = Color(0xFF99F6E4);
  static const teal300 = Color(0xFF5EEAD4);
  static const teal400 = Color(0xFF2DD4BF);
  static const teal500 = Color(0xFF14B8A6);
  static const teal600 = Color(0xFF0D9488);
  static const teal700 = Color(0xFF0F766E);
  static const teal800 = Color(0xFF115E59);
  static const teal900 = Color(0xFF134E4A);
  static const teal950 = Color(0xFF042F2E);
  static const green400 = Color(0xFF4ADE80);
  static const green600 = Color(0xFF16A34A);
  static const orange300 = Color(0xFFFDBA74);
  static const orange600 = Color(0xFFEA580C);
  static const red400 = Color(0xFFF87171);
  static const red600 = Color(0xFFDC2626);
  static const blue400 = Color(0xFF60A5FA);
  static const blue600 = Color(0xFF2563EB);
  static const purple400 = Color(0xFFC084FC);
  static const purple600 = Color(0xFF9333EA);
}
