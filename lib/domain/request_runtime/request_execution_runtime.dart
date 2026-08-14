import 'package:sendreq/domain/workspace/workspace_models.dart';

/// 请求执行的运行时响应结果。
class RuntimeResponse {
  /// 构建运行时响应。
  const RuntimeResponse({
    required this.statusCode,
    required this.timeMs,
    required this.sizeKb,
    required this.body,
    required this.headers,
  });

  /// 状态码。
  final int statusCode;

  /// 耗时（毫秒）。
  final int timeMs;

  /// 响应体大小（KB）。
  final double sizeKb;

  /// 响应体文本。
  final String body;

  /// 响应头列表。
  final List<KeyValueRow> headers;
}

/// 运行时错误类别，用于错误归类与界面提示。
enum RuntimeErrorCategory {
  /// 网络错误。
  network,

  /// 请求超时。
  timeout,

  /// 请求被取消。
  cancelled,

  /// 未知错误。
  unknown,
}

/// 请求执行失败时抛出的异常，携带类别与信息。
class RuntimeRequestException implements Exception {
  /// 用 [category] 与 [message] 构造异常。
  const RuntimeRequestException(this.category, this.message);

  /// 错误类别。
  final RuntimeErrorCategory category;

  /// 错误信息。
  final String message;
}

/// 请求执行运行时抽象，屏蔽不同请求传输实现的差异。
abstract interface class RequestExecutionRuntime {
  /// 发送请求并返回运行时响应。
  Future<RuntimeResponse> send({
    required RequestDraft draft,
    required String resolvedUrl,
  });

  /// 取消当前正在执行的请求。
  void cancel();
}
