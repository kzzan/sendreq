import 'package:sendreq/domain/workspace/workspace_models.dart';

/// 请求资产的稳定引用。它刻意不携带草稿、
/// 环境或已解析的凭证数据。
class RequestRef {
  const RequestRef({required this.id, this.workspaceId});

  final String id;
  final String? workspaceId;

  @override
  bool operator ==(Object other) =>
      other is RequestRef && other.id == id && other.workspaceId == workspaceId;

  @override
  int get hashCode => Object.hash(id, workspaceId);
}

/// 标识用于导航与安全用户反馈的资源。
enum ResourceKind {
  collection,
  request,
  requestTab,
  environment,
  execution,
  responseSnapshot,
  mockServer,
  settings,
}

/// 跨模块的资源引用。该引用刻意保持不透明：
/// 调用方必须查询所属模块，而不是直接解引用存储。
class ResourceRef {
  const ResourceRef({required this.kind, required this.id});

  final ResourceKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is ResourceRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// 用户发起操作的语义化结果。
enum OperationOutcomeKind { success, failed, cancelled, partial }

/// 允许作为通知恢复动作的 Shell 命令标识符。
///
/// 这些是数据标识符，绝不会是源模块持有的回调。
enum RecoveryCommandId {
  retry,
  retryExecution,
  retryMockServerSave,
  retryMockServerStart,
  retryMockServerStop,
  openResource,
  openEnvironment,
  copySafeError,
  dismiss,
}

/// 一种安全、可由 Shell 路由的恢复动作。
class RecoveryCommand {
  RecoveryCommand({
    required this.id,
    this.resourceRef,
    Map<String, String> arguments = const {},
  }) : arguments = Map.unmodifiable(arguments);

  final RecoveryCommandId id;
  final ResourceRef? resourceRef;
  final Map<String, String> arguments;
}

/// 模块返回的结构化结果，代替 UI 消息或错误。
class OperationOutcome {
  OperationOutcome({
    required this.kind,
    required this.code,
    this.resourceRef,
    Map<String, String> arguments = const {},
    this.recovery,
    this.relatedExecutionId,
    this.isRecoverable = false,
  }) : arguments = Map.unmodifiable(arguments) {
    if ((kind == OperationOutcomeKind.failed ||
            kind == OperationOutcomeKind.partial) &&
        isRecoverable &&
        recovery == null) {
      throw ArgumentError.value(
        recovery,
        'recovery',
        'Recoverable failed and partial outcomes require a recovery command.',
      );
    }
  }

  final OperationOutcomeKind kind;
  final String code;
  final ResourceRef? resourceRef;
  final Map<String, String> arguments;
  final RecoveryCommand? recovery;
  final String? relatedExecutionId;
  final bool isRecoverable;
}

/// 短生命周期的已解析请求负载。它可能包含凭证，
/// 因此只被执行端口接受，绝不会被投影消费。
class ExecutionPayload {
  ExecutionPayload({
    required this.method,
    required this.resolvedUrl,
    required this.draft,
    Map<String, String> headers = const {},
    this.body = '',
  }) : headers = Map.unmodifiable(headers);

  final String method;
  final String resolvedUrl;
  final RequestDraft draft;
  final Map<String, String> headers;
  final String body;
}

/// 在执行结果离开执行边界前，替换 Environment 持有的秘密值。
/// 这些值刻意不对外暴露。
class RedactionPolicy {
  RedactionPolicy(Iterable<String> secretValues)
    : _secretValues = List.unmodifiable(
        secretValues.where((value) => value.isNotEmpty).toSet().toList()
          ..sort((left, right) => right.length.compareTo(left.length)),
      );

  final List<String> _secretValues;

  String redact(String value) {
    var redacted = value;
    for (final secret in _secretValues) {
      redacted = redacted.replaceAll(secret, '[redacted]');
    }
    return redacted;
  }
}

/// Environment 模块发给 Execution 模块的一次性命令。
class ResolvedExecutionCommand {
  const ResolvedExecutionCommand({
    required this.executionId,
    required this.requestRef,
    required this.payload,
    required this.sanitizedRequestSummary,
    required this.redactionPolicy,
    this.environmentRef,
    this.environmentName,
  });

  final String executionId;
  final RequestRef requestRef;
  final ExecutionPayload payload;
  final String sanitizedRequestSummary;
  final RedactionPolicy redactionPolicy;
  final ResourceRef? environmentRef;
  final String? environmentName;
}

/// 允许离开 Execution 模块的响应投影。
class SanitizedResponseSnapshot {
  SanitizedResponseSnapshot({
    required this.responseSnapshotId,
    required this.executionId,
    required this.statusCode,
    required this.summary,
    Map<String, String> headers = const {},
    this.bodyPreview = '',
  }) : headers = Map.unmodifiable(headers);

  final String responseSnapshotId;
  final String executionId;
  final int? statusCode;
  final String summary;
  final Map<String, String> headers;
  final String bodyPreview;
}

/// 对 Shell 与当前 Request 安全的终端执行结果。
class SanitizedExecutionResult {
  const SanitizedExecutionResult({
    required this.executionId,
    required this.requestRef,
    required this.status,
    required this.summary,
    this.responseSnapshot,
    this.method = 'HTTP',
    this.displayPath = '',
    this.durationMs = 0,
    this.errorCategory,
    this.requestSnapshot,
  });

  final String executionId;
  final RequestRef requestRef;
  final OperationOutcomeKind status;
  final String summary;
  final SanitizedResponseSnapshot? responseSnapshot;
  final String method;
  final String displayPath;
  final int durationMs;
  final String? errorCategory;
  final ExecutionRequestSnapshot? requestSnapshot;
}

/// 长时间运行协议会话的受限、安全投影。
class SanitizedSessionProjection {
  const SanitizedSessionProjection({
    required this.sessionId,
    required this.requestRef,
    required this.status,
    required this.summary,
  });

  final String sessionId;
  final RequestRef requestRef;
  final String status;
  final String summary;
}

/// 交给 Contract Publishing 创建 Mock 的当前 HTTP 安全快照。
class SanitizedMockSourceSnapshot {
  const SanitizedMockSourceSnapshot({
    required this.requestRef,
    required this.requestSummary,
    required this.response,
  });

  final RequestRef requestRef;
  final String requestSummary;
  final SanitizedResponseSnapshot response;
}
