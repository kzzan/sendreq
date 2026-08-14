import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mock panel consumes only Contract Publishing projections', () {
    for (final path in const [
      'lib/ui/features/mock/widgets/mock_servers_panel.dart',
    ]) {
      final source = File(path).readAsStringSync();

      expect(source, isNot(contains('workspace_view_model.dart')));
      expect(source, isNot(contains('domain/workspace/workspace_models.dart')));
      expect(source, isNot(contains('domain/environments/')));
      expect(source, isNot(contains('transport.dart')));
      expect(source, isNot(contains('data/services/')));
      expect(source, contains('domain/contract_publishing/'));
    }
    for (final directory in const [
      'lib/features/history',
      'lib/features/documentation',
    ]) {
      final sourceFiles = Directory(directory).existsSync()
          ? Directory(directory)
                .listSync(recursive: true)
                .whereType<File>()
                .where((file) => file.path.endsWith('.dart'))
          : const <File>[];
      expect(sourceFiles, isEmpty, reason: directory);
    }
  });
}
