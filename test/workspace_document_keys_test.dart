import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/workspace_document_keys.dart';

void main() {
  test(
    'persistent payloads use independently versioned WorkspaceDocument keys',
    () {
      expect(
        WorkspaceDocumentKeys.persistentMockServersV1,
        'persistent-mock-servers-v1',
      );
      expect(WorkspaceDocumentKeys.userNoticesV1, 'user-notices-v1');
    },
  );
}
