import 'package:sendreq/domain/api_assets/api_asset_models.dart';

/// Owns immutable hierarchy snapshots and the request lookup index.
class InMemoryApiAssetSnapshotCache {
  List<ApiCollection>? _collections;
  List<ApiRequestDefinition>? _requests;
  Map<String, ApiRequestDefinition>? _requestIndex;

  List<ApiCollection> collections(
    List<ApiCollection> source,
    Map<String, ApiRequestDefinition> overrides,
  ) {
    _ensure(source, overrides);
    return _collections!;
  }

  List<ApiRequestDefinition> requests(
    List<ApiCollection> source,
    Map<String, ApiRequestDefinition> overrides,
  ) {
    _ensure(source, overrides);
    return _requests!;
  }

  ApiRequestDefinition? request(
    String requestId,
    List<ApiCollection> source,
    Map<String, ApiRequestDefinition> overrides,
  ) {
    _ensure(source, overrides);
    return _requestIndex![requestId];
  }

  void invalidate() {
    _collections = null;
    _requests = null;
    _requestIndex = null;
  }

  void _ensure(
    List<ApiCollection> source,
    Map<String, ApiRequestDefinition> overrides,
  ) {
    if (_collections != null) return;
    final collections = List<ApiCollection>.unmodifiable(
      source.map(
        (collection) => collection.copyWith(
          folders: [
            for (final folder in collection.folders)
              folder.copyWith(
                requests: [
                  for (final request in folder.requests)
                    overrides[request.id] ?? request,
                ],
              ),
          ],
        ),
      ),
    );
    final requests = List<ApiRequestDefinition>.unmodifiable([
      for (final collection in collections)
        for (final folder in collection.folders) ...folder.requests,
    ]);
    _collections = collections;
    _requests = requests;
    _requestIndex = Map<String, ApiRequestDefinition>.unmodifiable({
      for (final request in requests) request.id: request,
    });
  }
}
