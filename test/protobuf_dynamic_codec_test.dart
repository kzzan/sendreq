import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/services/protobuf_descriptor_set.dart';
import 'package:sendreq/data/services/protobuf_dynamic_codec.dart';

void main() {
  // 构造一个含 oneof、枚举、map 与 repeated 消息的虚拟描述符集，
  // 供后续用例验证动态编解码器的校验与编码行为。
  const descriptors = ProtobufDescriptorSet(
    messageTypes: ['.sendreq.Check'],
    messages: {
      '.sendreq.Check': ProtobufMessageDescriptor(
        name: '.sendreq.Check',
        // host 与 zone 同属一个 oneof（target），只能同时设置一个。
        oneofs: ['target'],
        fields: [
          ProtobufFieldDescriptor(
            name: 'host',
            number: 1,
            type: 9,
            repeated: false,
            oneofIndex: 0,
          ),
          ProtobufFieldDescriptor(
            name: 'zone',
            number: 2,
            type: 9,
            repeated: false,
            oneofIndex: 0,
          ),
          ProtobufFieldDescriptor(
            name: 'status',
            number: 3,
            type: 14,
            repeated: false,
            typeName: '.sendreq.Status',
          ),
          ProtobufFieldDescriptor(
            name: 'labels',
            number: 4,
            type: 11,
            repeated: true,
            typeName: '.sendreq.Check.LabelsEntry',
            mapEntry: true,
          ),
          ProtobufFieldDescriptor(
            name: 'children',
            number: 5,
            type: 11,
            repeated: true,
            typeName: '.sendreq.Child',
          ),
        ],
      ),
      '.sendreq.Child': ProtobufMessageDescriptor(
        name: '.sendreq.Child',
        fields: [
          ProtobufFieldDescriptor(
            name: 'name',
            number: 1,
            type: 9,
            repeated: false,
          ),
        ],
      ),
      // map<string,string> 在底层表现为 key/value 两个字段的消息条目。
      '.sendreq.Check.LabelsEntry': ProtobufMessageDescriptor(
        name: '.sendreq.Check.LabelsEntry',
        mapEntry: true,
        fields: [
          ProtobufFieldDescriptor(
            name: 'key',
            number: 1,
            type: 9,
            repeated: false,
          ),
          ProtobufFieldDescriptor(
            name: 'value',
            number: 2,
            type: 9,
            repeated: false,
          ),
        ],
      ),
    },
    enumTypes: {
      '.sendreq.Status': ProtobufEnumDescriptor(
        name: '.sendreq.Status',
        values: {'STATUS_OK': 0, 'STATUS_FAILED': 1},
      ),
    },
  );

  // 用例 1：oneof 内同时设置多个字段应返回字段级校验错误。
  test('reports a field-level oneof validation error', () {
    final error = const ProtobufDynamicCodec(
      descriptors,
    ).validateJson('.sendreq.Check', '{"host":"api","zone":"cn"}');
    expect(error, 'Only one field may be set for oneof target.');
  });

  // 用例 2：枚举按名称编解码，未知枚举值会被校验拒绝。
  test('encodes and decodes enum names', () {
    final codec = const ProtobufDynamicCodec(descriptors);
    final bytes = codec.encodeJson(
      '.sendreq.Check',
      '{"status":"STATUS_FAILED"}',
    );
    expect(
      codec.decodeJson('.sendreq.Check', bytes),
      contains('STATUS_FAILED'),
    );
    expect(
      codec.validateJson('.sendreq.Check', '{"status":"UNKNOWN"}'),
      'Invalid enum value for status.',
    );
  });

  // 用例 3：嵌套 repeated 字段的错误路径应带下标（children[0].name）。
  test('reports nested repeated field paths', () {
    expect(
      const ProtobufDynamicCodec(
        descriptors,
      ).validateJson('.sendreq.Check', '{"children":[{"name":42}]}'),
      'children[0].name must be a string.',
    );
  });

  // 用例 4：map 对象按 map entry 编码，解码后还原为 key/value 形式。
  test('encodes map objects as map entries', () {
    final codec = const ProtobufDynamicCodec(descriptors);
    final bytes = codec.encodeJson(
      '.sendreq.Check',
      '{"labels":{"env":"prod"}}',
    );
    final decoded = codec.decodeJson('.sendreq.Check', bytes);
    expect(decoded, contains('"labels": {'));
    expect(decoded, contains('"env": "prod"'));
  });

  // 用例 5：解码遇到意外 wire type 时，错误信息应带嵌套字段路径。
  test('returns decode errors with nested field paths', () {
    final result = const ProtobufDynamicCodec(
      descriptors,
    ).tryDecodeJson('.sendreq.Check', Uint8List.fromList([42, 2, 8, 1]));

    expect(result.isSuccess, isFalse);
    expect(result.error, 'Unexpected wire type for children[0].name.');
  });
}
