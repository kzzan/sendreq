import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/ui/core/theme/app_theme.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';

void main() {
  test('light and dark themes expose complete Chakra semantic projections', () {
    final light = SendreqTheme.light().extension<ChakraSemanticTokens>();
    final dark = SendreqTheme.dark().extension<ChakraSemanticTokens>();

    expect(light, same(ChakraSemanticTokens.light));
    expect(dark, same(ChakraSemanticTokens.dark));
    expect(light!.bg, const Color(0xFFFFFFFF));
    expect(light.bgSubtle, const Color(0xFFFAFAFA));
    expect(light.bgMuted, const Color(0xFFF4F4F5));
    expect(light.colorPaletteSolid, const Color(0xFF0D9488));
    expect(light.colorPaletteFocusRing, const Color(0xFF14B8A6));
    expect(dark!.bg, const Color(0xFF111111));
    expect(dark.bgPanel, const Color(0xFF18181B));
    expect(dark.colorPaletteSolid, const Color(0xFF14B8A6));
    expect(dark.colorPaletteContrast, const Color(0xFF042F2E));
  });
}
