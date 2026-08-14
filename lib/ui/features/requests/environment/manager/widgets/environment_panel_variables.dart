import 'package:flutter/material.dart';

import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/form_control_metrics.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/features/requests/environment/manager/widgets/environment_panel_navigation_items.dart';
import 'package:sendreq/ui/features/requests/environment/manager/widgets/environment_panel_variable_rows.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

class EnvironmentVariablesWorkspace extends StatelessWidget {
  /// 构造变量编辑工作区。
  const EnvironmentVariablesWorkspace({super.key, required this.viewModel});

  /// 工作区视图模型，提供变量数据与编辑操作。
  final WorkspaceViewModel viewModel;

  /// 构建变量工作区：标题栏、认证配置与变量编辑区。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authentication = viewModel.editingEnvironment.authentication;
    final authenticationLabel = switch (authentication.type) {
      RequestAuthenticationType.none => l10n.noAuth,
      RequestAuthenticationType.bearer => l10n.bearerToken,
      RequestAuthenticationType.basic => l10n.basicAuth,
      RequestAuthenticationType.apiKey => l10n.apiKey,
    };
    return Container(
      color: context.chakra.bg,
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: WorkspaceLayoutMetrics.panelPadding,
            decoration: BoxDecoration(
              color: context.chakra.bgSubtle,
              border: Border(bottom: BorderSide(color: context.chakra.border)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;
                final authenticationControl =
                    PopupMenuButton<RequestAuthenticationType>(
                      key: const ValueKey('environment-authentication-type'),
                      tooltip: l10n.configureEnvironmentAuthentication,
                      onSelected: (type) =>
                          _selectEnvironmentAuthenticationType(context, type),
                      itemBuilder: (context) => [
                        for (final type in RequestAuthenticationType.values)
                          PopupMenuItem(
                            value: type,
                            child: Text(switch (type) {
                              RequestAuthenticationType.none => l10n.noAuth,
                              RequestAuthenticationType.bearer =>
                                l10n.bearerToken,
                              RequestAuthenticationType.basic => l10n.basicAuth,
                              RequestAuthenticationType.apiKey => l10n.apiKey,
                            }),
                          ),
                      ],
                      child: Container(
                        height: FormControlMetrics.standardHeight,
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 7 : 9,
                        ),
                        decoration: BoxDecoration(
                          color: context.chakra.colorPaletteSolid.withValues(
                            alpha: 0.22,
                          ),
                          border: Border.all(
                            color: context.chakra.colorPaletteFg.withValues(
                              alpha: 0.42,
                            ),
                          ),
                          borderRadius: ChakraRadii.control,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 15,
                              color: context.chakra.colorPaletteFg,
                            ),
                            if (!isNarrow) ...[
                              const SizedBox(width: 6),
                              MonoText(
                                authenticationLabel,
                                color: context.chakra.colorPaletteFg,
                                size: 10,
                              ),
                              const SizedBox(width: 3),
                            ],
                            Icon(
                              Icons.expand_more,
                              size: 15,
                              color: context.chakra.fgMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                final addVariable = FilledButton.icon(
                  style: ChakraRecipes.sized(
                    ChakraRecipes.solidFor(context),
                    minimumSize: const Size(
                      0,
                      FormControlMetrics.standardHeight,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: viewModel.addEnvironmentVariable,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.addVariable),
                );
                final identity = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MonoText(
                      l10n.environmentVariables,
                      color: context.chakra.fgMuted,
                      size: 10,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: WorkspaceLayoutMetrics.groupGap),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: context.chakra.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            l10n.editingEnvironment(
                              viewModel.editingEnvironment.name,
                            ),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: context.chakra.fg,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        EnvironmentCountBadge(
                          count: viewModel.variables.length,
                        ),
                      ],
                    ),
                  ],
                );
                final commands = Wrap(
                  key: const ValueKey('environment-edit-commands'),
                  spacing: WorkspaceLayoutMetrics.groupGap,
                  runSpacing: WorkspaceLayoutMetrics.groupGap,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    authenticationControl,
                    if (!viewModel.isEditingActiveEnvironment)
                      OutlinedButton.icon(
                        key: const ValueKey('use-environment-for-requests'),
                        onPressed: viewModel.useEditingEnvironmentForRequests,
                        icon: const Icon(Icons.play_arrow_outlined, size: 16),
                        label: Text(l10n.useForRequests),
                      ),
                    addVariable,
                    if (viewModel.hasEnvironmentChanges) ...[
                      _EnvironmentDirtyState(l10n: l10n),
                      OutlinedButton.icon(
                        key: const ValueKey('discard-environment-changes'),
                        onPressed: () => _discardEnvironmentChanges(context),
                        icon: const Icon(Icons.undo_outlined, size: 16),
                        label: Text(l10n.discardChanges),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('save-environment-changes'),
                        onPressed: () => _saveEnvironmentChanges(context),
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: Text(l10n.saveChanges),
                      ),
                    ],
                  ],
                );
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: WorkspaceLayoutMetrics.groupGap),
                      commands,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: WorkspaceLayoutMetrics.groupGap),
                    Flexible(child: commands),
                  ],
                );
              },
            ),
          ),
          Expanded(child: _VariableEditor(viewModel: viewModel)),
        ],
      ),
    );
  }

  Future<void> _saveEnvironmentChanges(BuildContext context) async {
    await viewModel.saveEnvironmentChanges();
  }

  Future<void> _discardEnvironmentChanges(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.discardEnvironmentChangesTitle),
        content: Text(l10n.discardEnvironmentChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.discardChanges),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      viewModel.discardEnvironmentChanges();
    }
  }

  /// 切换环境认证类型；已有认证时先弹出确认对话框。
  Future<void> _selectEnvironmentAuthenticationType(
    BuildContext context,
    RequestAuthenticationType type,
  ) async {
    final l10n = AppLocalizations.of(context);
    final currentType = viewModel.editingEnvironment.authentication.type;
    // 目标类型与当前一致时无需任何处理
    if (currentType == type) return;
    // 从“无认证”切换时直接更新，无需二次确认
    if (currentType == RequestAuthenticationType.none) {
      viewModel.updateEditingEnvironmentAuthenticationType(type);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.switchEnvironmentAuthenticationTitle),
        content: Text(l10n.switchEnvironmentAuthenticationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.switchAuthentication),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      viewModel.updateEditingEnvironmentAuthenticationType(type);
    }
  }
}

