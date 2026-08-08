import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/core/theme/app_colors.dart';
import 'package:sendreq/core/theme/app_theme.dart';
import 'package:sendreq/core/theme/form_control_metrics.dart';

void main() {
  test('form controls use the shared compact workspace treatment', () {
    AppColors.applyBrightness(Brightness.dark);
    final theme = SendreqTheme.dark();
    final input = theme.inputDecorationTheme;

    expect(input.filled, isTrue);
    expect(input.fillColor, AppColors.surfaceLow);
    expect(input.contentPadding, FormControlMetrics.inputPadding);
    expect(input.constraints, FormControlMetrics.standardConstraints);
    expect(input.prefixIconConstraints, FormControlMetrics.iconConstraints);
    expect(input.suffixIconConstraints, FormControlMetrics.iconConstraints);
    expect(input.enabledBorder, isA<OutlineInputBorder>());
    expect(input.focusedBorder, isA<OutlineInputBorder>());
    expect(theme.switchTheme.trackOutlineColor, isNotNull);
    expect(theme.checkboxTheme.side, isNotNull);
    expect(theme.textSelectionTheme.cursorColor, AppColors.primary);
  });
}
