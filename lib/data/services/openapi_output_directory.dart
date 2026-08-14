import 'dart:io';

import 'package:sendreq/domain/api_assets/openapi_exchange.dart';

/// OpenAPI 默认导出目录的桌面文件系统适配器。
class OpenApiOutputDirectory {
  const OpenApiOutputDirectory._();

  static Future<Directory> ensureExists(String path) =>
      Directory(path).create(recursive: true);
}

class LocalOpenApiOutputDirectory implements OpenApiOutputDirectoryPort {
  const LocalOpenApiOutputDirectory();

  @override
  Future<void> ensureExists(String directory) async {
    await OpenApiOutputDirectory.ensureExists(directory);
  }
}
