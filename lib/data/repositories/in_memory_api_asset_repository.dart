import '../../domain/api_assets/api_asset_models.dart';
import '../../domain/repositories/api_asset_repository.dart';
import '../demo/demo_example_catalog.dart';

/// 基于内存实现的 API 资产仓库。
///
/// 所有数据保存在进程内，供原型/演示使用；请求的编辑结果通过
/// `_requestOverrides` 覆盖映射叠加到原始数据之上，从而保持原始结构不变。
class InMemoryApiAssetRepository implements ApiAssetRepository {
  /// 以给定的集合、打开的选项卡与活动请求构造仓库。
  InMemoryApiAssetRepository({
    required List<ApiCollection> collections,
    List<RequestTab> openTabs = const [],
    this._activeRequestId,
  }) : _collections = List.of(collections),
       _openTabs = List.of(openTabs);

  /// 创建产品首次安装使用的唯一 Demo 集合。
  ///
  /// 演示包含本地 REST CRUD、WebSocket 与 gRPC 请求；其余旧样本不进入
  /// 生产启动路径，避免用户首次看到与产品定位无关的接口集合。
  factory InMemoryApiAssetRepository.demo() {
    const initialRequestId = 'demo-rest-list-users';
    final initialTab = RequestTab(
      id: 'tab-$initialRequestId',
      requestId: initialRequestId,
      title: 'List users',
      openedAt: DateTime.utc(2026, 8, 8),
    );
    return InMemoryApiAssetRepository(
      collections: const [DemoExampleCatalog.collection],
      openTabs: [initialTab],
      activeRequestId: initialRequestId,
    );
  }

  /// 全部集合的原始数据。
  final List<ApiCollection> _collections;

  /// 当前打开的全部请求选项卡。
  final List<RequestTab> _openTabs;

  /// 请求编辑产生的覆盖定义（按请求 ID 索引）。
  final Map<String, ApiRequestDefinition> _requestOverrides = {};

  /// 当前活动请求的 ID。
  String? _activeRequestId;

  /// 当前活动请求的 ID，无则返回 null。
  @override
  String? get activeRequestId => _activeRequestId;

  /// 列出全部集合（叠加编辑覆盖后的只读快照）。
  @override
  List<ApiCollection> listCollections() =>
      List.unmodifiable(_collections.map(_collectionWithOverrides));

  /// 将三层结构扁平化后的全部请求定义。
  @override
  List<ApiRequestDefinition> listRequests() => [
    // 将三层结构（集合 → 文件夹 → 请求）扁平化为请求列表。
    for (final collection in listCollections())
      for (final folder in collection.folders)
        for (final request in folder.requests) request,
  ];

  /// 按 ID 获取请求定义，不存在时抛出异常。
  @override
  ApiRequestDefinition getRequest(String requestId) =>
      listRequests().firstWhere((request) => request.id == requestId);

  /// 新建一个空集合并返回，默认带一个"Requests"文件夹。
  @override
  ApiCollection createCollection() {
    // 按现有 "collection-new-" 前缀数量生成递增序号，保证 ID 唯一且可读。
    final count =
        _collections
            .where((item) => item.id.startsWith('collection-new-'))
            .length +
        1;
    final collection = ApiCollection(
      id: 'collection-new-$count',
      name: 'New collection $count',
      folders: [
        ApiFolder(
          id: 'folder-new-$count-requests',
          name: 'Requests',
          requests: const [],
        ),
      ],
    );
    _collections.add(collection);
    return collection;
  }

  /// 在指定集合下新建一个空文件夹并返回。
  @override
  ApiFolder createFolder({required String collectionId}) {
    final collectionIndex = _collections.indexWhere(
      (item) => item.id == collectionId,
    );
    if (collectionIndex < 0) {
      throw StateError('Collection not found: $collectionId');
    }
    final collection = _collections[collectionIndex];
    final count = collection.folders.length + 1;
    final folder = ApiFolder(
      // 先收集所有已存在的文件夹 ID，确保新文件夹 ID 全局唯一。
      id: _uniqueId('folder-${collection.id}-group-$count', {
        for (final existing in _collections)
          for (final folder in existing.folders) folder.id,
      }),
      name: 'New folder $count',
      requests: const [],
    );
    _collections[collectionIndex] = collection.copyWith(
      folders: [...collection.folders, folder],
    );
    return folder;
  }

