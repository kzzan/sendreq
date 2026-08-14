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
      entryPath: 'orders.proto',
      sources: const {
        'orders.proto':
            'syntax = "proto3"; package order.v1; message Order { string id = 1; } message Response { Order order = 1; }',
      },
    );

    expect(
      descriptor.message('.order.v1.Response')!.fields.single.typeName,
      '.order.v1.Order',
    );
  });

  test('parses the installed gRPC demo schema asset', () async {
    final descriptor = await const ProtoSourceParser().parseFile(
      'asset://assets/demo/order.proto',
    );

    expect(descriptor.message('.order.v1.CreateOrderRequest'), isNotNull);
    expect(
      descriptor
          .service('.order.v1.OrderService')!
          .methods
          .map((item) => item.name),
      ['GetOrder', 'CreateOrder', 'SubmitOrders', 'Chat', 'WatchOrders'],
    );
    final createOrder = descriptor.message('.order.v1.CreateOrderRequest')!;
    expect(
      createOrder.fields.singleWhere((field) => field.name == 'priority').type,
      14,
    );
    expect(
      createOrder.fields
          .singleWhere((field) => field.name == 'attributes')
          .mapEntry,
      isTrue,
    );
    expect(createOrder.oneofs, ['fulfilment']);
    final chat = descriptor.service('.order.v1.OrderService')!.methods[3];
    expect(chat.clientStreaming, isTrue);
    expect(chat.serverStreaming, isTrue);
    final watchOrders = descriptor
        .service('.order.v1.OrderService')!
        .methods
        .last;
    expect(watchOrders.clientStreaming, isFalse);
    expect(watchOrders.serverStreaming, isTrue);
  });
}
