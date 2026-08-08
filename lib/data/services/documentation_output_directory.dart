import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 统一管理接口文档与 OpenAPI 文件的本地输出目录。
class DocumentationOutputDirectory {
  /// 私有构造，仅供本类静态方法使用。
  const DocumentationOutputDirectory._();

  /// 从当前系统的 Documents 已知目录解析默认输出路径。
  ///
  /// 该平台 API 会处理 Windows 已重定向的 Documents、macOS 沙盒目录和 Linux
  /// 的桌面目录配置；生产代码不得通过 HOME 或 USERPROFILE 拼接路径。
  static Future<String> defaultPathForCurrentUser({
    Future<Directory> Function()? documentsDirectory,
  }) async {
    final documents =
        await (documentsDirectory ?? getApplicationDocumentsDirectory)();
    return Directory('${documents.path}${Platform.pathSeparator}sendreq').path;
  }

  /// 创建指定的文档输出目录；供用户选择目录和测试环境复用。
  static Future<Directory> ensureExists(String path) =>
      Directory(path).create(recursive: true);

  /// 仅供未注入桌面目录服务的 Widget 测试兜底，不能用于桌面应用启动路径。
  static String testFallbackPath() => Directory(
    '${Directory.current.path}${Platform.pathSeparator}sendreq-documents',
  ).path;
}
