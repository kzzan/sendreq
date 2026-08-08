import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'grpc_transport.dart';

/// 一条 gRPC 调用事件的本地快照。
class GrpcCallEvent {
  const GrpcCallEvent({
    required this.kind,
    required this.timestamp,
    required this.byteLength,
    this.metadata = const {},
    this.message,
    this.statusCode,
    this.statusMessage,
  });

  /// 事件类型（headers/trailers/status/message/error）。
  final GrpcTransportEventKind kind;

  /// 事件产生的时间。
  final DateTime timestamp;

  /// 该事件计入内存预算的字节数。
  final int byteLength;

  /// 脱敏后的 metadata 键值对。
  final Map<String, String> metadata;

  /// 二进制消息体；仅在 message 类事件中存在。
  final Uint8List? message;

  /// gRPC 状态码；仅在 status 类事件中存在。
  final int? statusCode;

  /// 状态说明或错误消息；已做脱敏。
  final String? statusMessage;
}

/// 单个请求的 gRPC 调用状态，事件数量和字节数始终受限。
class GrpcCallSnapshot {
  const GrpcCallSnapshot({
    required this.requestId,
    required this.state,
    required this.events,
    required this.omittedEventCount,
    required this.retainedByteCount,
    this.headers = const {},
    this.trailers = const {},
    this.errorMessage,
  });

  /// 所属请求 ID。
  final String requestId;

  /// 当前调用生命周期状态。
  final GrpcCallState state;

  /// 有界的事件历史（按数量与字节上限裁剪）。
  final List<GrpcCallEvent> events;

  /// 因超限被裁剪丢弃的事件个数。
  final int omittedEventCount;

  /// 当前保留事件占用的总字节数。
  final int retainedByteCount;

  /// 响应头 metadata。
  final Map<String, String> headers;

  /// 响应尾 metadata。
  final Map<String, String> trailers;

  /// 错误消息；成功时为空。
  final String? errorMessage;

