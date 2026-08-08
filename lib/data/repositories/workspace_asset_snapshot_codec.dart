import 'dart:convert';

import '../../domain/api_assets/api_asset_models.dart';
import 'in_memory_api_asset_repository.dart';

/// API 资产快照的稳定 JSON 格式。
///
/// 这个 codec 不了解 Isar，使领域快照的版本演进可以独立于存储引擎。
abstract final class WorkspaceAssetSnapshotCodec {
  /// 快照格式版本号。
  static const version = 1;

  /// 解码快照 JSON；版本不符、字段缺失或解析失败时返回 null。
  static InMemoryApiAssetRepository? decode(String source) {
    try {
      final root = Map<String, dynamic>.from(jsonDecode(source) as Map);
      // 版本不符视为不可用快照，返回 null 交由调用方回退。
      if (root['version'] != version) return null;
      return InMemoryApiAssetRepository(
        collections: (root['collections'] as List<dynamic>)
            .map(
              (value) => ApiCollection.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(growable: false),
        openTabs: (root['openTabs'] as List<dynamic>)
            .map(
              (value) =>
                  RequestTab.fromJson(Map<String, dynamic>.from(value as Map)),
            )
            .toList(growable: false),
        activeRequestId: root['activeRequestId'] as String?,
      );
    } on Object {
      // 任何解析异常都返回 null，交由调用方回退到示例或恢复流程。
      return null;
    }
  }

  /// 将资产快照编码为带版本号的 JSON 字符串。
  static String encode({
    required List<ApiCollection> collections,
    required List<RequestTab> openTabs,
    required String? activeRequestId,
  }) => jsonEncode({
    'version': version,
    'collections': collections.map((item) => item.toJson()).toList(),
    'openTabs': openTabs.map((item) => item.toJson()).toList(),
    'activeRequestId': activeRequestId,
  });
}
