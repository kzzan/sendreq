import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/core/theme/app_colors.dart';

void main() {
  test('global palettes match the environment prototypes', () {
    AppColors.applyBrightness(Brightness.dark);
    expect(AppColors.background, const Color(0xFF0B1326));
    expect(AppColors.surfaceLow, const Color(0xFF131B2E));
    expect(AppColors.surfaceMid, const Color(0xFF171F33));
    expect(AppColors.surfaceHigh, const Color(0xFF222A3D));
    expect(AppColors.surfaceHighest, const Color(0xFF2D3449));
    expect(AppColors.outline, const Color(0xFF464554));
    expect(AppColors.outlineStrong, const Color(0xFF908FA0));
    expect(AppColors.text, const Color(0xFFDAE2FD));
    expect(AppColors.textMuted, const Color(0xFFC7C4D7));
    expect(AppColors.primary, const Color(0xFFC0C1FF));
    expect(AppColors.primaryContainer, const Color(0xFF8083FF));

    AppColors.applyBrightness(Brightness.light);
    expect(AppColors.background, const Color(0xFFF9F9FF));
    expect(AppColors.surfaceLow, const Color(0xFFF1F3FF));
    expect(AppColors.surfaceMid, const Color(0xFFE9EDFF));
    expect(AppColors.surfaceHigh, const Color(0xFFE1E8FD));
    expect(AppColors.surfaceHighest, const Color(0xFFDCE2F7));
    expect(AppColors.outline, const Color(0xFFC7C4D8));
    expect(AppColors.outlineStrong, const Color(0xFF777587));
    expect(AppColors.text, const Color(0xFF141B2B));
    expect(AppColors.textMuted, const Color(0xFF464555));
    expect(AppColors.primary, const Color(0xFF3E32D3));
    expect(AppColors.primaryContainer, const Color(0xFF5850EC));

    AppColors.applyBrightness(Brightness.dark);
  });
}
