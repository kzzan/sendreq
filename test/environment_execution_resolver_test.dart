import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/environments/environment_execution_resolver.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';

void main() {
  ResolveExecutionRequest requestFor(RequestDraft draft) =>
      ResolveExecutionRequest(
        executionId: 'execution-1',
        requestRef: const RequestRef(id: 'request-1'),
        draft: draft,
      );

  test(
    'resolves Environment templates and injects authentication only into payload',
    () async {
      final resolver = EnvironmentExecutionResolver(
        InMemoryEnvironmentStore.sample(),
      );
      const draft = RequestDraft(
        method: 'POST',
        baseUrlToken: '{{baseUrl}}',
        path: '/v1/{{token}}',
        params: [KeyValueRow(keyName: 'trace', value: '{{token}}')],
        headers: [KeyValueRow(keyName: 'X-Request', value: '{{token}}')],
        body: '{"token":"{{token}}"}',
        webSocket: WebSocketRequestConfiguration(
          subprotocols: ['sendreq.{{token}}'],
        ),
      );

      final command = await resolver.resolve(requestFor(draft));

      expect(command.payload.resolvedUrl, contains('staging-token-value'));
      expect(
        command.payload.headers['Authorization'],
        'Bearer staging-token-value',
      );
      expect(command.payload.draft.body, contains('staging-token-value'));
      expect(command.payload.draft.webSocket.subprotocols, [
        'sendreq.staging-token-value',
      ]);
      expect(
        command.sanitizedRequestSummary,
        isNot(contains('staging-token-value')),
      );
      expect(
        command.redactionPolicy.redact(command.payload.draft.body),
        isNot(contains('staging-token-value')),
      );
    },
  );

  test(
    'uses request authentication and replaces a duplicate API key query row',
    () async {
      final resolver = EnvironmentExecutionResolver(
        InMemoryEnvironmentStore.sample(),
      );
      const draft = RequestDraft(
        method: 'GET',
        baseUrlToken: '{{baseUrl}}',
        path: '/v1/widgets',
        params: [KeyValueRow(keyName: 'api_key', value: 'obsolete')],
        headers: [],
        body: '',
        authenticationSource: RequestAuthenticationSource.request,
        authentication: RequestAuthentication.apiKey(
          apiKeyName: 'api_key',
          apiKeyValue: '{{token}}',
          apiKeyLocation: ApiKeyLocation.query,
        ),
      );

      final command = await resolver.resolve(requestFor(draft));

      expect(
        command.payload.resolvedUrl,
        contains('api_key=staging-token-value'),
      );
      expect(command.payload.resolvedUrl, isNot(contains('obsolete')));
      expect(
        command.sanitizedRequestSummary,
        isNot(contains('staging-token-value')),
      );
    },
  );

  test(
    'resolves URL encoded fields into the exact redacted execution body',
    () async {
      final resolver = EnvironmentExecutionResolver(
        InMemoryEnvironmentStore.sample(),
      );
      const draft = RequestDraft(
        method: 'POST',
        baseUrlToken: '{{baseUrl}}',
        path: '/v1/login',
        params: [],
        headers: [
          KeyValueRow(
            keyName: 'Content-Type',
            value: 'application/x-www-form-urlencoded',
          ),
        ],
        body: 'obsolete {{notDefined}} raw request body',
        formUrlEncodedFields: [
          KeyValueRow(keyName: 'token', value: '{{token}}&scope', secret: true),
          KeyValueRow(keyName: 'scope', value: 'read write'),
          KeyValueRow(keyName: 'scope', value: 'audit'),
          KeyValueRow(
            keyName: 'disabled',
            value: '{{notDefined}}',
            enabled: false,
          ),
        ],
      );

      final command = await resolver.resolve(requestFor(draft));

      expect(
        command.payload.body,
        'token=staging-token-value%26scope&scope=read+write&scope=audit',
      );
      expect(
        command.payload.body,
        isNot(contains('obsolete raw request body')),
      );
      expect(command.payload.body, isNot(contains('disabled')));
      expect(
        command.redactionPolicy.redact(command.payload.body),
        'token=[redacted]&scope=read+write&scope=audit',
      );
    },
  );

  test(
    'rejects unresolved variables before producing an execution payload',
    () async {
      final resolver = EnvironmentExecutionResolver(
        InMemoryEnvironmentStore.sample(),
      );
      const draft = RequestDraft(
        method: 'GET',
        baseUrlToken: '{{baseUrl}}',
        path: '/{{notDefined}}',
        params: [],
        headers: [],
        body: '',
      );

      expect(
        () => resolver.resolve(requestFor(draft)),
        throwsA(
          isA<EnvironmentResolutionException>().having(
            (error) => error.missingKeys,
            'missingKeys',
            contains('notDefined'),
          ),
        ),
      );
    },
  );
}
