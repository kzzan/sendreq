import 'dart:convert';
import 'dart:io';

import '../../domain/models/workspace_models.dart';

/// 本地 mock 服务器信息，包含外部访问可用的 URL。
class LocalMockServerInfo {
  /// 创建记录服务器 URL 的信息对象。
  const LocalMockServerInfo({required this.url});

  /// 外部访问服务器所需的 URL。
  final Uri url;
}

/// 本地 mock 运行时抽象：在回环地址启动服务器，并按草稿响应请求。
abstract interface class LocalMockRuntime {
  /// 服务器是否正在运行。
  bool get isRunning;

  /// 当前服务器信息，未运行时为 null。
  LocalMockServerInfo? get info;

  /// 以草稿中配置的假响应启动服务器。
  Future<LocalMockServerInfo> start(MockDraft draft);

  /// 更新运行中服务使用的草稿；未运行时保留为下一次启动的草稿。
  void updateDraft(MockDraft draft);

  /// 停止服务器并清理状态。
  Future<void> stop();
}

/// 基于 dart:io HttpServer 的回环 mock 运行时，监听 127.0.0.1 的随机端口。
class LoopbackMockRuntime implements LocalMockRuntime {
  /// 当前监听中的回环服务器；null 表示未运行。
  HttpServer? _server;

  /// 当前生效的 mock 草稿；null 表示尚未启动。
  MockDraft? _draft;

  // These headers describe the original connection or a byte representation
  // that no longer exists after the captured body has been decoded to text.
  // Replaying them makes HTTP clients attempt a second decompression or parse
  // incorrect framing information.
  static const _nonReplayableResponseHeaders = <String>{
    'age',
    'alt-svc',
    'connection',
    'content-digest',
    'content-encoding',
    'content-length',
    'content-md5',
    'content-range',
    'date',
    'digest',
    'keep-alive',
    'proxy-authenticate',
    'server',
    'server-timing',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
    'via',
  };

  /// 服务器是否正在运行。
  @override
  bool get isRunning => _server != null;

  /// 当前服务器信息；未运行时为 null。
  @override
  LocalMockServerInfo? get info => _server == null
      ? null
      : LocalMockServerInfo(
          url: Uri.parse('http://127.0.0.1:${_server!.port}'),
        );

  /// 停止旧服务器，绑定新的回环端口并挂起请求监听。
  @override
  Future<LocalMockServerInfo> start(MockDraft draft) async {
    await stop();
    _draft = draft;
    // 端口传 0 表示由系统分配空闲端口，避免冲突。
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
    return info!;
  }

  /// 更新运行中服务使用的草稿；未运行时保留为下次启动的草稿。
  @override
  void updateDraft(MockDraft draft) {
    _draft = draft;
  }

  /// 处理进入的 HTTP 请求：匹配草稿后返回其配置的假响应。
  Future<void> _handle(HttpRequest request) async {
    final draft = _draft;
    // 解析草稿的目标 URL，供后续与入站请求做方法与路径匹配。
    final target = draft == null
        ? null
        : Uri.tryParse(draft.request.resolvedUrl);
    // Quick Mock 只匹配方法和路径，调用端的 query 参数不影响结果。
    final matched =
        target != null &&
        request.method.toUpperCase() == draft!.request.method.toUpperCase() &&
        request.uri.path == target.path;
    if (!matched) {
      // 不匹配时返回 404 JSON 错误体。
      request.response.statusCode = HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': 'mock endpoint not found'}));
      await request.response.close();
      return;
    }
    request.response.statusCode = draft.response.statusCode;
    // 草稿保存的是解码后的文本体，不能回放原响应的传输、压缩或校验头；
    // 否则客户端会按 gzip 等旧编码再次解码，导致 FormatException。
    for (final header in draft.response.headers.where((item) => item.enabled)) {
      final key = header.keyName.trim();
      if (key.isEmpty ||
          _nonReplayableResponseHeaders.contains(key.toLowerCase())) {
        continue;
      }
      try {
        request.response.headers.set(key, header.value);
      } on FormatException {
        // Ignore malformed captured headers while keeping the mock response available.
      } on HttpException {
        // Ignore headers that dart:io reserves for the response stream.
      }
    }
    // 未显式设置 Content-Type 时默认返回 JSON。
    if (request.response.headers.value('content-type')?.isNotEmpty != true) {
      request.response.headers.contentType = ContentType.json;
    }
    request.response.write(draft.response.body);
    await request.response.close();
  }

  /// 停止服务器（强制关闭）并清空草稿引用。
  @override
  Future<void> stop() async {
    final server = _server;
    _server = null;
    _draft = null;
    await server?.close(force: true);
  }
}
