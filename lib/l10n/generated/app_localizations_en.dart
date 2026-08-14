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
  String get saved => 'Saved';

  @override
  String get preferencesSaved => 'Saved automatically';

  @override
  String get preferencesSaving => 'Saving...';

  @override
  String get preferencesSaveFailedShort => 'Save failed';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceDescription =>
      'Choose how sendreq matches your desktop.';

  @override
  String get font => 'Interface font';

  @override
  String get fontDescription =>
      'Choose the font used by navigation, labels, and controls.';

  @override
  String get codeFont => 'Code font';

  @override
  String get codeFontDescription =>
      'Choose the monospaced font used by requests, JSON, and timelines.';

  @override
  String get codeFontSize => 'Code size';

  @override
  String get codeFontSizeDescription =>
      'Set the base size for code and structured data.';

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
  String get updates => 'Updates';

  @override
  String get updateDescription =>
      'Check GitHub Releases for a newer sendreq desktop version.';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkingForUpdates => 'Checking GitHub Releases...';

  @override
  String get updateCheckNotRun => 'No update check has been run.';

  @override
  String appIsUpToDate(String version) {
    return 'Version $version is up to date.';
  }

  @override
  String appUpdateAvailable(String version) {
    return 'Version $version is available.';
  }

  @override
  String get updateCheckFailed => 'Could not check GitHub Releases. Try again.';

  @override
  String get updateNow => 'Update';

  @override
  String get english => 'English';

  @override
  String get simplifiedChinese => 'Simplified Chinese';

  @override
  String get sendRequest => 'Send request';

  @override
  String get resetPreferencesDescription =>
      'Reset only restores preferences. Requests and environments remain unchanged.';

  @override
  String get resetDefaults => 'Reset defaults';

  @override
  String get preferencesSaveFailed => 'Could not save preferences. Retry.';

  @override
  String get environmentChangesSaved => 'Environment changes saved.';

  @override
  String get environmentChangesDiscarded => 'Environment changes discarded.';

  @override
  String get environmentChangesPending => 'Environment changes are not saved.';

  @override
  String get environmentSaveFailed =>
      'Could not save environment changes. Retry.';

  @override
  String get environmentCreated => 'Environment created.';

  @override
  String get environmentRenamed => 'Environment renamed.';

  @override
  String get environmentDeleted => 'Environment deleted.';

  @override
  String get demoExampleLoaded => 'Demo example loaded.';

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
  String get folderRenamed => 'Group renamed.';

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
  String get grpcMetadata => 'Metadata';

  @override
  String get grpcMessage => 'Message';

  @override
  String get grpcProto => 'Proto';

  @override
  String get grpcDeadline => 'Deadline';

  @override
  String get grpcDeadlineHint => 'Optional call timeout';

  @override
  String get millisecondsShort => 'ms';

  @override
  String get discoverGrpcServices => 'Discover services';

  @override
  String get discoveringGrpcServices => 'Discovering...';

  @override
  String get grpcSchemaFromReflection =>
      'Services discovered from the active endpoint';

  @override
  String get grpcStartStream => 'Start stream';

  @override
  String get grpcSendMessage => 'Send message';

  @override
  String get grpcEndRequestStream => 'End sending';

  @override
  String get grpcClientStreaming => 'Client streaming';

  @override
  String get grpcServerStreaming => 'Server streaming';

  @override
  String get grpcBidirectionalStreaming => 'Bidirectional streaming';

  @override
  String get grpcUnary => 'Unary';

  @override
  String get grpcRequestMessage => 'Request message';

  @override
  String get grpcNoRequestSchema =>
      'Select a service and RPC method to view request fields.';

  @override
  String get grpcNextStreamMessage => 'Next stream message';

  @override
  String get grpcCallPayload => 'Call payload';

  @override
  String get grpcWireInvalid => 'Invalid payload';

  @override
  String get grpcMessageSchema => 'Message schema';

  @override
  String get grpcFieldRepeated => 'repeated';

  @override
  String grpcFieldOneof(String name) {
    return 'oneof: $name';
  }

  @override
  String get grpcEventSent => 'Sent';

  @override
  String get grpcEventReceived => 'Received';

  @override
  String get grpcEventHeaders => 'Headers';

  @override
  String get grpcEventTrailers => 'Trailers';

  @override
  String get grpcEventStatus => 'Status';

  @override
  String get grpcEventError => 'Error';

  @override
  String get grpcRequestStreamOpen => 'Send open';

  @override
  String get grpcRequestStreamClosed => 'Send closed';

  @override
  String get grpcStateIdle => 'Idle';

  @override
  String get grpcStateStarting => 'Starting';

  @override
  String get grpcStateRunning => 'Running';

  @override
  String get grpcStateCompleted => 'Completed';

  @override
  String get grpcStateCancelling => 'Cancelling';

  @override
  String get grpcStateCancelled => 'Cancelled';

  @override
  String get grpcStateFailed => 'Failed';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get changeRequestProtocol => 'Change request protocol';

  @override
  String get changeHttpMethod => 'Change HTTP method';

  @override
  String get workspace => 'Workspace';

  @override
  String get requests => 'Requests';

  @override
  String get allRequests => 'All requests';

  @override
  String get restRequests => 'REST';

  @override
  String get webSocketRequests => 'WebSocket';

  @override
  String get grpcRequests => 'gRPC';

  @override
  String get requestWorkingViews => 'Request types';

  @override
  String get mock => 'Mock';

  @override
  String get manage => 'Manage';

  @override
  String get collections => 'Collections';

  @override
  String get collectionResources => 'Collection resources';

  @override
  String get collectionActions => 'Collection actions';

  @override
  String get environments => 'Environments';

  @override
  String get savedMockServers => 'Saved Mock Servers';

  @override
  String get saveAsMockServer => 'Save as Mock Server';

  @override
  String get startMockServer => 'Start Server';

  @override
  String get stopMockServer => 'Stop Server';

  @override
  String mockEndpoints(int count) {
    return '$count endpoints';
  }

  @override
  String get searchRequests => 'Search requests...';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get activeEnvironment => 'Active environment';

  @override
  String get activeEnvironmentShort => 'ENV';

  @override
  String get environmentLabel => 'ENVIRONMENT';

  @override
  String get environmentLabelShort => 'ENV';

  @override
  String get manageEnvironments => 'Manage environments...';

  @override
  String get useForNextCall => 'USE FOR NEXT CALL';

  @override
  String get useForRequests => 'Use for requests';

  @override
  String editingEnvironment(String name) {
    return 'Editing: $name';
  }

  @override
  String environmentContextTooltip(String name) {
    return 'Environment: $name. Switch or manage environments.';
  }

  @override
  String currentSessionEnvironment(String name) {
    return 'Current session: $name';
  }

  @override
  String nextCallEnvironment(String name) {
    return 'Next call: $name';
  }

  @override
  String get variablesResolveBeforeSend => 'Variables resolve before sending.';

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
  String get noMatchingResources => 'No matching resources';

  @override
  String get requestProtocolFilter => 'Filter requests by protocol';

  @override
  String get allRequestProtocols => 'All request protocols';

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
  String get unsavedEnvironmentChanges => 'Unsaved environment changes';

  @override
  String get discardEnvironmentChangesTitle => 'Discard environment changes?';

  @override
  String get discardEnvironmentChangesMessage =>
      'Variables, authentication, and environment edits will return to the last saved version.';

  @override
  String get closeEnvironmentManagerTitle => 'Apply environment changes?';

  @override
  String get closeEnvironmentManagerMessage =>
      'Apply these changes before returning to Requests, or discard them to restore the last saved environment.';

  @override
  String get currentEnvironment => 'Current environment';

  @override
  String get selectCurrentEnvironment => 'Select current environment';

  @override
  String get selectEnvironmentToEdit => 'Select an environment to edit';

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
  String get environmentAuditNote => 'Changes take effect after Apply.';

  @override
  String get variableValue => 'Variable value';

  @override
  String get toggleSecretVisibility => 'Show or hide secret';

  @override
  String get changeVariableType => 'Change variable type';

  @override
  String get deleteVariable => 'Delete variable';

  @override
  String get requiredTokenVariable =>
      'Managed by Bearer authentication for this environment';

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
  String get requestSpecificAuthentication =>
      'Request only (does not inherit environment)';

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
  String get noMockDraft => 'No Mock Servers yet';

  @override
  String get mockDraftDescription => 'Create a saved local HTTP Mock Server.';

  @override
  String get newMock => 'New server';

  @override
  String get createMockFromResponse => 'Create from response';

  @override
  String get manualMock => 'Manually configured response';

  @override
  String get openCollections => 'Open collections';

  @override
  String get mockDraft => 'Mock Server';

  @override
  String get fromLatestResponse => 'Based on the latest response';

  @override
  String get returnToResponse => 'Back to response';

  @override
  String get responseExample => 'Response example';

  @override
  String get mockResponse => 'Mock response';

  @override
  String get mockLoopbackNote => 'HTTP-only. Runs on 127.0.0.1 after Start.';

  @override
  String get localRuntime => 'Local runtime';

  @override
  String get running => 'Running';

  @override
  String get stopped => 'Stopped';

  @override
  String get stopServer => 'Stop server';

  @override
  String get startServer => 'Start server';

  @override
  String get copyMockAddress => 'Copy server address';

  @override
  String get mockAddressCopied => 'Server address copied.';

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
  String get awaitingCurrentRequest => 'Waiting to send the current request';

  @override
  String get executionResult => 'Execution result for this request';

  @override
  String get pending => 'Pending';

  @override
  String get body => 'Body';

  @override
  String get responseHeaders => 'Response headers';

  @override
  String get duration => 'Time';

  @override
  String get size => 'Size';

  @override
  String get copyResponseBody => 'Copy response body';

  @override
  String get downloadResponseBody => 'Download response body';

  @override
  String get createMock => 'Create Mock Server from response';

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
  String get expandJsonNode => 'Expand JSON node';

  @override
  String get collapseJsonNode => 'Collapse JSON node';

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
  String get messagePayload => 'Message payload';

  @override
  String get base64Bytes => 'Base64 encoded bytes';

  @override
  String get protobufJsonPayload =>
      'JSON for the selected Protobuf message type';

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
  String get formUrlEncodedFields => 'URL encoded fields';

  @override
  String get formUrlEncodedFieldsDescription =>
      'Add fields to send as application/x-www-form-urlencoded.';

  @override
  String get newCollection => 'New collection';

  @override
  String get loadDemoExample => 'Load Demo Example';

  @override
  String get importOpenApi => 'Import OpenAPI';

  @override
  String get exportOpenApi => 'Export OpenAPI';

  @override
  String get exportApiDocumentation => 'Export API documentation...';

  @override
  String get selectDocumentationOutputDirectory =>
      'Select API documentation directory';

  @override
  String collectionDocumentationExported(String collectionName) {
    return 'API documentation for $collectionName exported.';
  }

  @override
  String get collectionDocumentationExportFailed =>
      'Could not export API documentation. Check the selected directory and retry.';

  @override
  String get collectionHasNoHttpRequests =>
      'This Collection has no HTTP requests to document.';

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
  String get openOriginalRequest => 'Open original request';

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
  String get folderDeleted => 'Group deleted.';

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
  String get openApiExported => 'OpenAPI exported.';

  @override
  String openApiExportFailed(String error) {
    return 'Could not export OpenAPI: $error';
  }

  @override
  String get rename => 'Rename';

  @override
  String get delete => 'Delete';

  @override
  String get newFolder => 'New group';

  @override
  String get renameCollection => 'Rename collection';

  @override
  String get renameFolder => 'Rename group';

  @override
  String get renameRequest => 'Rename request';

  @override
  String get deleteCollection => 'Delete collection';

  @override
  String get deleteFolder => 'Delete group';

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
  String get httpAuthenticationDelivery =>
      'HTTP: Authorization header on every request';

  @override
  String get webSocketAuthenticationDelivery =>
      'WebSocket: Authorization header during Upgrade';

  @override
  String get grpcAuthenticationDelivery =>
      'gRPC: authorization metadata for each call and stream';

  @override
  String get customAuthorizationConfigured =>
      'A custom Authorization header is configured for this request.';

  @override
  String get customAuthorizationHeader => 'Custom Authorization header';

  @override
  String get edit => 'Edit';

  @override
  String get preview => 'Preview';

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
  String get mockServerStarted => 'Mock Server started.';

  @override
  String get mockServerStopped => 'Mock Server stopped.';

  @override
  String get mockServerStartFailed => 'Could not start Mock Server. Retry.';

  @override
  String get mockServerStopFailed => 'Could not stop Mock Server. Retry.';

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
  String get expandWebSocketMessage => 'Expand message';

  @override
  String get collapseWebSocketMessage => 'Collapse message';

  @override
  String get openWebSocketMessageDetail => 'Open message detail';

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
      'Send an HTTP request before creating a Mock Server.';

  @override
  String couldNotSendMessage(String error) {
    return 'Could not send message: $error';
  }

  @override
  String get connectionClosed => 'Connection closed.';

  @override
  String get connectionFailed => 'Connection failed.';

  @override
  String get reconnectToApplyChanges => 'Reconnect to apply changes';

  @override
  String get restartToApplyChanges => 'Restart to apply changes';

  @override
  String get restartGrpcCall => 'Restart';

  @override
  String get webSocketAuthenticationFailed =>
      'Authentication failed. Update the active environment token and reconnect.';

  @override
  String get grpcAuthenticationFailed =>
      'Authentication failed. Update the active environment token and restart the call.';

  @override
  String grpcEnvironmentBearerAuthenticationFailed(String environmentName) {
    return 'Bearer authentication failed. This call uses the Bearer token from $environmentName. Switch to the intended environment or update its Bearer token, then restart the call.';
  }

  @override
  String get grpcRequestBearerAuthenticationFailed =>
      'Bearer authentication failed. This call uses the request Bearer token. Update the request token, then restart the call.';

  @override
  String get grpcApiKeyAuthenticationFailed =>
      'API key authentication failed. Update the request API key name and value, then restart the call.';

  @override
  String get grpcBasicAuthenticationFailed =>
      'Basic authentication failed. Update the request username and password, then restart the call.';

  @override
  String get grpcAuthenticationRequired =>
      'Authentication is required by this gRPC method. Configure the expected request or environment authentication, then restart the call.';

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

  @override
  String get notifications => 'Notifications';

  @override
  String get closeNotifications => 'Close notifications';

  @override
  String get noActionableNotifications => 'No actionable notifications';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get clearNotifications => 'Clear notifications';

  @override
  String get clearNotificationsTitle => 'Clear notifications?';

  @override
  String get clearNotificationsRecoveryMessage =>
      'This removes all notifications and their recovery actions. It does not change the underlying resources or operations.';

  @override
  String get notificationsClearFailed =>
      'Could not clear notifications. Retry.';

  @override
  String get acknowledgeNotification => 'Acknowledge notification';

  @override
  String get notificationActionFailed => 'Action failed';

  @override
  String get notificationActionPartiallyCompleted => 'Action partly completed';

  @override
  String get notificationSessionFailed => 'Session failed';

  @override
  String get notificationSessionReconnecting => 'Session reconnecting';

  @override
  String get notificationSessionDisconnected => 'Session disconnected';

  @override
  String get notificationActionCompleted => 'Action completed';

  @override
  String get notificationReviewAndAcknowledge =>
      'Review this event and acknowledge it when it is no longer needed.';

  @override
  String get notificationSafeRecoveryAvailable =>
      'A safe recovery action is available.';

  @override
  String get retryStart => 'Retry start';

  @override
  String get retryStop => 'Retry stop';

  @override
  String get retrySave => 'Retry save';

  @override
  String get retryAction => 'Retry action';

  @override
  String notificationsNeedAttention(int count) {
    return '$count notifications need attention';
  }

  @override
  String get savedMockServersTitle => 'Saved mock servers';

  @override
  String mockEndpointCount(int count) {
    return '$count endpoints';
  }

  @override
  String get serverName => 'Server name';

  @override
  String get copyServerUrl => 'Copy server URL';

  @override
  String get serverUrlCopied => 'Server URL copied.';

  @override
  String get startServerBeforeCopyingUrl =>
      'Start the server before copying its URL.';

  @override
  String get openServerSource => 'Open server source';

  @override
  String get mockServerActions => 'Mock server actions';

  @override
  String get openEndpointSource => 'Open endpoint source';

  @override
  String get openResponseSource => 'Open response source';

  @override
  String get mockSourceUnavailable => 'This Mock has no source.';

  @override
  String get archiveServer => 'Archive server';

  @override
  String get deleteServer => 'Delete server';

  @override
  String get archivedServerCannotStart => 'Archived servers cannot be started.';

  @override
  String get disabledServerCannotStart => 'Disabled servers cannot be started.';

  @override
  String get archivedServerCannotArchive =>
      'Archived servers cannot be archived again.';

  @override
  String get discardMockEdits => 'Discard unsaved Mock Server edits';

  @override
  String get noMockEditsToDiscard => 'No unsaved Mock Server edits to discard';

  @override
  String get discardMockChangesTitle => 'Discard changes?';

  @override
  String get discardMockChangesMessage =>
      'Discard the unsaved edits to this Mock Server?';

  @override
  String get archiveMockWithUnsavedEdits =>
      'Unsaved edits will be discarded. Archive this server?';

  @override
  String get archiveMockMessage =>
      'Archive this server and stop its local listener?';

  @override
  String get deleteMockWithUnsavedEdits =>
      'Unsaved edits will be discarded. Delete this server?';

  @override
  String get deleteMockMessage =>
      'Delete this server and stop its local listener?';

  @override
  String get endpoints => 'Endpoints';

  @override
  String get addEndpoint => 'Add endpoint';

  @override
  String get responseVariants => 'Response variants';

  @override
  String get addVariant => 'Add variant';

  @override
  String get defaultVariant => 'Default';

  @override
  String get conditionalVariant => 'Conditional';

  @override
  String get delayMs => 'Delay (ms)';

  @override
  String get removeVariant => 'Remove variant';

  @override
  String get matchesRequestHeader => 'Matches request header';

  @override
  String get headerName => 'Header name';

  @override
  String get headerValue => 'Header value';

  @override
  String get serverStopped => 'Server is stopped';

  @override
  String get startSavedServer => 'Start server';

  @override
  String get stopSavedServer => 'Stop server';

  @override
  String get sourceRequestUnavailable =>
      'The source request is no longer available.';

  @override
  String get sourceResponseUnavailable =>
      'The source response snapshot is no longer available.';

  @override
  String get mockServerSaved => 'Mock Server saved.';

  @override
  String get mockServerCreated => 'Mock Server created.';

  @override
  String get mockServerCreateFailed => 'Could not create Mock Server. Retry.';

  @override
  String get mockServersLoadFailed => 'Could not load saved Mock Servers.';

  @override
  String get protoSourceImportFailed =>
      'Could not import proto source. Review the file and try again.';

  @override
  String get descriptorSetImportFailed =>
      'Could not import descriptor set. Review the file and try again.';

  @override
  String get grpcReflectionFailed =>
      'Server reflection failed. Review the endpoint and try again.';

  @override
  String get mockServerSaveFailed => 'Could not save Mock Server. Retry.';

  @override
  String get mockServerStartedSaved => 'Mock Server started.';

  @override
  String get mockServerStartSavedFailed =>
      'Could not start Mock Server. Retry.';

  @override
  String get mockServerStoppedSaved => 'Mock Server stopped.';

  @override
  String get mockServerStopSavedFailed => 'Could not stop Mock Server. Retry.';

  @override
  String get mockServerArchived => 'Mock Server archived.';

  @override
  String get mockServerArchiveFailed => 'Could not archive Mock Server. Retry.';

  @override
  String get mockServerDeleted => 'Mock Server deleted.';

  @override
  String get mockServerDeleteFailed => 'Could not delete Mock Server. Retry.';
}
