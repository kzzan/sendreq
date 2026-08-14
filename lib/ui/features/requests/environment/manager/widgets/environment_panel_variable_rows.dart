import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sendreq/domain/environments/environment_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/l10n/workspace_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/workspace_form_controls.dart';

/// 变量表头行：固定各列的宽度与标签。
class EnvironmentVariableTableHeader extends StatelessWidget {
  /// 构造变量表头。
  const EnvironmentVariableTableHeader({super.key, required this.l10n});

  /// 本地化资源。
  final AppLocalizations l10n;

  /// 构建变量表头行。
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: context.chakra.bgEmphasized,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: MonoText(
              l10n.scope,
              color: context.chakra.fgMuted,
              size: 10,
            ),
          ),
          SizedBox(
            width: 230,
            child: MonoText(
              l10n.variableName,
              color: context.chakra.fgMuted,
              size: 10,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: MonoText(
              l10n.currentValue,
              color: context.chakra.fgMuted,
              size: 10,
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 114,
            child: MonoText(l10n.type, color: context.chakra.fgMuted, size: 10),
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
    final color = isGlobal
        ? context.chakra.fgMuted
        : context.chakra.colorPaletteFg;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 112),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: ChakraRadii.control,
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
class EnvironmentVariableRow extends StatelessWidget {
  /// 构造环境变量行。
  const EnvironmentVariableRow({
    super.key,
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
            ? context.chakra.colorPaletteSolid.withValues(alpha: 0.10)
            : null,
        border: Border(top: BorderSide(color: context.chakra.border)),
        borderRadius: variable.isAuthenticationBinding
            ? ChakraRadii.control
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
                        color: context.chakra.colorPaletteFg.withValues(
                          alpha: 0.14,
                        ),
                        border: Border.all(
                          color: context.chakra.colorPaletteFg.withValues(
                            alpha: 0.34,
                          ),
                        ),
                        borderRadius: ChakraRadii.control,
                      ),
                      child: MonoText(
                        l10n.authorization,
                        color: context.chakra.colorPaletteFg,
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
                      color: context.chakra.fg,
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
                                    color: context.chakra.fgMuted,
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
                                ? context.chakra.warning
                                : context.chakra.fg,
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
        color: context.chakra.bgSubtle,
        border: Border.all(color: context.chakra.border),
        borderRadius: ChakraRadii.control,
      ),
      child: Row(
        children: [
          Expanded(
            child: MonoText(
              type.localizedLabel(l10n),
              color: context.chakra.colorPaletteFg,
            ),
          ),
          Icon(
            locked ? Icons.lock_outline : Icons.expand_more,
            size: locked ? 14 : 16,
            color: context.chakra.fgMuted,
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
  Widget build(BuildContext context) => InlineSwitch(
    key: ValueKey('environment-boolean-value-$value'),
    label: '$value',
    value: value,
    onChanged: onChanged,
  );
}
