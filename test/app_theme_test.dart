import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/ui/core/theme/app_theme.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/form_control_metrics.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';

void main() {
  test('form controls use the shared compact workspace treatment', () {
    final theme = SendreqTheme.dark();
    final tokens = theme.extension<ChakraSemanticTokens>()!;
    final input = theme.inputDecorationTheme;

    expect(input.filled, isTrue);
    expect(input.fillColor, tokens.bgPanel);
    expect(input.contentPadding, FormControlMetrics.inputPadding);
    expect(input.constraints, FormControlMetrics.standardConstraints);
    expect(input.prefixIconConstraints, FormControlMetrics.iconConstraints);
    expect(input.suffixIconConstraints, FormControlMetrics.iconConstraints);
    expect(input.enabledBorder, isA<OutlineInputBorder>());
    expect(input.focusedBorder, isA<OutlineInputBorder>());
    expect(theme.switchTheme.trackOutlineColor, isNotNull);
    expect(theme.checkboxTheme.side, isNotNull);
    expect(theme.radioTheme.visualDensity, VisualDensity.compact);
    expect(
      theme.radioTheme.materialTapTargetSize,
      MaterialTapTargetSize.shrinkWrap,
    );
    expect(theme.textSelectionTheme.cursorColor, tokens.colorPaletteFg);
  });

  test('button recipes expose Chakra interaction states', () {
    final theme = SendreqTheme.light();
    final tokens = theme.extension<ChakraSemanticTokens>()!;
    final solid = theme.filledButtonTheme.style!;
    final outline = theme.outlinedButtonTheme.style!;
    final icon = theme.iconButtonTheme.style!;

    expect(solid.backgroundColor!.resolve({}), tokens.colorPaletteSolid);
    expect(
      solid.backgroundColor!.resolve({WidgetState.hovered}),
      tokens.colorPaletteFg,
    );
    expect(
      solid.backgroundColor!.resolve({WidgetState.pressed}),
      tokens.colorPaletteEmphasized,
    );
    expect(
      solid.backgroundColor!.resolve({WidgetState.disabled}),
      tokens.bgMuted,
    );
    expect(
      solid.side!.resolve({WidgetState.focused}),
      BorderSide(color: tokens.colorPaletteFocusRing, width: 2),
    );
    expect(
      outline.backgroundColor!.resolve({WidgetState.hovered}),
      tokens.bgSubtle,
    );
    expect(
      icon.backgroundColor!.resolve({WidgetState.hovered}),
      tokens.bgMuted,
    );
  });

  test('dense panels use the shared workspace padding baseline', () {
    const panel = DensePanel(child: SizedBox());

    expect(panel.padding, WorkspaceLayoutMetrics.panelPadding);
  });

  test('slot recipes coordinate panels timelines code and drawers', () {
    const tokens = ChakraSemanticTokens.dark;
    final panel = ChakraSlotRecipes.panel(tokens);
    final timeline = ChakraSlotRecipes.timelineEvent(tokens);
    final accent = ChakraSlotRecipes.timelineAccent(tokens.inbound);
    final code = ChakraSlotRecipes.codeSurface(tokens);
    final drawer = ChakraSlotRecipes.drawer(tokens);

    expect(panel.color, tokens.bgPanel);
    expect(panel.borderRadius, ChakraRadii.panel);
    expect((panel.border! as Border).top.color, tokens.border);
    expect((timeline.border! as Border).left.color, tokens.border);
    expect(accent.color, tokens.inbound);
    expect(code.color, tokens.bgSubtle);
    expect(code.borderRadius, ChakraRadii.control);
    expect((drawer.border! as Border).left.color, tokens.borderEmphasized);
    expect(drawer.boxShadow, isNotEmpty);
  });
}
