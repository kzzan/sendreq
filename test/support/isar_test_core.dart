import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';

/// Flutter test 不加载桌面插件，因而显式定位 pub cache 中的 Isar Core。
Future<void> initializeIsarForTest() async {
  if (!Platform.isLinux) {
    await Isar.initializeIsarCore(download: true);
    return;
  }
  final cache =
      Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}${Platform.pathSeparator}.pub-cache';
  final library = Directory(cache)
      .listSync(recursive: true)
      .whereType<File>()
      .firstWhere(
        (file) =>
            file.path.contains('isar_community_flutter_libs-') &&
            file.path.endsWith(
              '${Platform.pathSeparator}linux${Platform.pathSeparator}libisar.so',
            ),
      );
  await Isar.initializeIsarCore(libraries: {Abi.current(): library.path});
}
