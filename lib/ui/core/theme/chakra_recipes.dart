import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/form_control_metrics.dart';

/// Centralized Chakra-style component recipes for Material primitives.
abstract final class ChakraRecipes {
  static const _controlSize = Size(0, 32);
  static const _iconSize = Size.square(32);

  static TextStyle _labelFor(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium ??
      TextStyle(color: context.chakra.fg, fontSize: 12);

  static ButtonStyle solidFor(BuildContext context) =>
      solidButton(context.chakra, _labelFor(context));

  static ButtonStyle outlineFor(BuildContext context) =>
      outlineButton(context.chakra, _labelFor(context));

  static ButtonStyle ghostFor(BuildContext context) =>
      ghostButton(context.chakra, _labelFor(context));

  static ButtonStyle selectableFor(
    BuildContext context, {
    required bool selected,
  }) =>
      selectableButton(context.chakra, _labelFor(context), selected: selected);

  static ButtonStyle compactSelectableFor(
    BuildContext context, {
    required bool selected,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 10),
  }) =>
      sized(
        selectableFor(context, selected: selected),
        minimumSize: const Size(0, FormControlMetrics.denseHeight),
        maximumSize: const Size.fromHeight(FormControlMetrics.denseHeight),
        padding: padding,
      ).copyWith(
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  static ButtonStyle standardSelectableFor(
    BuildContext context, {
    required bool selected,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 8),
  }) => sized(
    selectableFor(context, selected: selected),
    minimumSize: const Size(0, FormControlMetrics.standardHeight),
    maximumSize: const Size.fromHeight(FormControlMetrics.standardHeight),
    padding: padding,
    alignment: Alignment.center,
  );

  static ButtonStyle iconSelectableFor(
    BuildContext context, {
    required bool selected,
    double size = 32,
  }) => sized(
    selectableFor(context, selected: selected),
    minimumSize: Size.square(size),
    maximumSize: Size.square(size),
    padding: EdgeInsets.zero,
  );

