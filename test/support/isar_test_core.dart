import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';

/// Flutter test 不加载桌面插件，因而显式定位 pub cache 中的 Isar Core。
Future<void> initializeIsarForTest() async {
  final cache = _pubCacheDirectory();
  final libraryName = switch (Platform.operatingSystem) {
    'linux' => 'linux${Platform.pathSeparator}libisar.so',
    'windows' => 'windows${Platform.pathSeparator}libisar.dll',
    'macos' => 'macos${Platform.pathSeparator}libisar.dylib',
    _ => throw UnsupportedError(
      'Isar persistence tests require a desktop operating system.',
    ),
  };
  final library = Directory(cache)
      .listSync(recursive: true)
      .whereType<File>()
      .firstWhere(
        (file) =>
            file.path.contains('isar_community_flutter_libs-') &&
            file.path.endsWith('${Platform.pathSeparator}$libraryName'),
      );
  await Isar.initializeIsarCore(libraries: {Abi.current(): library.path});
}

String _pubCacheDirectory() {
  final configured = Platform.environment['PUB_CACHE'];
  if (configured != null && configured.isNotEmpty) return configured;

  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      return '$localAppData${Platform.pathSeparator}Pub'
          '${Platform.pathSeparator}Cache';
    }
  }

  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return '$home${Platform.pathSeparator}.pub-cache';
  }
  throw StateError('Could not determine the Dart pub cache directory.');
}
