import 'dart:io';

import '../../domain/models/workspace_models.dart';
import 'api_documentation_generator.dart';

/// 将生成的 API 参考文档写入用户指定目录的 Markdown 文件。
class MarkdownDocumentationExporter {
  /// 创建 Markdown 接口文档导出器。
  const MarkdownDocumentationExporter();

  /// 创建目标目录并写入一个带 UTC 时间戳的文件，避免覆盖已有导出。
  Future<File> export({
    required GeneratedApiDocumentation documentation,
    required DocumentationDraft draft,
    required String outputDirectory,
    DateTime? now,
  }) async {
    final directory = Directory(outputDirectory);
    await directory.create(recursive: true);
    final timestamp = (now ?? DateTime.now()).toUtc();
    final file = await _nextAvailableFile(
      directory,
      fileNameFor(draft, timestamp),
    );
    await file.writeAsString(documentation.markdown, flush: true);
    return file;
  }

  /// 根据请求方法、端点和时间生成可读且跨平台安全的文件名。
  String fileNameFor(DocumentationDraft draft, DateTime timestamp) {
    final endpoint = Uri.tryParse(draft.request.resolvedUrl)?.path ?? '';
    final normalized = endpoint
        .replaceAll(RegExp(r'^/+|/+$'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
    final name = normalized.replaceAll(RegExp(r'^-+|-+$'), '');
    final stamp = timestamp
        .toIso8601String()
        .replaceAll(RegExp(r'[-:.]'), '')
        .replaceAll('Z', 'Z');
    return '${draft.request.method.toLowerCase()}-${name.isEmpty ? 'api' : name}-$stamp.md';
  }

  /// 查找不重名的目标文件，重名时追加递增序号。
  Future<File> _nextAvailableFile(Directory directory, String name) async {
    final extensionIndex = name.lastIndexOf('.');
    final stem = extensionIndex < 0 ? name : name.substring(0, extensionIndex);
    final extension = extensionIndex < 0 ? '' : name.substring(extensionIndex);
    var candidate = File('${directory.path}/$name');
    var index = 1;
    // 文件名已存在时追加递增序号，避免覆盖历史导出。
    while (await candidate.exists()) {
      candidate = File('${directory.path}/$stem-$index$extension');
      index += 1;
    }
    return candidate;
  }
}
