import 'dart:convert';
import 'dart:typed_data';

import 'package:sendreq/domain/grpc/protobuf_descriptor_set.dart';

/// Protobuf 响应解码结果；失败时保留错误而不是中断调用方流程。
class ProtobufDecodeResult {
  /// 创建解码成功结果，携带格式化 JSON 文本。
  const ProtobufDecodeResult.success(this.formattedJson) : error = null;

  /// 创建解码失败结果，携带错误文本。
  const ProtobufDecodeResult.failure(this.error) : formattedJson = null;

  /// 格式化后的 JSON 文本；失败时为 null。
  final String? formattedJson;

  /// 错误说明；成功时为 null。
  final String? error;

  /// 是否解码成功。
  bool get isSuccess => error == null;
}

/// 基于描述符集合，在 JSON 与 protobuf 二进制之间进行动态编解码。
class ProtobufDynamicCodec {
  /// 创建编解码器并绑定描述符集合。
  const ProtobufDynamicCodec(this.descriptors);

  /// 描述符集合，供编解码查找字段定义。
  final ProtobufDescriptorSet descriptors;

  /// 校验 JSON 是否可按指定消息描述编码；成功返回 null，失败返回字段错误。
  String? validateJson(String typeName, String source) {
    try {
      encodeJson(typeName, source);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  /// 将 JSON 对象文本编码为指定消息类型的 protobuf 字节。
  Uint8List encodeJson(String typeName, String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Protobuf JSON message must be an object.');
    }
    return Uint8List.fromList(_encodeMessage(_message(typeName), value, ''));
  }

  /// 将指定消息类型的 protobuf 字节解码为缩进格式的 JSON 文本。
  String decodeJson(String typeName, Uint8List bytes) =>
      const JsonEncoder.withIndent(
        '  ',
      ).convert(_decodeMessage(_message(typeName), _Reader(bytes), ''));

  /// 安全解码响应消息；单条失败时返回错误文本，调用方可继续处理后续流事件。
  ProtobufDecodeResult tryDecodeJson(String typeName, Uint8List bytes) {
    try {
      return ProtobufDecodeResult.success(decodeJson(typeName, bytes));
    } on FormatException catch (error) {
      return ProtobufDecodeResult.failure(error.message);
    }
  }

  /// 按名称查找消息描述，未找到时报错。
  ProtobufMessageDescriptor _message(String name) =>
      descriptors.message(name) ??
      (throw FormatException('Unknown Protobuf message type: $name'));

  /// 按描述符把 JSON 对象编码为字节流。
  List<int> _encodeMessage(
    ProtobufMessageDescriptor message,
    Map<String, dynamic> value,
    String path,
  ) {
    final bytes = <int>[];
    final selectedOneofs = <int>{};
    for (final entry in value.entries) {
      // 在描述符中定位与 JSON 键同名的字段。
      final field = message.fields
          .where((field) => field.name == entry.key)
          .firstOrNull;
      final fieldPath = path.isEmpty ? entry.key : '$path.${entry.key}';
      if (field == null) throw FormatException('Unknown field: $fieldPath');
      // 同一个 oneof 只能设置一个字段，提前阻止含义不明确的 gRPC 请求。
      final oneof = field.oneofIndex;
      if (oneof != null && !selectedOneofs.add(oneof)) {
        throw FormatException(
          'Only one field may be set for oneof ${message.oneofs[oneof]}.',
        );
      }
      // repeated 字段逐个编码，普通字段包装成单元素列表统一处理。
      final values = field.mapEntry
          ? _mapEntries(entry.value, field)
          : field.repeated
          ? _list(entry.value, fieldPath)
          : [entry.value];
      for (final (index, fieldValue) in values.indexed) {
        // 拼接 tag：字段编号左移 3 位，再按位或上 wire 类型。
        final wire = _wireType(field.type);
        _varint(bytes, (field.number << 3) | wire);
        _encodeValue(
          bytes,
          field,
          fieldValue,
          field.repeated && !field.mapEntry ? '$fieldPath[$index]' : fieldPath,
        );
      }
    }
    return bytes;
  }

  /// 按字段类型把单个值编码为对应的 wire 表示。
  void _encodeValue(
    List<int> bytes,
    ProtobufFieldDescriptor field,
    dynamic value,
    String path,
  ) {
    switch (field.type) {
      case 8:
        // bool：true 编为 1。
        _varint(bytes, value == true ? 1 : 0);
      case 5 || 13 || 3 || 4:
        // 整数类型直接写 varint。
        _varint(bytes, _int(value, path));
      case 14:
        // enum：JSON 使用枚举名称，编码时转成定义中的整数值。
        final enumType = descriptors.enumType(field.typeName ?? '');
        final enumValue = enumType?.values[_string(value, path)];
        if (enumValue == null) {
          throw FormatException('Invalid enum value for $path.');
        }
        _varint(bytes, enumValue);
      case 17 || 18:
        // sint32/sint64：先做 zigzag 变换再写 varint，压缩小负数。
        final number = _int(value, path);
        _varint(bytes, (number << 1) ^ (number >> 63));
      case 9:
        // string：UTF-8 字节加长度前缀。
        _length(bytes, utf8.encode(_string(value, path)));
      case 12:
        // bytes：base64 解码后加长度前缀。
        _length(bytes, base64Decode(_string(value, path)));
      case 11:
        // message：递归编码嵌套消息。
        if (value is! Map<String, dynamic>) {
          throw FormatException('$path must be an object.');
        }
        _length(bytes, _encodeMessage(_message(field.typeName!), value, path));
      default:
        throw FormatException(
          'Unsupported Protobuf field type for ${field.name}.',
        );
    }
  }

  /// 按描述符把字节流解码回 JSON 对象。
  Map<String, dynamic> _decodeMessage(
    ProtobufMessageDescriptor message,
    _Reader reader,
    String path,
  ) {
    final result = <String, dynamic>{};
    while (!reader.done) {
      final tag = reader.varint();
      final number = tag >> 3;
      final wire = tag & 7;
      // 按字段编号定位描述；未知字段直接跳过，保证向前兼容。
      final field = message.fields
          .where((field) => field.number == number)
          .firstOrNull;
      if (field == null) {
        reader.skip(wire);
        continue;
      }
      final fieldPath = path.isEmpty ? field.name : '$path.${field.name}';
      final valuePath = field.repeated && !field.mapEntry
          ? '$fieldPath[${(result[field.name] as List<dynamic>?)?.length ?? 0}]'
          : fieldPath;
      final value = _decodeValue(reader, field, wire, valuePath);
      // repeated 字段追加到列表，否则直接覆盖赋值。
      if (field.mapEntry && value is Map<String, dynamic>) {
        (result[field.name] ??=
                <String, dynamic>{} as dynamic)['${value['key']}'] =
            value['value'];
      } else if (field.repeated) {
        (result[field.name] ??= <dynamic>[] as dynamic).add(value);
      } else {
        result[field.name] = value;
      }
    }
    return result;
  }

  /// 按字段类型解码单个值；wire 类型与声明不符时报错。
  dynamic _decodeValue(
    _Reader reader,
    ProtobufFieldDescriptor field,
    int wire,
    String path,
  ) {
    if (wire != _wireType(field.type)) {
      throw FormatException('Unexpected wire type for $path.');
    }
    switch (field.type) {
      case 8:
        return reader.varint() != 0;
      case 5 || 13 || 3 || 4:
        return reader.varint();
      case 14:
        final value = reader.varint();
        final enumType = descriptors.enumType(field.typeName ?? '');
        return enumType?.values.entries
                .where((entry) => entry.value == value)
                .firstOrNull
                ?.key ??
            value;
      case 17 || 18:
        // zigzag 逆变换，还原带符号整数。
        final value = reader.varint();
        return (value >> 1) ^ -(value & 1);
      case 9:
        return utf8.decode(reader.length());
      case 12:
        return base64Encode(reader.length());
      case 11:
        // 递归解码嵌套消息。
        return _decodeMessage(
          _message(field.typeName!),
          _Reader(reader.length()),
          path,
        );
      default:
        throw FormatException('Unsupported Protobuf field type for $path.');
    }
  }

  /// 字段类型到 wire 类型的映射：string/bytes/message 使用长度前缀类型 2。
  int _wireType(int type) => switch (type) {
    9 || 11 || 12 => 2,
    _ => 0,
  };

  /// 校验值必须是列表，否则报错。
  List<dynamic> _list(dynamic value, String name) =>
      value is List ? value : throw FormatException('$name must be an array.');

  /// 校验值必须是整数，否则报错。
  int _int(dynamic value, String name) =>
      value is int ? value : throw FormatException('$name must be an integer.');

  /// 校验值必须是字符串，否则报错。
  String _string(dynamic value, String name) => value is String
      ? value
      : throw FormatException('$name must be a string.');

  /// 将 JSON object 展开为 map entry 消息列表。
  List<Map<String, dynamic>> _mapEntries(
    dynamic value,
    ProtobufFieldDescriptor field,
  ) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('${field.name} must be an object.');
    }
    return [
      for (final entry in value.entries)
        {'key': entry.key, 'value': entry.value},
    ];
  }

  /// 写出一个 varint：每 7 位一字节，续字节最高位置 1。
  void _varint(List<int> bytes, int value) {
    while (value > 127) {
      bytes.add((value & 127) | 128);
      value >>= 7;
    }
    bytes.add(value);
  }

  /// 写出带长度前缀的字节：先写长度 varint，再追加数据本体。
  void _length(List<int> bytes, List<int> value) {
    _varint(bytes, value.length);
    bytes.addAll(value);
  }
}

