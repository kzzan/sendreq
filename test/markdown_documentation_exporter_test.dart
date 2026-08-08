import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/services/api_documentation_generator.dart';
import 'package:sendreq/data/services/markdown_documentation_exporter.dart';
import 'package:sendreq/domain/models/workspace_models.dart';

void main() {
  test('exports Markdown documentation to the configured directory', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-docs-');
    addTearDown(() => directory.delete(recursive: true));
    const draft = DocumentationDraft(
      requestId: 'request-42',
      request: ExecutionRequestSnapshot(
        method: 'GET',
        resolvedUrl: 'https://api.sendreq.local/v1/widgets',
        headers: [],
        body: '',
        environmentName: 'Test',
      ),
      response: ResponseSnapshot(
        statusCode: 200,
        timeMs: 12,
        sizeKb: 0.1,
        body: '{"items":[]}',
        headers: [],
      ),
    );
    final documentation = const ApiDocumentationGenerator().generate(draft);

    final file = await const MarkdownDocumentationExporter().export(
      documentation: documentation,
      draft: draft,
      outputDirectory: directory.path,
      now: DateTime.utc(2026, 8, 7, 9, 30),
    );

    expect(file.parent.path, directory.path);
    expect(file.path, endsWith('get-v1-widgets-20260807T093000000Z.md'));
    expect(await file.readAsString(), documentation.markdown);
  });

  test(
    'Markdown export does not overwrite an existing timestamped document',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-docs-');
      addTearDown(() => directory.delete(recursive: true));
      const draft = DocumentationDraft(
        requestId: 'request-42',
        request: ExecutionRequestSnapshot(
          method: 'GET',
          resolvedUrl: 'https://api.sendreq.local/v1/widgets',
          headers: [],
          body: '',
          environmentName: 'Test',
        ),
        response: ResponseSnapshot(
          statusCode: 200,
          timeMs: 12,
          sizeKb: 0.1,
          body: '{"items":[]}',
          headers: [],
        ),
      );
      final documentation = const ApiDocumentationGenerator().generate(draft);
      const exporter = MarkdownDocumentationExporter();
      final timestamp = DateTime.utc(2026, 8, 7, 9, 30);

      final first = await exporter.export(
        documentation: documentation,
        draft: draft,
        outputDirectory: directory.path,
        now: timestamp,
      );
      final second = await exporter.export(
        documentation: documentation,
        draft: draft,
        outputDirectory: directory.path,
        now: timestamp,
      );

      expect(first.path, isNot(second.path));
      expect(second.path, endsWith('-1.md'));
      expect(await first.readAsString(), documentation.markdown);
      expect(await second.readAsString(), documentation.markdown);
    },
  );
}
