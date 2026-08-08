import 'generated/app_localizations.dart';

/// Localizes ViewModel feedback while keeping presentation-independent state.
///
/// Runtime and repository errors are intentionally returned unchanged because
/// their content comes from external systems rather than the application UI.
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
    final collectionMatch = RegExp(r'^(.+) created\.$').firstMatch(message);
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

    // 其余固定文案按表映射为本地化文本。
    return switch (message) {
      'Paste valid OpenAPI JSON.' => l10n.validOpenApiJsonRequired,
      'Preferences saved.' => l10n.preferencesSaved,
      'Could not save preferences. Retry.' => l10n.preferencesSaveFailed,
      'Could not prepare documentation output folder.' =>
        l10n.documentationOutputDirectoryPrepareFailed,
      'Environment changes saved.' => l10n.environmentChangesSaved,
      'Could not save environment changes. Retry.' =>
        l10n.environmentSaveFailed,
      'Collection deleted.' => l10n.collectionDeleted,
      'Folder deleted.' => l10n.folderDeleted,
      'Request deleted.' => l10n.requestDeleted,
      'Request renamed.' => l10n.requestRenamed,
      'Collection renamed.' => l10n.collectionRenamed,
      'Folder renamed.' => l10n.folderRenamed,
      'Request changes saved.' => l10n.requestChangesSaved,
      'WebSocket URL must use ws:// or wss://.' => l10n.webSocketUrlRequired,
      'WebSocket connection timed out.' => l10n.webSocketConnectionTimedOut,
      'The original request was deleted.' => l10n.originalRequestDeletedNotice,
      'Quick Mock started.' => l10n.mockServerStarted,
      'Quick Mock stopped.' => l10n.mockServerStopped,
      'Could not start Quick Mock. Retry.' => l10n.mockServerStartFailed,
      'Could not stop Quick Mock. Retry.' => l10n.mockServerStopFailed,
      'No saveable changes in the active resource.' => l10n.noSaveableChanges,
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
      'Send a request before creating a Quick Mock.' =>
        l10n.sendRequestBeforeMockDraft,
      'Send a request before creating documentation.' =>
        l10n.sendRequestBeforeDocumentation,
      'Create a Quick Mock before starting it.' =>
        l10n.createMockDraftBeforeStartingServer,
      'Connection closed.' => l10n.connectionClosed,
      'Connection failed.' => l10n.connectionFailed,
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