class _EnvironmentDirtyState extends StatelessWidget {
  const _EnvironmentDirtyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 210),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.edit_outlined, size: 14, color: context.chakra.warning),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            l10n.unsavedEnvironmentChanges,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.chakra.warning,
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 变量编辑区：表头 + 可横向滚动的变量行 + 计数/审计 footer。
class _VariableEditor extends StatelessWidget {
  /// 构造变量编辑区。
  const _VariableEditor({required this.viewModel});

  /// 工作区视图模型，提供变量列表与编辑操作。
  final WorkspaceViewModel viewModel;

  /// 构建变量编辑区。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: context.chakra.bgMuted,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 900,
              child: EnvironmentVariableTableHeader(l10n: l10n),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 900,
                child: ListView(
                  children: [
                    for (final variable in viewModel.variables)
                      EnvironmentVariableRow(
                        variable: variable,
                        onChanged: ({key, value, type}) =>
                            viewModel.updateEnvironmentVariable(
                              id: variable.id,
                              key: key,
                              value: value,
                              type: type,
                            ),
                        onToggleSecret: variable.isSecret
                            ? () => viewModel.toggleEnvironmentSecretVisibility(
                                variable.id,
                              )
                            : null,
                        onRemove:
                            variable.isProtected ||
                                variable.isAuthenticationBinding
                            ? null
                            : () => viewModel.removeEnvironmentVariable(
                                variable.id,
                              ),
                      ),
                    if (viewModel.variables.isEmpty)
                      SizedBox(
                        height: 190,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.data_object_outlined,
                                size: 26,
                                color: context.chakra.fgSubtle,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                l10n.environmentVariables,
                                style: TextStyle(
                                  color: context.chakra.fgMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: viewModel.addEnvironmentVariable,
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(l10n.addVariable),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 36,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: context.chakra.bgSubtle,
              border: Border(top: BorderSide(color: context.chakra.border)),
            ),
            child: Row(
              children: [
                MonoText(
                  '${viewModel.variables.length} ${l10n.environmentVariables.toLowerCase()}',
                  color: context.chakra.fgMuted,
                  size: 10,
                ),
                const Spacer(),
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: context.chakra.fgMuted,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    l10n.environmentAuditNote,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.chakra.fgMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Variable table header, row, and input controls live in environment_panel_variable_rows.dart.
