import 'package:isar_community/isar.dart';

part 'isar_workspace_models.g.dart';

/// 工作区快照文档。资产层级保留现有稳定 JSON 结构，避免改变领域模型。
@collection
class WorkspaceDocument {
  /// Isar 自增主键。
  Id id = Isar.autoIncrement;

  /// 文档唯一标识；字段带唯一索引，重复 key 写入会替换旧文档。
  @Index(unique: true, replace: true)
  late String key;

  /// 快照的 schema 版本，供启动时判断是否迁移。
  late int schemaVersion;

  /// 快照负载（JSON 字符串），具体结构由对应的 codec 解析。
  late String payloadJson;

  /// 最近一次写入或迁移的时间（UTC）。
  late DateTime updatedAt;
}
