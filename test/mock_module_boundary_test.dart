import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Shell and Execution do not depend on concrete Mock persistence or runtime',
    () {
      final protectedRoots = [
        Directory('lib/ui/shell'),
        Directory('lib/domain/request_runtime'),
      ];
      for (final root in protectedRoots) {
        for (final entry in root.listSync(recursive: true)) {
          if (entry is! File || !entry.path.endsWith('.dart')) continue;
          final source = entry.readAsStringSync();
          expect(
            source,
            isNot(contains('isar_mock_server_repository.dart')),
            reason: entry.path,
          );
          expect(
            source,
            isNot(contains('local_mock_server_runtime.dart')),
            reason: entry.path,
          );
        }
      }
    },
  );

  test('Contract Publishing does not read Secret stores or transports', () {
    final contractPublishing = Directory('lib/domain/contract_publishing');
    for (final entry in contractPublishing.listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      final source = entry.readAsStringSync();
      expect(source, isNot(contains('data/repositories/')), reason: entry.path);
      expect(
        source,
        isNot(contains('environment_store.dart')),
        reason: entry.path,
      );
      expect(source, isNot(contains('secret_store')), reason: entry.path);
      expect(
        source,
        isNot(contains("import '../grpc/grpc_transport.dart'")),
        reason: entry.path,
      );
      expect(
        source,
        isNot(contains("import '../websocket/websocket_transport.dart'")),
        reason: entry.path,
      );
    }
  });
}
