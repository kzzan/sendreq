import 'dart:convert';

import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/request_runtime/form_url_encoding.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/repositories/environment_store.dart';

/// 当某个 Environment 模板无法解析时，在执行前抛出。
class EnvironmentResolutionException implements Exception {
  const EnvironmentResolutionException(this.missingKeys);

  final List<String> missingKeys;

  @override
  String toString() =>
      'Missing environment variables: ${missingKeys.join(', ')}';
}

/// 负责模板、认证与脱敏的环境应用服务。
class EnvironmentExecutionResolver implements EnvironmentResolver {
  EnvironmentExecutionResolver(this._store);

  final EnvironmentStore _store;

  @override
  Future<ResolvedExecutionCommand> resolve(
    ResolveExecutionRequest request,
  ) async {
    final draft = request.draft;
    final authentication = _effectiveAuthentication(draft);
    final missingKeys = _missingKeys(draft, authentication);
    if (missingKeys.isNotEmpty) {
      throw EnvironmentResolutionException(missingKeys);
    }
    final resolvedAuthentication = _resolveAuthentication(authentication);
    final authenticationDraft = draft.copyWith(
      authentication: resolvedAuthentication,
      authenticationSource: RequestAuthenticationSource.request,
    );
    final resolvedDraft = authenticationDraft.copyWith(
      baseUrlToken: _resolve(draft.baseUrlToken),
      path: _resolve(draft.path),
      params: [
        for (final item in _paramsWithAuthentication(authenticationDraft))
          item.copyWith(
            keyName: _resolve(item.keyName),
            value: _resolve(item.value),
          ),
      ],
      headers: [
        for (final header in _headersWithAuthentication(authenticationDraft))
          header.copyWith(
            keyName: _resolve(header.keyName),
            value: _resolve(header.value),
          ),
      ],
      body: _resolve(draft.body),
      formUrlEncodedFields: [
        for (final field in draft.formUrlEncodedFields)
          field.copyWith(
            keyName: _resolve(field.keyName),
            value: _resolve(field.value),
          ),
      ],
      multipartFields: [
        for (final field in draft.multipartFields)
          field.copyWith(
            keyName: _resolve(field.keyName),
            value: _resolve(field.value),
          ),
      ],
      multipartFiles: [
        for (final file in draft.multipartFiles)
          file.copyWith(keyName: _resolve(file.keyName)),
      ],
      webSocket: draft.webSocket.copyWith(
        subprotocols: [
          for (final value in draft.webSocket.subprotocols) _resolve(value),
        ],
      ),
    );
    final policy = RedactionPolicy([
      ..._resolvedEnvironmentSecretValues(),
      ..._authenticationSecretValues(resolvedAuthentication),
      for (final header in resolvedDraft.headers)
        if (header.enabled && header.secret) header.value,
      for (final parameter in resolvedDraft.params)
        if (parameter.enabled && parameter.secret) parameter.value,
      for (final field in resolvedDraft.formUrlEncodedFields)
        if (field.enabled && field.secret) ...[
          field.value,
          encodeFormUrlComponent(field.value),
        ],
      for (final field in resolvedDraft.multipartFields)
        if (field.enabled && field.secret) field.value,
    ]);
    final resolvedUrl = _resolvedUrl(resolvedDraft);
    return ResolvedExecutionCommand(
      executionId: request.executionId,
      requestRef: request.requestRef,
      environmentRef:
          request.environmentRef ??
          ResourceRef(
            kind: ResourceKind.environment,
            id: _store.activeEnvironment.id,
          ),
      environmentName: _store.activeEnvironment.name,
      payload: ExecutionPayload(
        method: resolvedDraft.method,
        resolvedUrl: resolvedUrl,
        draft: resolvedDraft,
        headers: {
          for (final header in resolvedDraft.headers)
            if (header.enabled && header.keyName.trim().isNotEmpty)
              header.keyName: header.value,
        },
        body: _executionBody(resolvedDraft),
      ),
      sanitizedRequestSummary:
          '${resolvedDraft.method} ${policy.redact(resolvedUrl)}',
      redactionPolicy: policy,
    );
  }

  RequestAuthentication _effectiveAuthentication(RequestDraft draft) =>
      draft.authenticationSource == RequestAuthenticationSource.environment
      ? _store.activeEnvironment.authentication
      : draft.authentication;

  List<String> _missingKeys(
    RequestDraft draft,
    RequestAuthentication authentication,
  ) {
    final missing = <String>{};
    for (final template in [
      draft.baseUrlToken,
      draft.path,
      if (!_usesStructuredForm(draft)) draft.body,
      ...authentication.templateValues,
      for (final row in draft.params.where((row) => row.enabled)) row.keyName,
      for (final row in draft.params.where((row) => row.enabled)) row.value,
      for (final row in draft.headers.where((row) => row.enabled)) row.keyName,
      for (final row in draft.headers.where((row) => row.enabled)) row.value,
      for (final row in draft.formUrlEncodedFields.where((row) => row.enabled))
        row.keyName,
      for (final row in draft.formUrlEncodedFields.where((row) => row.enabled))
        row.value,
      for (final row in draft.multipartFields.where((row) => row.enabled))
        row.keyName,
      for (final row in draft.multipartFields.where((row) => row.enabled))
        row.value,
      for (final row in draft.multipartFiles.where((row) => row.enabled))
        row.keyName,
    ]) {
      missing.addAll(_store.resolveTemplate(template).missingKeys);
    }
    return missing.toList(growable: false);
  }

