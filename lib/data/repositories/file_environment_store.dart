import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/environments/environment_models.dart';
import 'package:sendreq/domain/repositories/environment_store.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';

/// 将环境、变量、认证配置持久化到本地 JSON 文件。
///
/// 编辑中的值保留在内存中，只有调用 [saveChanges] 成功后才写盘并清除脏状态。
class FileEnvironmentStore implements EnvironmentStore {
  /// 私有构造：包装内存存储与持久化目录。
  FileEnvironmentStore._(
    this._delegate, {
    required this.configurationDirectory,
  });

  /// 内存委托：保存编辑中的状态并执行数据变更规则。
  final InMemoryEnvironmentStore _delegate;

  /// 环境配置持久化所在的目录。
  final Directory configurationDirectory;

  Future<void> _writeQueue = Future<void>.value();

  /// 加载环境存储：优先读取 JSON 文件，缺失或损坏时回退到干净默认值。
  static Future<FileEnvironmentStore> load({
    Directory? configurationDirectory,
  }) async {
    try {
      return await loadForMigration(
        configurationDirectory: configurationDirectory,
      );
    } on Object {
      // 环境配置损坏不能阻止应用启动；使用无示例凭据的默认配置。
      final directory =
          configurationDirectory ?? await getApplicationSupportDirectory();
      return FileEnvironmentStore._(
        InMemoryEnvironmentStore.defaults(),
        configurationDirectory: directory,
      );
    }
  }

  /// 严格读取旧 JSON，供迁入 Isar 时判断是否可安全使用源数据。
  ///
  /// 与 [load] 不同，存在但损坏的数据会抛出，避免示例数据覆盖用户配置。
  static Future<FileEnvironmentStore> loadForMigration({
    Directory? configurationDirectory,
  }) async {
    final directory =
        configurationDirectory ?? await getApplicationSupportDirectory();
    final file = _fileFor(directory);
    final source = await _readSource(
      preferred: file,
      allowLegacyLookup: configurationDirectory == null,
    );
    if (source == null) {
      return FileEnvironmentStore._(
        InMemoryEnvironmentStore.defaults(),
        configurationDirectory: directory,
      );
    }
    final value = jsonDecode(await source.readAsString());
    if (value is! Map || value['version'] != 1) {
      throw const FormatException('Unsupported environment data version.');
    }
    // 迁移只复制，不删除旧路径中的用户数据；复制失败时仍继续从旧文件恢复。
    if (source.path != file.path) {
      try {
        await file.parent.create(recursive: true);
        await source.copy(file.path);
      } on FileSystemException {
        // 后续保存仍会写入系统应用支持目录。
      }
    }
    return FileEnvironmentStore._(
      InMemoryEnvironmentStore.fromJson(Map<String, dynamic>.from(value)),
      configurationDirectory: directory,
    );
  }

  /// 解析环境配置文件在指定目录下的完整路径。
  static File _fileFor(Directory directory) =>
      File('${directory.path}${Platform.pathSeparator}environments.json');

  /// 定位环境配置文件：优先使用标准路径，必要时回退读取旧版 XDG 路径。
  static Future<File?> _readSource({
    required File preferred,
    required bool allowLegacyLookup,
  }) async {
    if (await preferred.exists()) return preferred;
    if (!allowLegacyLookup) return null;
    final legacy = _legacyFileForCurrentUser();
    return await legacy.exists() ? legacy : null;
  }

  /// 仅用于读取早期版本写入的手写 XDG 配置路径。
  static File _legacyFileForCurrentUser() {
    final home = Platform.environment['HOME'];
    final config = Platform.environment['XDG_CONFIG_HOME'];
    final root =
        config ?? (home == null || home.isEmpty ? null : '$home/.config');
    return File(
      '${root ?? Directory.current.path}${Platform.pathSeparator}sendreq${Platform.pathSeparator}environments.json',
    );
  }

  /// 列出全部环境配置。
  @override
  List<EnvironmentProfile> listEnvironments() => _delegate.listEnvironments();

  /// 当前激活的环境配置。
  @override
  EnvironmentProfile get activeEnvironment => _delegate.activeEnvironment;

