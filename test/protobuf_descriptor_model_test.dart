import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/grpc/protobuf_descriptor_set.dart';

void main() {
  // 动态描述模型须同时承载 Protobuf 约束和 gRPC service/RPC 元数据。
  test('descriptor set exposes enum, oneof, map, and service metadata', () {
    const descriptor = ProtobufDescriptorSet(
      messageTypes: ['.sendreq.CheckRequest'],
      messages: {
        '.sendreq.CheckRequest': ProtobufMessageDescriptor(
          name: '.sendreq.CheckRequest',
          oneofs: ['target'],
          fields: [
            ProtobufFieldDescriptor(
              name: 'host',
              number: 1,
              type: 9,
              repeated: false,
              oneofIndex: 0,
            ),
          ],
        ),
      },
      enumTypes: {
        '.sendreq.Status': ProtobufEnumDescriptor(
          name: '.sendreq.Status',
          values: {'STATUS_OK': 0},
        ),
      },
      services: {
        // 服务元数据需同时暴露方法与流式标志，供 gRPC 调用面板使用。
        '.sendreq.Health': ProtobufServiceDescriptor(
          name: '.sendreq.Health',
          methods: [
            ProtobufMethodDescriptor(
              name: 'Watch',
              requestType: '.sendreq.CheckRequest',
              responseType: '.sendreq.Status',
              serverStreaming: true,
            ),
          ],
        ),
      },
    );

    // 三类查询分别验证消息/枚举/服务元数据的可访问性。
    expect(descriptor.message('.sendreq.CheckRequest')!.oneofs, ['target']);
    expect(descriptor.enumType('.sendreq.Status')!.values['STATUS_OK'], 0);
    expect(
      descriptor.service('.sendreq.Health')!.methods.single.serverStreaming,
      isTrue,
    );
  });
}
