import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/environments/environment_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

/// 将仅用于展示的工作区值映射为当前应用语言。
/// 领域对象刻意保持与语言无关的枚举值。
extension WorkspaceSectionLocalizations on WorkspaceSection {
  /// 返回分区的中文本地化标签。
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    WorkspaceSection.requests => l10n.requests,
    WorkspaceSection.mock => l10n.mock,
    WorkspaceSection.settings => l10n.settings,
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
