import 'package:sendreq/domain/authentication/request_authentication.dart';

/// Environment authentication templates shared by editing and persistence.
abstract final class EnvironmentAuthenticationPolicy {
  static const removableVariableKeys = {
    AuthenticationVariableNames.basicUsername,
    AuthenticationVariableNames.basicPassword,
    AuthenticationVariableNames.apiKey,
  };

  static const allVariableKeys = {
    AuthenticationVariableNames.bearerToken,
    ...removableVariableKeys,
  };

  static RequestAuthentication forType(
    RequestAuthentication current,
    RequestAuthenticationType type,
  ) => switch (type) {
    RequestAuthenticationType.none => const RequestAuthentication.none(),
    RequestAuthenticationType.bearer => RequestAuthentication.bearer(
      current.bearerToken.isNotEmpty
          ? current.bearerToken
          : '{{${AuthenticationVariableNames.bearerToken}}}',
    ),
    RequestAuthenticationType.basic => RequestAuthentication.basic(
      username: current.username.isNotEmpty
          ? current.username
          : '{{${AuthenticationVariableNames.basicUsername}}}',
      password: current.password.isNotEmpty
          ? current.password
          : '{{${AuthenticationVariableNames.basicPassword}}}',
    ),
    RequestAuthenticationType.apiKey => RequestAuthentication.apiKey(
      apiKeyName: current.apiKeyName.isNotEmpty
          ? current.apiKeyName
          : AuthenticationVariableNames.defaultApiKeyHeader,
      apiKeyValue: current.apiKeyValue.isNotEmpty
          ? current.apiKeyValue
          : '{{${AuthenticationVariableNames.apiKey}}}',
      apiKeyLocation: current.apiKeyLocation,
    ),
  };

  static RequestAuthentication normalize(RequestAuthentication value) =>
      switch (value.type) {
        RequestAuthenticationType.none => const RequestAuthentication.none(),
        RequestAuthenticationType.bearer => const RequestAuthentication.bearer(
          '{{${AuthenticationVariableNames.bearerToken}}}',
        ),
        RequestAuthenticationType.basic => const RequestAuthentication.basic(
          username: '{{${AuthenticationVariableNames.basicUsername}}}',
          password: '{{${AuthenticationVariableNames.basicPassword}}}',
        ),
        RequestAuthenticationType.apiKey => RequestAuthentication.apiKey(
          apiKeyName: value.apiKeyName.trim().isEmpty
              ? AuthenticationVariableNames.defaultApiKeyHeader
              : value.apiKeyName,
          apiKeyValue: '{{${AuthenticationVariableNames.apiKey}}}',
          apiKeyLocation: value.apiKeyLocation,
        ),
      };

  static Set<String> referencedVariableKeys(RequestAuthentication value) => {
    for (final template in value.templateValues)
      ...RegExp(
        r'\{\{\s*([^}]+?)\s*\}\}',
      ).allMatches(template).map((match) => match.group(1)!.trim()),
  };
}
