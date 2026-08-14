import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  test('request text write paths trim leading and trailing whitespace', () {
    final repository = InMemoryApiAssetRepository.demo();
    final viewModel = workspaceViewModel(assetRepository: repository);

    viewModel.updateActiveDraftUrl(' http://127.0.0.1:8081/api/v1/users ');
    viewModel.addActiveDraftField(headers: false);
    viewModel.updateActiveDraftField(
      headers: false,
      index: 0,
      keyName: ' page ',
      value: ' 1 ',
    );
    viewModel.addActiveDraftField(headers: true);
    viewModel.updateActiveDraftField(
      headers: true,
      index: 0,
      keyName: ' X-Trace ',
      value: ' enabled ',
    );
    viewModel.updateActiveDraftBody(' {"name":"Ada"} ');
    viewModel.updateActiveBearerToken(' request-token ');
    viewModel.saveRequest('demo-rest-list-users');

    final saved = repository.getRequest('demo-rest-list-users');
    expect(saved.urlTemplate, 'http://127.0.0.1:8081/api/v1/users');
    expect(saved.queryParams.first.key, 'page');
    expect(saved.queryParams.first.value, '1');
    expect(saved.headers.first.key, 'X-Trace');
    expect(saved.headers.first.value, 'enabled');
    expect(saved.bodyTemplate, '{"name":"Ada"}');
    expect(saved.authentication.bearerToken, 'request-token');
  });

  test('WebSocket composer payload is normalized before send', () {
    final viewModel = workspaceViewModel();
    viewModel.selectRequest('demo-websocket-echo');

    viewModel.updateActiveWebSocketMessage('  sendreq websocket demo  ');

    expect(
      viewModel.activeWebSocketMessageDraft.payload,
      'sendreq websocket demo',
    );
  });
}
