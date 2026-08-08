import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/models/workspace_models.dart';
import '../../domain/request_runtime/request_execution_runtime.dart';

/// 基于 package:http 的真实请求执行运行时，负责把请求草稿发送到网络。
class HttpRequestExecutionRuntime implements RequestExecutionRuntime {
  /// [clientFactory] 用于按需创建 http 客户端，便于测试时注入自定义实现。
  HttpRequestExecutionRuntime({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  /// 创建 http 客户端的工厂函数，测试时可注入自定义实现。
  final http.Client Function() _clientFactory;
  // 当前进行中的客户端，取消请求时用于强制关闭连接。
  http.Client? _activeClient;
  // 是否收到取消请求，用于在异常分支中区分"取消"与普通网络错误。
  bool _cancelRequested = false;

  /// 发送一次 HTTP 请求，返回结构化响应结果。
  @override
  Future<RuntimeResponse> send({
    required RequestDraft draft,
    required String resolvedUrl,
  }) async {
    // 每次发送都重置取消标记，并创建一个全新的客户端实例。
    _cancelRequested = false;
    final client = _clientFactory();
    _activeClient = client;
    final stopwatch = Stopwatch()..start();
    try {
      final request = await _buildRequest(draft, resolvedUrl);
      // 发送请求并设置 20 秒超时，避免连接无限期挂起。
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed);
      stopwatch.stop();
      return RuntimeResponse(
        statusCode: response.statusCode,
        timeMs: stopwatch.elapsedMilliseconds,
        sizeKb: response.bodyBytes.length / 1024,
        body: response.body,
        headers: response.headers.entries
            .map((entry) => KeyValueRow(keyName: entry.key, value: entry.value))
            .toList(growable: false),
      );
    } on RuntimeRequestException {
      // 运行时主动抛出的业务异常原样透传，不重复包装。
      rethrow;
    } on FileSystemException catch (error) {
      throw RuntimeRequestException(
        RuntimeErrorCategory.network,
        'Cannot read ${error.path ?? 'the selected file'}. Choose the file again.',
      );
    } on TimeoutException {
      throw const RuntimeRequestException(
        RuntimeErrorCategory.timeout,
        'Request timed out after 20 seconds.',
      );
    } on Exception catch (error) {
      // 若当前已被取消，则报"已取消"而非网络错误，便于 UI 区分两类失败。
      if (_cancelRequested) {
        throw const RuntimeRequestException(
          RuntimeErrorCategory.cancelled,
          'Request cancelled.',
        );
      }
      throw RuntimeRequestException(
        RuntimeErrorCategory.network,
        'Network request failed: $error',
      );
    } finally {
      // 无论成败都关闭客户端，并清理当前活动引用。
      client.close();
      if (identical(_activeClient, client)) {
        _activeClient = null;
      }
    }
  }

  /// 依据草稿构建 http 请求；Content-Type 为 multipart 时改为分段上传请求。
  Future<http.BaseRequest> _buildRequest(
    RequestDraft draft,
    String resolvedUrl,
  ) async {
    final uri = Uri.parse(resolvedUrl);
    final supportsBody = _supportsBody(draft.method);
    // 普通表单/JSON 请求：直接写入请求体并保留显式的 Content-Type 头。
    if (!_usesMultipart(draft) || !supportsBody) {
      final request = http.Request(draft.method, uri);
      _copyHeaders(draft, request, omitEntityHeaders: !supportsBody);
      if (supportsBody && draft.body.isNotEmpty) request.body = draft.body;
      return request;
    }

    final request = http.MultipartRequest(draft.method, uri);
    // MultipartRequest owns the boundary-bearing Content-Type header.
    _copyHeaders(draft, request, omitEntityHeaders: true);
    // 只收集启用的表单字段，写入 multipart 的普通字段部分。
    for (final field in draft.multipartFields.where(
      (item) => item.enabled && item.keyName.trim().isNotEmpty,
    )) {
      request.fields[field.keyName] = field.value;
    }
    // 为每个启用的文件校验字段名与路径后，追加为 multipart 的文件部分。
    for (final file in draft.multipartFiles.where((item) => item.enabled)) {
      if (file.keyName.trim().isEmpty) {
        throw RuntimeRequestException(
          RuntimeErrorCategory.network,
          'Enter a multipart field name for ${file.fileName}.',
        );
      }
      if (file.path.isEmpty) {
        throw RuntimeRequestException(
          RuntimeErrorCategory.network,
          'Choose ${file.fileName} again before sending.',
        );
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          file.keyName,
          file.path,
          filename: file.fileName,
        ),
      );
    }
    return request;
  }

  /// 复制启用的请求头到 http 请求对象；可跳过 Content-Type 交由底层生成。
  void _copyHeaders(
    RequestDraft draft,
    http.BaseRequest request, {
    required bool omitEntityHeaders,
  }) {
    for (final header in draft.headers.where((item) => item.enabled)) {
      final name = header.keyName.trim();
      // 编辑器中的未完成空行不是请求 Header，避免交给 dart:io 后出现模糊错误。
      if (name.isEmpty) continue;
      final normalizedName = name.toLowerCase();
      if (omitEntityHeaders &&
          (normalizedName == 'content-type' ||
              normalizedName == 'content-length' ||
              normalizedName == 'transfer-encoding')) {
        continue;
      }
      if (_hasInvalidHeaderValue(header.value)) {
        throw RuntimeRequestException(
          RuntimeErrorCategory.network,
          'Header "$name" contains unsupported characters.',
        );
      }
      try {
        request.headers[name] = header.value;
      } on FormatException {
        throw RuntimeRequestException(
          RuntimeErrorCategory.network,
          'Header "$name" has an invalid name or value.',
        );
      }
    }
  }

  /// HTTP Header 值必须是单行 ASCII 文本；换行和非 ASCII 字符会被 dart:io 拒绝。
  bool _hasInvalidHeaderValue(String value) =>
      value.codeUnits.any((unit) => unit < 0x20 || unit > 0x7e);

  /// 判断草稿是否声明了 multipart/form-data 内容类型。
  bool _usesMultipart(RequestDraft draft) => draft.headers.any(
    (header) =>
        header.enabled &&
        header.keyName.toLowerCase() == 'content-type' &&
        header.value.toLowerCase().startsWith('multipart/form-data'),
  );

  /// GET 与 HEAD 之外的请求方法允许携带请求体。
  bool _supportsBody(String method) {
    final normalizedMethod = method.trim().toUpperCase();
    return normalizedMethod != 'GET' && normalizedMethod != 'HEAD';
  }

  /// 置取消标记并强制关闭当前客户端，以中断进行中的请求。
  @override
  void cancel() {
    _cancelRequested = true;
    _activeClient?.close();
  }
}
