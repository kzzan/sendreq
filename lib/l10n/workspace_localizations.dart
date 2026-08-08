import '../domain/models/workspace_models.dart';
import '../domain/environments/environment_models.dart';
import 'generated/app_localizations.dart';

/// Maps presentation-only workspace values to the active app language.
/// Domain objects deliberately keep language-neutral enum values.
extension WorkspaceSectionLocalizations on WorkspaceSection {
  /// 返回分区的中文本地化标签。
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    WorkspaceSection.dashboard => l10n.dashboard,
    WorkspaceSection.collections => l10n.collections,
    WorkspaceSection.history => l10n.history,
    WorkspaceSection.environments => l10n.environments,
    WorkspaceSection.mockServers => l10n.mockServers,
    WorkspaceSection.documentation => l10n.docs,
    WorkspaceSection.settings => l10n.settings,
  };

  /// 返回分区在命令面板中的搜索提示文本。
  String localizedCommandHint(AppLocalizations l10n) => switch (this) {
    WorkspaceSection.dashboard => l10n.searchMetrics,
    WorkspaceSection.collections => l10n.searchRequests,
    WorkspaceSection.history => l10n.searchHistory,
    WorkspaceSection.environments => l10n.searchVariables,
    WorkspaceSection.mockServers => l10n.searchMocks,
    WorkspaceSection.documentation => l10n.searchDocumentation,
    WorkspaceSection.settings => l10n.searchSettings,
  };
}

/// 环境变量类型的本地化标签。
extension EnvironmentVariableTypeLocalizations on EnvironmentVariableType {
  /// 返回变量类型的本地化标签。
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    EnvironmentVariableType.string => l10n.variableTypeString,
    EnvironmentVariableType.number => l10n.variableTypeNumber,
    EnvironmentVariableType.boolean => l10n.variableTypeBoolean,
    EnvironmentVariableType.secret => l10n.variableTypeSecret,
  };
}
