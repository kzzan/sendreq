import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/grpc/grpc_call_models.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';

export 'package:sendreq/domain/grpc/grpc_call_models.dart';

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

  /// 当前注册表管理的全部调用快照，供工作台汇总活跃会话。
  Iterable<GrpcCallSnapshot> get calls =>
      _entries.values.map((entry) => entry.snapshot);

  /// 发起调用。新的调用会先取消同一请求此前仍在运行的调用。
  Future<void> start({
    required String requestId,
    required GrpcCallConfiguration configuration,
  }) async {
    await cancel(requestId);
    final entry = _entryFor(requestId);
    entry.generation += 1;
    final generation = entry.generation;
    entry.redactionPolicy = configuration.redactionPolicy;
    entry.redactedValues = configuration.redactedValues;
    entry.snapshot = GrpcCallSnapshot(
      requestId: requestId,
      state: GrpcCallState.connecting,
      events: const [],
      omittedEventCount: 0,
      retainedByteCount: 0,
      endpoint: configuration.redactedEndpoint,
      rpcShape: configuration.rpcShape,
      requestStreamOpen: configuration.clientStreaming,
      sessionContext: configuration.effectiveSessionContext,
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
      if (!configuration.clientStreaming) {
        _append(
          entry,
          _snapshotEvent(
            GrpcTransportEvent.request(configuration.requestBytes),
            entry,
          ),
        );
      }
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
      entry.snapshot = entry.snapshot.copyWith(
        state: GrpcCallState.cancelled,
        requestStreamOpen: false,
      );
    } on Object catch (error) {
      entry.snapshot = entry.snapshot.copyWith(
        state: GrpcCallState.error,
        errorMessage: _redact('$error', entry),
        requestStreamOpen: false,
      );
    } finally {
      entry.call = null;
      _changed();
    }
  }

  /// 取消并移除某一请求的临时调用状态。
  Future<void> disposeRequest(String requestId) async {
    final entry = _entries[requestId];
    if (entry == null) return;
    await cancel(requestId);
    // 终态调用的 cancel 会保持状态不变，但销毁请求仍必须释放订阅与 transport。
    entry.generation += 1;
    await entry.subscription?.cancel();
    entry.subscription = null;
    try {
      await entry.call?.cancel();
    } on Object {
      // 销毁边界不再向已移除的请求投影终态错误。
    }
    entry.call = null;
    _entries.remove(requestId);
    _changed();
  }

  /// 向仍处于打开状态的客户端流写入一条消息，并将其加入本地时间线。
  Future<void> send({
    required String requestId,
    required Uint8List message,
  }) async {
    final entry = _entries[requestId];
    final call = entry?.call;
    if (entry == null ||
        call == null ||
        entry.snapshot.state != GrpcCallState.running ||
        !entry.snapshot.requestStreamOpen) {
      throw StateError('The gRPC request stream is not open.');
    }
    try {
      await call.send(message);
      _append(
        entry,
        _snapshotEvent(GrpcTransportEvent.request(message), entry),
      );
      _changed();
    } on Object catch (error) {
      _fail(entry, entry.generation, '$error');
    }
  }

  /// 结束客户端流的发送方向，保留服务端响应流直到服务端完成。
  Future<void> closeRequestStream(String requestId) async {
    final entry = _entries[requestId];
    final call = entry?.call;
    if (entry == null || call == null || !entry.snapshot.requestStreamOpen) {
      return;
    }
    try {
      await call.closeRequestStream();
      entry.snapshot = entry.snapshot.copyWith(requestStreamOpen: false);
      _changed();
    } on Object catch (error) {
      _fail(entry, entry.generation, '$error');
    }
  }

  /// 标记仍在运行的指定调用（或全部调用）需要用户以新配置重新启动。
  void markConfigurationChanged([String? requestId]) {
    for (final item in _entries.entries) {
      if (requestId != null && item.key != requestId) continue;
      final state = item.value.snapshot.state;
      if (state == GrpcCallState.connecting ||
          state == GrpcCallState.running ||
          state == GrpcCallState.cancelling) {
        item.value.snapshot = item.value.snapshot.copyWith(
          requiresRestart: true,
        );
      }
    }
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
          requestStreamOpen: false,
        );
      case GrpcTransportEventKind.error:
        entry.snapshot = entry.snapshot.copyWith(
          state: GrpcCallState.error,
          errorMessage: event.statusMessage,
          requestStreamOpen: false,
        );
      case GrpcTransportEventKind.request:
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
    final statusMessage = event.statusCode == 16
        ? _authenticationFailureMessage(entry)
        : event.statusMessage == null
        ? null
        : _actionableAuthenticationFailure(
            _redact(event.statusMessage!, entry),
            entry,
          );
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
    final redacted = _actionableAuthenticationFailure(
      _redact(error, entry),
      entry,
    );
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
      requestStreamOpen: false,
    );
    _changed();
  }

  /// 调用流自然结束时若仍处于 running，则标记为 completed。
  void _completeIfRunning(_CallEntry entry, int generation) {
    if (!_isCurrent(entry, generation) ||
        entry.snapshot.state != GrpcCallState.running) {
      return;
    }
    entry.snapshot = entry.snapshot.copyWith(
      state: GrpcCallState.completed,
      requestStreamOpen: false,
    );
    _changed();
  }

  /// 用固定占位符替换值中出现的所有敏感串。
  String _redact(String value, _CallEntry entry) {
    final policy = entry.redactionPolicy;
    if (policy != null) {
      return policy.redact(value).replaceAll('[redacted]', '********');
    }
    var result = value;
    for (final secret in entry.redactedValues) {
      if (secret.isNotEmpty) result = result.replaceAll(secret, '********');
    }
    return result;
  }

  String _actionableAuthenticationFailure(String value, _CallEntry entry) {
    final normalized = value.toLowerCase();
    if (normalized.contains('unauthenticated') ||
        normalized.contains('unauthorized') ||
        normalized.contains('authorization')) {
      return _authenticationFailureMessage(entry);
    }
    return value;
  }

  String _authenticationFailureMessage(_CallEntry entry) {
    final context = entry.snapshot.sessionContext;
    switch (context.authenticationType) {
      case RequestAuthenticationType.bearer:
        if (context.authenticationSource ==
            RequestAuthenticationSource.environment) {
          return 'Bearer authentication failed. This call uses the Environment Bearer token from ${context.environmentName}. Switch to the intended environment or update its Bearer token, then restart the call.';
        }
        return 'Bearer authentication failed. This call uses the request Bearer token. Update the request token, then restart the call.';
      case RequestAuthenticationType.basic:
        return 'Basic authentication failed. Update the request username and password, then restart the call.';
      case RequestAuthenticationType.apiKey:
        return 'API key authentication failed. Update the request API key name and value, then restart the call.';
      case RequestAuthenticationType.none:
        return 'Authentication is required by this gRPC method. Configure the expected request or environment authentication, then restart the call.';
    }
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

  /// 由 Environment 持有的策略，用于所有后续会话投影。
  RedactionPolicy? redactionPolicy;

  /// 为现有调用方与测试提供的遗留兼容输入。
  List<String> redactedValues = const [];

  /// 调用代次；每次新发起或取消时自增，用于忽略迟到事件。
  int generation = 0;
}