  String _resolve(String template) =>
      _store.resolveTemplate(template).executionValue;

  RequestAuthentication _resolveAuthentication(
    RequestAuthentication authentication,
  ) => authentication.copyWith(
    bearerToken: _resolve(authentication.bearerToken),
    username: _resolve(authentication.username),
    password: _resolve(authentication.password),
    apiKeyName: _resolve(authentication.apiKeyName),
    apiKeyValue: _resolve(authentication.apiKeyValue),
  );

  List<KeyValueRow> _headersWithAuthentication(RequestDraft draft) {
    final authentication = draft.authentication;
    final headers = [
      for (final header in draft.headers)
        if (!authentication.usesAuthorizationHeader ||
            header.keyName.toLowerCase() != 'authorization')
          if (!authentication.apiKeyInHeader ||
              header.keyName.toLowerCase() !=
                  authentication.apiKeyName.toLowerCase())
            header,
    ];
    if (authentication.usesBearerToken) {
      headers.add(
        KeyValueRow(
          id: 'authentication-bearer',
          keyName: 'Authorization',
          value: 'Bearer ${authentication.bearerToken}',
          secret: true,
        ),
      );
    }
    if (authentication.usesBasicAuthentication) {
      headers.add(
        KeyValueRow(
          id: 'authentication-basic',
          keyName: 'Authorization',
          value:
              'Basic ${base64Encode(utf8.encode('${authentication.username}:${authentication.password}'))}',
          secret: true,
        ),
      );
    }
    if (authentication.apiKeyInHeader &&
        authentication.apiKeyName.trim().isNotEmpty) {
      headers.add(
        KeyValueRow(
          id: 'authentication-api-key-header',
          keyName: authentication.apiKeyName,
          value: authentication.apiKeyValue,
          secret: true,
        ),
      );
    }
    return headers;
  }

  List<KeyValueRow> _paramsWithAuthentication(RequestDraft draft) {
    final authentication = draft.authentication;
    final params = [
      for (final parameter in draft.params)
        if (!authentication.apiKeyInQuery ||
            parameter.keyName.toLowerCase() !=
                authentication.apiKeyName.toLowerCase())
          parameter,
    ];
    if (authentication.apiKeyInQuery &&
        authentication.apiKeyName.trim().isNotEmpty) {
      params.add(
        KeyValueRow(
          id: 'authentication-api-key-query',
          keyName: authentication.apiKeyName,
          value: authentication.apiKeyValue,
          secret: true,
        ),
      );
    }
    return params;
  }

  String _resolvedUrl(RequestDraft draft) {
    final uri = Uri.parse('${draft.baseUrlToken}${draft.path}');
    final query = <String, List<String>>{
      for (final entry in uri.queryParametersAll.entries)
        entry.key: List<String>.of(entry.value),
    };
    for (final parameter in draft.params.where(
      (item) => item.enabled && item.keyName.trim().isNotEmpty,
    )) {
      query.putIfAbsent(parameter.keyName, () => []).add(parameter.value);
    }
    // `Uri.replace(queryParameters: const {})` 会产生一个尾随 `?`。空查询
    // 必须保持为无查询的规范 URL，避免传输层把它当作不同的请求目标。
    if (query.isEmpty) return uri.replace(query: null).toString();
    return uri.replace(queryParameters: query).toString();
  }

  String _executionBody(RequestDraft draft) => _usesUrlEncodedForm(draft)
      ? encodeFormUrlFields(draft.formUrlEncodedFields)
      : draft.body;

  bool _usesUrlEncodedForm(RequestDraft draft) => draft.headers.any(
    (header) =>
        header.enabled &&
        header.keyName.toLowerCase() == 'content-type' &&
        header.value.toLowerCase().startsWith(
          'application/x-www-form-urlencoded',
        ),
  );

  bool _usesStructuredForm(RequestDraft draft) =>
      _usesUrlEncodedForm(draft) ||
      draft.headers.any(
        (header) =>
            header.enabled &&
            header.keyName.toLowerCase() == 'content-type' &&
            header.value.toLowerCase().startsWith('multipart/form-data'),
      );

  List<String> _resolvedEnvironmentSecretValues() => [
    for (final variable in _store.listVariables())
      if (variable.isSecret)
        _store.resolveTemplate('{{${variable.key}}}').executionValue,
  ];

  List<String> _authenticationSecretValues(RequestAuthentication auth) =>
      switch (auth.type) {
        RequestAuthenticationType.bearer => [auth.bearerToken],
        RequestAuthenticationType.basic => [auth.username, auth.password],
        RequestAuthenticationType.apiKey => [auth.apiKeyValue],
        RequestAuthenticationType.none => const [],
      };
}
