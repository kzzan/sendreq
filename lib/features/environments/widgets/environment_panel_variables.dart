part of 'environment_panel.dart';

class _VariablesWorkspace extends StatelessWidget {
  /// 构造变量编辑工作区。
  const _VariablesWorkspace({required this.viewModel});

  /// 工作区视图模型，提供变量数据与编辑操作。
  final WorkspaceViewModel viewModel;

  /// 构建变量工作区：标题栏、认证配置与变量编辑区。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authentication = viewModel.activeEnvironment.authentication;
    final authenticationLabel = switch (authentication.type) {
      RequestAuthenticationType.none => l10n.noAuth,
      RequestAuthenticationType.bearer => l10n.bearerToken,
      RequestAuthenticationType.basic => l10n.basicAuth,
      RequestAuthenticationType.apiKey => l10n.apiKey,
    };
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Container(
            height: 72,
            padding: const EdgeInsets.fromLTRB(18, 9, 16, 9),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              border: Border(bottom: BorderSide(color: AppColors.outline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoText(
                        l10n.environmentVariables,
                        color: AppColors.textMuted,
                        size: 10,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            viewModel.activeEnvironment.name,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 9),
                          _CountBadge(count: viewModel.variables.length),
                        ],
                      ),
                    ],
                  ),
                ),
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
                          RequestAuthenticationType.bearer => l10n.bearerToken,
                          RequestAuthenticationType.basic => l10n.basicAuth,
                          RequestAuthenticationType.apiKey => l10n.apiKey,
                        }),
                      ),
                  ],
                  child: Container(
                    height: FormControlMetrics.standardHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.22),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.42),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        MonoText(
                          authenticationLabel,
                          color: AppColors.primary,
                          size: 10,
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.expand_more,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(
                      0,
                      FormControlMetrics.standardHeight,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  onPressed: viewModel.addEnvironmentVariable,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.addVariable),
                ),
              ],
            ),
          ),
          Expanded(child: _VariableEditor(viewModel: viewModel)),
        ],
      ),
    );
  }

  /// 切换环境认证类型；已有认证时先弹出确认对话框。
  Future<void> _selectEnvironmentAuthenticationType(
    BuildContext context,
    RequestAuthenticationType type,
  ) async {
    final l10n = AppLocalizations.of(context);
    final currentType = viewModel.activeEnvironment.authentication.type;
    // 目标类型与当前一致时无需任何处理
    if (currentType == type) return;
    // 从“无认证”切换时直接更新，无需二次确认
    if (currentType == RequestAuthenticationType.none) {
      viewModel.updateActiveEnvironmentAuthenticationType(type);
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
      viewModel.updateActiveEnvironmentAuthenticationType(type);
    }
  }
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
      color: AppColors.surfaceMid,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 900,
              child: _VariableTableHeader(l10n: l10n),
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
                      _EnvironmentVariableRow(
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
                                color: AppColors.textFaint,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                l10n.environmentVariables,
                                style: TextStyle(
                                  color: AppColors.textMuted,
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
              color: AppColors.surfaceLow,
              border: Border(top: BorderSide(color: AppColors.outline)),
            ),
            child: Row(
              children: [
                MonoText(
                  '${viewModel.variables.length} ${l10n.environmentVariables.toLowerCase()}',
                  color: AppColors.textMuted,
                  size: 10,
                ),
                const Spacer(),
                Icon(
                  Icons.history_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    l10n.environmentAuditNote,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
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

/// 变量表头行：固定各列的宽度与标签。
class _VariableTableHeader extends StatelessWidget {
  /// 构造变量表头。
  const _VariableTableHeader({required this.l10n});

  /// 本地化资源。
  final AppLocalizations l10n;

  /// 构建变量表头行。
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: MonoText(l10n.scope, color: AppColors.textMuted, size: 10),
          ),
          SizedBox(
            width: 230,
            child: MonoText(
              l10n.variableName,
              color: AppColors.textMuted,
              size: 10,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: MonoText(
              l10n.currentValue,
              color: AppColors.textMuted,
              size: 10,
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 114,
            child: MonoText(l10n.type, color: AppColors.textMuted, size: 10),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

/// 变量作用域标签：Global 与本地作用域使用不同配色。
class _ScopeLabel extends StatelessWidget {
  /// 构造作用域标签。
  const _ScopeLabel({required this.scope});

  /// 作用域名（如 Global）。
  final String scope;

  /// 构建作用域标签。
  @override
  Widget build(BuildContext context) {
    final isGlobal = scope == 'Global';
    final color = isGlobal ? AppColors.textMuted : AppColors.primary;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 112),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(3),
        ),
        child: MonoText(scope, color: color, size: 10),
      ),
    );
  }
}

/// 生成统一的变量输入框装饰，可指定可选提示文本。
InputDecoration _variableInputDecoration([String? hintText]) {
  return InputDecoration(hintText: hintText);
}

/// 数字输入格式器：仅允许合法的十进制数字（含负数与小数）。
final _numberInputFormatter = TextInputFormatter.withFunction((
  oldValue,
  value,
) {
  final text = value.text;
  return text.isEmpty || RegExp(r'^-?(?:\d+)?(?:\.\d*)?$').hasMatch(text)
      ? value
      : oldValue;
});

/// 环境变量行：支持编辑变量名/值、切换类型与删除。
class _EnvironmentVariableRow extends StatelessWidget {
  /// 构造环境变量行。
  const _EnvironmentVariableRow({
    required this.variable,
    required this.onChanged,
    required this.onToggleSecret,
    required this.onRemove,
  });

  /// 当前环境变量的展示数据。
  final EnvironmentVariableView variable;

  /// 字段变更回调（key/value/type 任一修改时触发）。
  final void Function({
    String? key,
    String? value,
    EnvironmentVariableType? type,
  })
  onChanged;

  /// 切换密钥可见性回调（非密钥变量为 null）。
  final VoidCallback? onToggleSecret;

  /// 删除该变量回调；受保护的 token 不提供该操作。
  final VoidCallback? onRemove;

  /// 构建环境变量行：各列字段编辑器与操作按钮。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: variable.isAuthenticationBinding
            ? AppColors.primaryContainer.withValues(alpha: 0.10)
            : null,
        border: Border(top: BorderSide(color: AppColors.outline)),
        borderRadius: variable.isAuthenticationBinding
            ? BorderRadius.circular(2)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(width: 132, child: _ScopeLabel(scope: variable.scope)),
          SizedBox(
            width: 230,
            child: Row(
              children: [
                if (variable.isAuthenticationBinding) ...[
                  Tooltip(
                    message: l10n.configureEnvironmentAuthentication,
                    child: Container(
                      key: ValueKey('environment-auth-binding-${variable.id}'),
                      height: 22,
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.34),
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: MonoText(
                        l10n.authorization,
                        color: AppColors.primary,
                        size: 9,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: TextFormField(
                    key: ValueKey('environment-key-${variable.id}'),
                    initialValue: variable.key,
                    readOnly:
                        variable.isProtected ||
                        variable.isRequired ||
                        variable.isAuthenticationBinding,
                    onChanged:
                        variable.isProtected ||
                            variable.isRequired ||
                            variable.isAuthenticationBinding
                        ? null
                        : (value) => onChanged(key: value),
                    style: TextStyle(
                      color: AppColors.text,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                    ),
                    decoration: _variableInputDecoration(l10n.variableName)
                        .copyWith(
                          suffixIcon:
                              variable.isProtected ||
                                  variable.isRequired ||
                                  variable.isAuthenticationBinding
                              ? Tooltip(
                                  message: variable.isRequired
                                      ? l10n.requiredEnvironmentBaseUrl
                                      : variable.isProtected
                                      ? l10n.requiredTokenVariable
                                      : l10n.configureEnvironmentAuthentication,
                                  child: Icon(
                                    variable.isRequired || variable.isProtected
                                        ? Icons.lock_outline
                                        : Icons.link_outlined,
                                    size: 15,
                                    color: AppColors.textMuted,
                                  ),
                                )
                              : null,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: variable.type == EnvironmentVariableType.boolean
                      ? _BooleanValueControl(
                          key: ValueKey('environment-boolean-${variable.id}'),
                          value: variable.displayValue == 'true',
                          onChanged: (value) => onChanged(value: '$value'),
                        )
                      : TextFormField(
                          key: ValueKey(
                            'environment-value-${variable.id}-${variable.isMasked}',
                          ),
                          initialValue: variable.displayValue,
                          obscureText: variable.isMasked,
                          readOnly: variable.isMasked,
                          keyboardType:
                              variable.type == EnvironmentVariableType.number
                              ? const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                )
                              : TextInputType.text,
                          inputFormatters:
                              variable.type == EnvironmentVariableType.number
                              ? [_numberInputFormatter]
                              : null,
                          onChanged: variable.isMasked
                              ? null
                              : (value) => onChanged(value: value),
                          // 密钥变量使用警示色突出显示，避免误改。
                          style: TextStyle(
                            color: variable.isSecret
                                ? AppColors.warning
                                : AppColors.text,
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                          ),
                          decoration: _variableInputDecoration(
                            l10n.variableValue,
                          ),
                        ),
                ),
                if (onToggleSecret != null)
                  DenseIconButton(
                    icon: Icons.visibility_outlined,
                    tooltip: l10n.toggleSecretVisibility,
                    onPressed: onToggleSecret,
                    size: 36,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // 类型选择下拉框：从枚举中挑选并同步到视图模型。
          SizedBox(
            width: 114,
            child:
                variable.isProtected ||
                    variable.isRequired ||
                    variable.isAuthenticationBinding
                ? Tooltip(
                    message: variable.isRequired
                        ? l10n.requiredEnvironmentBaseUrl
                        : variable.isProtected
                        ? l10n.requiredTokenVariable
                        : l10n.configureEnvironmentAuthentication,
                    child: _VariableTypeDisplay(
                      type: variable.type,
                      locked: true,
                    ),
                  )
                : PopupMenuButton<EnvironmentVariableType>(
                    tooltip: l10n.changeVariableType,
                    onSelected: (type) => onChanged(type: type),
                    itemBuilder: (context) => [
                      for (final type in EnvironmentVariableType.values)
                        PopupMenuItem(
                          key: ValueKey('environment-type-${type.name}'),
                          value: type,
                          child: Text(type.localizedLabel(l10n)),
                        ),
                    ],
                    child: _VariableTypeDisplay(type: variable.type),
                  ),
          ),
          DenseIconButton(
            icon:
                variable.isProtected ||
                    variable.isRequired ||
                    variable.isAuthenticationBinding
                ? Icons.lock_outline
                : Icons.close,
            tooltip: variable.isRequired
                ? l10n.requiredEnvironmentBaseUrl
                : variable.isProtected
                ? l10n.requiredTokenVariable
                : variable.isAuthenticationBinding
                ? l10n.configureEnvironmentAuthentication
                : l10n.deleteVariable,
            onPressed: onRemove,
            size: 36,
          ),
        ],
      ),
    );
  }
}

/// 变量类型展示标签：可锁定（显示锁图标）或作为下拉触发入口。
class _VariableTypeDisplay extends StatelessWidget {
  /// 构造变量类型展示标签。
  const _VariableTypeDisplay({required this.type, this.locked = false});

  /// 当前展示的变量类型。
  final EnvironmentVariableType type;

  /// 是否锁定（受保护变量不可修改类型）。
  final bool locked;

  /// 构建变量类型展示标签。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: MonoText(
              type.localizedLabel(l10n),
              color: AppColors.primary,
            ),
          ),
          Icon(
            locked ? Icons.lock_outline : Icons.expand_more,
            size: locked ? 14 : 16,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

/// 布尔变量的值控件：标准输入框外观内嵌 Switch 切换开关。
class _BooleanValueControl extends StatelessWidget {
  /// 构造布尔值控件。
  const _BooleanValueControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// 当前布尔值。
  final bool value;

  /// 切换值时的回调。
  final ValueChanged<bool> onChanged;

  /// 构建布尔值控件。
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      // Boolean 保持标准输入框的外形，类型切换不改变值列的尺寸或边框。
      key: ValueKey('environment-boolean-value-$value'),
      initialValue: '$value',
      readOnly: true,
      enableInteractiveSelection: false,
      style: TextStyle(
        color: AppColors.text,
        fontFamily: 'JetBrains Mono',
        fontSize: 12,
      ),
      decoration: _variableInputDecoration().copyWith(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 5, right: 3),
          child: SizedBox(
            key: const ValueKey('environment-boolean-switch-compact'),
            width: 30,
            height: 22,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 38,
          maxWidth: 38,
          minHeight: 0,
          maxHeight: 28,
        ),
      ),
    );
  }
}
