import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _maxProductionDartLines = 500;

/// 暂存例外必须有单一、可验证的责任，并在 docs/README.md 的迁移表中登记。
const _sizeExceptions = <String, String>{
  'lib/domain/grpc/protobuf_descriptor_set.dart':
      'Cohesive protobuf descriptor table and wire reader.',
  'lib/domain/api_assets/api_asset_models.dart':
      'Cohesive API asset value-object table.',
  'lib/domain/contract_publishing/mock_server.dart':
      'Cohesive mock-server value-object table.',
};

void main() {
  test(
    'handwritten modules use explicit imports instead of part libraries',
    () {
      final violations = <String>[];
      for (final entry in Directory('lib').listSync(recursive: true)) {
        if (entry is! File || !entry.path.endsWith('.dart')) continue;
        if (entry.path.endsWith('.g.dart')) continue;

        final relativePath = entry.path.replaceFirst(RegExp(r'^\./'), '');
        for (final line in const LineSplitter().convert(
          entry.readAsStringSync(),
        )) {
          final source = line.trim();
          if (source.startsWith('part of ')) {
            violations.add('$relativePath: $source');
          } else if (source.startsWith('part ') &&
              !source.contains(".g.dart'")) {
            violations.add('$relativePath: $source');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Only generated .g.dart parts are permitted.',
      );
    },
  );

  test('handwritten production Dart files stay within the size budget', () {
    final oversized = <String, int>{};
    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      if (entry.path.endsWith('.g.dart')) continue;
      if (entry.path.contains('/l10n/generated/')) continue;

      final relativePath = entry.path.replaceFirst(RegExp(r'^\./'), '');
      final lines = const LineSplitter()
          .convert(entry.readAsStringSync())
          .length;
      if (lines > _maxProductionDartLines) oversized[relativePath] = lines;
    }

    expect(
      oversized.keys.toSet(),
      equals(_sizeExceptions.keys.toSet()),
      reason:
          'Every file over $_maxProductionDartLines lines must be split or '
          'recorded with its migration responsibility.',
    );

    for (final entry in _sizeExceptions.entries) {
      expect(entry.value, isNotEmpty, reason: '${entry.key} needs a reason');
    }
  });
}
