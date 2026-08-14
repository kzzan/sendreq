import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widgets only consume colors through the Chakra semantic token layer', () {
    final violations = <String>[];
    final sourceFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in sourceFiles) {
      if (file.path.endsWith('core/theme/chakra_tokens.dart')) {
        continue;
      }
      final source = file.readAsStringSync();
      if (RegExp(r'\bColors\.').hasMatch(source)) {
        violations.add('${file.path}: direct Material Colors usage');
      }
      if (RegExp(r'\bColor\s*\(').hasMatch(source)) {
        violations.add('${file.path}: hard-coded Color constructor');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Raw colors belong only in chakra_tokens.dart; all other code must use semantic tokens.\n'
          '${violations.join('\n')}',
    );
  });

  test('no mutable compatibility color projection remains', () {
    expect(File('lib/ui/core/theme/app_colors.dart').existsSync(), isFalse);
    final violations = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      if (file.readAsStringSync().contains('AppColors')) {
        violations.add(file.path);
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Widgets must read context.chakra: ${violations.join(', ')}',
    );
  });

  test('legacy and Fluent palette values are absent from application code', () {
    const legacyValues = [
      '0xFF0B1326',
      '0xFF131B2E',
      '0xFF171F33',
      '0xFF222A3D',
      '0xFF2D3449',
      '0xFF464554',
      '0xFF908FA0',
      '0xFFDAE2FD',
      '0xFFC0C1FF',
      '0xFF8083FF',
      '0xFFF9F9FF',
      '0xFFF1F3FF',
      '0xFFE9EDFF',
      '0xFFE1E8FD',
      '0xFFDCE2F7',
      '0xFFC7C4D8',
      '0xFF777587',
      '0xFF3E32D3',
      '0xFF5850EC',
      '0xFF0F6CBD',
      '0xFF479EF5',
      '0xFF0078D4',
      '0xFF107C10',
    ];
    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    for (final value in legacyValues) {
      expect(source, isNot(contains(value)), reason: '$value must not return');
    }
  });

  test('platform startup and canonical brand source use Chakra teal', () {
    final linuxRunner = File(
      'linux/runner/my_application.cc',
    ).readAsStringSync();
    final appIcon = File(
      'assets/branding/sendreq-app-icon.svg',
    ).readAsStringSync();

    expect(linuxRunner, contains('"#111111"'));
    expect(appIcon, contains('fill="#0D9488"'));
    expect(appIcon, contains('fill="#14B8A6"'));
    expect(appIcon, contains('fill="#FFFFFF"'));

    for (final legacyValue in const [
      '#0B1326',
      '#3E32D3',
      '#C0C1FF',
      '#F9F9FF',
      '#8083FF',
      '#0F6CBD',
      '#479EF5',
    ]) {
      expect(linuxRunner, isNot(contains(legacyValue)));
      expect(appIcon, isNot(contains(legacyValue)));
    }
  });

  test('shared controls do not rebuild recipes with styleFrom', () {
    final violations = <String>[];
    for (final root in const ['lib/ui/core/widgets', 'lib/ui/features']) {
      for (final file
          in Directory(root)
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        if (file.readAsStringSync().contains('.styleFrom(')) {
          violations.add(file.path);
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Shared controls must consume Chakra recipes: ${violations.join(', ')}',
    );
  });

  test('workspace surfaces consume shared Chakra button recipes', () {
    final violations = <String>[];
    for (final root in const [
      'lib/ui/core/widgets',
      'lib/ui/features',
      'lib/ui/shell',
    ]) {
      for (final file
          in Directory(root)
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        if (source.contains('ButtonStyle(')) {
          violations.add('${file.path}: local ButtonStyle');
        }
        if (source.contains('textButtonTheme.style') ||
            source.contains('outlinedButtonTheme.style') ||
            source.contains('iconButtonTheme.style')) {
          violations.add('${file.path}: copied themed ButtonStyle');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Workspace controls must consume ChakraRecipes: ${violations.join(', ')}',
    );
  });

  test('feature surfaces use shared Chakra radius and slot recipes', () {
    final violations = <String>[];
    for (final file
        in Directory('lib/ui/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      if (source.contains('BorderRadius.circular(')) {
        violations.add('${file.path}: one-off radius');
      }
      if (source.contains('OutlineInputBorder(')) {
        violations.add('${file.path}: local input border');
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Feature geometry must use ChakraRadii: ${violations.join(', ')}',
    );
  });
}
