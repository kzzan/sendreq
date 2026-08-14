import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/form_control_metrics.dart';
import 'package:sendreq/domain/environments/environment_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';

/// 请求上下文中的环境选择器。
///
/// 环境属于整个工作区的执行上下文：切换后立即影响当前请求以及其他
/// Collection 请求中所有 `{{variable}}` 的解析，但不会修改请求定义。
class RequestEnvironmentSelector extends StatelessWidget {
  /// 构造环境选择器。
  const RequestEnvironmentSelector({
    super.key,
    required this.environments,
    required this.activeEnvironmentId,
    required this.onSelected,
    this.controlKey = const Key('request-environment-selector'),
    this.width = defaultWidth,
  });

  /// 可选的环境列表。
  final List<EnvironmentProfile> environments;

  /// 当前激活的环境 ID。
  final String activeEnvironmentId;

  /// 用户切换环境时的回调。
  final ValueChanged<String> onSelected;

  /// 控件语义化 key，便于测试定位。
  final Key controlKey;

  /// 选择器宽度；窄屏顶栏可使用更紧凑的稳定宽度。
  final double width;

  static const double defaultWidth = 164;

  /// 从环境中解析当前激活的环境配置。
  EnvironmentProfile get _activeEnvironment => environments.firstWhere(
    (environment) => environment.id == activeEnvironmentId,
  );

  /// 构建环境选择器：下拉菜单 + 当前环境胶囊展示。
  @override
  Widget build(BuildContext context) {
    final activeEnvironment = _activeEnvironment;
    return PopupMenuButton<String>(
      key: controlKey,
      tooltip: AppLocalizations.of(context).activeEnvironment,
      initialValue: activeEnvironmentId,
      offset: const Offset(0, FormControlMetrics.standardHeight),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final environment in environments)
          PopupMenuItem(
            value: environment.id,
            child: Row(
              children: [
                Icon(
                  environment.id == activeEnvironmentId
                      ? Icons.check
                      : Icons.circle,
                  size: environment.id == activeEnvironmentId ? 16 : 7,
                  color: environment.id == activeEnvironmentId
                      ? context.chakra.success
                      : context.chakra.fgSubtle,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    environment.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: SizedBox(
        width: width,
        height: FormControlMetrics.standardHeight,
        child: Container(
          padding: const EdgeInsets.only(left: 10, right: 7),
          decoration: BoxDecoration(
            color: context.chakra.bgMuted,
            border: Border.all(color: context.chakra.border),
            borderRadius: ChakraRadii.control,
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: context.chakra.success,
                  borderRadius: ChakraRadii.control,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: MonoText(
                  activeEnvironment.name,
                  color: context.chakra.fg,
                  size: 11,
                  weight: FontWeight.w600,
                ),
              ),
              Icon(Icons.expand_more, size: 16, color: context.chakra.fgMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// 展示未解析的环境变量列表，并提供“打开环境面板”的恢复操作入口。
/// 展示未解析的环境变量并提供恢复操作入口。
class MissingVariablesNotice extends StatelessWidget {
  /// 构造未解析变量提示条。
  const MissingVariablesNotice({
    super.key,
    required this.variables,
    required this.onOpenEnvironment,
  });

  /// 尚未解析出的变量名集合。
  final List<String> variables;

  /// 点击“打开环境”按钮时触发，用于跳转到环境管理面板。
  final VoidCallback onOpenEnvironment;

  /// 构建警示提示条：左侧文案，右侧“打开环境”入口。
  @override
  Widget build(BuildContext context) => Container(
    // 警示色横幅：黄底 + 黄色描边，与普通信息区区分开来。
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: context.chakra.warning.withValues(alpha: 0.10),
      border: Border.all(color: context.chakra.warning.withValues(alpha: 0.45)),
      borderRadius: ChakraRadii.control,
    ),
    child: Row(
      children: [
        // 左侧警告图标 + 变量名拼接的提示文案。
        Icon(
          Icons.warning_amber_outlined,
          size: 16,
          color: context.chakra.warning,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            AppLocalizations.of(
              context,
            ).missingEnvironmentVariables(variables.join('、')),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.chakra.warning, fontSize: 12),
          ),
        ),
        // 右侧快捷入口：直接跳转到环境管理面板补充变量。
        TextButton.icon(
          onPressed: onOpenEnvironment,
          icon: const Icon(Icons.tune_outlined, size: 15),
          label: Text(AppLocalizations.of(context).openEnvironment),
          style: ChakraRecipes.warningGhostFor(context),
        ),
      ],
    ),
  );
}
