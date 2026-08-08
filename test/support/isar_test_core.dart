import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';

/// Flutter test 不加载桌面插件，因而显式定位 pub cache 中的 Isar Core。
Future<void> initializeIsarForTest() async {
  final packageRoot = await _packageRoot('isar_community_flutter_libs');
  final libraryName = switch (Platform.operatingSystem) {
    'linux' => 'linux${Platform.pathSeparator}libisar.so',
    'windows' => 'windows${Platform.pathSeparator}libisar.dll',
    'macos' => 'macos${Platform.pathSeparator}libisar.dylib',
    _ => throw UnsupportedError(
      'Isar persistence tests require a desktop operating system.',
    ),
  };
  final library = File(
    '${packageRoot.path}${Platform.pathSeparator}$libraryName',
  );
  if (!await library.exists()) {
    throw StateError('Bundled Isar Core was not found at ${library.path}.');
  }
  await Isar.initializeIsarCore(libraries: {Abi.current(): library.path});
}

Future<Directory> _packageRoot(String packageName) async {
  final config = File(
    '${Directory.current.path}${Platform.pathSeparator}.dart_tool'
    '${Platform.pathSeparator}package_config.json',
  );
  final value = jsonDecode(await config.readAsString()) as Map<String, dynamic>;
  final package = (value['packages'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .firstWhere((entry) => entry['name'] == packageName);
  return Directory.fromUri(config.uri.resolve(package['rootUri'] as String));
}
