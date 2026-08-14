import 'package:sendreq/l10n/generated/app_localizations.dart';

/// 对 ViewModel 的反馈做本地化，同时保持与展示无关的状态。
///
/// 全局通知只应传入应用自有安全文案；无法识别的内容仅供局部状态展示。
extension WorkspaceMessageLocalizations on String? {
  /// 将运行时/仓库返回的消息映射为本地化文案，无法识别时原样返回。
  String? localized(AppLocalizations l10n) {
    final message = this;
    if (message == null) return null;

    // 识别带参数的“导入 N 个 OpenAPI 请求”消息。
    final importMatch = RegExp(
      r'^(\d+) OpenAPI requests imported into (.+)\.$',
    ).firstMatch(message);
    if (importMatch != null) {
      return l10n.openApiRequestsImported(
        int.parse(importMatch.group(1)!),
        importMatch.group(2)!,
      );
    }
    // 识别“xx created.”这类简单模式。
    final collectionMatch = RegExp(
      r'^(?!Environment created\.$|Mock Server created\.$)(.+) created\.$',
    ).firstMatch(message);
    if (collectionMatch != null) {
      return l10n.collectionCreated(collectionMatch.group(1)!);
    }
    // 识别缺少环境变量的提示，变量列表按当前语言重新拼接分隔符。
    final missingVariablesMatch = RegExp(
      r'^Missing environment variables: (.+)$',
    ).firstMatch(message);
    if (missingVariablesMatch != null) {
      final names = missingVariablesMatch.group(1)!.split(RegExp(r'[、,]\s*'));
      final separator = l10n.localeName.startsWith('zh') ? '、' : ', ';
      return l10n.missingEnvironmentVariables(names.join(separator));
    }
    // 识别带插值的本地化消息。
    final couldNotSend = RegExp(
      r'^Could not send message: (.+)$',
    ).allMatches(message);
    if (couldNotSend.isNotEmpty) {
      return l10n.couldNotSendMessage(couldNotSend.first.group(1)!);
    }
    final couldNotImport = RegExp(
      r'^Could not import proto source: (.+)$',
    ).allMatches(message);
    if (couldNotImport.isNotEmpty) {
      return l10n.couldNotImportProto(couldNotImport.first.group(1)!);
    }
    final couldNotImportDescriptor = RegExp(
      r'^Could not import descriptor set: (.+)$',
    ).allMatches(message);
    if (couldNotImportDescriptor.isNotEmpty) {
      return l10n.couldNotImportDescriptorSet(
        couldNotImportDescriptor.first.group(1)!,
      );
    }
    final oneofOnlyOne = RegExp(
      r'^Only one field may be set for oneof (.+)\.$',
    ).allMatches(message);
    if (oneofOnlyOne.isNotEmpty) {
      return l10n.oneofOnlyOneField(oneofOnlyOne.first.group(1)!);
    }
    final invalidEnum = RegExp(
      r'^Invalid enum value for (.+)\.$',
    ).allMatches(message);
    if (invalidEnum.isNotEmpty) {
      return l10n.invalidEnumValueForField(invalidEnum.first.group(1)!);
    }
    final unexpectedWire = RegExp(
      r'^Unexpected wire type for (.+)\.$',
    ).allMatches(message);
    if (unexpectedWire.isNotEmpty) {
      return l10n.unexpectedWireTypeForField(unexpectedWire.first.group(1)!);
    }
    final unsupportedField = RegExp(
      r'^Unsupported Protobuf field type for (.+)\.$',
    ).allMatches(message);
    if (unsupportedField.isNotEmpty) {
      return l10n.unsupportedProtobufFieldType(
        unsupportedField.first.group(1)!,
      );
    }
    final unknownMessageType = RegExp(
      r'^Unknown Protobuf message type: (.+)$',
    ).allMatches(message);
    if (unknownMessageType.isNotEmpty) {
      return l10n.unknownProtobufMessageType(
        unknownMessageType.first.group(1)!,
      );
    }
    final unknownField = RegExp(r'^Unknown field: (.+)$').allMatches(message);
    if (unknownField.isNotEmpty) {
      return l10n.unknownProtobufField(unknownField.first.group(1)!);
    }
    final grpcEnvironmentBearerFailure = RegExp(
      r'^Bearer authentication failed\. This call uses the Environment Bearer token from (.+)\. Switch to the intended environment or update its Bearer token, then restart the call\.$',
    ).firstMatch(message);
    if (grpcEnvironmentBearerFailure != null) {
      return l10n.grpcEnvironmentBearerAuthenticationFailed(
        grpcEnvironmentBearerFailure.group(1)!,
      );
    }

    // 其余固定文案按表映射为本地化文本。
    return switch (message) {
      'Paste valid OpenAPI JSON.' => l10n.validOpenApiJsonRequired,
      'Could not save preferences. Retry.' => l10n.preferencesSaveFailed,
      'Environment created.' => l10n.environmentCreated,
      'Environment renamed.' => l10n.environmentRenamed,
      'Environment deleted.' => l10n.environmentDeleted,
      'Environment changes saved.' => l10n.environmentChangesSaved,
      'Environment changes discarded.' => l10n.environmentChangesDiscarded,
      'Could not save environment changes. Retry.' =>
        l10n.environmentSaveFailed,
      'Collection deleted.' => l10n.collectionDeleted,
      'Folder deleted.' => l10n.folderDeleted,
      'Request deleted.' => l10n.requestDeleted,
      'Request renamed.' => l10n.requestRenamed,
      'Collection renamed.' => l10n.collectionRenamed,
      'Folder renamed.' => l10n.folderRenamed,
      'Request changes saved.' => l10n.requestChangesSaved,
      'Demo example loaded.' => l10n.demoExampleLoaded,
      'WebSocket URL must use ws:// or wss://.' => l10n.webSocketUrlRequired,
      'WebSocket connection timed out.' => l10n.webSocketConnectionTimedOut,
      'The original request was deleted.' => l10n.originalRequestDeletedNotice,
      'Mock Server saved.' => l10n.mockServerSaved,
      'Mock Server created.' => l10n.mockServerCreated,
      'Could not create Mock Server. Retry.' => l10n.mockServerCreateFailed,
      'Could not load saved Mock Servers.' => l10n.mockServersLoadFailed,
      'Could not import proto source. Review the file and try again.' =>
        l10n.protoSourceImportFailed,
      'Could not import descriptor set. Review the file and try again.' =>
        l10n.descriptorSetImportFailed,
      'Server reflection failed. Review the endpoint and try again.' =>
        l10n.grpcReflectionFailed,
      'Could not save Mock Server. Retry.' => l10n.mockServerSaveFailed,
      'Mock Server started.' => l10n.mockServerStartedSaved,
      'Could not start Mock Server. Retry.' => l10n.mockServerStartSavedFailed,
      'Mock Server stopped.' => l10n.mockServerStoppedSaved,
      'Could not stop Mock Server. Retry.' => l10n.mockServerStopSavedFailed,
      'Mock Server archived.' => l10n.mockServerArchived,
      'Could not archive Mock Server. Retry.' => l10n.mockServerArchiveFailed,
      'Mock Server deleted.' => l10n.mockServerDeleted,
      'Could not delete Mock Server. Retry.' => l10n.mockServerDeleteFailed,
      'Could not clear notifications. Retry.' => l10n.notificationsClearFailed,
      'The source request is no longer available.' =>
        l10n.sourceRequestUnavailable,
      'The source response snapshot is no longer available.' =>
        l10n.sourceResponseUnavailable,
      'Send is available when an active request is open.' =>
        l10n.sendActiveRequestRequired,
      'Connect before sending a message.' => l10n.connectBeforeSending,
      'The active request is already sending.' => l10n.requestAlreadySending,
      'Enter a request URL before sending.' =>
        l10n.enterRequestUrlBeforeSending,
      'Select a Protobuf schema and message type before sending.' =>
        l10n.selectProtobufSchemaBeforeSending,
      'Import a valid Protobuf descriptor set before sending.' =>
        l10n.importProtobufDescriptorBeforeSending,
      'Enter a JSON message before formatting.' =>
        l10n.enterJsonMessageBeforeFormatting,
      'The message is not valid JSON.' => l10n.messageNotValidJson,
      'Binary messages must use valid Base64.' =>
        l10n.binaryMessagesRequireBase64,
      'Enter a JSON request body before formatting.' =>
        l10n.enterJsonRequestBodyBeforeFormatting,
      'The request body is not valid JSON.' => l10n.requestBodyNotValidJson,
      'Connection closed.' => l10n.connectionClosed,
      'Connection failed.' => l10n.connectionFailed,
      'Authentication failed. Update the active environment token and reconnect.' =>
        l10n.webSocketAuthenticationFailed,
      'Authentication failed. Update the active environment token and restart the call.' =>
        l10n.grpcAuthenticationFailed,
      'Bearer authentication failed. This call uses the request Bearer token. Update the request token, then restart the call.' =>
        l10n.grpcRequestBearerAuthenticationFailed,
      'API key authentication failed. Update the request API key name and value, then restart the call.' =>
        l10n.grpcApiKeyAuthenticationFailed,
      'Basic authentication failed. Update the request username and password, then restart the call.' =>
        l10n.grpcBasicAuthenticationFailed,
      'Authentication is required by this gRPC method. Configure the expected request or environment authentication, then restart the call.' =>
        l10n.grpcAuthenticationRequired,
      'Paste an OpenAPI 3.x JSON document with a paths object.' =>
        l10n.pasteOpenApi3JsonRequired,
      'No supported HTTP operations found.' => l10n.noSupportedHttpOperations,
      'Unsupported WebSocket frame.' => l10n.unsupportedWebSocketFrame,
      'Protobuf JSON message must be an object.' =>
        l10n.protobufJsonMustBeObject,
      'Unexpected end of Protobuf data.' => l10n.unexpectedEndOfProtobufData,
      'Invalid Protobuf length.' => l10n.invalidProtobufLength,
      'Unsupported Protobuf wire type.' => l10n.unsupportedProtobufWireType,
      'Request timed out after 20 seconds.' => l10n.requestTimedOut,
      'Request cancelled.' => l10n.requestCancelled,
      // 未匹配的文案保持原样返回。
      _ => message,
    };
  }
}
