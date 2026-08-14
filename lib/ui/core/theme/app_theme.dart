import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/code_text_theme.dart';

/// Builds Material themes from the application's Chakra semantic system.
abstract final class SendreqTheme {
  static ThemeData dark({
    String? fontFamily,
    String codeFontFamily = 'JetBrains Mono',
    double codeFontSize = 12,
  }) => _buildTheme(
    Brightness.dark,
    ChakraSemanticTokens.dark,
    fontFamily: fontFamily,
    codeFontFamily: codeFontFamily,
    codeFontSize: codeFontSize,
  );

  static ThemeData light({
    String? fontFamily,
    String codeFontFamily = 'JetBrains Mono',
    double codeFontSize = 12,
  }) => _buildTheme(
    Brightness.light,
    ChakraSemanticTokens.light,
    fontFamily: fontFamily,
    codeFontFamily: codeFontFamily,
    codeFontSize: codeFontSize,
  );

  static ThemeData _buildTheme(
    Brightness brightness,
    ChakraSemanticTokens tokens, {
    required String? fontFamily,
    required String codeFontFamily,
    required double codeFontSize,
  }) {
    final baseText = TextStyle(
      color: tokens.fg,
      fontFamily: fontFamily,
      letterSpacing: 0,
    );
    final label = baseText.copyWith(fontSize: 12, fontWeight: FontWeight.w600);
    final inputTheme = ChakraRecipes.input(tokens, baseText);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: tokens.bg,
      canvasColor: tokens.bgPanel,
      hoverColor: tokens.bgMuted,
      focusColor: tokens.colorPaletteFocusRing.withValues(alpha: 0.18),
      highlightColor: tokens.bgEmphasized,
      splashColor: tokens.transparent,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      extensions: [
        tokens,
        CodeTextTheme(
          fontFamily: codeFontFamily,
          fontSize: codeFontSize.clamp(10, 18),
        ),
      ],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: tokens.colorPaletteSolid,
        onPrimary: tokens.colorPaletteContrast,
        primaryContainer: tokens.colorPaletteSubtle,
        onPrimaryContainer: tokens.colorPaletteFg,
        secondary: tokens.information,
        onSecondary: tokens.colorPaletteContrast,
        secondaryContainer: tokens.bgMuted,
        onSecondaryContainer: tokens.fg,
        tertiary: tokens.methodPut,
        onTertiary: tokens.colorPaletteContrast,
        tertiaryContainer: tokens.bgMuted,
        onTertiaryContainer: tokens.fg,
        surface: tokens.bgPanel,
        onSurface: tokens.fg,
        error: tokens.error,
        onError: tokens.colorPaletteContrast,
        errorContainer: tokens.error.withValues(alpha: 0.14),
        onErrorContainer: tokens.error,
        outline: tokens.border,
        outlineVariant: tokens.borderEmphasized,
        shadow: tokens.shadow,
        scrim: tokens.shadow,
        inverseSurface: tokens.fg,
        onInverseSurface: tokens.bg,
        inversePrimary: tokens.colorPaletteFg,
        surfaceTint: tokens.transparent,
      ),
      textTheme: TextTheme(
        titleLarge: baseText.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: baseText.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: baseText.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseText.copyWith(fontSize: 14, height: 1.4),
        bodyMedium: baseText.copyWith(fontSize: 13, height: 1.4),
        bodySmall: baseText.copyWith(
          fontSize: 12,
          height: 1.35,
          color: tokens.fgMuted,
        ),
        labelLarge: label,
        labelMedium: label,
        labelSmall: baseText.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tokens.fgSubtle,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: inputTheme,
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: inputTheme,
        menuStyle: ChakraRecipes.menu(tokens),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ChakraRecipes.solidButton(tokens, label),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ChakraRecipes.outlineButton(tokens, label),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ChakraRecipes.ghostButton(tokens, label),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ChakraRecipes.iconButton(tokens),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return tokens.bgMuted;
          if (states.contains(WidgetState.selected)) {
            return tokens.colorPaletteSolid;
          }
          return tokens.transparent;
        }),
        checkColor: WidgetStatePropertyAll(tokens.colorPaletteContrast),
        side: BorderSide(color: tokens.borderEmphasized),
        shape: const RoundedRectangleBorder(borderRadius: ChakraRadii.control),
      ),
      radioTheme: RadioThemeData(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return tokens.disabled;
          if (states.contains(WidgetState.selected)) {
            return tokens.colorPaletteSolid;
          }
          return tokens.borderEmphasized;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return tokens.fgSubtle;
          if (states.contains(WidgetState.selected)) {
            return tokens.colorPaletteContrast;
          }
          return tokens.fgMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return tokens.bgMuted;
          if (states.contains(WidgetState.selected)) {
            return tokens.colorPaletteSolid;
          }
          return tokens.bgEmphasized;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.colorPaletteFg;
          }
          return tokens.borderEmphasized;
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tokens.colorPaletteFg,
        unselectedLabelColor: tokens.fgMuted,
        indicatorColor: tokens.colorPaletteSolid,
        dividerColor: tokens.border,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return tokens.bgEmphasized;
          if (states.contains(WidgetState.hovered)) return tokens.bgMuted;
          return tokens.transparent;
        }),
        labelStyle: label,
        unselectedLabelStyle: label,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: tokens.colorPaletteSolid,
        textColor: tokens.colorPaletteContrast,
        smallSize: 7,
        largeSize: 16,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tokens.colorPaletteFg,
        selectionColor: tokens.colorPaletteSubtle,
        selectionHandleColor: tokens.colorPaletteSolid,
      ),
      cardTheme: CardThemeData(
        color: tokens.bgPanel,
        surfaceTintColor: tokens.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: ChakraRadii.panel,
          side: BorderSide(color: tokens.border),
        ),
      ),
      menuTheme: MenuThemeData(style: ChakraRecipes.menu(tokens)),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.bgPanel,
        surfaceTintColor: tokens.transparent,
        shape: const RoundedRectangleBorder(borderRadius: ChakraRadii.panel),
        textStyle: baseText.copyWith(fontSize: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.bgPanel,
        surfaceTintColor: tokens.transparent,
        elevation: 8,
        shape: const RoundedRectangleBorder(borderRadius: ChakraRadii.panel),
        titleTextStyle: baseText.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: baseText.copyWith(
          fontSize: 13,
          color: tokens.fgMuted,
          height: 1.45,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.bgPanel,
        contentTextStyle: baseText.copyWith(fontSize: 12),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: ChakraRadii.control,
          side: BorderSide(color: tokens.border),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(tokens.borderEmphasized),
        trackColor: WidgetStatePropertyAll(tokens.bgMuted),
        radius: ChakraRadii.sm,
        thickness: const WidgetStatePropertyAll(6),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.bgPanel,
          border: Border.all(color: tokens.border),
          borderRadius: ChakraRadii.control,
          boxShadow: [
            BoxShadow(
              color: tokens.shadow.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        textStyle: TextStyle(color: tokens.fg, fontSize: 12),
      ),
    );
  }
}
