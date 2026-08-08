import 'dart:io';

/// 将 OpenAPI JSON 写入接口文档输出目录。
class OpenApiFileExporter {
  /// 创建 OpenAPI 文件导出器。
  const OpenApiFileExporter();

  /// 创建输出目录并以 UTC 时间戳命名文件，保留每一次导出。
  Future<File> export({
    required String outputDirectory,
    required String source,
    DateTime? now,
  }) async {
    final directory = Directory(outputDirectory);
    await directory.create(recursive: true);
    final file = await _nextAvailableFile(
      directory,
      fileNameFor(now ?? DateTime.now()),
    );
    await file.writeAsString(source, flush: true);
    return file;
  }

  /// 生成跨平台安全且可排序的 OpenAPI 文件名。
  String fileNameFor(DateTime timestamp) {
    final stamp = timestamp
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[-:.]'), '')
        .replaceAll('Z', 'Z');
    return 'openapi-$stamp.json';
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
