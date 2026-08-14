import 'dart:async';

import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/ui/features/requests/output/models/response_viewer_models.dart';
import 'package:sendreq/ui/shell/application/user_notice.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 当前响应、HTTP Mock 与通知的协调操作。
extension WorkspaceExecutionOperations on WorkspaceViewModel {
  void publishUserMessage(UserMessage message) {
    internals.noticeController.recordSessionMessage(message);
    notifyWorkspace();
  }

  void selectResponseTab(ResponseTab tab) {
    if (internals.activeResponseTab == tab) return;
    internals.activeResponseTab = tab;
    notifyWorkspace();
  }

  void createManualMockServer() {
    const body = '{\n  "message": "Mock response"\n}';
    unawaited(
      _createMockServer(
        SanitizedMockSourceSnapshot(
          requestRef: const RequestRef(id: 'manual-mock-server'),
          requestSummary: 'GET /',
          response: SanitizedResponseSnapshot(
            responseSnapshotId: 'manual-mock-server',
            executionId: 'manual-mock-server',
            statusCode: 200,
            summary: '200 OK',
            headers: {'Content-Type': 'application/json'},
            bodyPreview: body,
          ),
        ),
      ),
    );
  }

  /// 只从活动 HTTP Request 的当前安全结果创建 Mock。
  void createMockServerFromResponse() {
    final source = internals.currentExecutionResult;
    final response = source?.responseSnapshot;
    final request = source?.requestSnapshot;
    if (source == null ||
        response == null ||
        request == null ||
        source.requestRef.id != internals.activeRequestId ||
        isActiveGrpc ||
        isActiveWebSocket) {
      internals.lastActionMessage =
          'Send this HTTP request before creating a Mock Server.';
      notifyWorkspace();
      return;
    }
    unawaited(
      _createMockServer(
        SanitizedMockSourceSnapshot(
          requestRef: source.requestRef,
          requestSummary: '${request.method} ${request.resolvedUrl}',
          response: response,
        ),
      ),
    );
  }

  Future<void> _createMockServer(SanitizedMockSourceSnapshot snapshot) async {
    final outcome = await internals.contractPublishing
        .createMockServerFromSnapshot(snapshot);
    final message = outcome.kind == OperationOutcomeKind.success
        ? 'Mock Server created.'
        : 'Could not create Mock Server. Retry.';
    await internals.feedbackDispatcher.dispatchOutcome(
      outcome,
      message: message,
    );
    if (outcome.kind == OperationOutcomeKind.success) {
      internals.activeMockServerId = outcome.resourceRef?.id;
      internals.activeSection = WorkspaceSection.mock;
    } else {
      internals.lastActionMessage = message;
    }
    notifyWorkspace();
  }

  Future<void> loadSavedMockServersInternal() async {
    final outcome = await internals.contractPublishing.loadMockServers();
    if (outcome.kind != OperationOutcomeKind.success) {
      await internals.feedbackDispatcher.dispatchOutcome(
        outcome,
        message: 'Could not load saved Mock Servers.',
      );
    }
    if (!internals.isDisposed && outcome.kind != OperationOutcomeKind.success) {
      internals.lastActionMessage = 'Could not load saved Mock Servers.';
    } else if (!internals.isDisposed) {
      internals.activeMockServerId = savedMockServers.firstOrNull?.server.id;
    }
    if (!internals.isDisposed) notifyWorkspace();
  }

  Future<void> restoreUnreadNoticesInternal() async {
    await internals.noticeController.restoreUnread();
    if (!internals.isDisposed) notifyWorkspace();
  }

  Future<void> acknowledgeNotice(String deduplicationKey) async {
    await internals.noticeController.acknowledge(deduplicationKey);
    if (!internals.isDisposed) notifyWorkspace();
  }

  Future<bool> clearNotices() async {
    final cleared = await internals.noticeController.clearAll();
    if (!cleared) {
      internals.noticeController.recordSessionMessage(
        UserMessage(
          message: 'Could not clear notifications. Retry.',
          severity: UserMessageSeverity.error,
          deduplicationKey: 'notifications.clear.failed',
        ),
      );
    }
    if (!internals.isDisposed) notifyWorkspace();
    return cleared;
  }

