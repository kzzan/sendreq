import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:sendreq/domain/api_assets/openapi_exchange.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';

class LocalOpenApiFileReader implements OpenApiFileReadPort {
  const LocalOpenApiFileReader();

  @override
  Future<String> read(String path) => File(path).readAsString();
}

class LocalResponseBodyDownload implements ResponseBodyDownloadPort {
  const LocalResponseBodyDownload();

  @override
  Future<String> save(String body) async {
    final directory = await getDownloadsDirectory();
    if (directory == null) {
      throw const FileSystemException(
        'System Downloads directory is unavailable.',
      );
    }
    await directory.create(recursive: true);
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final file = File(
      '${directory.path}${Platform.pathSeparator}sendreq-response-$timestamp.json',
    );
    await file.writeAsString(body);
    return file.path;
  }
}
