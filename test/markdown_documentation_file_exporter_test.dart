import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/services/markdown_documentation_file_exporter.dart';
import 'package:sendreq/domain/api_assets/collection_documentation.dart';

void main() {
  const exporter = MarkdownDocumentationFileExporter();

  test('sanitizes names and never overwrites an existing document', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sendreq-markdown-export-',
    );
    addTearDown(() => directory.delete(recursive: true));
    const request = MarkdownDocumentationFileRequest(
      outputDirectory: '',
      collectionName: ' Orders: API / v1. ',
      source: '# Orders',
    );

    final first = await exporter.write(
      MarkdownDocumentationFileRequest(
        outputDirectory: directory.path,
        collectionName: request.collectionName,
        source: request.source,
      ),
    );
    final second = await exporter.write(
      MarkdownDocumentationFileRequest(
        outputDirectory: directory.path,
        collectionName: request.collectionName,
        source: '# New export',
      ),
    );

    expect(first.fileName, 'Orders- API - v1.md');
    expect(second.fileName, 'Orders- API - v1-1.md');
    expect(
      await File('${directory.path}/${first.fileName}').readAsString(),
      '# Orders',
    );
    expect(
      await File('${directory.path}/${second.fileName}').readAsString(),
      '# New export',
    );
    expect(first.fileName, isNot(contains(directory.path)));
  });

  test('requires the caller-selected directory to exist', () async {
    final missing = '${Directory.systemTemp.path}/sendreq-missing-directory';
    expect(
      () => exporter.write(
        MarkdownDocumentationFileRequest(
          outputDirectory: missing,
          collectionName: 'API',
          source: '# API',
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
