import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';

/// 解析 OpenAPI 文档失败时抛出的异常，携带面向用户的错误信息。
class OpenApiImportException implements Exception {
  /// 创建携带错误信息的导入异常。
  const OpenApiImportException(this.message);

  /// 面向用户的错误说明。
  final String message;
}

/// 导入结果：包含生成的集合，以及摊平后的请求定义列表。
class OpenApiImportResult {
  /// 创建导入结果。
  const OpenApiImportResult({required this.collection});

  /// 导入得到的请求集合。
  final ApiCollection collection;

  /// 遍历所有文件夹，返回集合内全部请求定义。
  List<ApiRequestDefinition> get requests => [
    for (final folder in collection.folders)
      for (final request in folder.requests) request,
  ];
}

/// OpenAPI 请求体导入投影：原始正文与两类结构化文本字段互斥保留。
class ImportedRequestBody {
  const ImportedRequestBody({
    this.contentType,
    this.rawBody = '',
    this.formUrlEncodedFields = const [],
    this.multipartFields = const [],
  });

  final String? contentType;
  final String rawBody;
  final List<ApiField> formUrlEncodedFields;
  final List<ApiField> multipartFields;
}

/// 解析后的 OpenAPI 认证方案描述。
class OpenApiAuthenticationScheme {
  /// 创建认证方案描述。
  const OpenApiAuthenticationScheme({
    required this.type,
    this.apiKeyName = 'X-API-Key',
    this.apiKeyLocation = ApiKeyLocation.header,
  });

  /// 从 securitySchemes 条目解析认证方案，无法识别时回退为 none。
  factory OpenApiAuthenticationScheme.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString();
    final httpScheme = json['scheme']?.toString().toLowerCase();
    if (type == 'http' && httpScheme == 'bearer') {
      return const OpenApiAuthenticationScheme(
        type: RequestAuthenticationType.bearer,
      );
    }
    if (type == 'http' && httpScheme == 'basic') {
      return const OpenApiAuthenticationScheme(
        type: RequestAuthenticationType.basic,
      );
    }
    if (type == 'apiKey') {
      return OpenApiAuthenticationScheme(
        type: RequestAuthenticationType.apiKey,
        apiKeyName: json['name'] as String? ?? 'X-API-Key',
        apiKeyLocation: json['in'] == 'query'
            ? ApiKeyLocation.query
            : ApiKeyLocation.header,
      );
    }
    return const OpenApiAuthenticationScheme(
      type: RequestAuthenticationType.none,
    );
  }

  /// 认证类型。
  final RequestAuthenticationType type;

  /// apiKey 认证使用的参数名。
  final String apiKeyName;

  /// apiKey 认证的传递位置（header 或 query）。
  final ApiKeyLocation apiKeyLocation;
}

/// 导入过程中使用的文件夹构建器，暂存请求直到最终汇总。
class FolderImportBuilder {
  /// 创建文件夹构建器。
  FolderImportBuilder({required this.id, required this.name});

  /// 文件夹唯一标识。
  final String id;

  /// 文件夹显示名称。
  final String name;

  /// 暂存的请求定义列表。
  final List<ApiRequestDefinition> requests = [];
}
