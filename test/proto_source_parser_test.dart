import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/services/proto_source_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 用例 1：验证解析器能跨文件解析 import 依赖，并识别消息、oneof 与
  // 服务端流式 RPC。这里构造两个内存中的 .proto 源文件（shared.proto 被
  // health.proto 导入），再断言解析出的描述符结构。
  test('parses imported messages and a server-streaming RPC', () {
    final descriptor = const ProtoSourceParser().parse(
      entryPath: 'health.proto',
      sources: const {
        'shared.proto':
            'syntax = "proto3"; package sendreq; message Status { string value = 1; }',
        'health.proto':
            'import "shared.proto"; package sendreq; message Check { string host = 1; oneof target { string zone = 2; } } service Health { rpc Watch (Check) returns (stream Status); }',
      },
    );

    // 被导入的 shared.proto 中的 Status 消息也应当可见。
    expect(descriptor.message('.sendreq.Check')!.oneofs, ['target']);
    expect(descriptor.message('.sendreq.Status'), isNotNull);
    // stream 关键字应被识别为服务端流式方法。
    expect(
      descriptor.service('.sendreq.Health')!.methods.single.serverStreaming,
      isTrue,
    );
  });

  // 用例 2：验证导入的本地文件不存在时抛出 FormatException，而非静默失败。
  test('reports a missing local import', () {
    expect(
      () => const ProtoSourceParser().parse(
        entryPath: 'health.proto',
        sources: const {'health.proto': 'import "missing.proto";'},
      ),
      throwsFormatException,
    );
  });

  test('parses relative imports from local proto files', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-proto-');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/shared.proto').writeAsString(
      'syntax = "proto3"; package sendreq; message Status { string value = 1; }',
    );
    final entry = File('${directory.path}/health.proto');
    await entry.writeAsString(
      'syntax = "proto3"; import "shared.proto"; package sendreq; service Health { rpc Check (Status) returns (Status); }',
    );

    final descriptor = await const ProtoSourceParser().parseFile(entry.path);

    expect(descriptor.message('.sendreq.Status'), isNotNull);
    expect(descriptor.service('.sendreq.Health')!.methods.single.name, 'Check');
  });

  test('resolves same-package message fields to fully qualified names', () {
    final descriptor = const ProtoSourceParser().parse(
      entryPath: 'messages.proto',
      sources: const {
        'messages.proto':
            'syntax = "proto3"; package example.v1; message Item { string id = 1; } message Response { Item item = 1; }',
      },
    );

    expect(
      descriptor.message('.example.v1.Response')!.fields.single.typeName,
      '.example.v1.Item',
    );
  });
}
