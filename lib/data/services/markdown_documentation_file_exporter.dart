import 'dart:io';

import 'package:sendreq/domain/api_assets/collection_documentation.dart';

class MarkdownDocumentationFileExporter
    implements MarkdownDocumentationFilePort {
  const MarkdownDocumentationFileExporter();

  @override
  Future<MarkdownDocumentationFileResult> write(
    MarkdownDocumentationFileRequest request,
  ) async {
    final directory = Directory(request.outputDirectory);
    if (!await directory.exists()) {
      throw const FileSystemException(
        'Selected output directory is unavailable.',
      );
    }
    final stem = sanitizeFileName(request.collectionName);
    final file = await _nextAvailableFile(directory, '$stem.md');
    await file.writeAsString(request.source, flush: true);
    return MarkdownDocumentationFileResult(
      fileName: file.uri.pathSegments.last,
    );
  }

  String sanitizeFileName(String value) {
    var sanitized = value
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[. ]+$'), '');
    if (sanitized.isEmpty) sanitized = 'sendreq-api';
    if (const {
      'con',
      'prn',
      'aux',
      'nul',
      'com1',
      'com2',
      'com3',
      'com4',
      'com5',
      'com6',
      'com7',
      'com8',
      'com9',
      'lpt1',
      'lpt2',
      'lpt3',
      'lpt4',
      'lpt5',
      'lpt6',
      'lpt7',
      'lpt8',
      'lpt9',
    }.contains(sanitized.toLowerCase())) {
      sanitized = 'sendreq-$sanitized';
    }
    return sanitized;
  }

  Future<File> _nextAvailableFile(Directory directory, String fileName) async {
    final stem = fileName.substring(0, fileName.length - 3);
    var candidate = File('${directory.path}/$fileName');
    var sequence = 1;
    while (await candidate.exists()) {
      candidate = File('${directory.path}/$stem-$sequence.md');
      sequence++;
    }
    return candidate;
  }
}