  /// 基于当前快照生成部分更新的副本。
  GrpcCallSnapshot copyWith({
    GrpcCallState? state,
    List<GrpcCallEvent>? events,
    int? omittedEventCount,
    int? retainedByteCount,
    Map<String, String>? headers,
    Map<String, String>? trailers,
    String? errorMessage,
    bool clearError = false,
  }) => GrpcCallSnapshot(
    requestId: requestId,
    state: state ?? this.state,
    events: events ?? this.events,
    omittedEventCount: omittedEventCount ?? this.omittedEventCount,
    retainedByteCount: retainedByteCount ?? this.retainedByteCount,
    headers: headers ?? this.headers,
    trailers: trailers ?? this.trailers,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

/// 按请求 ID 隔离管理 gRPC 调用、取消和有界本地事件历史。
class GrpcCallRegistry {
  GrpcCallRegistry(
    this._transport, {
    this.maxEventsPerCall = 500,
    this.maxRetainedBytesPerCall = 1024 * 1024,
    this.onChanged,
  });

  /// 底层 gRPC transport。
  final GrpcTransport _transport;

  /// 每个请求保留的最大事件数。
  final int maxEventsPerCall;

  /// 每个请求保留事件的最大字节数。
  final int maxRetainedBytesPerCall;

  /// 状态变化时的通知回调。
  final void Function()? onChanged;

  /// 请求 ID 到其调用条目（含状态与历史）的映射。
  final Map<String, _CallEntry> _entries = {};

  /// 返回请求的调用快照；没有调用过时为 idle。
  GrpcCallSnapshot callFor(String requestId) =>
      _entries[requestId]?.snapshot ??
      GrpcCallSnapshot(
        requestId: requestId,
        state: GrpcCallState.idle,
        events: const [],
        omittedEventCount: 0,
        retainedByteCount: 0,
      );

  /// 发起调用。新的调用会先取消同一请求此前仍在运行的调用。
  Future<void> start({
    required String requestId,
    required GrpcCallConfiguration configuration,
  }) async {
    await cancel(requestId);
    final entry = _entryFor(requestId);
    entry.generation += 1;
    final generation = entry.generation;
    entry.redactedValues = configuration.redactedValues;
    entry.snapshot = GrpcCallSnapshot(
      requestId: requestId,
      state: GrpcCallState.connecting,
      events: const [],
      omittedEventCount: 0,
      retainedByteCount: 0,
    );
    _changed();
    try {
      final call = await _transport.start(configuration);
      if (!_isCurrent(entry, generation)) {
        await call.cancel();
        return;
      }
      entry.call = call;
      entry.subscription = call.events.listen(
        (event) => _handleEvent(entry, generation, event),
        onError: (Object error) => _fail(entry, generation, '$error'),
        onDone: () => _completeIfRunning(entry, generation),
      );
      entry.snapshot = entry.snapshot.copyWith(state: GrpcCallState.running);
      _changed();
    } on Object catch (error) {
      _fail(entry, generation, '$error');
    }
  }

  /// 显式取消一个请求的调用；取消后的迟到事件会被 generation 忽略。
  Future<void> cancel(String requestId) async {
    final entry = _entries[requestId];
    if (entry == null ||
        entry.snapshot.state == GrpcCallState.idle ||
        entry.snapshot.state == GrpcCallState.completed ||
        entry.snapshot.state == GrpcCallState.cancelled ||
        entry.snapshot.state == GrpcCallState.error) {
      return;
    }
    entry.generation += 1;
    entry.snapshot = entry.snapshot.copyWith(state: GrpcCallState.cancelling);
    _changed();
    await entry.subscription?.cancel();
    entry.subscription = null;
    try {
      await entry.call?.cancel();
      entry.snapshot = entry.snapshot.copyWith(state: GrpcCallState.cancelled);
    } on Object catch (error) {
      entry.snapshot = entry.snapshot.copyWith(
        state: GrpcCallState.error,
        errorMessage: _redact('$error', entry),
      );
    } finally {
      entry.call = null;
      _changed();
    }
  }

  /// 取消并移除某一请求的临时调用状态。
  Future<void> disposeRequest(String requestId) async {
    await cancel(requestId);
    _entries.remove(requestId);
    _changed();
  }

  /// 释放全部在途调用。
  Future<void> dispose() async {
    for (final requestId in _entries.keys.toList(growable: false)) {
      await disposeRequest(requestId);
    }
  }

  /// 取请求的调用条目；不存在则创建 idle 新条目。
  _CallEntry _entryFor(String requestId) => _entries.putIfAbsent(
    requestId,
    () => _CallEntry(
      GrpcCallSnapshot(
        requestId: requestId,
        state: GrpcCallState.idle,
        events: const [],
        omittedEventCount: 0,
        retainedByteCount: 0,
      ),
    ),
  );

  /// 判断事件是否属于当前代次的调用，用于忽略取消后的迟到事件。
  bool _isCurrent(_CallEntry entry, int generation) =>
      entry.generation == generation;

  /// 将 transport 事件转为快照事件并追加，同时推进状态机。
  void _handleEvent(
    _CallEntry entry,
    int generation,
    GrpcTransportEvent transportEvent,
  ) {
    if (!_isCurrent(entry, generation)) return;
    final event = _snapshotEvent(transportEvent, entry);
    _append(entry, event);
    switch (transportEvent.kind) {
      case GrpcTransportEventKind.headers:
        entry.snapshot = entry.snapshot.copyWith(headers: event.metadata);
      case GrpcTransportEventKind.trailers:
        entry.snapshot = entry.snapshot.copyWith(trailers: event.metadata);
      case GrpcTransportEventKind.status:
        entry.snapshot = entry.snapshot.copyWith(
          state: transportEvent.statusCode == 0
              ? GrpcCallState.completed
              : GrpcCallState.error,
          errorMessage: transportEvent.statusCode == 0
              ? null
              : event.statusMessage,
          clearError: transportEvent.statusCode == 0,
        );
      case GrpcTransportEventKind.error:
        entry.snapshot = entry.snapshot.copyWith(
          state: GrpcCallState.error,
          errorMessage: event.statusMessage,
        );
      case GrpcTransportEventKind.message:
        break;
    }
    _changed();
  }

  /// 将 transport 事件复制为不可变快照，并对 metadata 与消息做脱敏。
  GrpcCallEvent _snapshotEvent(GrpcTransportEvent event, _CallEntry entry) {
    final metadata = {
      for (final item in event.metadata.entries)
        item.key: _redact(item.value, entry),
    };
    final message = event.message == null
        ? null
        : Uint8List.fromList(event.message!);
    final statusMessage = event.statusMessage == null
        ? null
        : _redact(event.statusMessage!, entry);
    final byteLength =
        message?.length ??
        utf8
                .encode(
                  metadata.entries
                      .map((item) => '${item.key}:${item.value}')
                      .join(),
                )
                .length +
            utf8.encode(statusMessage ?? '').length;
    return GrpcCallEvent(
      kind: event.kind,
      timestamp: DateTime.now(),
      byteLength: byteLength,
      metadata: Map.unmodifiable(metadata),
      message: message,
      statusCode: event.statusCode,
      statusMessage: statusMessage,
    );
  }

  /// 追加事件，超出数量或字节上限时从头部裁剪并累计省略计数。
  void _append(_CallEntry entry, GrpcCallEvent event) {
    final events = [...entry.snapshot.events, event];
    var bytes = entry.snapshot.retainedByteCount + event.byteLength;
    var omitted = entry.snapshot.omittedEventCount;
    while (events.length > maxEventsPerCall ||
        (bytes > maxRetainedBytesPerCall && events.length > 1)) {
      final removed = events.removeAt(0);
      bytes -= removed.byteLength;
      omitted += 1;
    }
    entry.snapshot = entry.snapshot.copyWith(
      events: List.unmodifiable(events),
      retainedByteCount: bytes,
      omittedEventCount: omitted,
    );
  }

  /// 记录错误事件并将调用置为 error 状态。
  void _fail(_CallEntry entry, int generation, String error) {
    if (!_isCurrent(entry, generation)) return;
    final redacted = _redact(error, entry);
    _append(
      entry,
      GrpcCallEvent(
        kind: GrpcTransportEventKind.error,
        timestamp: DateTime.now(),
        byteLength: utf8.encode(redacted).length,
        statusMessage: redacted,
      ),
    );
    entry.snapshot = entry.snapshot.copyWith(
      state: GrpcCallState.error,
      errorMessage: redacted,
    );
    _changed();
  }

  /// 调用流自然结束时若仍处于 running，则标记为 completed。
  void _completeIfRunning(_CallEntry entry, int generation) {
    if (!_isCurrent(entry, generation) ||
        entry.snapshot.state != GrpcCallState.running) {
      return;
    }
    entry.snapshot = entry.snapshot.copyWith(state: GrpcCallState.completed);
    _changed();
  }

  /// 用固定占位符替换值中出现的所有敏感串。
  String _redact(String value, _CallEntry entry) {
    var result = value;
    for (final secret in entry.redactedValues) {
      if (secret.isNotEmpty) result = result.replaceAll(secret, '********');
    }
    return result;
  }

  /// 触发外部变化通知（若已注册）。
  void _changed() => onChanged?.call();
}

/// 单个请求的内部调用状态，含存活对象与代次信息。
class _CallEntry {
  _CallEntry(this.snapshot);

  /// 对外可见的调用快照。
  GrpcCallSnapshot snapshot;

  /// 正在运行的 transport 调用；无调用时为空。
  GrpcCall? call;

  /// 事件流订阅，取消时需释放。
  StreamSubscription<GrpcTransportEvent>? subscription;

  /// 该调用需脱敏的敏感值集合。
  List<String> redactedValues = const [];

  /// 调用代次；每次新发起或取消时自增，用于忽略迟到事件。
  int generation = 0;
}
