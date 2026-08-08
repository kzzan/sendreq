import 'dart:convert';

import '../../domain/api_assets/api_asset_models.dart';
import '../../domain/models/workspace_models.dart';

/// Execution History 快照的 JSON 编解码与敏感请求头脱敏规则。
abstract final class ExecutionHistorySnapshotCodec {
  /// 快照文档的格式版本号。
  static const version = 1;

  /// 请求/响应体保留的最大字节数，超出部分截断。
  static const maxBodyBytes = 32 * 1024;

  /// 请求头值保留的最大字节数，超出部分截断。
  static const maxHeaderValueBytes = 4 * 1024;

  /// 错误信息保留的最大字节数，超出部分截断。
  static const maxErrorMessageBytes = 4 * 1024;

  /// 截断后追加的标记文本。
  static const _truncationMarker = '\n...[truncated]';

  /// 按名称强制脱敏的请求头（统一小写），避免将凭据写入快照。
  static const _sensitiveHeaderNames = <String>{
    'authorization',
    'cookie',
    'proxy-authorization',
    'set-cookie',
    'x-api-key',
  };

  /// 将一条执行记录连同发生时间编码为单条存储条目。
  static Map<String, Object?> entry(
    ExecutionRecord record,
    DateTime occurredAt,
  ) => {
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'record': _encodeRecord(record),
  };

  /// 将条目列表编码为带版本号的文档 JSON。
  static String encodeDocument(List<Map<String, Object?>> entries) =>
      jsonEncode({'version': version, 'records': entries});

  /// 保留最新条目，直到文档编码后的 UTF-8 大小落入指定预算。
  static List<Map<String, Object?>> retainWithinByteBudget(
    Iterable<Map<String, Object?>> entries, {
    required int maxBytes,
  }) {
    final retained = <Map<String, Object?>>[];
    for (final entry in entries) {
      final candidate = [...retained, entry];
      // 编码后超过预算则停止累积，保留此前已验证的条目。
      if (utf8.encode(encodeDocument(candidate)).length > maxBytes) break;
      retained.add(entry);
    }
    return retained;
  }

