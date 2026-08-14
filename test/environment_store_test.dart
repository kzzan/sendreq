import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/environments/environment_models.dart';

void main() {
  test(
    'active environment overrides global values and Secrets stay masked',
    () {
      final store = InMemoryEnvironmentStore.sample();

      // 默认活动环境（staging）的变量应覆盖全局值并参与模板解析。
      expect(
        store.resolveTemplate('{{baseUrl}}').executionValue,
        'https://staging.sendreq.io',
      );
      // 密钥变量对外只暴露掩码，绝不泄露明文值。
      expect(
        store
            .listVariables()
            .singleWhere((value) => value.key == 'token')
            .displayValue,
        '••••••••••••••••',
      );

      // 切换活动环境后，同一模板应解析为生产环境的地址。
      store.setActiveEnvironment('production');
      expect(
        store.resolveTemplate('{{baseUrl}}').executionValue,
        'https://api.sendreq.io',
      );
    },
  );

  // 验证缺失变量时模板解析给出可诊断的结果：标记为缺失并列出缺失键，
  // 同时展示值保留原始占位符形态，便于用户定位。
  test('missing template variables retain a safe diagnostic', () {
    final result = InMemoryEnvironmentStore.sample().resolveTemplate(
      '{{baseUrl}}/{{missing}}',
    );

    expect(result.status, TemplateResolutionStatus.missingVariable);
    expect(result.missingKeys, ['missing']);
    expect(result.displayValue, '{{baseUrl}}/{{missing}}');
  });

  // 空白变量虽然已创建，但不能作为请求执行值；应与未定义变量一样阻止解析。
  test(
    'blank environment variables are unavailable for template resolution',
    () {
      final store = InMemoryEnvironmentStore.sample();
      final token = store.listVariables().singleWhere(
        (value) => value.key == 'token',
      );
      store.updateVariable(id: token.id, value: '   ');

      final result = store.resolveTemplate('Bearer {{token}}');

      expect(result.status, TemplateResolutionStatus.missingVariable);
      expect(result.missingKeys, ['token']);
      expect(result.executionValue, 'Bearer {{token}}');
    },
  );

  // 验证密钥的“显示/隐藏”切换、变量编辑与新增，以及显式保存后才清除未保存标记。
  test('environment variables can be edited, revealed, and saved', () async {
    final store = InMemoryEnvironmentStore.sample();
    final token = store.listVariables().singleWhere(
      (value) => value.key == 'token',
    );

    // 切换可见性后应能读取到明文 token 值。
    store.toggleSecretVisibility(token.id);
    expect(
      store
          .listVariables()
          .singleWhere((value) => value.id == token.id)
          .displayValue,
      'staging-token-value',
    );

    // 修改 token 并新增变量，此时应处于“有未保存修改”状态。
    store.updateVariable(id: token.id, value: 'replaced-token');
    store.addVariable();
    expect(store.hasUnsavedChanges, isTrue);
    expect(store.listVariables(), hasLength(4));

    // 显式保存后未保存标记应被清除。
    await store.saveChanges();
    expect(store.hasUnsavedChanges, isFalse);
  });

  test('global variables can be added and resolve in every environment', () {
    final store = InMemoryEnvironmentStore.sample();

    store.addGlobalVariable();
    final global = store.listVariables().singleWhere(
      (value) => value.id == 'variable-1',
    );
    expect(global.scope, 'Global');

    store.updateVariable(id: global.id, key: 'region', value: 'cn-north-1');
    expect(store.resolveTemplate('{{region}}').executionValue, 'cn-north-1');
    store.setActiveEnvironment('production');
    expect(store.resolveTemplate('{{region}}').executionValue, 'cn-north-1');
  });

  test(
    'switching environments is immediate but does not create edits',
    () async {
      final store = InMemoryEnvironmentStore.sample();

      await store.setActiveEnvironment('production');

      expect(store.activeEnvironment.id, 'production');
      expect(store.hasUnsavedChanges, isFalse);
    },
  );

  test(
    'discard restores saved configuration and keeps a valid selection',
    () async {
      final store = InMemoryEnvironmentStore.sample();
      final stagingBaseUrl = store.listVariables().singleWhere(
        (variable) => variable.id == 'staging-base-url',
      );
      store.updateVariable(id: stagingBaseUrl.id, value: 'https://draft.test');
      await store.setActiveEnvironment('production');

      store.discardChanges();

      expect(store.activeEnvironment.id, 'production');
      expect(store.hasUnsavedChanges, isFalse);
      await store.setActiveEnvironment('staging');
      expect(
        store.resolveTemplate('{{baseUrl}}').executionValue,
        'https://staging.sendreq.io',
      );
    },
  );

  test('committing an older snapshot keeps newer edits dirty', () {
    final store = InMemoryEnvironmentStore.sample();
    final variable = store.listVariables().singleWhere(
      (item) => item.id == 'staging-base-url',
    );
    store.updateVariable(id: variable.id, value: 'https://saved.example');
    final persisted = store.toJson();
    store.updateVariable(id: variable.id, value: 'https://draft.example');

    store.commitSavedSnapshot(persisted);

    expect(store.hasUnsavedChanges, isTrue);
    store.discardChanges();
    expect(
      store.resolveTemplate('{{baseUrl}}').executionValue,
      'https://saved.example',
    );
  });

  test('environment variables are isolated across environment switches', () {
    final store = InMemoryEnvironmentStore.sample();

    final stagingBaseUrl = store.listVariables().singleWhere(
      (variable) => variable.id == 'staging-base-url',
    );
    store.updateVariable(
      id: stagingBaseUrl.id,
      value: ' https://staging.local ',
    );

    store.setActiveEnvironment('production');
    final productionBaseUrl = store.listVariables().singleWhere(
      (variable) => variable.id == 'production-base-url',
    );
    store.updateVariable(
      id: productionBaseUrl.id,
      value: ' https://production.local ',
    );
    expect(
      store.resolveTemplate('{{baseUrl}}').executionValue,
      'https://production.local',
    );

    store.setActiveEnvironment('staging');
    expect(
      store.resolveTemplate('{{baseUrl}}').executionValue,
      'https://staging.local',
    );
    expect(
      store.listVariables().any(
        (variable) =>
            variable.id == productionBaseUrl.id &&
            variable.displayValue == 'https://production.local',
      ),
      isFalse,
    );
  });

  test('variable type changes normalize values for the selected type', () {
    final store = InMemoryEnvironmentStore.sample();
    store.addVariable();
    final variableId = 'variable-1';

    store.updateVariable(id: variableId, type: EnvironmentVariableType.number);
    var variable = store.listVariables().singleWhere(
      (value) => value.id == variableId,
    );
    expect(variable.type, EnvironmentVariableType.number);
    expect(variable.displayValue, '0');

    store.updateVariable(id: variableId, value: '-12.5');
    store.updateVariable(id: variableId, type: EnvironmentVariableType.boolean);
    variable = store.listVariables().singleWhere(
      (value) => value.id == variableId,
    );
    expect(variable.type, EnvironmentVariableType.boolean);
    expect(variable.displayValue, 'false');

    store.updateVariable(id: variableId, value: 'YES');
    variable = store.listVariables().singleWhere(
      (value) => value.id == variableId,
    );
    expect(variable.displayValue, 'true');

    store.updateVariable(id: variableId, type: EnvironmentVariableType.secret);
    variable = store.listVariables().singleWhere(
      (value) => value.id == variableId,
    );
    expect(variable.isMasked, isTrue);
    store.toggleSecretVisibility(variableId);
    expect(
      store
          .listVariables()
          .singleWhere((value) => value.id == variableId)
          .displayValue,
      'true',
    );
  });

  test('every environment keeps a required baseUrl variable', () {
    final store = InMemoryEnvironmentStore.sample();
    final baseUrl = store.listVariables().singleWhere(
      (variable) => variable.key == 'baseUrl',
    );

    store.updateVariable(
      id: baseUrl.id,
      key: 'endpoint',
      type: EnvironmentVariableType.number,
    );

    final unchanged = store.listVariables().singleWhere(
      (variable) => variable.id == baseUrl.id,
    );
    expect(unchanged.key, 'baseUrl');
    expect(unchanged.type, EnvironmentVariableType.string);
    expect(store.removeVariable(baseUrl.id), isFalse);
  });

  test('GeoIP Lookup sample resolves its endpoint and query input', () {
    final store = InMemoryEnvironmentStore.sample();

    store.setActiveEnvironment('geoip-lookup');

    expect(
      store.resolveTemplate('{{baseUrl}}/tools/geoip/lookup').executionValue,
      'https://www.reurl.to/tools/geoip/lookup',
    );
    expect(store.resolveTemplate('{{domain}}').executionValue, 'qq.com');
    expect(
      store.listVariables().any((variable) => variable.key == 'token'),
      isFalse,
    );
  });

  test(
    'Reurl Production sample resolves GeoIP requests and masks its token',
    () {
      final store = InMemoryEnvironmentStore.sample();

      store.setActiveEnvironment('reurl-production');

      expect(
        store
            .resolveTemplate('{{baseUrl}}/geoip/city?ip={{ip}}&lang={{lang}}')
            .executionValue,
        'https://api.reurl.to/geoip/city?ip=1.1.1.1&lang=en',
      );
      expect(
        store
            .listVariables()
            .singleWhere((variable) => variable.id == 'reurl-token')
            .isMasked,
        isTrue,
      );
    },
  );

  test('environments can be created, renamed, and safely deleted', () {
    final store = InMemoryEnvironmentStore.sample();

    final local = store.createEnvironment('Local');
    expect(store.activeEnvironment.id, local.id);
    final baseUrl = store.listVariables().singleWhere(
      (variable) => variable.key == 'baseUrl',
    );
    expect(store.listVariables(), hasLength(2));
    expect(baseUrl.isRequired, isTrue);
    expect(baseUrl.type, EnvironmentVariableType.string);

    store.addVariable();
    store.renameEnvironment(local.id, 'Local development');
    expect(
      store.listEnvironments().singleWhere((item) => item.id == local.id).name,
      'Local development',
    );
    expect(
      store
          .listVariables()
          .singleWhere((item) => item.id == 'variable-1')
          .scope,
      'Local development',
    );

    expect(store.deleteEnvironment(local.id), isTrue);
    expect(store.activeEnvironment.id, 'staging');
    expect(store.listEnvironments(), hasLength(4));

    expect(store.deleteEnvironment('staging'), isTrue);
    expect(store.deleteEnvironment('production'), isTrue);
    expect(store.deleteEnvironment('geoip-lookup'), isTrue);
    expect(store.deleteEnvironment('reurl-production'), isFalse);
    expect(store.listEnvironments(), hasLength(1));
    expect(store.activeEnvironment.id, 'reurl-production');
  });

  test(
    'protected token can change value but cannot be removed or reconfigured',
    () {
      final store = InMemoryEnvironmentStore.sample();
      final token = store.listVariables().singleWhere(
        (variable) => variable.key == 'token',
      );

      store.updateVariable(
        id: token.id,
        key: 'apiKey',
        type: EnvironmentVariableType.string,
        value: 'updated-token',
      );
      store.toggleSecretVisibility(token.id);
      final updated = store.listVariables().singleWhere(
        (variable) => variable.id == token.id,
      );
      expect(updated.key, 'token');
      expect(updated.type, EnvironmentVariableType.secret);
      expect(updated.displayValue, 'updated-token');
      expect(
        store.resolveTemplate('{{token}}').executionValue,
        'updated-token',
      );
      expect(store.removeVariable(token.id), isFalse);
      expect(
        store.listVariables().where((variable) => variable.key == 'token'),
        hasLength(1),
      );
    },
  );

  test('environment authentication creates and marks its linked variables', () {
    final store = InMemoryEnvironmentStore.sample();

    store.updateActiveAuthentication(
      const RequestAuthentication.basic(
        username: '{{${AuthenticationVariableNames.basicUsername}}}',
        password: '{{${AuthenticationVariableNames.basicPassword}}}',
      ),
    );

    final username = store.listVariables().singleWhere(
      (variable) => variable.key == AuthenticationVariableNames.basicUsername,
    );
    final password = store.listVariables().singleWhere(
      (variable) => variable.key == AuthenticationVariableNames.basicPassword,
    );
    expect(username.type, EnvironmentVariableType.string);
    expect(username.isAuthenticationBinding, isTrue);
    expect(password.type, EnvironmentVariableType.secret);
    expect(password.isAuthenticationBinding, isTrue);
    store.updateVariable(id: username.id, value: 'alice');
    store.updateVariable(id: username.id, key: 'renamedUsername');
    expect(
      store
          .listVariables()
          .singleWhere((variable) => variable.id == username.id)
          .key,
      AuthenticationVariableNames.basicUsername,
    );
    expect(
      store
          .listVariables()
          .singleWhere((variable) => variable.id == username.id)
          .displayValue,
      'alice',
    );
    expect(store.removeVariable(username.id), isFalse);

    store.updateActiveAuthentication(
      const RequestAuthentication.apiKey(
        apiKeyName: AuthenticationVariableNames.defaultApiKeyHeader,
        apiKeyValue: '{{${AuthenticationVariableNames.apiKey}}}',
        apiKeyLocation: ApiKeyLocation.header,
      ),
    );
    final apiKey = store.listVariables().singleWhere(
      (variable) => variable.key == AuthenticationVariableNames.apiKey,
    );
    expect(apiKey.type, EnvironmentVariableType.secret);
    expect(apiKey.isAuthenticationBinding, isTrue);
    expect(
      store.listVariables().any(
        (variable) => variable.key == AuthenticationVariableNames.bearerToken,
      ),
      isFalse,
    );
    expect(
      store.listVariables().any((variable) => variable.id == username.id),
      isFalse,
    );
    expect(store.listUnusedAuthenticationVariableNames(), isEmpty);
    store.removeUnusedAuthenticationVariables();

    store.updateActiveAuthentication(
      const RequestAuthentication.bearer('{{unexpected}}'),
    );
    expect(
      store.activeEnvironment.authentication.bearerToken,
      '{{${AuthenticationVariableNames.bearerToken}}}',
    );
    expect(
      store.listVariables().any(
        (variable) => variable.key == AuthenticationVariableNames.apiKey,
      ),
      isFalse,
    );
    expect(store.listUnusedAuthenticationVariableNames(), isEmpty);
  });
}
