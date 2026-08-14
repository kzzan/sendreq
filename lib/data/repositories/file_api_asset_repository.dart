import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/repositories/api_asset_repository.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';

/// 将 API 资产持久化到本地，同时保留内存仓库的数据变更规则。
class FileApiAssetRepository implements ApiAssetRepository {
  /// 私有构造：包装内存仓库与可选的配置目录。
  FileApiAssetRepository._(this._delegate, {this.configurationDirectory});

  /// 内存委托：持有全部资产状态并执行数据变更规则。
  final InMemoryApiAssetRepository _delegate;

  /// 显式指定的配置目录；为 null 时按系统约定推导。
  final Directory? configurationDirectory;

  /// 串行写盘队列，保证多次变更按顺序落盘。
  Future<void> _writeQueue = Future.value();

  /// 加载资产仓库：优先从 JSON 文件恢复，任何失败都回退到空工作区。
  static Future<FileApiAssetRepository> load({
    Directory? configurationDirectory,
  }) async {
    try {
      return await loadForMigration(
        configurationDirectory: configurationDirectory,
      );
    } on Object {
      // 读取或解析失败时回退到空工作区，避免测试数据进入用户存储。
      return FileApiAssetRepository._(
        InMemoryApiAssetRepository(collections: const []),
        configurationDirectory: configurationDirectory,
      );
    }
  }

  /// 严格读取旧 JSON，供启动迁移编排判断是否应展示恢复入口。
  ///
  /// 文件不存在时返回新的空工作区；存在但损坏的数据必须由调用方处理，
  /// 不能静默覆盖为示例数据。
  static Future<FileApiAssetRepository> loadForMigration({
    Directory? configurationDirectory,
  }) async {
    final file = _fileFor(configurationDirectory);
    if (!await file.exists()) {
      return FileApiAssetRepository._(
        InMemoryApiAssetRepository(collections: const []),
        configurationDirectory: configurationDirectory,
      );
    }
    final root = Map<String, dynamic>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
    // 仅接受已知版本，避免误解析未来格式的数据。
    if (root['version'] != 1) {
      throw const FormatException('Unsupported asset version.');
    }
    final collections = (root['collections'] as List<dynamic>)
        .map(
          (value) =>
              ApiCollection.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(growable: false);
    final tabs = (root['openTabs'] as List<dynamic>)
        .map(
          (value) =>
              RequestTab.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(growable: false);
    return FileApiAssetRepository._(
      InMemoryApiAssetRepository(
        collections: collections,
        openTabs: tabs,
        activeRequestId: root['activeRequestId'] as String?,
      ),
      configurationDirectory: configurationDirectory,
    );
  }

  /// 解析资产 JSON 文件的路径（默认遵循 XDG 配置约定）。
  static File _fileFor(Directory? configured) {
    final root =
        configured ??
        Directory(
          '${Platform.environment['XDG_CONFIG_HOME'] ?? '${Platform.environment['HOME']}/.config'}/sendreq',
        );
    return File('${root.path}/api-assets.json');
  }

  /// 标记数据已变更，将写盘追加到串行队列。
  void _changed() => _writeQueue = _writeQueue.then((_) => _write());

  /// 等待所有排队的写盘操作完成。
  @override
  Future<void> flush() => _writeQueue;

  /// 在 Isar 导入前保留旧 JSON 资产文件，迁移失败时可人工恢复。
  Future<void> backupIfPresent() async {
    final source = _fileFor(configurationDirectory);
    if (!await source.exists()) return;
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    await source.copy('${source.path}.$timestamp.bak');
  }

  /// 将当前全部资产编码后原子写入 JSON 文件。
  Future<void> _write() async {
    final file = _fileFor(configurationDirectory);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    // 先写临时文件再原子重命名，避免写入中断留下损坏的数据。
    await temporary.writeAsString(
      jsonEncode({
        'version': 1,
        'collections': _delegate
            .listCollections()
            .map((item) => item.toJson())
            .toList(),
        'openTabs': _delegate
            .listOpenTabs()
            .map((item) => item.toJson())
            .toList(),
        'activeRequestId': _delegate.activeRequestId,
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  /// 列出全部集合（返回只读快照）。
  @override
  List<ApiCollection> listCollections() => _delegate.listCollections();

  /// 列出全部扁平化请求定义。
  @override
  List<ApiRequestDefinition> listRequests() => _delegate.listRequests();

  /// 按 ID 获取请求定义，不存在时抛出异常。
  @override
  ApiRequestDefinition getRequest(String id) => _delegate.getRequest(id);

  /// 当前活动请求的 ID。
  @override
  String? get activeRequestId => _delegate.activeRequestId;

  /// 列出当前打开的选项卡。
  @override
  List<RequestTab> listOpenTabs() => _delegate.listOpenTabs();

  /// 新建一个空集合并持久化。
  @override
  ApiCollection createCollection() {
    final value = _delegate.createCollection();
    _changed();
    return value;
  }

  /// 在指定集合下新建一个空文件夹并持久化。
  @override
  ApiFolder createFolder({required String collectionId}) {
    final value = _delegate.createFolder(collectionId: collectionId);
    _changed();
    return value;
  }

  /// 新建一个请求定义并持久化。
  @override
  ApiRequestDefinition createRequest({
    String? collectionId,
    String? folderId,
    ApiRequestProtocol protocol = ApiRequestProtocol.http,
  }) {
    final value = _delegate.createRequest(
      collectionId: collectionId,
      folderId: folderId,
      protocol: protocol,
    );
    _changed();
    return value;
  }

  /// 导入已有集合（必要时重命名 ID）并持久化。
  @override
  ApiCollection addCollection(ApiCollection value) {
    final result = _delegate.addCollection(value);
    _changed();
    return result;
  }

  /// 重命名集合并持久化。
  @override
  void renameCollection(String id, String name) {
    _delegate.renameCollection(id, name);
    _changed();
  }

  /// 删除集合并持久化。
  @override
  void deleteCollection(String id) {
    _delegate.deleteCollection(id);
    _changed();
  }

  /// 重命名文件夹并持久化。
  @override
  void renameFolder({
    required String collectionId,
    required String folderId,
    required String name,
  }) {
    _delegate.renameFolder(
      collectionId: collectionId,
      folderId: folderId,
      name: name,
    );
    _changed();
  }

  /// 删除文件夹并持久化。
  @override
  void deleteFolder({required String collectionId, required String folderId}) {
    _delegate.deleteFolder(collectionId: collectionId, folderId: folderId);
    _changed();
  }

  /// 重命名请求并持久化。
  @override
  void renameRequest(String id, String name) {
    _delegate.renameRequest(id, name);
    _changed();
  }

  /// 删除请求并持久化。
  @override
  void deleteRequest(String id) {
    _delegate.deleteRequest(id);
    _changed();
  }

  /// 批量导入请求并持久化。
  @override
  void addRequests(List<ApiRequestDefinition> values) {
    _delegate.addRequests(values);
    _changed();
  }

  /// 更新请求内容并持久化。
  @override
  void updateRequest(ApiRequestDefinition value) {
    _delegate.updateRequest(value);
    _changed();
  }

  /// 打开请求选项卡并持久化。
  @override
  RequestTab openRequestTab(String id) {
    final value = _delegate.openRequestTab(id);
    _changed();
    return value;
  }

  /// 激活指定选项卡并持久化。
  @override
  void activateRequestTab(String id) {
    _delegate.activateRequestTab(id);
    _changed();
  }

  /// 关闭指定选项卡并持久化。
  @override
  void closeRequestTab(String id) {
    _delegate.closeRequestTab(id);
    _changed();
  }
}