  /// 新建请求定义并挂到指定集合/文件夹，未指定时自动选用或创建。
  @override
  ApiRequestDefinition createRequest({String? collectionId, String? folderId}) {
    // 未指定集合时退化为第一个集合；连集合都没有则先创建一个。
    final collection = collectionId == null
        ? (_collections.isEmpty ? createCollection() : _collections.first)
        : _collections.firstWhere((item) => item.id == collectionId);
    // 未指定文件夹时取第一个文件夹；为空则现场新建一个空文件夹。
    final folder = folderId == null
        ? collection.folders.isEmpty
              ? ApiFolder(
                  id: 'folder-${collection.id}-requests',
                  name: 'Requests',
                  requests: const [],
                )
              : collection.folders.first
        : collection.folders.firstWhere((item) => item.id == folderId);
    // 原集合没有文件夹时，需要把新建的空文件夹写回集合。
    if (collection.folders.isEmpty) {
      _replaceCollection(collection.copyWith(folders: [folder]));
    }
    // 序号基于现有新请求数量递增，避免重名。
    final count =
        listRequests()
            .where((item) => item.id.startsWith('request-new-'))
            .length +
        1;
    final request = ApiRequestDefinition(
      id: 'request-new-$count',
      collectionId: collection.id,
      folderId: folder.id,
      name: 'New request $count',
      method: 'GET',
      urlTemplate: '',
      queryParams: const [],
      headers: const [],
      bodyTemplate: '',
      metadata: {'collectionName': collection.name, 'folderName': folder.name},
    );
    return _appendRequest(request);
  }

  /// 导入已有集合（含文件夹与请求），必要时重命名 ID 保持全局唯一。
  @override
  ApiCollection addCollection(ApiCollection collection) {
    // 先为集合、文件夹、请求分别生成唯一 ID，避免与存量数据冲突。
    final collectionId = _uniqueId(
      collection.id,
      _collections.map((item) => item.id).toSet(),
    );
    final folderIds = {
      for (final existing in _collections)
        for (final folder in existing.folders) folder.id,
    };
    final requestIds = listRequests().map((item) => item.id).toSet();
    final folders = <ApiFolder>[];
    for (final folder in collection.folders) {
      final folderId = _uniqueId(folder.id, folderIds);
      folderIds.add(folderId);
      folders.add(
        folder.copyWith(
          id: folderId,
          requests: [
            for (final request in folder.requests)
              () {
                // 用 IIFE 逐请求重新分配 ID 并修正其归属关系与元数据。
                final requestId = _uniqueId(request.id, requestIds);
                requestIds.add(requestId);
                return request.copyWith(
                  id: requestId,
                  collectionId: collectionId,
                  folderId: folderId,
                  metadata: {
                    ...request.metadata,
                    'collectionName': collection.name,
                    'folderName': folder.name,
                  },
                );
              }(),
          ],
        ),
      );
    }
    final added = collection.copyWith(id: collectionId, folders: folders);
    _collections.add(added);
    return added;
  }

  /// 重命名集合并同步更新其下所有请求元数据中的集合名。
  @override
  void renameCollection(String collectionId, String name) {
    final index = _collections.indexWhere((item) => item.id == collectionId);
    if (index < 0) {
      throw StateError('Collection not found: $collectionId');
    }
    final collection = _collections[index];
    // 重命名集合时同步刷新其下所有请求元数据里的集合名，保证显示一致。
    _collections[index] = collection.copyWith(
      name: name,
      folders: [
        for (final folder in collection.folders)
          folder.copyWith(
            requests: [
              for (final request in folder.requests)
                request.copyWith(
                  metadata: {...request.metadata, 'collectionName': name},
                ),
            ],
          ),
      ],
    );
  }

  /// 删除集合及其全部请求、相关选项卡，并清理覆盖记录。
  @override
  void deleteCollection(String collectionId) {
    final index = _collections.indexWhere((item) => item.id == collectionId);
    if (index < 0) {
      throw StateError('Collection not found: $collectionId');
    }

    final collection = _collections.removeAt(index);
    // 收集该集合下全部请求 ID，以便清理覆盖记录与打开的选项卡。
    final requestIds = {
      for (final folder in collection.folders)
        for (final request in folder.requests) request.id,
    };
    for (final requestId in requestIds) {
      _requestOverrides.remove(requestId);
    }
    _openTabs.removeWhere((tab) => requestIds.contains(tab.requestId));
    // 若活动请求被删除，回退到最后打开的选项卡（没有则置空）。
    if (_activeRequestId != null && requestIds.contains(_activeRequestId)) {
      _activeRequestId = _openTabs.isEmpty ? null : _openTabs.last.requestId;
    }
  }

