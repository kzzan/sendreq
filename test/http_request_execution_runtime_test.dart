import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sendreq/data/services/http_request_execution_runtime.dart';
import 'package:sendreq/domain/models/workspace_models.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';

void main() {
  test('GET requests never send a body or entity headers', () async {
    final client = _RecordingClient();
    final runtime = HttpRequestExecutionRuntime(clientFactory: () => client);
    final draft = RequestDraft(
      method: 'GET',
      baseUrlToken: '',
      path: 'https://example.test/geoip',
      params: const [],
      headers: const [
        KeyValueRow(keyName: 'Content-Type', value: 'application/json'),
        KeyValueRow(keyName: 'X-Trace', value: 'trace-42'),
      ],
      body: '{"unexpected":true}',
    );

    await runtime.send(draft: draft, resolvedUrl: draft.path);

    expect(client.body, isEmpty);
    expect(
      client.headers.keys.any((name) => name.toLowerCase() == 'content-type'),
      isFalse,
    );
    expect(
      client.headers.entries
          .singleWhere((entry) => entry.key.toLowerCase() == 'x-trace')
          .value,
      'trace-42',
    );
  });

  // 验证 multipart 上传请求：运行时应将普通表单字段与多个文件流式写入请求体，
  // 并透传额外的请求头。通过记录客户端截获实际发出的内容进行断言。
  test('multipart requests stream form fields and selected files', () async {
    // 在系统临时目录创建真实文件，模拟用户选择的待上传附件。
    final directory = await Directory.systemTemp.createTemp('sendreq-upload-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/avatar.txt');
    await file.writeAsString('avatar-content');
    final secondFile = File('${directory.path}/banner.txt');
    await secondFile.writeAsString('banner-content');
    final client = _RecordingClient();
    final runtime = HttpRequestExecutionRuntime(clientFactory: () => client);
    // 构造带两个普通字段、两个同名 files[] 文件的 multipart 草稿，
    // 并额外指定 Content-Type 与自定义追踪头。
    final draft = RequestDraft(
      method: 'POST',
      baseUrlToken: '',
      path: 'https://example.test/upload',
      params: const [],
      headers: const [
        KeyValueRow(keyName: 'Content-Type', value: 'multipart/form-data'),
        KeyValueRow(keyName: 'X-Trace', value: 'trace-42'),
      ],
      body: '',
      multipartFields: const [
        KeyValueRow(keyName: 'description', value: 'profile image'),
      ],
      multipartFiles: [
        MultipartFileRow(
          id: 'file-1',
          keyName: 'files[]',
          path: file.path,
          fileName: 'avatar.txt',
          sizeBytes: await file.length(),
        ),
        MultipartFileRow(
          id: 'file-2',
          keyName: 'files[]',
          path: secondFile.path,
          fileName: 'banner.txt',
          sizeBytes: await secondFile.length(),
        ),
      ],
    );

    await runtime.send(draft: draft, resolvedUrl: draft.path);

    // Content-Type 应为运行时自动补充边界参数的 multipart 类型。
    expect(
      client.headers.entries
          .singleWhere((entry) => entry.key.toLowerCase() == 'content-type')
          .value,
      startsWith('multipart/form-data;'),
    );
    // 自定义 X-Trace 请求头应原样透传。
    expect(
      client.headers.entries
          .singleWhere((entry) => entry.key.toLowerCase() == 'x-trace')
          .value,
      'trace-42',
    );
    // 请求体应同时包含普通字段与每个文件（含文件名与内容）。
    expect(client.body, contains('name="description"'));
    expect(client.body, contains('profile image'));
    expect(client.body, contains('name="files[]"; filename="avatar.txt"'));
    expect(client.body, contains('avatar-content'));
    expect(client.body, contains('name="files[]"; filename="banner.txt"'));
    expect(client.body, contains('banner-content'));
  });

  test('identifies the Header that contains unsupported characters', () async {
    final runtime = HttpRequestExecutionRuntime();
    final draft = RequestDraft(
      method: 'GET',
      baseUrlToken: '',
      path: 'https://example.test/health',
      params: const [],
      headers: const [
        KeyValueRow(keyName: 'Authorization', value: 'Bearer token\ninvalid'),
      ],
      body: '',
    );

    await expectLater(
      runtime.send(draft: draft, resolvedUrl: draft.path),
      throwsA(
        isA<RuntimeRequestException>().having(
          (error) => error.message,
          'message',
          'Header "Authorization" contains unsupported characters.',
        ),
      ),
    );
  });
}

/// 记录客户端：截获经其发送的请求头与完整请求体，用于断言运行时实际发出的内容。
class _RecordingClient extends http.BaseClient {
  final headers = <String, String>{};
  String body = '';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    body = await request.finalize().transform(utf8.decoder).join();
    headers.addAll(request.headers);
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"ok":true}')),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}
