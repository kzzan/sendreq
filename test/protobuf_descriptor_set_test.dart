import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/grpc/protobuf_descriptor_set.dart';

void main() {
  // 验证解析器能从序列化的 FileDescriptorSet 中展开消息类型，且嵌套类型以点分全名返回。
  test('discovers nested message types from a FileDescriptorSet', () {
    // 手工构造的 FileDescriptorSet 二进制：包含 file(包名 sendreq)、
    // message Event，以及嵌套其中的 message Metadata。
    final bytes = Uint8List.fromList([
      0x0a,
      0x1e,
      0x12,
      0x07,
      ...'sendreq'.codeUnits,
      0x22,
      0x13,
      0x0a,
      0x05,
      ...'Event'.codeUnits,
      0x1a,
      0x0a,
      0x0a,
      0x08,
      ...'Metadata'.codeUnits,
    ]);

    // 期望得到扁平化后的全名列表，含嵌套的 .sendreq.Event.Metadata。
    expect(ProtobufDescriptorSet.parse(bytes).messageTypes, [
      '.sendreq.Event',
      '.sendreq.Event.Metadata',
    ]);
  });

  // 验证没有任何消息类型的 descriptor set 会被视为无效输入并抛出 FormatException。
  test('rejects descriptor sets without message types', () {
    expect(
      () => ProtobufDescriptorSet.parse(Uint8List.fromList([0x0a, 0x00])),
      throwsFormatException,
    );
  });

  test('parses services and streaming methods from descriptor sets', () {
    final message = _messageDescriptor('Check');
    final method = <int>[];
    _stringField(method, 1, 'Chat');
    _stringField(method, 2, '.sendreq.Check');
    _stringField(method, 3, '.sendreq.Check');
    _varintField(method, 5, 1);
    _varintField(method, 6, 1);
    final service = <int>[];
    _stringField(service, 1, 'Health');
    _bytesField(service, 2, method);
    final file = <int>[];
    _stringField(file, 2, 'sendreq');
    _bytesField(file, 4, message);
    _bytesField(file, 6, service);
    final descriptorSet = <int>[];
    _bytesField(descriptorSet, 1, file);

    final descriptors = ProtobufDescriptorSet.parse(
      Uint8List.fromList(descriptorSet),
    );
    final parsed = descriptors.service('.sendreq.Health')!.methods.single;

    expect(parsed.name, 'Chat');
    expect(parsed.requestType, '.sendreq.Check');
    expect(parsed.responseType, '.sendreq.Check');
    expect(parsed.clientStreaming, isTrue);
    expect(parsed.serverStreaming, isTrue);
  });
}

List<int> _messageDescriptor(String name) {
  final bytes = <int>[];
  _stringField(bytes, 1, name);
  return bytes;
}

void _stringField(List<int> output, int number, String value) =>
    _bytesField(output, number, value.codeUnits);

void _bytesField(List<int> output, int number, List<int> value) {
  _varint(output, (number << 3) | 2);
  _varint(output, value.length);
  output.addAll(value);
}

void _varintField(List<int> output, int number, int value) {
  _varint(output, number << 3);
  _varint(output, value);
}

void _varint(List<int> output, int value) {
  var remaining = value;
  while (remaining > 127) {
    output.add((remaining & 127) | 128);
    remaining >>= 7;
  }
  output.add(remaining);
}