  /// 重命名文件夹并同步更新其中请求元数据里的文件夹名。
  @override
  void renameFolder({
    required String collectionId,
    required String folderId,
    required String name,
  }) {
    final collectionIndex = _collections.indexWhere(
      (item) => item.id == collectionId,
    );
    if (collectionIndex < 0) {
      throw StateError('Collection not found: $collectionId');
    }
    final collection = _collections[collectionIndex];
    final folderIndex = collection.folders.indexWhere(
      (item) => item.id == folderId,
    );
    if (folderIndex < 0) {
      throw StateError('Folder not found: $folderId');
    }
    final folders = List<ApiFolder>.of(collection.folders);
    final folder = folders[folderIndex];
    // 同步更新文件夹内所有请求元数据里的文件夹名。
    folders[folderIndex] = folder.copyWith(
      name: name,
      requests: [
        for (final request in folder.requests)
          request.copyWith(metadata: {...request.metadata, 'folderName': name}),
      ],
    );
    _collections[collectionIndex] = collection.copyWith(folders: folders);
  }

  /// 删除文件夹及其全部请求、相关选项卡，并清理覆盖记录。
  @override
  void deleteFolder({required String collectionId, required String folderId}) {
    final collectionIndex = _collections.indexWhere(
      (item) => item.id == collectionId,
    );
    if (collectionIndex < 0) {
      throw StateError('Collection not found: $collectionId');
    }
    final collection = _collections[collectionIndex];
    final folderIndex = collection.folders.indexWhere(
      (item) => item.id == folderId,
    );
    if (folderIndex < 0) {
      throw StateError('Folder not found: $folderId');
    }

    final folders = List<ApiFolder>.of(collection.folders);
    final folder = folders.removeAt(folderIndex);
    // 与删除集合一致：清理该文件夹下请求的覆盖记录与打开选项卡。
    final requestIds = {for (final request in folder.requests) request.id};
    for (final requestId in requestIds) {
      _requestOverrides.remove(requestId);
    }
    _openTabs.removeWhere((tab) => requestIds.contains(tab.requestId));
    if (_activeRequestId != null && requestIds.contains(_activeRequestId)) {
      _activeRequestId = _openTabs.isEmpty ? null : _openTabs.last.requestId;
    }
    _collections[collectionIndex] = collection.copyWith(folders: folders);
  }

  /// 重命名请求并同步更新对应选项卡的标题。
  @override
  void renameRequest(String requestId, String name) {
    final request = getRequest(requestId);
    _requestOverrides[requestId] = request.copyWith(name: name);
    // 同步更新所有指向该请求的选项卡标题，保持标签页显示一致。
    for (var index = 0; index < _openTabs.length; index++) {
      final tab = _openTabs[index];
      if (tab.requestId == requestId) {
        _openTabs[index] = RequestTab(
          id: tab.id,
          requestId: tab.requestId,
          title: name,
          openedAt: tab.openedAt,
          isDirty: tab.isDirty,
        );
      }
    }
  }

  /// 删除请求及其选项卡；删除活动请求时激活相邻选项卡。
  @override
  void deleteRequest(String requestId) {
    // 先定位请求所在的集合。
    final collectionIndex = _collections.indexWhere(
      (collection) => collection.folders.any(
        (folder) => folder.requests.any((request) => request.id == requestId),
      ),
    );
    if (collectionIndex < 0) {
      throw StateError('Request not found: $requestId');
    }
    final collection = _collections[collectionIndex];
    // 从所有文件夹中过滤掉目标请求（不可变方式重建结构）。
    final folders = [
      for (final folder in collection.folders)
        folder.copyWith(
          requests: folder.requests
              .where((request) => request.id != requestId)
              .toList(growable: false),
        ),
    ];
    _collections[collectionIndex] = collection.copyWith(folders: folders);
    _requestOverrides.remove(requestId);
    final tabIndex = _openTabs.indexWhere((tab) => tab.requestId == requestId);
    if (tabIndex >= 0) {
      _openTabs.removeAt(tabIndex);
    }
    // 若删除的是活动请求，则激活其左侧相邻选项卡（越界时收敛到首/尾）。
    if (_activeRequestId == requestId) {
      _activeRequestId = _openTabs.isEmpty
          ? null
          : _openTabs[(tabIndex - 1).clamp(0, _openTabs.length - 1)].requestId;
    }
  }

  /// 批量导入请求定义到其所属的集合/文件夹。
  @override
  void addRequests(List<ApiRequestDefinition> requests) {
    for (final request in requests) {
      _appendRequest(request);
    }
  }

  /// 更新请求内容，结果写入覆盖映射并对外可见。
  @override
  void updateRequest(ApiRequestDefinition request) {
    // 先校验请求确实存在，再写入覆盖映射。
    getRequest(request.id);
    _requestOverrides[request.id] = request;
  }

