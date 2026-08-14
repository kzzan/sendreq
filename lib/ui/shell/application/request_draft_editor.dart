import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';

/// M2 请求草稿编辑规则；不持有 UI、存储或传输依赖。
class RequestDraftEditor {
  const RequestDraftEditor();

  RequestDraft replaceUrl({
    required RequestDraft draft,
    required String url,
    required String Function() nextParameterId,
    required Iterable<String> environmentVariableKeys,
  }) {
    final parts = splitUrl(url);
    return draft.copyWith(
      baseUrlToken: parts.baseUrlToken,
      path: parts.path,
      params: [
        for (final parameter in parts.parameters)
          KeyValueRow(
            id: nextParameterId(),
            keyName: parameter.key,
            value: normalizeParameterReference(
              parameter.value,
              environmentVariableKeys,
            ),
          ),
      ],
    );
  }

  DraftUrlParts splitUrl(String url) {
    final fragmentIndex = url.indexOf('#');
    final fragment = fragmentIndex < 0 ? '' : url.substring(fragmentIndex);
    final withoutFragment = fragmentIndex < 0
        ? url
        : url.substring(0, fragmentIndex);
    final queryIndex = withoutFragment.indexOf('?');
    final location = queryIndex < 0
        ? withoutFragment
        : withoutFragment.substring(0, queryIndex);
    final rawQuery = queryIndex < 0
        ? ''
        : withoutFragment.substring(queryIndex + 1);
    final tokenEnd = location.startsWith('{{') ? location.indexOf('}}') : -1;
    if (tokenEnd >= 0) {
      return DraftUrlParts(
        baseUrlToken: location.substring(0, tokenEnd + 2),
        path: '${location.substring(tokenEnd + 2)}$fragment',
        parameters: _queryParameters(rawQuery),
      );
    }
    final absolute = Uri.tryParse(location);
    if (absolute != null && absolute.hasScheme && absolute.hasAuthority) {
      return DraftUrlParts(
        baseUrlToken: '${absolute.scheme}://${absolute.authority}',
        path: '${absolute.path}$fragment',
        parameters: _queryParameters(rawQuery),
      );
    }
    return DraftUrlParts(
      baseUrlToken: '',
      path: '$location$fragment',
      parameters: _queryParameters(rawQuery),
    );
  }

  String normalizeParameterReference(String value, Iterable<String> keys) {
    final match = RegExp(
      r'^\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}$',
    ).firstMatch(value);
    if (match == null) return value;
    final inputKey = match.group(1)!;
    for (final key in keys) {
      if (key.toLowerCase() == inputKey.toLowerCase()) return '{{$key}}';
    }
    return '{{$inputKey}}';
  }

  RequestDraft normalize(RequestDraft draft) {
    final schema = draft.grpc.protoSchema;
    return draft.copyWith(
      method: draft.method.trim(),
      baseUrlToken: draft.baseUrlToken.trim(),
      path: draft.path.trim(),
      body: draft.body.trim(),
      params: _trimRows(draft.params),
      headers: _trimRows(draft.headers),
      formUrlEncodedFields: _trimRows(draft.formUrlEncodedFields),
      multipartFields: _trimRows(draft.multipartFields),
      multipartFiles: [
        for (final file in draft.multipartFiles)
          file.copyWith(keyName: file.keyName.trim()),
      ],
      authentication: _trimAuthentication(draft.authentication),
      webSocket: draft.webSocket.copyWith(
        subprotocols: [
          for (final value in draft.webSocket.subprotocols)
            if (value.trim().isNotEmpty) value.trim(),
        ],
      ),
      grpc: draft.grpc.copyWith(
        protoSchema: schema?.copyWith(
          path: schema.path.trim(),
          fingerprint: schema.fingerprint.trim(),
          messageType: schema.messageType?.trim(),
        ),
        serviceName: draft.grpc.serviceName?.trim(),
        methodName: draft.grpc.methodName?.trim(),
      ),
    );
  }

  List<DraftUrlQueryParameter> _queryParameters(String query) => [
    for (final entry in query.split('&'))
      if (entry.isNotEmpty)
        DraftUrlQueryParameter(
          key: Uri.decodeQueryComponent(entry.split('=').first),
          value: entry.contains('=')
              ? Uri.decodeQueryComponent(
                  entry.substring(entry.indexOf('=') + 1),
                )
              : '',
        ),
  ];

  List<KeyValueRow> _trimRows(List<KeyValueRow> rows) => [
    for (final row in rows)
      row.copyWith(keyName: row.keyName.trim(), value: row.value.trim()),
  ];

  RequestAuthentication _trimAuthentication(RequestAuthentication value) =>
      switch (value.type) {
        RequestAuthenticationType.none => const RequestAuthentication.none(),
        RequestAuthenticationType.bearer => RequestAuthentication.bearer(
          value.bearerToken.trim(),
        ),
        RequestAuthenticationType.basic => RequestAuthentication.basic(
          username: value.username.trim(),
          password: value.password.trim(),
        ),
        RequestAuthenticationType.apiKey => RequestAuthentication.apiKey(
          apiKeyName: value.apiKeyName.trim(),
          apiKeyValue: value.apiKeyValue.trim(),
          apiKeyLocation: value.apiKeyLocation,
        ),
      };
}

class DraftUrlParts {
  const DraftUrlParts({
    required this.baseUrlToken,
    required this.path,
    required this.parameters,
  });
  final String baseUrlToken;
  final String path;
  final List<DraftUrlQueryParameter> parameters;
}

class DraftUrlQueryParameter {
  const DraftUrlQueryParameter({required this.key, required this.value});
  final String key;
  final String value;
}
