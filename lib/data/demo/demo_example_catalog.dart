import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';

/// 产品提供的可选示例，不会在加载时覆盖用户已有集合。
abstract final class DemoExampleCatalog {
  /// 示例集合的稳定 ID；重复加载时由仓储生成冲突安全的新 ID。
  static const collectionId = 'collection-sendreq-demo';

  /// 正式产品只提供一个最小 REST 示例，不携带协议测试 schema。
  static const collection = ApiCollection(
    id: collectionId,
    name: 'Sendreq REST Example',
    folders: [
      ApiFolder(
        id: 'folder-demo-rest',
        name: 'REST',
        requests: [
          ApiRequestDefinition(
            id: 'demo-rest-list-users',
            collectionId: collectionId,
            folderId: 'folder-demo-rest',
            name: 'List users',
            method: 'GET',
            urlTemplate: 'http://127.0.0.1:8081/api/v1/users',
            queryParams: [
              ApiField(key: 'page', value: '1'),
              ApiField(key: 'limit', value: '20'),
            ],
            headers: [],
            bodyTemplate: '',
            authenticationSource: RequestAuthenticationSource.request,
            metadata: {'folderName': 'REST'},
          ),
        ],
      ),
    ],
  );
}
