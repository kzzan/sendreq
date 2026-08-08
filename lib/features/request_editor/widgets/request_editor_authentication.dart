part of 'request_editor_panel.dart';

class _AuthEditor extends StatefulWidget {
  /// 构造鉴权编辑区。
  const _AuthEditor({required this.viewModel});

  /// 视图模型，提供认证来源/类型与凭据的读写能力。
  final WorkspaceViewModel viewModel;

  /// 创建鉴权编辑区状态。
  @override
  State<_AuthEditor> createState() => _AuthEditorState();
}

/// 鉴权编辑区状态：统一控制各凭据字段的显隐。
class _AuthEditorState extends State<_AuthEditor> {
  /// 是否临时显示秘密凭据（Bearer Token、Basic 密码、API Key 值）。
  var _isSecretVisible = false;

  /// 构建鉴权编辑区：认证来源 + 类型 + 对应凭据字段。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewModel = widget.viewModel;
    return DensePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(
            title: l10n.authorization,
            subtitle: l10n.authorizationAppliedAsHeader,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RequestAuthenticationSource>(
            key: const Key('request-authentication-source'),
            initialValue: viewModel.activeAuthenticationSource,
            decoration: InputDecoration(labelText: l10n.authenticationSource),
            items: [
              DropdownMenuItem(
                value: RequestAuthenticationSource.environment,
                child: Text(l10n.inheritEnvironmentAuthentication),
              ),
              DropdownMenuItem(
                value: RequestAuthenticationSource.request,
                child: Text(l10n.requestSpecificAuthentication),
              ),
            ],
            onChanged: (source) {
              if (source != null) {
                viewModel.setActiveAuthenticationSource(source);
              }
            },
          ),
          const SizedBox(height: 12),
          if (viewModel.activeAuthenticationSource ==
              RequestAuthenticationSource.environment)
            _InheritedAuthenticationSummary(viewModel: viewModel)
          else ...[
            DropdownButtonFormField<RequestAuthenticationType>(
              key: const Key('request-authentication-type'),
              initialValue: viewModel.activeAuthenticationType,
              decoration: InputDecoration(labelText: l10n.authenticationType),
              items: [
                for (final type in RequestAuthenticationType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(_authenticationTypeLabel(l10n, type)),
                  ),
              ],
              onChanged: (type) {
                if (type != null) viewModel.setActiveAuthenticationType(type);
              },
            ),
            const SizedBox(height: 16),
            if (viewModel.activeAuthenticationType ==
                RequestAuthenticationType.bearer) ...[
              Text(l10n.token, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('request-bearer-token-input'),
                initialValue: viewModel.activeBearerToken,
                obscureText:
                    !_isSecretVisible &&
                    !_isEnvironmentReference(viewModel.activeBearerToken),
                onChanged: viewModel.updateActiveBearerToken,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).pasteBearerToken,
                  prefixIcon: Icon(Icons.key_outlined, size: 18),
                  suffixIcon:
                      _isEnvironmentReference(viewModel.activeBearerToken)
                      ? null
                      : IconButton(
                          tooltip: _isSecretVisible
                              ? l10n.hideValue
                              : l10n.revealValue,
                          icon: Icon(
                            _isSecretVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          onPressed: () => setState(
                            () => _isSecretVisible = !_isSecretVisible,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context).bearerTokenStored,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ] else if (viewModel.activeAuthenticationType ==
                RequestAuthenticationType.basic) ...[
              TextFormField(
                key: const Key('request-basic-username-input'),
                initialValue: viewModel.activeBasicUsername,
                onChanged: (value) =>
                    viewModel.updateActiveBasicAuthentication(username: value),
                decoration: InputDecoration(
                  labelText: l10n.username,
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('request-basic-password-input'),
                initialValue: viewModel.activeBasicPassword,
                obscureText:
                    !_isSecretVisible &&
                    !_isEnvironmentReference(viewModel.activeBasicPassword),
                onChanged: (value) =>
                    viewModel.updateActiveBasicAuthentication(password: value),
                decoration: InputDecoration(
                  labelText: l10n.password,
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  suffixIcon:
                      _isEnvironmentReference(viewModel.activeBasicPassword)
                      ? null
                      : IconButton(
                          tooltip: _isSecretVisible
                              ? l10n.hideValue
                              : l10n.revealValue,
                          icon: Icon(
                            _isSecretVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          onPressed: () => setState(
                            () => _isSecretVisible = !_isSecretVisible,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.basicAuthenticationStored,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ] else if (viewModel.activeAuthenticationType ==
                RequestAuthenticationType.apiKey) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('request-api-key-name-input'),
                      initialValue: viewModel.activeApiKeyName,
                      onChanged: (value) => viewModel
                          .updateActiveApiKeyAuthentication(name: value),
                      decoration: InputDecoration(labelText: l10n.apiKeyName),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<ApiKeyLocation>(
                      key: const Key('request-api-key-location'),
                      initialValue: viewModel.activeApiKeyLocation,
                      decoration: InputDecoration(labelText: l10n.sendIn),
                      items: [
                        DropdownMenuItem(
                          value: ApiKeyLocation.header,
                          child: Text(l10n.requestHeaders),
                        ),
                        DropdownMenuItem(
                          value: ApiKeyLocation.query,
                          child: Text(l10n.queryParameters),
                        ),
                      ],
                      onChanged: (location) {
                        if (location != null) {
                          viewModel.updateActiveApiKeyAuthentication(
                            location: location,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('request-api-key-value-input'),
                initialValue: viewModel.activeApiKeyValue,
                obscureText:
                    !_isSecretVisible &&
                    !_isEnvironmentReference(viewModel.activeApiKeyValue),
                onChanged: (value) =>
                    viewModel.updateActiveApiKeyAuthentication(value: value),
                decoration: InputDecoration(
                  labelText: l10n.apiKeyValue,
                  prefixIcon: const Icon(Icons.key_outlined, size: 18),
                  suffixIcon:
                      _isEnvironmentReference(viewModel.activeApiKeyValue)
                      ? null
                      : IconButton(
                          tooltip: _isSecretVisible
                              ? l10n.hideValue
                              : l10n.revealValue,
                          icon: Icon(
                            _isSecretVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          onPressed: () => setState(
                            () => _isSecretVisible = !_isSecretVisible,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.apiKeyAuthenticationStored,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ] else
              Text(
                AppLocalizations.of(context).noAuthorizationHeader,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }
}

/// 继承环境鉴权时的只读摘要：展示来源环境与生效的认证类型。
class _InheritedAuthenticationSummary extends StatelessWidget {
  /// 构造继承鉴权摘要。
  const _InheritedAuthenticationSummary({required this.viewModel});

  /// 视图模型，提供当前认证类型与环境信息。
  final WorkspaceViewModel viewModel;

  /// 构建摘要卡片：链接图标 + 认证类型 + 当前环境 + 配置入口。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.link_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _authenticationTypeLabel(
                    l10n,
                    viewModel.activeAuthenticationType,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.activeEnvironment}: ${viewModel.activeEnvironment.name}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          DenseIconButton(
            icon: Icons.tune_outlined,
            tooltip: l10n.configureEnvironmentAuthentication,
            onPressed: viewModel.openEnvironmentForActiveRequest,
            size: 30,
          ),
        ],
      ),
    );
  }
}

/// 将认证类型枚举映射为本地化标签文本。
String _authenticationTypeLabel(
  AppLocalizations l10n,
  RequestAuthenticationType type,
) => switch (type) {
  RequestAuthenticationType.none => l10n.noAuth,
  RequestAuthenticationType.bearer => l10n.bearerToken,
  RequestAuthenticationType.basic => l10n.basicAuth,
  RequestAuthenticationType.apiKey => l10n.apiKey,
};

/// 环境变量引用只暴露变量名，不包含真实密钥，保持可读便于核对配置。
bool _isEnvironmentReference(String value) => RegExp(
  r'^\s*(?:Bearer\s+)?\{\{[^{}]+\}\}\s*$',
  caseSensitive: false,
).hasMatch(value);