  static ButtonStyle warningGhostFor(
    BuildContext context, {
    double height = 28,
  }) =>
      sized(
        ghostFor(context),
        minimumSize: Size(0, height),
        maximumSize: Size.fromHeight(height),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ).copyWith(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return context.chakra.fgSubtle;
          }
          return context.chakra.warning;
        }),
      );

  static ButtonStyle flatTabFor(
    BuildContext context, {
    required bool selected,
    required double minimumWidth,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 12),
  }) =>
      sized(
        selectableFor(context, selected: selected),
        minimumSize: Size(minimumWidth, 36),
        maximumSize: const Size.fromHeight(36),
        padding: padding,
      ).copyWith(
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        side: const WidgetStatePropertyAll(BorderSide.none),
        backgroundColor: WidgetStatePropertyAll(context.chakra.transparent),
      );

  static ButtonStyle destructiveFor(BuildContext context) =>
      destructiveButton(context.chakra, _labelFor(context));

  static ButtonStyle iconFor(BuildContext context, {double size = 32}) => sized(
    iconButton(context.chakra),
    minimumSize: Size.square(size),
    maximumSize: Size.square(size),
  );

  static InputDecoration mutedInputFor(
    BuildContext context, {
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) => InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: context.chakra.bgMuted,
  );

  static ButtonStyle solidButton(
    ChakraSemanticTokens tokens,
    TextStyle label,
  ) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(_controlSize),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    ),
    textStyle: WidgetStatePropertyAll(label),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: ChakraRadii.control),
    ),
    elevation: const WidgetStatePropertyAll(0),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return tokens.fgSubtle;
      return tokens.colorPaletteContrast;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return tokens.bgMuted;
      if (states.contains(WidgetState.pressed)) {
        return tokens.colorPaletteEmphasized;
      }
      if (states.contains(WidgetState.hovered)) return tokens.colorPaletteFg;
      return tokens.colorPaletteSolid;
    }),
    side: _focusSide(tokens),
    overlayColor: WidgetStatePropertyAll(tokens.transparent),
  );

  static ButtonStyle outlineButton(
    ChakraSemanticTokens tokens,
    TextStyle label,
  ) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(_controlSize),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    ),
    textStyle: WidgetStatePropertyAll(label),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: ChakraRadii.control),
    ),
    elevation: const WidgetStatePropertyAll(0),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return tokens.fgSubtle;
      return tokens.fg;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return tokens.bgMuted;
      if (states.contains(WidgetState.pressed)) return tokens.bgEmphasized;
      if (states.contains(WidgetState.hovered)) return tokens.bgSubtle;
      return tokens.transparent;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: tokens.colorPaletteFocusRing, width: 2);
      }
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(color: tokens.border);
      }
      return BorderSide(color: tokens.borderEmphasized);
    }),
    overlayColor: WidgetStatePropertyAll(tokens.transparent),
  );

  static ButtonStyle ghostButton(
    ChakraSemanticTokens tokens,
    TextStyle label,
  ) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(_controlSize),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    textStyle: WidgetStatePropertyAll(label),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: ChakraRadii.control),
    ),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return tokens.fgSubtle;
      return tokens.colorPaletteFg;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) return tokens.bgEmphasized;
      if (states.contains(WidgetState.hovered)) return tokens.bgMuted;
      return tokens.transparent;
    }),
    side: _focusSide(tokens),
    overlayColor: WidgetStatePropertyAll(tokens.transparent),
  );

  static ButtonStyle destructiveButton(
    ChakraSemanticTokens tokens,
    TextStyle label,
  ) => solidButton(tokens, label).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return tokens.fgSubtle;
      return tokens.colorPaletteContrast;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return tokens.bgMuted;
      if (states.contains(WidgetState.pressed)) {
        return tokens.error.withValues(alpha: 0.78);
      }
      if (states.contains(WidgetState.hovered)) {
        return tokens.error.withValues(alpha: 0.88);
      }
      return tokens.error;
    }),
  );

  static ButtonStyle selectableButton(
    ChakraSemanticTokens tokens,
    TextStyle label, {
    required bool selected,
  }) => ghostButton(tokens, label).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return tokens.fgSubtle;
      return selected ? tokens.colorPaletteFg : tokens.fgMuted;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) return tokens.bgEmphasized;
      if (states.contains(WidgetState.hovered)) return tokens.bgMuted;
      return selected ? tokens.colorPaletteSubtle : tokens.transparent;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: tokens.colorPaletteFocusRing, width: 2);
      }
      return BorderSide(
        color: selected ? tokens.colorPaletteSolid : tokens.border,
      );
    }),
  );

  static ButtonStyle sized(
    ButtonStyle base, {
    Size? minimumSize,
    Size? maximumSize,
    EdgeInsetsGeometry? padding,
    AlignmentGeometry? alignment,
  }) => base.copyWith(
    minimumSize: minimumSize == null
        ? null
        : WidgetStatePropertyAll(minimumSize),
    maximumSize: maximumSize == null
        ? null
        : WidgetStatePropertyAll(maximumSize),
    padding: padding == null ? null : WidgetStatePropertyAll(padding),
    alignment: alignment,
  );

  static ButtonStyle iconButton(ChakraSemanticTokens tokens) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(_iconSize),
    maximumSize: const WidgetStatePropertyAll(_iconSize),
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: ChakraRadii.control),
    ),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return tokens.fgSubtle;
      return tokens.fgMuted;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) return tokens.bgEmphasized;
      if (states.contains(WidgetState.hovered)) return tokens.bgMuted;
      return tokens.transparent;
    }),
    side: _focusSide(tokens),
    overlayColor: WidgetStatePropertyAll(tokens.transparent),
  );

  static InputDecorationTheme input(
    ChakraSemanticTokens tokens,
    TextStyle baseText,
  ) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: ChakraRadii.control,
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: tokens.bgPanel,
      constraints: FormControlMetrics.standardConstraints,
      contentPadding: FormControlMetrics.inputPadding,
      prefixIconConstraints: FormControlMetrics.iconConstraints,
      suffixIconConstraints: FormControlMetrics.iconConstraints,
      hintStyle: baseText.copyWith(color: tokens.fgSubtle, fontSize: 12),
      labelStyle: baseText.copyWith(
        color: tokens.fgMuted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: baseText.copyWith(
        color: tokens.colorPaletteFg,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      helperStyle: baseText.copyWith(color: tokens.fgSubtle, fontSize: 11),
      errorStyle: baseText.copyWith(color: tokens.error, fontSize: 11),
      counterStyle: baseText.copyWith(color: tokens.fgSubtle, fontSize: 10),
      prefixIconColor: tokens.fgSubtle,
      suffixIconColor: tokens.fgSubtle,
      border: border(tokens.borderEmphasized),
      enabledBorder: border(tokens.borderEmphasized),
      disabledBorder: border(tokens.border),
      focusedBorder: border(tokens.colorPaletteFocusRing, 2),
      errorBorder: border(tokens.error),
      focusedErrorBorder: border(tokens.error, 2),
    );
  }

  static MenuStyle menu(ChakraSemanticTokens tokens) => MenuStyle(
    backgroundColor: WidgetStatePropertyAll(tokens.bgPanel),
    side: WidgetStatePropertyAll(BorderSide(color: tokens.border)),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: ChakraRadii.panel),
    ),
    elevation: const WidgetStatePropertyAll(4),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
  );

  static WidgetStateProperty<BorderSide> _focusSide(
    ChakraSemanticTokens tokens,
  ) => WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.focused)) {
      return BorderSide(color: tokens.colorPaletteFocusRing, width: 2);
    }
    return BorderSide.none;
  });
}