/// 解码用的 protobuf wire 格式读取器（按偏移顺序消费字节）。
class _Reader {
  /// 创建读取器并绑定待解码的字节。
  _Reader(this.bytes);

  /// 待解码的原始字节。
  final Uint8List bytes;

  /// 当前读取偏移。
  int offset = 0;

  /// 是否已消费完所有字节。
  bool get done => offset == bytes.length;

  /// 读取一个 varint。
  int varint() {
    var value = 0;
    var shift = 0;
    while (true) {
      if (offset >= bytes.length) {
        throw const FormatException('Unexpected end of Protobuf data.');
      }
      final byte = bytes[offset++];
      value |= (byte & 127) << shift;
      // 最高位为 0 表示 varint 结束。
      if (byte & 128 == 0) return value;
      shift += 7;
    }
  }

  /// 读取一段长度前缀数据。
  Uint8List length() {
    final size = varint();
    if (offset + size > bytes.length) {
      throw const FormatException('Invalid Protobuf length.');
    }
    final value = Uint8List.sublistView(bytes, offset, offset + size);
    offset += size;
    return value;
  }

  /// 跳过未知字段：解码时仅需支持 varint 与长度前缀两类。
  void skip(int wire) {
    switch (wire) {
      case 0:
        varint();
      case 2:
        length();
      default:
        throw const FormatException('Unsupported Protobuf wire type.');
    }
  }
}
