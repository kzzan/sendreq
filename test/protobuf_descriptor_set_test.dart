import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/services/protobuf_descriptor_set.dart';

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
}
