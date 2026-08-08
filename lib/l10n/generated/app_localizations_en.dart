// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get settingsSubtitle => 'Local workspace preferences';

  @override
  String get savePreferences => 'Save preferences';

  @override
  String get saved => 'Saved';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceDescription =>
      'Choose how sendreq matches your desktop.';

  @override
  String get font => 'Font';

  @override
  String get fontDescription =>
      'Apply a readable interface font. Code and data stay monospaced.';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get system => 'System';

  @override
  String get language => 'Language';

  @override
  String get languageDescription =>
      'Choose the language used throughout sendreq.';

  @override
  String get english => 'English';

  @override
  String get simplifiedChinese => 'Simplified Chinese';

  @override
  String get keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get sendRequest => 'Send request';

  @override
  String get sendShortcutDescription =>
      'Choose the shortcut used by the global Send action.';

  @override
  String get shortcutConflictWarning =>
      'Ctrl+Space can conflict with input methods or editor completion.';

  @override
  String get customShortcut => 'Custom shortcut';

  @override
  String get noCustomShortcut => 'Not configured';

  @override
  String get recordShortcut => 'Record shortcut';

  @override
  String get recordShortcutHint => 'Press a key combination. Esc cancels.';

  @override
  String get shortcutModifierRequired =>
      'Use Ctrl, Cmd, Alt, or Shift with another key.';

  @override
  String get shortcutReserved => 'Ctrl/Cmd+K and Ctrl/Cmd+S are reserved.';

  @override
  String get shortcutUnavailable => 'This shortcut cannot be used.';

  @override
  String shortcutUpdated(String shortcut) {
    return 'Send shortcut set to $shortcut.';
  }

  @override
  String get resetPreferencesDescription =>
      'Reset only restores preferences. Requests, environments, and history remain unchanged.';

  @override
  String get resetDefaults => 'Reset defaults';

  @override
  String get preferencesSaved => 'Preferences saved';

  @override
  String get preferencesSaveFailed => 'Could not save preferences. Retry.';

  @override
  String get documentationExport => 'Documentation export';

  @override
  String get documentationOutputDirectoryDescription =>
      'Choose where exported Markdown API references are written.';

  @override
  String get noDocumentationOutputDirectory => 'No output folder selected';

  @override
  String get chooseDocumentationOutputFolder =>
      'Choose documentation output folder';

  @override
  String get chooseOutputDirectory => 'Choose output folder';

  @override
  String get changeOutputDirectory => 'Change output folder';

  @override
  String get defaultOutputDirectory => 'Default folder';

  @override
  String get customOutputDirectory => 'Custom folder';

  @override
  String get restoreDefaultOutputDirectory => 'Use default output folder';

  @override
  String documentationOutputDirectoryUnavailable(String error) {
    return 'The output folder could not be created: $error';
  }

  @override
  String get documentationOutputDirectoryPrepareFailed =>
      'Could not create the documentation output folder. Choose another folder and try again.';

  @override
  String get clearOutputDirectory => 'Clear output folder';

  @override
  String get configureDocumentationOutputDirectory =>
      'Choose a documentation output folder in Settings before exporting.';

  @override
  String get exportMarkdown => 'Export Markdown';

  @override
  String markdownExportedTo(String path) {
    return 'Markdown documentation exported to $path.';
  }

  @override
  String markdownExportFailed(String error) {
    return 'Could not export Markdown documentation: $error';
  }

  @override
  String get environmentChangesSaved => 'Environment changes saved.';

  @override
  String get environmentChangesPending => 'Environment changes are not saved.';

  @override
  String get environmentSaveFailed =>
      'Could not save environment changes. Retry.';

  @override
  String get invalidHttpStatus => 'Enter an HTTP status from 100 to 599.';

  @override
  String entityDataIgnoredForMethod(String method) {
    return '$method does not send a body or entity headers.';
  }

  @override
  String collectionCreated(String name) {
    return '$name created.';
  }

  @override
  String folderCreated(String name) {
    return '$name created.';
  }

  @override
  String get requestRenamed => 'Request renamed.';

  @override
  String get collectionRenamed => 'Collection renamed.';

  @override
  String get folderRenamed => 'Folder renamed.';

  @override
  String get requestChangesSaved => 'Request changes saved.';

  @override
  String get protocolHttp => 'HTTP';

  @override
  String get protocolWebSocket => 'WebSocket';

  @override
  String get protocolGrpc => 'gRPC';

  @override
  String get grpcConfiguration => 'gRPC configuration';

  @override
  String get importProto => 'Import .proto';

  @override
  String get noProtoSelected => 'No .proto file selected';

  @override
  String get grpcService => 'Service';

  @override
  String get grpcMethod => 'RPC method';

  @override
  String get grpcTls => 'Use TLS';

  @override
  String get grpcMetadataHint =>
      'Enabled request headers are sent as gRPC metadata.';

  @override
  String get changeRequestProtocol => 'Change request protocol';

  @override
  String get changeHttpMethod => 'Change HTTP method';

  @override
  String get workspace => 'Workspace';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get collections => 'Collections';

  @override
  String get collectionActions => 'Collection actions';

  @override
  String get history => 'History';

  @override
  String get environments => 'Environments';

  @override
  String get mockServers => 'Quick Mock';

  @override
  String get documentation => 'Documentation';

  @override
  String get docs => 'Docs';

  @override
  String get searchMetrics => 'Search metrics...';

  @override
  String get searchRequests => 'Search requests...';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get searchHistory => 'Search history...';

  @override
  String get searchVariables => 'Search variables...';

  @override
  String get searchMocks => 'Search Quick Mock...';

  @override
  String get searchDocumentation => 'Search documentation...';

  @override
  String get searchSettings => 'Search settings...';

  @override
  String get openCommandPalette => 'Open command palette';

  @override
  String get activeEnvironment => 'Active environment';

  @override
  String get activeEnvironmentShort => 'ACTIVE ENV';

  @override
  String get variablesResolveBeforeSend => 'Variables resolve before sending.';

  @override
  String get openDocumentation => 'Open documentation';

  @override
  String get saveActiveResource => 'Save active resource';

  @override
  String get noSaveableChanges => 'No saveable changes';

  @override
  String get minimizeWindow => 'Minimize window';

  @override
  String get closeWindow => 'Close window';

  @override
  String get desktopMvp => 'desktop mvp';

  @override
  String get noRequestsYet => 'No requests yet';

  @override
  String get createRequestToStart =>
      'Create a request to start testing an API.';

  @override
  String get newRequest => 'New request';

  @override
  String get request => 'Request';

  @override
  String get response => 'Response';

  @override
  String get commandPalette => 'Command palette';

  @override
  String get searchCommands => 'Search commands';

  @override
  String get noMatchingResources => 'No matching resources';

  @override
  String get sendActiveRequest => 'Send active request';

  @override
  String get environmentVariables => 'Environment variables';

  @override
  String get environmentConfiguration => 'ENVIRONMENT CONFIGURATION';

  @override
  String environmentUsesName(String name) {
    return 'The active request resolves variables with $name';
  }

  @override
  String get returnToRequest => 'Back to request';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get noChanges => 'No changes';

  @override
  String get currentEnvironment => 'Current environment';

  @override
  String get selectCurrentEnvironment => 'Select current environment';

  @override
  String get newEnvironment => 'New environment';

  @override
  String get createEnvironment => 'Create environment';

  @override
  String get renameEnvironment => 'Rename environment';

  @override
  String get deleteEnvironment => 'Delete environment';

  @override
  String get environmentName => 'Environment name';

  @override
  String deleteEnvironmentConfirmation(String name) {
    return 'Delete $name and all of its variables?';
  }

  @override
  String get lastEnvironmentRequired =>
      'Keep at least one environment for variable resolution.';

  @override
  String get environmentNameMustBeUnique => 'Enter a unique environment name.';

  @override
  String get environmentActions => 'Environment actions';

  @override
  String get scope => 'Scope';

  @override
  String get variableName => 'Variable name';

  @override
  String get currentValue => 'Current value';

  @override
  String get type => 'Type';

  @override
  String get addVariable => 'Add variable';

  @override
  String get addParameterFromEnvironment => 'Add parameter from environment';

  @override
  String get managedByAuthentication => 'Managed by Auth';

  @override
  String get environmentAuditNote =>
      'Saving changes creates a lightweight revision record. Full audit diffs will be available in a later release.';

  @override
  String get variableValue => 'Variable value';

  @override
  String get toggleSecretVisibility => 'Show or hide secret';

  @override
  String get changeVariableType => 'Change variable type';

  @override
  String get deleteVariable => 'Delete variable';

  @override
  String get requiredTokenVariable => 'Token is required for every environment';

  @override
  String get requiredEnvironmentBaseUrl =>
      'Every environment requires a base URL';

  @override
  String get variableTypeString => 'Text';

  @override
  String get variableTypeNumber => 'Number';

  @override
  String get variableTypeBoolean => 'Boolean';

  @override
  String get variableTypeSecret => 'Secret';

  @override
  String get authenticationType => 'Authentication type';

  @override
  String get authenticationSource => 'Authentication source';

  @override
  String get inheritEnvironmentAuthentication => 'Inherit environment';

  @override
  String get requestSpecificAuthentication => 'Request-specific';

  @override
  String get configureEnvironmentAuthentication =>
      'Configure environment authentication';

  @override
  String get clearUnusedAuthenticationVariables => 'Clear unused credentials';

  @override
  String get clearUnusedAuthenticationVariablesTitle =>
      'Clear unused credentials?';

  @override
  String clearUnusedAuthenticationVariablesMessage(String variables) {
    return 'This permanently removes: $variables';
  }

  @override
  String get clearCredentials => 'Clear credentials';

  @override
  String get switchEnvironmentAuthenticationTitle =>
      'Switch authentication method?';

  @override
  String get switchEnvironmentAuthenticationMessage =>
      'The current authentication credentials will be removed from this environment.';

  @override
  String get switchAuthentication => 'Switch authentication';

  @override
  String get basicAuth => 'Basic auth';

  @override
  String get apiKey => 'API key';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get apiKeyName => 'Key';

  @override
  String get apiKeyValue => 'Value';

  @override
  String get sendIn => 'Send in';

  @override
  String get basicAuthenticationStored =>
      'Authorization is generated only when this request runs.';

  @override
  String get apiKeyAuthenticationStored =>
      'This API key is generated only when this request runs.';

  @override
  String get noMockDraft => 'No Quick Mock yet';

  @override
  String get mockDraftDescription =>
      'Available for this session only. Removed when sendreq closes.';

  @override
  String get newMock => 'New Quick Mock';

  @override
  String get createMockFromResponse => 'Use response for Quick Mock';

  @override
  String get manualMock => 'Manually configured response';

  @override
  String get openCollections => 'Open collections';

  @override
  String get mockDraft => 'Quick Mock';

  @override
  String get fromLatestResponse => 'Based on the latest response';

  @override
  String get returnToResponse => 'Back to response';

  @override
  String get responseExample => 'Response example';

  @override
  String get mockResponse => 'Quick Mock response';

  @override
  String get mockLoopbackNote =>
      'Matches method and path. Query parameters are ignored.';

  @override
  String get localRuntime => 'Local runtime';

  @override
  String get running => 'Running';

  @override
  String get stopped => 'Stopped';

  @override
  String get stopServer => 'Stop Quick Mock';

  @override
  String get startServer => 'Start Quick Mock';

  @override
  String get copyMockAddress => 'Copy Quick Mock address';

  @override
  String get mockAddressCopied => 'Quick Mock address copied.';

  @override
  String get noDocumentationDraft => 'No documentation draft yet';

  @override
  String get documentationDraftDescription =>
      'Send a request, then generate API documentation from its response.';

  @override
  String get documentationDraft => 'Documentation draft';

  @override
  String get fromResponseSnapshot => 'Generated from a response snapshot';

  @override
  String get tryIt => 'Try it';

  @override
  String get copyApiReference => 'Copy API reference';

  @override
  String get apiReferenceCopied => 'API reference copied.';

  @override
  String get apiReference => 'API reference';

  @override
  String get curlCopied => 'cURL copied.';

  @override
  String get curl => 'cURL';

  @override
  String get responseExampleCopied => 'Response example copied.';

  @override
  String copyNamedValue(String name) {
    return 'Copy $name';
  }

  @override
  String get responseTitle => 'Response';

  @override
  String executionSnapshot(String environment) {
    return 'Execution snapshot · $environment';
  }

  @override
  String get unknownEnvironment => 'Unknown environment';

  @override
  String get awaitingCurrentRequest => 'Waiting to send the current request';

  @override
  String get executionResult => 'Execution result for this request';

  @override
  String get pending => 'Pending';

  @override
  String get originalRequestDeleted =>
      'The original request was deleted and cannot be reopened.';

  @override
  String get body => 'Body';

  @override
  String get responseHeaders => 'Response headers';

  @override
  String get requestSnapshot => 'Request snapshot';

  @override
  String get duration => 'Time';

  @override
  String get size => 'Size';

  @override
  String get copyResponseBody => 'Copy response body';

  @override
  String get downloadResponseBody => 'Download response body';

  @override
  String get generateDocumentation => 'Generate documentation';

  @override
  String get createMock => 'Use response for Quick Mock';

  @override
  String get replaceQuickMockTitle => 'Replace Quick Mock?';

  @override
  String get replaceQuickMockMessage =>
      'The current response configuration will be replaced.';

  @override
  String get replaceQuickMock => 'Replace';

  @override
  String get responseBodyCopied => 'Response body copied.';

  @override
  String responseSavedAt(String path) {
    return 'Response saved to $path';
  }

  @override
  String responseSaveFailed(String message) {
    return 'Could not save response: $message';
  }

  @override
  String get responseBody => 'Response body';

  @override
  String get validJson => 'Valid JSON';

  @override
  String get plainText => 'Plain text';

  @override
  String get formattedView => 'Formatted';

  @override
  String get rawView => 'Raw';

  @override
  String responseLineCount(int count) {
    return '$count lines';
  }

  @override
  String get copyDisplayedResponse => 'Copy displayed response';

  @override
  String get displayedResponseCopied => 'Displayed response copied.';

  @override
  String get noResponseYet => 'No response yet';

  @override
  String get noResponseBody => 'This execution has no response body';

  @override
  String get responseAwaitingDescription =>
      'Send the current request to view its status, duration, and response content here.';

  @override
  String get requestAtExecution => 'Request at execution';

  @override
  String environmentValue(String name) {
    return 'Environment  $name';
  }

  @override
  String get requestHeaders => 'Request headers';

  @override
  String get requestBody => 'Request body';

  @override
  String get empty => '(empty)';

  @override
  String sendingRequest(String name) {
    return 'Sending $name';
  }

  @override
  String usingEnvironment(String name) {
    return 'Using environment: $name';
  }

  @override
  String get cancelSend => 'Cancel send';

  @override
  String get errorDetailsCopied => 'Error details copied.';

  @override
  String get copyErrorDetails => 'Copy error details';

  @override
  String get retry => 'Retry';

  @override
  String get startupRecoveryTitle => 'Local data needs recovery';

  @override
  String get startupRecoveryDescription =>
      'sendreq kept the original files unchanged. Repair the JSON or folder access, then retry migration.';

  @override
  String get returnToRequestEditor => 'Back to request editor';

  @override
  String get unsavedRequest => 'Unsaved request';

  @override
  String saveRequestBeforeClose(String name) {
    return 'Save changes to $name before closing?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String get saveAndClose => 'Save and close';

  @override
  String get discardUnsavedChanges => 'Discard unsaved changes?';

  @override
  String discardChangesForRequest(String name) {
    return 'Changes to $name cannot be recovered.';
  }

  @override
  String get continueEditing => 'Continue editing';

  @override
  String closeRequest(String name) {
    return 'Close $name';
  }

  @override
  String get closeOtherTabs => 'Close other tabs';

  @override
  String get closeTabsToLeft => 'Close tabs to the left';

  @override
  String get closeTabsToRight => 'Close tabs to the right';

  @override
  String get send => 'Send';

  @override
  String missingEnvironmentVariables(String variables) {
    return 'Missing environment variables: $variables';
  }

  @override
  String get openEnvironment => 'Open environment';

  @override
  String get unsaved => 'Unsaved';

  @override
  String get discardUnsavedChangesTooltip => 'Discard unsaved changes';

  @override
  String get queryParameters => 'Query parameters';

  @override
  String get protocol => 'Protocol';

  @override
  String get authorization => 'Authorization';

  @override
  String newMessages(int count) {
    return '$count new';
  }

  @override
  String webSocketState(String state) {
    return 'WebSocket $state';
  }

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connect => 'Connect';

  @override
  String get connecting => 'Connecting';

  @override
  String get closing => 'Closing';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connected => 'Connected';

  @override
  String get connectionError => 'Connection error';

  @override
  String get formatJson => 'Format JSON';

  @override
  String get connectBeforeSending => 'Connect before sending a message.';

  @override
  String get selectProtobufBeforeSending =>
      'Select a Protobuf schema and message type before sending.';

  @override
  String get sendWithShortcut => 'Ctrl+Enter to send';

  @override
  String get messagePayload => 'Message payload';

  @override
  String get base64Bytes => 'Base64 encoded bytes';

  @override
  String get protobufJsonPayload =>
      'JSON for the selected Protobuf message type';

  @override
  String get executionHistory => 'Execution history';

  @override
  String get latestRequestSnapshots => 'Latest request snapshots';

  @override
  String historyExecutionCount(int count) {
    return '$count executions';
  }

  @override
  String get historyTimeline => 'Execution timeline';

  @override
  String get historyExecutionDetail => 'Execution detail';

  @override
  String get historyTotal => 'Total';

  @override
  String get historyAll => 'All';

  @override
  String get historySuccess => 'Success';

  @override
  String get historyFailed => 'Failed';

  @override
  String get historyEmpty => 'No executions yet.';

  @override
  String get historyNoSearchResults => 'No executions match this search.';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryTitle => 'Clear execution history?';

  @override
  String get clearHistoryMessage =>
      'This removes all execution records from the current session.';

  @override
  String get historyCleared => 'Execution history cleared.';

  @override
  String dashboardForEnvironment(String name) {
    return 'Last 24 hours, $name workspace';
  }

  @override
  String get quickStart => 'Quick start';

  @override
  String get quickStartDescription =>
      'Start a draft or import an existing API definition.';

  @override
  String get requestVolume => 'Request volume';

  @override
  String get environmentHealth => 'Environment health';

  @override
  String get active => 'ACTIVE';

  @override
  String get ready => 'READY';

  @override
  String get noFiles => 'No files';

  @override
  String selectedFileCount(int count) {
    return '$count selected';
  }

  @override
  String get optional => 'Optional';

  @override
  String fieldCount(int count) {
    return '$count fields';
  }

  @override
  String get multipartFieldsDescription =>
      'Add text values only when the endpoint requires them.';

  @override
  String get newCollection => 'New collection';

  @override
  String get loadDemoExample => 'Load Demo Example';

  @override
  String get importOpenApi => 'Import OpenAPI';

  @override
  String get exportOpenApi => 'Export OpenAPI';

  @override
  String get importOpenApiJson => 'Import OpenAPI JSON';

  @override
  String get selectOpenApiFile => 'Select OpenAPI JSON file';

  @override
  String openApiFileLoaded(String name) {
    return 'Loaded $name';
  }

  @override
  String get openApiFileReadFailed =>
      'Could not read the selected OpenAPI file.';

  @override
  String get import => 'Import';

  @override
  String get method => 'Method';

  @override
  String get path => 'Path';

  @override
  String get status => 'Status';

  @override
  String get when => 'When';

  @override
  String get openExecutionSnapshot => 'Open execution snapshot';

  @override
  String get legacyExecutionNoSnapshot =>
      'This legacy execution has no stored snapshot';

  @override
  String collectionCount(int count) {
    return '$count collections';
  }

  @override
  String deleteCollectionConfirmation(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests',
      one: '1 request',
      zero: 'requests',
    );
    return 'Delete $name and its $_temp0?';
  }

  @override
  String deleteFolderConfirmation(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests',
      one: '1 request',
      zero: 'requests',
    );
    return 'Delete $name and its $_temp0?';
  }

  @override
  String deleteRequestConfirmation(String name) {
    return 'Delete $name?';
  }

  @override
  String deleteWithUnsavedChanges(String description, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests have',
      one: '1 request has',
    );
    return '$description $_temp0 unsaved changes.';
  }

  @override
  String get collectionDeleted => 'Collection deleted.';

  @override
  String get folderDeleted => 'Folder deleted.';

  @override
  String get requestDeleted => 'Request deleted.';

  @override
  String get importFailed => 'Import failed.';

  @override
  String get openApiJsonExample => '{ \"openapi\": \"3.0.0\" }';

  @override
  String get validOpenApiJsonRequired => 'Paste valid OpenAPI JSON.';

  @override
  String openApiRequestsImported(int count, String name) {
    return '$count OpenAPI requests imported into $name.';
  }

  @override
  String openApiExportedTo(String path) {
    return 'OpenAPI exported to $path.';
  }

  @override
  String openApiExportFailed(String error) {
    return 'Could not export OpenAPI: $error';
  }

  @override
  String get rename => 'Rename';

  @override
  String get delete => 'Delete';

  @override
  String get newFolder => 'New folder';

  @override
  String get renameCollection => 'Rename collection';

  @override
  String get renameFolder => 'Rename folder';

  @override
  String get renameRequest => 'Rename request';

  @override
  String get deleteCollection => 'Delete collection';

  @override
  String get deleteFolder => 'Delete folder';

  @override
  String get deleteRequest => 'Delete request';

  @override
  String get name => 'Name';

  @override
  String get unsavedRequestChanges => 'Unsaved request changes';

  @override
  String get discardAndDelete => 'Discard and delete';

  @override
  String get saveAndDelete => 'Save and delete';

  @override
  String get webSocketProtocol => 'WebSocket protocol';

  @override
  String get webSocketProtocolHint =>
      'Optional subprotocols sent during the handshake.';

  @override
  String get subprotocols => 'Subprotocols';

  @override
  String get protobufDescriptor => 'Protobuf descriptor';

  @override
  String get descriptorUnavailable =>
      'Descriptor file is unavailable. Import it again to recover this request.';

  @override
  String get noDescriptorSelected => 'No descriptor set selected';

  @override
  String get messageType => 'Message type';

  @override
  String get addField => 'Add field';

  @override
  String get addRow => 'Add row';

  @override
  String get key => 'Key';

  @override
  String get value => 'Value';

  @override
  String get removeRow => 'Remove row';

  @override
  String get changeBodyContentType => 'Change body content type';

  @override
  String get noContentType => 'No content type';

  @override
  String get requestBodyHint => '// Request body';

  @override
  String get requestTabParams => 'Params';

  @override
  String get requestTabHeaders => 'Headers';

  @override
  String get requestTabAuth => 'Auth';

  @override
  String get requestTabBody => 'Body';

  @override
  String get requestTabProtocol => 'Protocol';

  @override
  String get subprotocolsHint => 'graphql-transport-ws, events.v1';

  @override
  String sendRequestWithShortcut(String shortcut) {
    return 'Send request ($shortcut)';
  }

  @override
  String get fieldEnabled => 'Enable field';

  @override
  String get fieldDisabled => 'Disable field';

  @override
  String get fileEnabled => 'Enable file';

  @override
  String get fileDisabled => 'Disable file';

  @override
  String get removeSecretProtection => 'Remove secret protection';

  @override
  String get selectedFilesUnreadable =>
      'Some selected files could not be read.';

  @override
  String get addFormField => 'Add form field';

  @override
  String get removeFile => 'Remove file';

  @override
  String get removeFormField => 'Remove form field';

  @override
  String get batchField => 'BATCH FIELD';

  @override
  String get fieldName => 'Field name';

  @override
  String get field => 'Field';

  @override
  String get enabled => 'ON';

  @override
  String activeFieldCount(int count) {
    return '$count active';
  }

  @override
  String get disableRow => 'Disable row';

  @override
  String get enableRow => 'Enable row';

  @override
  String get hideValue => 'Hide value';

  @override
  String get revealValue => 'Reveal value';

  @override
  String get markAsSecret => 'Mark as secret';

  @override
  String get chooseFilesDescription =>
      'Select one or more files to send with this request.';

  @override
  String get authorizationAppliedAsHeader =>
      'Independent authentication settings';

  @override
  String get customAuthorizationConfigured =>
      'A custom Authorization header is configured for this request.';

  @override
  String get customAuthorizationHeader => 'Custom Authorization header';

  @override
  String get edit => 'Edit';

  @override
  String get token => 'Token';

  @override
  String get bearerTokenStored =>
      'Authorization is generated only when this request runs.';

  @override
  String get noAuthorizationHeader => 'This request uses no authentication.';

  @override
  String get webSocketUrlRequired => 'WebSocket URL must use ws:// or wss://.';

  @override
  String get originalRequestDeletedNotice =>
      'The original request was deleted.';

  @override
  String get mockServerStarted => 'Quick Mock started.';

  @override
  String get mockServerStopped => 'Quick Mock stopped.';

  @override
  String get mockServerStartFailed => 'Could not start Quick Mock. Retry.';

  @override
  String get mockServerStopFailed => 'Could not stop Quick Mock. Retry.';

  @override
  String get files => 'Files';

  @override
  String get chooseFiles => 'Choose files';

  @override
  String get formFields => 'Form fields';

  @override
  String get browse => 'Browse';

  @override
  String get apply => 'Apply';

  @override
  String get bearerToken => 'Bearer token';

  @override
  String get noAuth => 'No auth';

  @override
  String get pasteBearerToken => 'Paste a bearer token';

  @override
  String earlierMessagesOmitted(int count) {
    return '$count earlier messages omitted to protect memory.';
  }

  @override
  String get webSocketInbound => 'IN';

  @override
  String get webSocketOutbound => 'OUT';

  @override
  String get webSocketSystem => 'SYSTEM';

  @override
  String get webSocketTextFrame => 'Text';

  @override
  String get webSocketBinaryFrame => 'Binary';

  @override
  String get webSocketCloseFrame => 'Close';

  @override
  String get webSocketErrorFrame => 'Error';

  @override
  String webSocketMessageSemantics(String direction, String kind, int bytes) {
    return '$direction $kind message, $bytes bytes';
  }

  @override
  String byteCount(int count) {
    return '$count B';
  }

  @override
  String get webSocketConnectionTimedOut => 'WebSocket connection timed out.';

  @override
  String get webSocketMessageFormat => 'Choose message format';

  @override
  String get webSocketTextFrameHeading => 'TEXT FRAME';

  @override
  String get webSocketBinaryFrameHeading => 'BINARY FRAME';

  @override
  String pasteSerializedMessageBase64(String format) {
    return 'Paste Base64 for serialized $format bytes.';
  }

  @override
  String get grpcResponseTitle => 'gRPC response';

  @override
  String get cancelGrpcCall => 'Cancel gRPC call';

  @override
  String earlierGrpcEventsOmitted(int count) {
    return '$count earlier events omitted';
  }

  @override
  String get awaitingGrpcResponse => 'Awaiting gRPC response';

  @override
  String get sendActiveRequestRequired =>
      'Send is available when an active request is open.';

  @override
  String get requestAlreadySending => 'The active request is already sending.';

  @override
  String get enterRequestUrlBeforeSending =>
      'Enter a request URL before sending.';

  @override
  String get selectProtobufSchemaBeforeSending =>
      'Select a Protobuf schema and message type before sending.';

  @override
  String get importProtobufDescriptorBeforeSending =>
      'Import a valid Protobuf descriptor set before sending.';

  @override
  String get enterJsonMessageBeforeFormatting =>
      'Enter a JSON message before formatting.';

  @override
  String get messageNotValidJson => 'The message is not valid JSON.';

  @override
  String get binaryMessagesRequireBase64 =>
      'Binary messages must use valid Base64.';

  @override
  String get enterJsonRequestBodyBeforeFormatting =>
      'Enter a JSON request body before formatting.';

  @override
  String get requestBodyNotValidJson => 'The request body is not valid JSON.';

  @override
  String encodesToBytes(int count) {
    return 'Encodes to $count bytes';
  }

  @override
  String get sendRequestBeforeMockDraft =>
      'Send a request before creating a Quick Mock.';

  @override
  String get sendRequestBeforeDocumentation =>
      'Send a request before creating documentation.';

  @override
  String get createMockDraftBeforeStartingServer =>
      'Create a Quick Mock before starting it.';

  @override
  String couldNotSendMessage(String error) {
    return 'Could not send message: $error';
  }

  @override
  String get connectionClosed => 'Connection closed.';

  @override
  String get connectionFailed => 'Connection failed.';

  @override
  String couldNotImportProto(String error) {
    return 'Could not import proto source: $error';
  }

  @override
  String couldNotImportDescriptorSet(String error) {
    return 'Could not import descriptor set: $error';
  }

  @override
  String oneofOnlyOneField(String name) {
    return 'Only one field may be set for oneof $name.';
  }

  @override
  String invalidEnumValueForField(String field) {
    return 'Invalid enum value for $field.';
  }

  @override
  String unexpectedWireTypeForField(String path) {
    return 'Unexpected wire type for $path.';
  }

  @override
  String unsupportedProtobufFieldType(String path) {
    return 'Unsupported Protobuf field type for $path.';
  }

  @override
  String get pasteOpenApi3JsonRequired =>
      'Paste an OpenAPI 3.x JSON document with a paths object.';

  @override
  String get noSupportedHttpOperations => 'No supported HTTP operations found.';

  @override
  String get unsupportedWebSocketFrame => 'Unsupported WebSocket frame.';

  @override
  String get protobufJsonMustBeObject =>
      'Protobuf JSON message must be an object.';

  @override
  String unknownProtobufMessageType(String name) {
    return 'Unknown Protobuf message type: $name';
  }

  @override
  String unknownProtobufField(String path) {
    return 'Unknown field: $path';
  }

  @override
  String get unexpectedEndOfProtobufData => 'Unexpected end of Protobuf data.';

  @override
  String get invalidProtobufLength => 'Invalid Protobuf length.';

  @override
  String get unsupportedProtobufWireType => 'Unsupported Protobuf wire type.';

  @override
  String get requestTimedOut => 'Request timed out after 20 seconds.';

  @override
  String get requestCancelled => 'Request cancelled.';
}