  Future<void> recoverNotice(UserNotice notice) async {
    final recovery = notice.recovery;
    final ref = recovery?.resourceRef;
    if (recovery == null || ref == null) {
      internals.lastActionMessage =
          'This recovery action is no longer available.';
      notifyWorkspace();
      return;
    }
    switch (recovery.id) {
      case RecoveryCommandId.retryMockServerStart:
        await startSavedMockServer(ref);
      case RecoveryCommandId.retryMockServerStop:
        await stopSavedMockServer(ref);
      case RecoveryCommandId.retryMockServerSave:
      case RecoveryCommandId.retry:
      case RecoveryCommandId.retryExecution:
      case RecoveryCommandId.openResource:
      case RecoveryCommandId.openEnvironment:
      case RecoveryCommandId.copySafeError:
      case RecoveryCommandId.dismiss:
        internals.lastActionMessage =
            'This recovery action is no longer available.';
        notifyWorkspace();
    }
  }

  Future<void> startSavedMockServer(ResourceRef ref) async {
    final outcome = await internals.contractPublishing.startMockServer(ref);
    internals.lastActionMessage = outcome.kind == OperationOutcomeKind.success
        ? 'Mock Server started.'
        : 'Could not start Mock Server. Retry.';
    await internals.feedbackDispatcher.dispatchOutcome(
      outcome,
      message: internals.lastActionMessage,
    );
    notifyWorkspace();
  }

  Future<void> stopSavedMockServer(ResourceRef ref) async {
    final outcome = await internals.contractPublishing.stopMockServer(ref);
    internals.lastActionMessage = outcome.kind == OperationOutcomeKind.success
        ? 'Mock Server stopped.'
        : 'Could not stop Mock Server. Retry.';
    await internals.feedbackDispatcher.dispatchOutcome(
      outcome,
      message: internals.lastActionMessage,
    );
    notifyWorkspace();
  }

  Future<void> saveSavedMockServer(MockServer server) async {
    final outcome = await internals.contractPublishing.saveMockServer(server);
    internals.lastActionMessage = outcome.kind == OperationOutcomeKind.success
        ? 'Mock Server saved.'
        : 'Could not save Mock Server. Retry.';
    await internals.feedbackDispatcher.dispatchOutcome(
      outcome,
      message: internals.lastActionMessage,
    );
    notifyWorkspace();
  }

  Future<void> archiveSavedMockServer(ResourceRef ref) async {
    final outcome = await internals.contractPublishing.archiveMockServer(ref);
    internals.lastActionMessage = outcome.kind == OperationOutcomeKind.success
        ? 'Mock Server archived.'
        : 'Could not archive Mock Server. Retry.';
    await internals.feedbackDispatcher.dispatchOutcome(
      outcome,
      message: internals.lastActionMessage,
    );
    notifyWorkspace();
  }

  Future<void> deleteSavedMockServer(ResourceRef ref) async {
    final previous = savedMockServers;
    final removedIndex = previous.indexWhere(
      (item) => item.server.id == ref.id,
    );
    final outcome = await internals.contractPublishing.deleteMockServer(ref);
    internals.lastActionMessage = outcome.kind == OperationOutcomeKind.success
        ? 'Mock Server deleted.'
        : 'Could not delete Mock Server. Retry.';
    await internals.feedbackDispatcher.dispatchOutcome(
      outcome,
      message: internals.lastActionMessage,
    );
    if (outcome.kind == OperationOutcomeKind.success &&
        internals.activeMockServerId == ref.id) {
      final remaining = savedMockServers;
      internals.activeMockServerId = remaining.isEmpty
          ? null
          : remaining[removedIndex.clamp(0, remaining.length - 1)].server.id;
    }
    notifyWorkspace();
  }

  String? mockSourceUnavailableReason(MockSourceReference source) {
    switch (source.kind) {
      case MockSourceKind.request:
        return requestExists(source.resourceRef.id)
            ? null
            : 'The source request is no longer available.';
      case MockSourceKind.responseSnapshot:
        return internals
                    .currentExecutionResult
                    ?.responseSnapshot
                    ?.responseSnapshotId ==
                source.resourceRef.id
            ? null
            : 'The source response is no longer in the current Request.';
    }
  }

  void openMockSource(MockSourceReference source) {
    final unavailableReason = mockSourceUnavailableReason(source);
    if (unavailableReason != null) {
      internals.lastActionMessage = unavailableReason;
      notifyWorkspace();
      return;
    }
    final requestId = source.kind == MockSourceKind.request
        ? source.resourceRef.id
        : internals.currentExecutionResult?.requestRef.id;
    if (requestId != null) selectRequest(requestId);
  }
}
