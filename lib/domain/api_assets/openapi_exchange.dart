import 'package:sendreq/domain/repositories/api_asset_repository.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';

/// 读取 OpenAPI 文档时发现的丢失或不支持的构造。
enum OpenApiImportIssueKind { unsupported, loss, conflict }

class OpenApiImportIssue {
  const OpenApiImportIssue({
    required this.kind,
    required this.path,
    required this.code,
  });

  final OpenApiImportIssueKind kind;
  final String path;
  final String code;
}

/// 在改动任何资产之前，解析 OpenAPI 得到的不可变结果。
class OpenApiImportPreview {
  OpenApiImportPreview({
    required this.id,
    required this.collection,
    required List<OpenApiImportIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final String id;
  final ApiCollection collection;
  final List<OpenApiImportIssue> issues;

  int get additionCount => collection.folders.fold(
    0,
    (count, folder) => count + folder.requests.length,
  );

  int get unsupportedCount => issues
      .where((issue) => issue.kind == OpenApiImportIssueKind.unsupported)
      .length;

  int get lossCount =>
      issues.where((issue) => issue.kind == OpenApiImportIssueKind.loss).length;

  int get conflictCount => issues
      .where((issue) => issue.kind == OpenApiImportIssueKind.conflict)
      .length;
}

/// 纯 OpenAPI 解析。它不得选择文件或改动资产存储。
abstract interface class OpenApiImportTransformer {
  OpenApiImportPreview preview(String source);
}

/// 纯 OpenAPI 序列化。它绝不会读取实时执行或环境。
abstract interface class OpenApiExportPort {
  String serialize(OpenApiExportSnapshot snapshot);
}

/// 将已序列化的 OpenAPI 文档写入调用方指定位置的边界。
///
/// 返回值只包含安全、可显示的实际路径；Shell 不接触 `dart:io` 文件对象。
abstract interface class OpenApiFileExportPort {
  Future<OpenApiFileExportResult> write(OpenApiFileExportRequest request);
}

/// OpenAPI 默认导出目录的文件系统边界。
///
/// 此端口只服务 OpenAPI 导出，目标目录由调用方明确提供。
abstract interface class OpenApiOutputDirectoryPort {
  Future<void> ensureExists(String directory);
}

/// 读取用户已在 UI 中选择的 OpenAPI 源文件。
abstract interface class OpenApiFileReadPort {
  Future<String> read(String path);
}

class OpenApiFileExportRequest {
  const OpenApiFileExportRequest({
    required this.outputDirectory,
    required this.source,
  });

  final String outputDirectory;
  final String source;
}

class OpenApiFileExportResult {
  const OpenApiFileExportResult({required this.path});

  final String path;
}

class OpenApiExportSnapshot {
  OpenApiExportSnapshot({
    required List<ApiRequestDefinition> requests,
    this.title = 'sendreq API',
  }) : requests = List.unmodifiable(requests);

  final List<ApiRequestDefinition> requests;
  final String title;
}

/// M2 应用端口：先预览，再使用完全相同的预览 id 提交。
abstract interface class OpenApiImportPort {
  OpenApiImportPreview preview(String source);

  ApiCollection commit(String previewId);
}

/// 在调用方显式确认提交前，保持已解析的预览不对外可见。
class OpenApiAssetImportService implements OpenApiImportPort {
  OpenApiAssetImportService({
    required this.assetRepository,
    required this.transformer,
  });

  final ApiAssetRepository assetRepository;
  final OpenApiImportTransformer transformer;
  final Map<String, OpenApiImportPreview> _pending = {};

  @override
  OpenApiImportPreview preview(String source) {
    final preview = transformer.preview(source);
    _pending[preview.id] = preview;
    return preview;
  }

  @override
  ApiCollection commit(String previewId) {
    final preview = _pending[previewId];
    if (preview == null) {
      throw StateError('OpenAPI import preview "$previewId" is unavailable.');
    }
    final collection = assetRepository.addCollection(preview.collection);
    _pending.remove(previewId);
    return collection;
  }
}