  /// 解码文档 JSON 为条目列表；来源为 null、版本不符或解析失败时返回空列表。
  static List<Map<String, Object?>> decodeEntries(String? source) {
    if (source == null) return const [];
    try {
      final root = Map<String, dynamic>.from(jsonDecode(source) as Map);
      if (root['version'] != version) return const [];
      return (root['records'] as List<dynamic>)
          .map((item) => Map<String, Object?>.from(item as Map))
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  /// 将单条存储条目解码回执行记录，缺失字段按容错默认值处理。
  static ExecutionRecord decodeRecord(Map<String, Object?> stored) {
    final value = Map<String, dynamic>.from(stored['record'] as Map);
    return ExecutionRecord(
      id: value['id'] as String,
      requestId: value['requestId'] as String?,
      method: value['method'] as String,
      protocol: value['protocol'] == null && value['method'] == 'WS'
          ? ApiRequestProtocol.webSocket
          : ApiRequestProtocol.fromStorageValue(value['protocol']),
      path: value['path'] as String,
      status: value['status'] as int?,
      timeMs: value['timeMs'] as int,
      // 记录未保存时间时回退到条目自身的发生时间。
      when: value['when'] as String? ?? stored['occurredAt'] as String,
      requestSnapshot: value['request'] is Map
          ? _decodeRequest(Map<String, dynamic>.from(value['request'] as Map))
          : null,
      response: value['response'] is Map
          ? _decodeResponse(Map<String, dynamic>.from(value['response'] as Map))
          : null,
      errorCategory: value['errorCategory'] as String?,
      errorMessage: value['errorMessage'] as String?,
      webSocketSummary: value['webSocket'] is Map
          ? _decodeWebSocketSummary(
              Map<String, dynamic>.from(value['webSocket'] as Map),
            )
          : null,
    );
  }

  /// 编码执行记录为存储 Map；错误信息超出预算时截断。
  static Map<String, Object?> _encodeRecord(ExecutionRecord record) => {
    'id': record.id,
    'requestId': record.requestId,
    'method': record.method,
    'protocol': record.protocol.storageValue,
    'path': record.path,
    'status': record.status,
    'timeMs': record.timeMs,
    'when': record.when,
    'request': record.requestSnapshot == null
        ? null
        : _encodeRequest(record.requestSnapshot!),
    'response': record.response == null
        ? null
        : _encodeResponse(record.response!),
    'errorCategory': record.errorCategory,
    'errorMessage': record.errorMessage == null
        ? null
        : _truncate(record.errorMessage!, maxBytes: maxErrorMessageBytes),
    'webSocket': record.webSocketSummary == null
        ? null
        : _encodeWebSocketSummary(record.webSocketSummary!),
  };

  /// 编码请求快照；正文按字节预算截断，请求头做脱敏。
  static Map<String, Object?> _encodeRequest(ExecutionRequestSnapshot value) =>
      {
        'method': value.method,
        'protocol': value.protocol.storageValue,
        'resolvedUrl': value.resolvedUrl,
        'headers': value.headers.map(_encodeHeader).toList(),
        'body': _truncate(value.body, maxBytes: maxBodyBytes),
        'environmentName': value.environmentName,
      };

  /// 编码响应快照；正文按字节预算截断，响应头做脱敏。
  static Map<String, Object?> _encodeResponse(ResponseSnapshot value) => {
    'statusCode': value.statusCode,
    'timeMs': value.timeMs,
    'sizeKb': value.sizeKb,
    'body': _truncate(value.body, maxBytes: maxBodyBytes),
    'headers': value.headers.map(_encodeHeader).toList(),
  };

  /// 编码 WebSocket 的纯元数据摘要，明确不接收会话事件或二进制负载。
  static Map<String, Object?> _encodeWebSocketSummary(
    WebSocketSessionHistorySummary value,
  ) => {
    'endpoint': _truncate(value.endpoint, maxBytes: maxErrorMessageBytes),
    'startedAt': value.startedAt.toUtc().toIso8601String(),
    'endedAt': value.endedAt.toUtc().toIso8601String(),
    'terminalStatus': value.terminalStatus,
    'inboundMessageCount': value.inboundMessageCount,
    'outboundMessageCount': value.outboundMessageCount,
    'errorMessage': value.errorMessage == null
        ? null
        : _truncate(value.errorMessage!, maxBytes: maxErrorMessageBytes),
  };

  /// 解码 WebSocket 摘要；不完整或损坏的摘要会让该条记录按普通历史回退。
  static WebSocketSessionHistorySummary? _decodeWebSocketSummary(
    Map<String, dynamic> value,
  ) {
    try {
      return WebSocketSessionHistorySummary(
        endpoint: value['endpoint'] as String,
        startedAt: DateTime.parse(value['startedAt'] as String).toUtc(),
        endedAt: DateTime.parse(value['endedAt'] as String).toUtc(),
        terminalStatus: value['terminalStatus'] as String,
        inboundMessageCount: value['inboundMessageCount'] as int,
        outboundMessageCount: value['outboundMessageCount'] as int,
        errorMessage: value['errorMessage'] as String?,
      );
    } on Object {
      return null;
    }
  }

  /// 编码请求头；敏感请求头的值一律用圆点占位并标记 secret。
  static Map<String, Object?> _encodeHeader(KeyValueRow value) => {
    'key': value.keyName,
    'value': _isSensitiveHeader(value)
        ? '••••••••••••'
        : _truncate(value.value, maxBytes: maxHeaderValueBytes),
    'enabled': value.enabled,
    'secret': _isSensitiveHeader(value),
  };

  /// 判断请求头是否敏感：显式标记 secret 或命中敏感名称列表。
  static bool _isSensitiveHeader(KeyValueRow value) =>
      value.secret ||
      _sensitiveHeaderNames.contains(value.keyName.toLowerCase());

  /// 将字符串按 UTF-8 字节预算截断，并在末尾追加截断标记。
  static String _truncate(String value, {required int maxBytes}) {
    final bytes = utf8.encode(value);
    if (bytes.length <= maxBytes) return value;
    final marker = utf8.encode(_truncationMarker);
    final limit = maxBytes - marker.length;
    var end = limit;
    // 截断点可能落在多字节字符中间，向前回退到合法 UTF-8 边界。
    while (end > 0) {
      try {
        return '${utf8.decode(bytes.sublist(0, end))}$_truncationMarker';
      } on FormatException {
        end--;
      }
    }
    return _truncationMarker;
  }

  /// 从存储 Map 还原请求快照。
  static ExecutionRequestSnapshot _decodeRequest(Map<String, dynamic> value) =>
      ExecutionRequestSnapshot(
        method: value['method'] as String,
        protocol: ApiRequestProtocol.fromStorageValue(value['protocol']),
        resolvedUrl: value['resolvedUrl'] as String,
        headers: _decodeHeaders(value['headers']),
        body: value['body'] as String,
        environmentName: value['environmentName'] as String,
      );

  /// 从存储 Map 还原响应快照。
  static ResponseSnapshot _decodeResponse(Map<String, dynamic> value) =>
      ResponseSnapshot(
        statusCode: value['statusCode'] as int,
        timeMs: value['timeMs'] as int,
        sizeKb: (value['sizeKb'] as num).toDouble(),
        body: value['body'] as String,
        headers: _decodeHeaders(value['headers']),
      );

  /// 从存储列表还原请求头；缺省字段按默认值补齐。
  static List<KeyValueRow> _decodeHeaders(Object? source) => [
    for (final item in (source as List<dynamic>? ?? const <dynamic>[]))
      KeyValueRow(
        keyName: (item as Map)['key'] as String,
        value: item['value'] as String,
        enabled: item['enabled'] as bool? ?? true,
        secret: item['secret'] as bool? ?? false,
      ),
  ];
}
