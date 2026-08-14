import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/ui/shell/application/request_draft_editor.dart';

void main() {
  const editor = RequestDraftEditor();

  test('splits URLs and normalizes environment query references', () {
    var sequence = 0;
    final draft = editor.replaceUrl(
      draft: const RequestDraft(
        method: 'GET',
        baseUrlToken: '',
        path: '',
        params: [],
        headers: [],
        body: '',
      ),
      url: 'https://api.example.test/v1/users?tag={Token}&tag=next#details',
      nextParameterId: () => 'param-${sequence++}',
      environmentVariableKeys: const ['token'],
    );

    expect(draft.baseUrlToken, 'https://api.example.test');
    expect(draft.path, '/v1/users#details');
    expect(draft.params.map((row) => row.value), ['{{token}}', 'next']);
    expect(draft.params.map((row) => row.id), ['param-0', 'param-1']);
  });

  test('normalizes editable request text without changing row identity', () {
    final normalized = editor.normalize(
      const RequestDraft(
        method: ' post ',
        baseUrlToken: ' https://api.example.test ',
        path: ' /v1/users ',
        params: [KeyValueRow(id: 'query', keyName: ' page ', value: ' 1 ')],
        headers: [
          KeyValueRow(id: 'header', keyName: ' X-Trace ', value: ' test '),
        ],
        body: ' {"name":"Ada"} ',
      ),
    );

    expect(normalized.method, 'post');
    expect(normalized.baseUrlToken, 'https://api.example.test');
    expect(normalized.params.single.id, 'query');
    expect(normalized.params.single.keyName, 'page');
    expect(normalized.headers.single.value, 'test');
  });
}
