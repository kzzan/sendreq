import 'dart:io';
import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sendreq/data/database/isar_workspace_models.dart';

/// Isar 工作区数据库的生命周期入口。
class IsarWorkspace {
  /// 私有构造：包装已打开的 Isar 实例，仅由 [open] 创建。
  IsarWorkspace._(this.instance);

  /// 当前应用层工作区文档格式。
  static const currentDocumentSchemaVersion = 3;

  /// 底层打开的 Isar 实例，各存储模块通过它读写工作区文档。
  final Isar instance;

  /// 打开（必要时创建）工作区数据库，并在返回前完成文档迁移。
  static Future<IsarWorkspace> open({Directory? directory}) async {
    final root = directory ?? await getApplicationSupportDirectory();
    await root.create(recursive: true);
    final instance = await Isar.open(
      [WorkspaceDocumentSchema],
      directory: root.path,
      name: 'sendreq_workspace',
    );
    final workspace = IsarWorkspace._(instance);
    try {
      await workspace._migrateDocuments();
      return workspace;
    } on Object {
      // 迁移失败时关闭实例并重新抛出，避免遗留半初始化的工作区。
      await instance.close();
      rethrow;
    }
  }

  /// 关闭底层 Isar 实例，释放数据库连接。
  Future<void> close() => instance.close();

  /// 将所有工作区文档升级到 [currentDocumentSchemaVersion]；无法处理的文档直接抛错。
  Future<void> _migrateDocuments() async {
    final documents = await instance.workspaceDocuments
        .where()
        .anyId()
        .findAll();
    final upgrades = <WorkspaceDocument>[];
    for (final document in documents) {
      if (document.schemaVersion > currentDocumentSchemaVersion) {
        // 文档版本高于当前支持的版本，无法降级处理，直接报错。
        throw IsarWorkspaceMigrationException.unsupportedVersion(
          document.key,
          document.schemaVersion,
        );
      }
      if (document.schemaVersion < 1 || !_isJsonObject(document.payloadJson)) {
        // 文档过旧或负载不是合法 JSON 对象，视为无效数据。
        throw IsarWorkspaceMigrationException.invalidDocument(document.key);
      }
      if (document.schemaVersion < currentDocumentSchemaVersion) {
        // 旧版本文档原地升级到当前版本，并刷新更新时间。
        document
          ..schemaVersion = currentDocumentSchemaVersion
          ..updatedAt = DateTime.now().toUtc();
        upgrades.add(document);
      }
    }
    if (upgrades.isEmpty) return;
    await instance.writeTxn(() => instance.workspaceDocuments.putAll(upgrades));
  }

  /// 判断字符串是否能解析为 JSON 对象（Map），用于校验文档负载。
  bool _isJsonObject(String source) {
    try {
      return jsonDecode(source) is Map;
    } on FormatException {
      return false;
    }
  }
}

/// 工作区升级失败时保留原始数据并向启动层提供可恢复原因。
class IsarWorkspaceMigrationException implements Exception {
  /// 私有构造，仅由各工厂方法创建。
  const IsarWorkspaceMigrationException._(this.message);

  /// 创建"文档使用了不支持的 schema 版本"异常。
  factory IsarWorkspaceMigrationException.unsupportedVersion(
    String key,
    int version,
  ) => IsarWorkspaceMigrationException._(
    'Workspace document "$key" uses unsupported schema version $version.',
  );

  /// 创建"文档无效且未迁移"异常。
  factory IsarWorkspaceMigrationException.invalidDocument(String key) =>
      IsarWorkspaceMigrationException._(
        'Workspace document "$key" is invalid and was not migrated.',
      );

  /// 异常的人类可读说明。
  final String message;

  /// 返回带类型前缀的异常描述。
  @override
  String toString() => 'IsarWorkspaceMigrationException: $message';
}
