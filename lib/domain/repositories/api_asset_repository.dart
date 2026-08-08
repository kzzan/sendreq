import '../api_assets/api_asset_models.dart';

/// API 资产（集合、文件夹、请求）与请求选项卡的领域仓储契约。
abstract interface class ApiAssetRepository {
  List<ApiCollection> listCollections();

  List<ApiRequestDefinition> listRequests();

  ApiRequestDefinition getRequest(String requestId);

  ApiCollection createCollection();

  ApiFolder createFolder({required String collectionId});

  ApiRequestDefinition createRequest({String? collectionId, String? folderId});

  ApiCollection addCollection(ApiCollection collection);

  void renameCollection(String collectionId, String name);

  void deleteCollection(String collectionId);

  void renameFolder({
    required String collectionId,
    required String folderId,
    required String name,
  });

  void deleteFolder({required String collectionId, required String folderId});

  void renameRequest(String requestId, String name);

  void deleteRequest(String requestId);

  void addRequests(List<ApiRequestDefinition> requests);

  void updateRequest(ApiRequestDefinition request);

  List<RequestTab> listOpenTabs();

  String? get activeRequestId;

  RequestTab openRequestTab(String requestId);

  void activateRequestTab(String tabId);

  void closeRequestTab(String tabId);
}