/// Coordinated geometry for components whose header/body/footer slots must align.
abstract final class ChakraSlotRecipes {
  static const panelRadius = ChakraRadii.panel;
  static const panelPadding = EdgeInsets.all(8);
  static const panelHeaderHeight = 36.0;
  static const timelineHeaderHeight = 30.0;
  static const navigationRowHeight = 30.0;
  static const drawerFooterHeight = 40.0;

  static BoxDecoration panel(ChakraSemanticTokens tokens) => BoxDecoration(
    color: tokens.bgPanel,
    border: Border.all(color: tokens.border),
    borderRadius: panelRadius,
  );

  static BoxDecoration timelineEvent(ChakraSemanticTokens tokens) =>
      BoxDecoration(
        color: tokens.bgPanel,
        border: Border.all(color: tokens.border),
        borderRadius: panelRadius,
      );

  static BoxDecoration timelineAccent(Color accent) => BoxDecoration(
    color: accent,
    borderRadius: const BorderRadius.only(
      topLeft: ChakraRadii.md,
      bottomLeft: ChakraRadii.md,
    ),
  );

  static BoxDecoration codeSurface(ChakraSemanticTokens tokens) =>
      BoxDecoration(
        color: tokens.bgSubtle,
        border: Border.all(color: tokens.border),
        borderRadius: ChakraRadii.control,
      );

  static BoxDecoration drawer(ChakraSemanticTokens tokens) => BoxDecoration(
    color: tokens.bgPanel,
    border: Border(left: BorderSide(color: tokens.borderEmphasized)),
    boxShadow: [
      BoxShadow(
        color: tokens.shadow.withValues(alpha: 0.22),
        blurRadius: 18,
        offset: const Offset(-4, 0),
      ),
    ],
  );

  static BoxDecoration selectedNavigationItem(ChakraSemanticTokens tokens) =>
      BoxDecoration(
        color: tokens.colorPaletteSubtle,
        border: Border(
          left: BorderSide(color: tokens.colorPaletteSolid, width: 3),
        ),
      );
}