  /// 返回当前打开的全部选项卡（只读快照）。
  @override
  List<RequestTab> listOpenTabs() => List.unmodifiable(_openTabs);

  /// 打开请求的选项卡（已存在则复用），并设为活动状态。
  @override
  RequestTab openRequestTab(String requestId) {
    final request = getRequest(requestId);
    // 已打开的选项卡直接复用，否则新建一个。
    final existing = _openTabs.where((tab) => tab.requestId == requestId);
    final tab = existing.isNotEmpty
        ? existing.first
        : RequestTab(
            id: 'tab-${request.id}',
            requestId: request.id,
            title: request.name,
            openedAt: DateTime.now().toUtc(),
          );
    if (existing.isEmpty) {
      _openTabs.add(tab);
    }
    // 打开即视为激活。
    _activeRequestId = requestId;
    return tab;
  }

  /// 激活指定选项卡。
  @override
  void activateRequestTab(String tabId) {
    final tab = _openTabs.firstWhere((candidate) => candidate.id == tabId);
    _activeRequestId = tab.requestId;
  }

  /// 关闭指定选项卡；关闭活动选项卡时激活相邻选项卡。
  @override
  void closeRequestTab(String tabId) {
    final index = _openTabs.indexWhere((tab) => tab.id == tabId);
    if (index < 0) {
      return;
    }
    final wasActive = _openTabs[index].requestId == _activeRequestId;
    _openTabs.removeAt(index);
    // 关闭的是活动选项卡时，激活其左侧相邻选项卡（为空则置空）。
    if (wasActive) {
      _activeRequestId = _openTabs.isEmpty
          ? null
          : _openTabs[(index - 1).clamp(0, _openTabs.length - 1)].requestId;
    }
  }

  /// 在集合快照上叠加请求覆盖映射，返回反映最新编辑结果的视图。
  ApiCollection _collectionWithOverrides(ApiCollection collection) {
    return collection.copyWith(
      folders: [
        for (final folder in collection.folders)
          folder.copyWith(
            requests: [
              for (final request in folder.requests)
                _requestOverrides[request.id] ?? request,
            ],
          ),
      ],
    );
  }

  /// 将请求追加到其所属集合/文件夹中；集合或文件夹不存在时自动创建。
  ApiRequestDefinition _appendRequest(ApiRequestDefinition request) {
    final collectionIndex = _collections.indexWhere(
      (item) => item.id == request.collectionId,
    );
    // 目标集合不存在：用请求元数据反推建集合与文件夹，并把请求挂进去。
    if (collectionIndex < 0) {
      final collection = ApiCollection(
        id: request.collectionId,
        name: request.metadata['collectionName'] ?? 'Imported Collection',
        folders: [
          ApiFolder(
            id: request.folderId,
            name: request.metadata['folderName'] ?? 'Requests',
            requests: [request],
          ),
        ],
      );
      _collections.add(collection);
      return request;
    }

    final collection = _collections[collectionIndex];
    final folders = List<ApiFolder>.of(collection.folders);
    var folderIndex = folders.indexWhere((item) => item.id == request.folderId);
    // 目标文件夹不存在：新建空文件夹并追加到集合末尾。
    if (folderIndex < 0) {
      folders.add(
        ApiFolder(
          id: request.folderId,
          name: request.metadata['folderName'] ?? 'Requests',
          requests: const [],
        ),
      );
      folderIndex = folders.length - 1;
    }

    // 请求 ID 需全局唯一；保留原始 ID 的优先，冲突时加序号后缀。
    final requestId = _uniqueId(
      request.id,
      listRequests().map((item) => item.id).toSet(),
    );
    final folder = folders[folderIndex];
    final added = request.copyWith(
      id: requestId,
      collectionId: collection.id,
      folderId: folder.id,
      metadata: {
        ...request.metadata,
        'collectionName': collection.name,
        'folderName': folder.name,
      },
    );
    folders[folderIndex] = folder.copyWith(
      requests: [...folder.requests, added],
    );
    _collections[collectionIndex] = collection.copyWith(folders: folders);
    return added;
  }

  /// 用新的集合对象替换同 ID 的旧集合（用于补写新建的空文件夹）。
  void _replaceCollection(ApiCollection collection) {
    final index = _collections.indexWhere((item) => item.id == collection.id);
    if (index >= 0) {
      _collections[index] = collection;
    }
  }

  /// 生成唯一 ID：优先保留偏好 ID，已占用时附加递增的序号后缀。
  String _uniqueId(String preferred, Set<String> used) {
    if (!used.contains(preferred)) return preferred;
    var index = 2;
    while (used.contains('$preferred-$index')) {
      index++;
    }
    return '$preferred-$index';
  }
}
