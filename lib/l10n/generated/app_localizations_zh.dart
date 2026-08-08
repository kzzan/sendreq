// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settings => '设置';

  @override
  String get settingsSubtitle => '本地工作区偏好';

  @override
  String get savePreferences => '保存偏好';

  @override
  String get saved => '已保存';

  @override
  String get appearance => '外观';

  @override
  String get appearanceDescription => '选择 sendreq 使用的桌面外观。';

  @override
  String get font => '字体';

  @override
  String get fontDescription => '设置界面字体；代码和数据区域仍保持等宽字体。';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get system => '跟随系统';

  @override
  String get language => '语言';

  @override
  String get languageDescription => '选择 sendreq 中使用的界面语言。';

  @override
  String get english => 'English';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get keyboardShortcuts => '键盘快捷键';

  @override
  String get sendRequest => '发送请求';

  @override
  String get sendShortcutDescription => '选择全局“发送”操作使用的快捷键。';

  @override
  String get shortcutConflictWarning => 'Ctrl+Space 可能与输入法切换或编辑器补全冲突。';

  @override
  String get customShortcut => '自定义快捷键';

  @override
  String get noCustomShortcut => '尚未设置';

  @override
  String get recordShortcut => '录入快捷键';

  @override
  String get recordShortcutHint => '按下一个组合键。按 Esc 取消。';

  @override
  String get shortcutModifierRequired => '请使用 Ctrl、Cmd、Alt 或 Shift 加其他按键。';

  @override
  String get shortcutReserved => 'Ctrl/Cmd+K 和 Ctrl/Cmd+S 已被系统操作占用。';

  @override
  String get shortcutUnavailable => '此快捷键不可用。';

  @override
  String shortcutUpdated(String shortcut) {
    return '发送快捷键已设为 $shortcut。';
  }

  @override
  String get resetPreferencesDescription => '重置只恢复偏好设置，不会删除请求、环境和历史记录。';

  @override
  String get resetDefaults => '恢复默认设置';

  @override
  String get preferencesSaved => '偏好设置已保存';

  @override
  String get preferencesSaveFailed => '无法保存偏好设置，请重试。';

  @override
  String get documentationExport => '文档导出';

  @override
  String get documentationOutputDirectoryDescription =>
      '选择导出的 Markdown 接口文档写入的位置。';

  @override
  String get noDocumentationOutputDirectory => '尚未选择输出文件夹';

  @override
  String get chooseDocumentationOutputFolder => '选择文档输出文件夹';

  @override
  String get chooseOutputDirectory => '选择输出文件夹';

  @override
  String get changeOutputDirectory => '更改输出文件夹';

  @override
  String get defaultOutputDirectory => '默认文件夹';

  @override
  String get customOutputDirectory => '自定义文件夹';

  @override
  String get restoreDefaultOutputDirectory => '使用默认输出文件夹';

  @override
  String documentationOutputDirectoryUnavailable(String error) {
    return '无法创建输出文件夹：$error';
  }

  @override
  String get documentationOutputDirectoryPrepareFailed =>
      '无法创建文档输出文件夹。请选择其他文件夹后重试。';

  @override
  String get clearOutputDirectory => '清除输出文件夹';

  @override
  String get configureDocumentationOutputDirectory => '请先在设置中选择文档输出文件夹。';

  @override
  String get exportMarkdown => '导出 Markdown';

  @override
  String markdownExportedTo(String path) {
    return 'Markdown 接口文档已导出至 $path。';
  }

  @override
  String markdownExportFailed(String error) {
    return '无法导出 Markdown 接口文档：$error';
  }

  @override
  String get environmentChangesSaved => '环境修改已保存。';

  @override
  String get environmentChangesPending => '环境修改尚未保存。';

  @override
  String get environmentSaveFailed => '无法保存环境修改，请重试。';

  @override
  String get invalidHttpStatus => '请输入 100 到 599 之间的 HTTP 状态码。';

  @override
  String entityDataIgnoredForMethod(String method) {
    return '$method 不会发送请求体或实体请求头。';
  }

  @override
  String collectionCreated(String name) {
    return '已创建 $name。';
  }

  @override
  String folderCreated(String name) {
    return '已创建 $name。';
  }

  @override
  String get requestRenamed => '请求已重命名。';

  @override
  String get collectionRenamed => '集合已重命名。';

  @override
  String get folderRenamed => '文件夹已重命名。';

  @override
  String get requestChangesSaved => '请求修改已保存。';

  @override
  String get protocolHttp => 'HTTP';

  @override
  String get protocolWebSocket => 'WebSocket';

  @override
  String get protocolGrpc => 'gRPC';

  @override
  String get grpcConfiguration => 'gRPC 配置';

  @override
  String get importProto => '导入 .proto';

  @override
  String get noProtoSelected => '尚未选择 .proto 文件';

  @override
  String get grpcService => '服务';

  @override
  String get grpcMethod => 'RPC 方法';

  @override
  String get grpcTls => '使用 TLS';

  @override
  String get grpcMetadataHint => '已启用的请求头将作为 gRPC metadata 发送。';

  @override
  String get changeRequestProtocol => '切换请求协议';

  @override
  String get changeHttpMethod => '切换 HTTP 方法';

  @override
  String get workspace => '工作区';

  @override
  String get dashboard => '仪表盘';

  @override
  String get collections => '集合';

  @override
  String get collectionActions => '集合操作';

  @override
  String get history => '历史记录';

  @override
  String get environments => '环境';

  @override
  String get mockServers => 'Quick Mock';

  @override
  String get documentation => '文档';

  @override
  String get docs => '文档';

  @override
  String get searchMetrics => '搜索指标...';

  @override
  String get searchRequests => '搜索请求...';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get searchHistory => '搜索历史...';

  @override
  String get searchVariables => '搜索变量...';

  @override
  String get searchMocks => '搜索 Quick Mock...';

  @override
  String get searchDocumentation => '搜索文档...';

  @override
  String get searchSettings => '搜索设置...';

  @override
  String get openCommandPalette => '打开命令面板';

  @override
  String get activeEnvironment => '当前环境';

  @override
  String get activeEnvironmentShort => '当前环境';

  @override
  String get variablesResolveBeforeSend => '变量会在发送前解析。';

  @override
  String get openDocumentation => '打开文档';

  @override
  String get saveActiveResource => '保存当前资源';

  @override
  String get noSaveableChanges => '没有可保存的修改';

  @override
  String get minimizeWindow => '最小化窗口';

  @override
  String get closeWindow => '关闭窗口';

  @override
  String get desktopMvp => '桌面版原型';

  @override
  String get noRequestsYet => '还没有请求';

  @override
  String get createRequestToStart => '创建一个请求，开始测试 API。';

  @override
  String get newRequest => '新建请求';

  @override
  String get request => '请求';

  @override
  String get response => '响应';

  @override
  String get commandPalette => '命令面板';

  @override
  String get searchCommands => '搜索命令';

  @override
  String get noMatchingResources => '没有匹配的资源';

  @override
  String get sendActiveRequest => '发送当前请求';

  @override
  String get environmentVariables => '环境变量';

  @override
  String get environmentConfiguration => '环境配置';

  @override
  String environmentUsesName(String name) {
    return '当前请求使用 $name 解析变量';
  }

  @override
  String get returnToRequest => '返回请求';

  @override
  String get saveChanges => '保存修改';

  @override
  String get noChanges => '无修改';

  @override
  String get currentEnvironment => '当前环境';

  @override
  String get selectCurrentEnvironment => '选择当前环境';

  @override
  String get newEnvironment => '新增环境';

  @override
  String get createEnvironment => '创建环境';

  @override
  String get renameEnvironment => '重命名环境';

  @override
  String get deleteEnvironment => '删除环境';

  @override
  String get environmentName => '环境名称';

  @override
  String deleteEnvironmentConfirmation(String name) {
    return '删除 $name 及其全部变量？';
  }

  @override
  String get lastEnvironmentRequired => '至少保留一个环境用于解析变量。';

  @override
  String get environmentNameMustBeUnique => '请输入唯一的环境名称。';

  @override
  String get environmentActions => '环境操作';

  @override
  String get scope => '范围';

  @override
  String get variableName => '变量名';

  @override
  String get currentValue => '当前值';

  @override
  String get type => '类型';

  @override
  String get addVariable => '新增变量';

  @override
  String get addParameterFromEnvironment => '从环境添加参数';

  @override
  String get managedByAuthentication => '由认证管理';

  @override
  String get environmentAuditNote => '保存修改后会生成轻量修订记录；完整审计差异将在后续版本提供。';

  @override
  String get variableValue => '变量值';

  @override
  String get toggleSecretVisibility => '显示或隐藏密钥';

  @override
  String get changeVariableType => '切换变量类型';

  @override
  String get deleteVariable => '删除变量';

  @override
  String get requiredTokenVariable => '每个环境均需保留 token';

  @override
  String get requiredEnvironmentBaseUrl => '每个环境均需保留基础 URL';

  @override
  String get variableTypeString => '文本';

  @override
  String get variableTypeNumber => '数字';

  @override
  String get variableTypeBoolean => '布尔值';

  @override
  String get variableTypeSecret => '密钥';

  @override
  String get authenticationType => '认证类型';

  @override
  String get authenticationSource => '认证来源';

  @override
  String get inheritEnvironmentAuthentication => '继承环境认证';

  @override
  String get requestSpecificAuthentication => '请求专用认证';

  @override
  String get configureEnvironmentAuthentication => '配置环境认证';

  @override
  String get clearUnusedAuthenticationVariables => '清理未使用凭据';

  @override
  String get clearUnusedAuthenticationVariablesTitle => '清理未使用凭据？';

  @override
  String clearUnusedAuthenticationVariablesMessage(String variables) {
    return '将永久删除：$variables';
  }

  @override
  String get clearCredentials => '清理凭据';

  @override
  String get switchEnvironmentAuthenticationTitle => '切换认证方式？';

  @override
  String get switchEnvironmentAuthenticationMessage => '当前环境中现有认证凭据将被删除，且无法恢复。';

  @override
  String get switchAuthentication => '切换认证';

  @override
  String get basicAuth => 'Basic 认证';

  @override
  String get apiKey => 'API Key';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get apiKeyName => '键名';

  @override
  String get apiKeyValue => '值';

  @override
  String get sendIn => '发送位置';

  @override
  String get basicAuthenticationStored => '仅在发送请求时生成 Authorization 请求头。';

  @override
  String get apiKeyAuthenticationStored => '仅在发送请求时生成 API Key。';

  @override
  String get noMockDraft => '尚无 Quick Mock';

  @override
  String get mockDraftDescription => '仅当前会话可用，关闭 sendreq 后自动移除。';

  @override
  String get newMock => '新建 Quick Mock';

  @override
  String get createMockFromResponse => '用响应创建 Quick Mock';

  @override
  String get manualMock => '手动配置';

  @override
  String get openCollections => '打开集合';

  @override
  String get mockDraft => 'Quick Mock';

  @override
  String get fromLatestResponse => '基于最近一次响应';

  @override
  String get returnToResponse => '返回响应';

  @override
  String get responseExample => '响应示例';

  @override
  String get mockResponse => '返回内容';

  @override
  String get mockLoopbackNote => '按方法和路径匹配，忽略查询参数。';

  @override
  String get localRuntime => '本地运行时';

  @override
  String get running => '运行中';

  @override
  String get stopped => '已停止';

  @override
  String get stopServer => '停止 Quick Mock';

  @override
  String get startServer => '启动 Quick Mock';

  @override
  String get copyMockAddress => '复制 Quick Mock 地址';

  @override
  String get mockAddressCopied => '已复制 Quick Mock 地址。';

  @override
  String get noDocumentationDraft => '尚未创建文档草稿';

  @override
  String get documentationDraftDescription => '发送请求后，可根据响应生成接口文档。';

  @override
  String get documentationDraft => '文档草稿';

  @override
  String get fromResponseSnapshot => '基于响应快照生成';

  @override
  String get tryIt => '试运行';

  @override
  String get copyApiReference => '复制 API 参考';

  @override
  String get apiReferenceCopied => '已复制 API 参考。';

  @override
  String get apiReference => 'API 参考';

  @override
  String get curlCopied => '已复制 cURL。';

  @override
  String get curl => 'cURL';

  @override
  String get responseExampleCopied => '已复制响应示例。';

  @override
  String copyNamedValue(String name) {
    return '复制$name';
  }

  @override
  String get responseTitle => '响应';

  @override
  String executionSnapshot(String environment) {
    return '执行快照 · $environment';
  }

  @override
  String get unknownEnvironment => '未知环境';

  @override
  String get awaitingCurrentRequest => '等待发送当前请求';

  @override
  String get executionResult => '本次请求的执行结果';

  @override
  String get pending => '待执行';

  @override
  String get originalRequestDeleted => '原始请求已删除，无法回到编辑器。';

  @override
  String get body => '正文';

  @override
  String get responseHeaders => '响应头';

  @override
  String get requestSnapshot => '请求快照';

  @override
  String get duration => '耗时';

  @override
  String get size => '大小';

  @override
  String get copyResponseBody => '复制响应正文';

  @override
  String get downloadResponseBody => '下载响应正文';

  @override
  String get generateDocumentation => '生成文档';

  @override
  String get createMock => '用响应创建 Quick Mock';

  @override
  String get replaceQuickMockTitle => '替换当前 Quick Mock？';

  @override
  String get replaceQuickMockMessage => '当前响应配置将被替换。';

  @override
  String get replaceQuickMock => '替换';

  @override
  String get responseBodyCopied => '已复制响应正文。';

  @override
  String responseSavedAt(String path) {
    return '响应已保存至 $path';
  }

  @override
  String responseSaveFailed(String message) {
    return '无法保存响应：$message';
  }

  @override
  String get responseBody => '响应正文';

  @override
  String get validJson => '合法 JSON';

  @override
  String get plainText => '纯文本';

  @override
  String get formattedView => '格式化';

  @override
  String get rawView => '原始';

  @override
  String responseLineCount(int count) {
    return '$count 行';
  }

  @override
  String get copyDisplayedResponse => '复制当前视图';

  @override
  String get displayedResponseCopied => '已复制当前视图。';

  @override
  String get noResponseYet => '尚未获得响应';

  @override
  String get noResponseBody => '这次执行没有响应正文';

  @override
  String get responseAwaitingDescription => '发送当前请求后，可在这里查看状态、耗时和响应内容。';

  @override
  String get requestAtExecution => '执行时的请求';

  @override
  String environmentValue(String name) {
    return '环境  $name';
  }

  @override
  String get requestHeaders => '请求头';

  @override
  String get requestBody => '请求正文';

  @override
  String get empty => '（空）';

  @override
  String sendingRequest(String name) {
    return '正在发送 $name';
  }

  @override
  String usingEnvironment(String name) {
    return '使用环境：$name';
  }

  @override
  String get cancelSend => '取消发送';

  @override
  String get errorDetailsCopied => '已复制错误详情。';

  @override
  String get copyErrorDetails => '复制错误详情';

  @override
  String get retry => '重试';

  @override
  String get startupRecoveryTitle => '本地数据需要恢复';

  @override
  String get startupRecoveryDescription =>
      'sendreq 未修改原始文件。请修复 JSON 文件或目录访问权限后，再重试迁移。';

  @override
  String get returnToRequestEditor => '返回编辑请求';

  @override
  String get unsavedRequest => '请求尚未保存';

  @override
  String saveRequestBeforeClose(String name) {
    return '关闭前要保存「$name」的修改吗？';
  }

  @override
  String get cancel => '取消';

  @override
  String get discardChanges => '放弃修改';

  @override
  String get saveAndClose => '保存并关闭';

  @override
  String get discardUnsavedChanges => '放弃未保存的修改？';

  @override
  String discardChangesForRequest(String name) {
    return '「$name」的修改将无法恢复。';
  }

  @override
  String get continueEditing => '继续编辑';

  @override
  String closeRequest(String name) {
    return '关闭 $name';
  }

  @override
  String get closeOtherTabs => '关闭其他标签页';

  @override
  String get closeTabsToLeft => '关闭左侧标签页';

  @override
  String get closeTabsToRight => '关闭右侧标签页';

  @override
  String get send => '发送';

  @override
  String missingEnvironmentVariables(String variables) {
    return '缺少环境变量：$variables';
  }

  @override
  String get openEnvironment => '前往环境';

  @override
  String get unsaved => '未保存';

  @override
  String get discardUnsavedChangesTooltip => '放弃未保存的修改';

  @override
  String get queryParameters => '查询参数';

  @override
  String get protocol => '协议';

  @override
  String get authorization => '认证';

  @override
  String newMessages(int count) {
    return '$count 条新消息';
  }

  @override
  String webSocketState(String state) {
    return 'WebSocket $state';
  }

  @override
  String get disconnect => '断开连接';

  @override
  String get connect => '连接';

  @override
  String get connecting => '正在连接';

  @override
  String get closing => '正在关闭';

  @override
  String get disconnected => '未连接';

  @override
  String get connected => '已连接';

  @override
  String get connectionError => '连接错误';

  @override
  String get formatJson => '格式化 JSON';

  @override
  String get connectBeforeSending => '请先连接再发送消息。';

  @override
  String get selectProtobufBeforeSending => '发送前请选择 Protobuf 架构和消息类型。';

  @override
  String get sendWithShortcut => '按 Ctrl+Enter 发送';

  @override
  String get messagePayload => '消息内容';

  @override
  String get base64Bytes => 'Base64 编码字节';

  @override
  String get protobufJsonPayload => '所选 Protobuf 消息类型的 JSON';

  @override
  String get executionHistory => '执行历史';

  @override
  String get latestRequestSnapshots => '最新请求快照';

  @override
  String historyExecutionCount(int count) {
    return '共 $count 次执行';
  }

  @override
  String get historyTimeline => '执行时间线';

  @override
  String get historyExecutionDetail => '执行详情';

  @override
  String get historyTotal => '总数';

  @override
  String get historyAll => '全部';

  @override
  String get historySuccess => '成功';

  @override
  String get historyFailed => '失败';

  @override
  String get historyEmpty => '暂无执行记录';

  @override
  String get historyNoSearchResults => '没有匹配的执行记录';

  @override
  String get clearHistory => '清除历史记录';

  @override
  String get clearHistoryTitle => '清除执行历史记录？';

  @override
  String get clearHistoryMessage => '这会移除当前会话中的全部执行记录。';

  @override
  String get historyCleared => '执行历史记录已清除。';

  @override
  String dashboardForEnvironment(String name) {
    return '过去 24 小时，$name 工作区';
  }

  @override
  String get quickStart => '快速开始';

  @override
  String get quickStartDescription => '新建草稿，或导入已有 API 定义。';

  @override
  String get requestVolume => '请求量';

  @override
  String get environmentHealth => '环境状态';

  @override
  String get active => '当前';

  @override
  String get ready => '就绪';

  @override
  String get noFiles => '没有文件';

  @override
  String selectedFileCount(int count) {
    return '已选择 $count 个';
  }

  @override
  String get optional => '可选';

  @override
  String fieldCount(int count) {
    return '$count 个字段';
  }

  @override
  String get multipartFieldsDescription => '仅在接口需要时添加文本字段。';

  @override
  String get newCollection => '新建集合';

  @override
  String get loadDemoExample => '加载示例集合';

  @override
  String get importOpenApi => '导入 OpenAPI';

  @override
  String get exportOpenApi => '导出 OpenAPI';

  @override
  String get importOpenApiJson => '导入 OpenAPI JSON';

  @override
  String get selectOpenApiFile => '选择 OpenAPI JSON 文件';

  @override
  String openApiFileLoaded(String name) {
    return '已载入 $name';
  }

  @override
  String get openApiFileReadFailed => '无法读取所选 OpenAPI 文件。';

  @override
  String get import => '导入';

  @override
  String get method => '方法';

  @override
  String get path => '路径';

  @override
  String get status => '状态';

  @override
  String get when => '时间';

  @override
  String get openExecutionSnapshot => '打开执行快照';

  @override
  String get legacyExecutionNoSnapshot => '这条历史执行记录没有存储快照';

  @override
  String collectionCount(int count) {
    return '$count 个集合';
  }

  @override
  String deleteCollectionConfirmation(String name, int count) {
    return '删除 $name 及其 $count 个请求？';
  }

  @override
  String deleteFolderConfirmation(String name, int count) {
    return '删除 $name 及其 $count 个请求？';
  }

  @override
  String deleteRequestConfirmation(String name) {
    return '删除 $name？';
  }

  @override
  String deleteWithUnsavedChanges(String description, int count) {
    return '$description $count 个请求有未保存的修改。';
  }

  @override
  String get collectionDeleted => '集合已删除。';

  @override
  String get folderDeleted => '文件夹已删除。';

  @override
  String get requestDeleted => '请求已删除。';

  @override
  String get importFailed => '导入失败。';

  @override
  String get openApiJsonExample => '{ \"openapi\": \"3.0.0\" }';

  @override
  String get validOpenApiJsonRequired => '请粘贴有效的 OpenAPI JSON。';

  @override
  String openApiRequestsImported(int count, String name) {
    return '已将 $count 个 OpenAPI 请求导入到 $name。';
  }

  @override
  String openApiExportedTo(String path) {
    return 'OpenAPI 已导出到 $path。';
  }

  @override
  String openApiExportFailed(String error) {
    return '无法导出 OpenAPI：$error';
  }

  @override
  String get rename => '重命名';

  @override
  String get delete => '删除';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get renameCollection => '重命名集合';

  @override
  String get renameFolder => '重命名文件夹';

  @override
  String get renameRequest => '重命名请求';

  @override
  String get deleteCollection => '删除集合';

  @override
  String get deleteFolder => '删除文件夹';

  @override
  String get deleteRequest => '删除请求';

  @override
  String get name => '名称';

  @override
  String get unsavedRequestChanges => '存在未保存的请求修改';

  @override
  String get discardAndDelete => '放弃并删除';

  @override
  String get saveAndDelete => '保存并删除';

  @override
  String get webSocketProtocol => 'WebSocket 协议';

  @override
  String get webSocketProtocolHint => '握手时发送的可选子协议。';

  @override
  String get subprotocols => '子协议';

  @override
  String get protobufDescriptor => 'Protobuf 描述符';

  @override
  String get descriptorUnavailable => '描述符文件不可用，请重新导入以恢复此请求。';

  @override
  String get noDescriptorSelected => '尚未选择描述符集合';

  @override
  String get messageType => '消息类型';

  @override
  String get addField => '新增字段';

  @override
  String get addRow => '新增行';

  @override
  String get key => '键';

  @override
  String get value => '值';

  @override
  String get removeRow => '删除行';

  @override
  String get changeBodyContentType => '切换正文内容类型';

  @override
  String get noContentType => '无内容类型';

  @override
  String get requestBodyHint => '// 请求正文';

  @override
  String get requestTabParams => '参数';

  @override
  String get requestTabHeaders => '请求头';

  @override
  String get requestTabAuth => '认证';

  @override
  String get requestTabBody => '正文';

  @override
  String get requestTabProtocol => '协议';

  @override
  String get subprotocolsHint => 'graphql-transport-ws, events.v1';

  @override
  String sendRequestWithShortcut(String shortcut) {
    return '发送请求（$shortcut）';
  }

  @override
  String get fieldEnabled => '启用字段';

  @override
  String get fieldDisabled => '停用字段';

  @override
  String get fileEnabled => '启用文件';

  @override
  String get fileDisabled => '停用文件';

  @override
  String get removeSecretProtection => '移除密钥保护';

  @override
  String get selectedFilesUnreadable => '部分选中的文件无法读取。';

  @override
  String get addFormField => '新增表单字段';

  @override
  String get removeFile => '移除文件';

  @override
  String get removeFormField => '移除表单字段';

  @override
  String get batchField => '批量字段';

  @override
  String get fieldName => '字段名称';

  @override
  String get field => '字段';

  @override
  String get enabled => '启用';

  @override
  String activeFieldCount(int count) {
    return '已启用 $count 项';
  }

  @override
  String get disableRow => '停用此行';

  @override
  String get enableRow => '启用此行';

  @override
  String get hideValue => '隐藏值';

  @override
  String get revealValue => '显示值';

  @override
  String get markAsSecret => '标记为密钥';

  @override
  String get chooseFilesDescription => '选择一个或多个文件随此请求发送。';

  @override
  String get authorizationAppliedAsHeader => '独立认证配置';

  @override
  String get customAuthorizationConfigured => '此请求已配置自定义 Authorization 请求头。';

  @override
  String get customAuthorizationHeader => '自定义 Authorization 请求头';

  @override
  String get edit => '编辑';

  @override
  String get token => '令牌';

  @override
  String get bearerTokenStored => '仅在发送请求时生成 Authorization 请求头。';

  @override
  String get noAuthorizationHeader => '此请求不使用认证。';

  @override
  String get webSocketUrlRequired => 'WebSocket URL 必须使用 ws:// 或 wss://。';

  @override
  String get originalRequestDeletedNotice => '原始请求已删除。';

  @override
  String get mockServerStarted => 'Quick Mock 已启动。';

  @override
  String get mockServerStopped => 'Quick Mock 已停止。';

  @override
  String get mockServerStartFailed => '无法启动 Quick Mock，请重试。';

  @override
  String get mockServerStopFailed => '无法停止 Quick Mock，请重试。';

  @override
  String get files => '文件';

  @override
  String get chooseFiles => '选择文件';

  @override
  String get formFields => '表单字段';

  @override
  String get browse => '浏览';

  @override
  String get apply => '应用';

  @override
  String get bearerToken => 'Bearer 令牌';

  @override
  String get noAuth => '无认证';

  @override
  String get pasteBearerToken => '粘贴 Bearer 令牌';

  @override
  String earlierMessagesOmitted(int count) {
    return '为保护内存，已省略较早的 $count 条消息。';
  }

  @override
  String get webSocketInbound => '入站';

  @override
  String get webSocketOutbound => '出站';

  @override
  String get webSocketSystem => '系统';

  @override
  String get webSocketTextFrame => '文本';

  @override
  String get webSocketBinaryFrame => '二进制';

  @override
  String get webSocketCloseFrame => '关闭';

  @override
  String get webSocketErrorFrame => '错误';

  @override
  String webSocketMessageSemantics(String direction, String kind, int bytes) {
    return '$direction$kind消息，$bytes 字节';
  }

  @override
  String byteCount(int count) {
    return '$count B';
  }

  @override
  String get webSocketConnectionTimedOut => 'WebSocket 连接已超时。';

  @override
  String get webSocketMessageFormat => '选择消息格式';

  @override
  String get webSocketTextFrameHeading => '文本帧';

  @override
  String get webSocketBinaryFrameHeading => '二进制帧';

  @override
  String pasteSerializedMessageBase64(String format) {
    return '请粘贴序列化 $format 字节的 Base64 数据。';
  }

  @override
  String get grpcResponseTitle => 'gRPC 响应';

  @override
  String get cancelGrpcCall => '取消 gRPC 调用';

  @override
  String earlierGrpcEventsOmitted(int count) {
    return '已省略较早的 $count 个事件。';
  }

  @override
  String get awaitingGrpcResponse => '等待 gRPC 响应';

  @override
  String get sendActiveRequestRequired => '存在活动请求时才可发送。';

  @override
  String get requestAlreadySending => '当前请求正在发送中。';

  @override
  String get enterRequestUrlBeforeSending => '请先输入请求地址再发送。';

  @override
  String get selectProtobufSchemaBeforeSending =>
      '请先选择 Protobuf schema 与消息类型再发送。';

  @override
  String get importProtobufDescriptorBeforeSending =>
      '请先导入有效的 Protobuf 描述符集再发送。';

  @override
  String get enterJsonMessageBeforeFormatting => '请先输入 JSON 消息再格式化。';

  @override
  String get messageNotValidJson => '消息不是合法的 JSON。';

  @override
  String get binaryMessagesRequireBase64 => '二进制消息必须使用合法的 Base64。';

  @override
  String get enterJsonRequestBodyBeforeFormatting => '请先输入 JSON 请求体再格式化。';

  @override
  String get requestBodyNotValidJson => '请求体不是合法的 JSON。';

  @override
  String encodesToBytes(int count) {
    return '编码为 $count 字节';
  }

  @override
  String get sendRequestBeforeMockDraft => '请先发送请求，再创建 Quick Mock。';

  @override
  String get sendRequestBeforeDocumentation => '请先发送一次请求再生成文档。';

  @override
  String get createMockDraftBeforeStartingServer => '请先创建 Quick Mock 再启动。';

  @override
  String couldNotSendMessage(String error) {
    return '无法发送消息：$error';
  }

  @override
  String get connectionClosed => '连接已关闭。';

  @override
  String get connectionFailed => '连接失败。';

  @override
  String couldNotImportProto(String error) {
    return '无法导入 proto 源：$error';
  }

  @override
  String couldNotImportDescriptorSet(String error) {
    return '无法导入描述符集：$error';
  }

  @override
  String oneofOnlyOneField(String name) {
    return 'oneof $name 中只能设置一个字段。';
  }

  @override
  String invalidEnumValueForField(String field) {
    return '字段 $field 的枚举值无效。';
  }

  @override
  String unexpectedWireTypeForField(String path) {
    return '字段 $path 的 wire 类型不符合预期。';
  }

  @override
  String unsupportedProtobufFieldType(String path) {
    return '不支持的 Protobuf 字段类型：$path。';
  }

  @override
  String get pasteOpenApi3JsonRequired =>
      '请粘贴包含 paths 对象的 OpenAPI 3.x JSON 文档。';

  @override
  String get noSupportedHttpOperations => '未找到受支持的 HTTP 操作。';

  @override
  String get unsupportedWebSocketFrame => '不支持的 WebSocket 帧。';

  @override
  String get protobufJsonMustBeObject => 'Protobuf JSON 消息必须是对象。';

  @override
  String unknownProtobufMessageType(String name) {
    return '未知的 Protobuf 消息类型：$name';
  }

  @override
  String unknownProtobufField(String path) {
    return '未知字段：$path';
  }

  @override
  String get unexpectedEndOfProtobufData => 'Protobuf 数据意外结束。';

  @override
  String get invalidProtobufLength => '非法的 Protobuf 长度。';

  @override
  String get unsupportedProtobufWireType => '不支持的 Protobuf wire 类型。';

  @override
  String get requestTimedOut => '请求在 20 秒后超时。';

  @override
  String get requestCancelled => '请求已取消。';
}