  /// 更新当前环境的默认认证策略。
  @override
  void updateActiveAuthentication(RequestAuthentication authentication) =>
      _delegate.updateActiveAuthentication(authentication);

  @override
  void updateEnvironmentAuthentication({
    required String environmentId,
    required RequestAuthentication authentication,
  }) => _delegate.updateEnvironmentAuthentication(
    environmentId: environmentId,
    authentication: authentication,
  );

  /// 列出当前环境的变量（含全局变量）。
  @override
  List<EnvironmentVariableView> listVariables({String? environmentId}) =>
      _delegate.listVariables(environmentId: environmentId);

  /// 列出当前认证不再使用的凭据变量名。
  @override
  List<String> listUnusedAuthenticationVariableNames({String? environmentId}) =>
      _delegate.listUnusedAuthenticationVariableNames(
        environmentId: environmentId,
      );

  /// 删除当前认证不再使用的凭据变量。
  @override
  void removeUnusedAuthenticationVariables({String? environmentId}) => _delegate
      .removeUnusedAuthenticationVariables(environmentId: environmentId);

  /// 是否存在尚未保存的修改。
  @override
  bool get hasUnsavedChanges => _delegate.hasUnsavedChanges;

  /// 切换当前激活的环境。
  @override
  Future<void> setActiveEnvironment(String environmentId) async {
    await _delegate.setActiveEnvironment(environmentId);
    _writeQueue = _writeQueue.then(
      (_) => _writeSnapshot(_delegate.savedJsonWithActiveEnvironment()),
    );
    await _writeQueue;
  }

  /// 创建环境并设为当前环境。
  @override
  EnvironmentProfile createEnvironment(String name, {bool activate = true}) =>
      _delegate.createEnvironment(name, activate: activate);

  /// 重命名环境并同步更新变量作用域。
  @override
  void renameEnvironment(String environmentId, String name) =>
      _delegate.renameEnvironment(environmentId, name);

  /// 删除环境及其变量；至少保留一个环境。
  @override
  bool deleteEnvironment(String environmentId) =>
      _delegate.deleteEnvironment(environmentId);

  /// 更新指定变量的键、值或类型（null 表示保持不变）。
  @override
  void updateVariable({
    required String id,
    String? environmentId,
    String? key,
    String? value,
    EnvironmentVariableType? type,
  }) => _delegate.updateVariable(
    id: id,
    environmentId: environmentId,
    key: key,
    value: value,
    type: type,
  );

  /// 在当前环境新增一个空变量。
  @override
  void addVariable({String? environmentId}) =>
      _delegate.addVariable(environmentId: environmentId);

  /// 在全局范围新增一个空变量。
  @override
  void addGlobalVariable() => _delegate.addGlobalVariable();

  /// 移除指定变量；受保护变量不可移除。
  @override
  bool removeVariable(String id) => _delegate.removeVariable(id);

  /// 切换密钥变量的可见/隐藏状态。
  @override
  void toggleSecretVisibility(String id) =>
      _delegate.toggleSecretVisibility(id);

  /// 将当前内存状态编码后原子写入文件，成功后清除未保存标记。
  @override
  Future<void> saveChanges() async {
    final snapshot = _delegate.toJson();
    _writeQueue = _writeQueue.then((_) => _writeSnapshot(snapshot));
    await _writeQueue;
    _delegate.commitSavedSnapshot(snapshot);
  }

  @override
  void discardChanges() => _delegate.discardChanges();

  Future<void> _writeSnapshot(Map<String, Object> snapshot) async {
    final file = _fileFor(configurationDirectory);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({'version': 1, ...snapshot}),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  /// 导出未包装版本号的环境快照，供首次迁移到 Isar 时复用。
  ///
  /// 该方法只用于迁移；正式运行时不再由此仓储承担环境写入。
  Map<String, Object> exportSnapshot() => _delegate.toJson();

  /// 在迁入 Isar 前保留旧环境文件，避免新存储成为唯一副本。
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

  /// 解析模板字符串中的 `{{变量名}}` 占位符。
  @override
  TemplateResolutionResult resolveTemplate(String template) =>
      _delegate.resolveTemplate(template);
}
