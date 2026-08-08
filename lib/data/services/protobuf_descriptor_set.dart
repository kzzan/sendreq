import 'dart:typed_data';

/// 单个 protobuf 字段的描述信息。
class ProtobufFieldDescriptor {
  /// 创建单个字段的描述对象。
  const ProtobufFieldDescriptor({
    required this.name,
    required this.number,
    required this.type,
    required this.repeated,
    this.typeName,
    this.oneofIndex,
    this.mapEntry = false,
  });

  /// 字段名。
  final String name;

  /// 字段编号（wire 上的 field number）。
  final int number;

  /// protobuf 字段类型编号（如 8=bool、9=string、11=message）。
  final int type;

  /// 是否为 repeated 重复字段。
  final bool repeated;

  /// 字段类型为消息（type == 11）时引用的完整类型名。
  final String? typeName;

  /// 所属 oneof 声明索引；为空表示字段不受 oneof 约束。
  final int? oneofIndex;

  /// 是否为编译器生成的 map entry 消息字段。
  final bool mapEntry;
}

/// 单个 protobuf 枚举的描述信息。
class ProtobufEnumDescriptor {
  /// 创建枚举描述对象。
  const ProtobufEnumDescriptor({required this.name, required this.values});

  /// 完整限定名。
  final String name;

  /// 枚举名称到数值的稳定映射。
  final Map<String, int> values;
}

/// gRPC/Protobuf service 中的单个 RPC 方法描述。
class ProtobufMethodDescriptor {
  /// 创建 RPC 方法描述。
  const ProtobufMethodDescriptor({
    required this.name,
    required this.requestType,
    required this.responseType,
    this.clientStreaming = false,
    this.serverStreaming = false,
  });

  /// 方法名。
  final String name;

  /// 请求消息类型。
  final String requestType;

  /// 响应消息类型。
  final String responseType;

  /// 是否为客户端流式调用。
  final bool clientStreaming;

  /// 是否为服务端流式调用。
  final bool serverStreaming;
}

/// gRPC/Protobuf service 的描述信息。
class ProtobufServiceDescriptor {
  /// 创建 service 描述对象。
  const ProtobufServiceDescriptor({required this.name, required this.methods});

  /// 完整限定服务名。
  final String name;

  /// 服务公开的 RPC 方法。
  final List<ProtobufMethodDescriptor> methods;
}

/// 单个消息类型的描述，包含字段列表。
class ProtobufMessageDescriptor {
  /// 创建消息类型描述对象。
  const ProtobufMessageDescriptor({
    required this.name,
    required this.fields,
    this.oneofs = const [],
    this.mapEntry = false,
  });

  /// 消息的完整限定名（含包名前缀）。
  final String name;

  /// 该消息的字段描述列表。
  final List<ProtobufFieldDescriptor> fields;

  /// oneof 声明名称，字段通过 [ProtobufFieldDescriptor.oneofIndex] 引用。
  final List<String> oneofs;

  /// 是否为 map 语法生成的内部 entry 消息。
  final bool mapEntry;
}

/// 从 FileDescriptorSet 字节流解析出的消息类型定义集合。
class ProtobufDescriptorSet {
  /// 创建描述符集合。
  const ProtobufDescriptorSet({
    required this.messageTypes,
    required this.messages,
    this.enumTypes = const {},
    this.services = const {},
  });

  /// 按字典序排列的全部消息类型名。
  final List<String> messageTypes;

  /// 消息类型名到描述对象的映射。
  final Map<String, ProtobufMessageDescriptor> messages;

  /// 完整限定枚举名到枚举描述的映射。
  final Map<String, ProtobufEnumDescriptor> enumTypes;

  /// 完整限定服务名到 service 描述的映射。
  final Map<String, ProtobufServiceDescriptor> services;

  /// 按名称查找消息描述，未找到时返回 null。
  ProtobufMessageDescriptor? message(String name) => messages[name];

  /// 按完整限定名查找枚举描述。
  ProtobufEnumDescriptor? enumType(String name) => enumTypes[name];

  /// 按完整限定名查找服务描述。
  ProtobufServiceDescriptor? service(String name) => services[name];

  /// 从 FileDescriptorSet 字节流中解析出全部消息类型。
  static ProtobufDescriptorSet parse(Uint8List bytes) {
    final messages = <String>[];
    final definitions = <String, ProtobufMessageDescriptor>{};
    final enums = <String, ProtobufEnumDescriptor>{};
    final reader = _WireReader(bytes);
    // 顶层遍历 FileDescriptorSet，只关心 file 列表（field 1、wire type 2）。
    while (!reader.isDone) {
      final tag = reader.readVarint();
      if (tag >> 3 == 1 && tag & 7 == 2) {
        // 每个 file 消息中：field 2 为包名，field 4 为消息描述符。
        final file = _WireReader(reader.readLengthDelimited());
        var packageName = '';
        final messageDescriptors = <Uint8List>[];
        final enumDescriptors = <Uint8List>[];
        while (!file.isDone) {
          final fileTag = file.readVarint();
          if (fileTag >> 3 == 2 && fileTag & 7 == 2) {
            packageName = file.readString();
          } else if (fileTag >> 3 == 4 && fileTag & 7 == 2) {
            messageDescriptors.add(file.readLengthDelimited());
          } else if (fileTag >> 3 == 5 && fileTag & 7 == 2) {
            enumDescriptors.add(file.readLengthDelimited());
          } else {
            // 其余未知字段按 wire 类型跳过。
            file.skip(fileTag & 7);
          }
        }
        for (final descriptor in messageDescriptors) {
          _collectMessages(
            _WireReader(descriptor),
            packageName,
            messages,
            definitions,
            enums,
          );
        }
        for (final descriptor in enumDescriptors) {
          final enumType = _parseEnum(_WireReader(descriptor), packageName);
          if (enumType != null) enums[enumType.name] = enumType;
        }
      } else {
        reader.skip(tag & 7);
      }
    }
    if (messages.isEmpty) {
      throw const FormatException(
        'No message types found in FileDescriptorSet.',
      );
    }
    // 排序保证输出顺序稳定，便于 UI 展示与测试断言。
    messages.sort();
    final normalizedDefinitions = <String, ProtobufMessageDescriptor>{
      for (final entry in definitions.entries)
        entry.key: ProtobufMessageDescriptor(
          name: entry.value.name,
          oneofs: entry.value.oneofs,
          mapEntry: entry.value.mapEntry,
          fields: [
            for (final field in entry.value.fields)
              ProtobufFieldDescriptor(
                name: field.name,
                number: field.number,
                type: field.type,
                repeated: field.repeated,
                typeName: field.typeName,
                oneofIndex: field.oneofIndex,
                mapEntry:
                    field.type == 11 &&
                    definitions[field.typeName]?.mapEntry == true,
              ),
          ],
        ),
    };
    return ProtobufDescriptorSet(
      messageTypes: List.unmodifiable(messages),
      messages: Map.unmodifiable(normalizedDefinitions),
      enumTypes: Map.unmodifiable(enums),
    );
  }

  /// 递归收集一条消息描述及其嵌套消息，产出完整限定名。
  static void _collectMessages(
    _WireReader reader,
    String prefix,
    List<String> output,
    Map<String, ProtobufMessageDescriptor> definitions,
    Map<String, ProtobufEnumDescriptor> enums,
  ) {
    String? name;
    final nested = <Uint8List>[];
    final fields = <Uint8List>[];
    final enumDescriptors = <Uint8List>[];
    final oneofs = <String>[];
    var mapEntry = false;
    while (!reader.isDone) {
      final tag = reader.readVarint();
      // DescriptorProto 字段：1=名称、2=字段描述、3=嵌套消息类型。
      if (tag >> 3 == 1 && tag & 7 == 2) {
        name = reader.readString();
      } else if (tag >> 3 == 3 && tag & 7 == 2) {
        nested.add(reader.readLengthDelimited());
      } else if (tag >> 3 == 2 && tag & 7 == 2) {
        fields.add(reader.readLengthDelimited());
      } else if (tag >> 3 == 4 && tag & 7 == 2) {
        enumDescriptors.add(reader.readLengthDelimited());
      } else if (tag >> 3 == 8 && tag & 7 == 2) {
        oneofs.add(_parseOneofName(_WireReader(reader.readLengthDelimited())));
      } else if (tag >> 3 == 7 && tag & 7 == 2) {
        mapEntry = _isMapEntry(_WireReader(reader.readLengthDelimited()));
      } else {
        reader.skip(tag & 7);
      }
    }
    if (name == null || name.isEmpty) return;
    // 前导点号表示根包级消息；嵌套消息按包名逐级拼接限定名。
    final qualified = prefix.isEmpty ? '.$name' : '.$prefix.$name';
    output.add(qualified);
    definitions[qualified] = ProtobufMessageDescriptor(
      name: qualified,
      fields: [for (final field in fields) _parseField(_WireReader(field))],
      oneofs: oneofs.where((name) => name.isNotEmpty).toList(growable: false),
      mapEntry: mapEntry,
    );
    for (final descriptor in enumDescriptors) {
      final enumType = _parseEnum(
        _WireReader(descriptor),
        qualified.substring(1),
      );
      if (enumType != null) enums[enumType.name] = enumType;
    }
    // 递归处理嵌套消息，其前缀为当前消息去掉前导点号的限定名。
    for (final descriptor in nested) {
      _collectMessages(
        _WireReader(descriptor),
        qualified.substring(1),
        output,
        definitions,
        enums,
      );
    }
  }

  /// 解析单个 FieldDescriptorProto：1=名称、3=编号、4=label、5=类型、6=类型名。
  static ProtobufFieldDescriptor _parseField(_WireReader reader) {
    String? name;
    String? typeName;
    var number = 0;
    var type = 0;
    var repeated = false;
    int? oneofIndex;
    while (!reader.isDone) {
      final tag = reader.readVarint();
      switch (tag >> 3) {
        case 1 when tag & 7 == 2:
          name = reader.readString();
        case 3 when tag & 7 == 0:
          number = reader.readVarint();
        case 4 when tag & 7 == 0:
          // label 值为 3 表示 repeated 字段。
          repeated = reader.readVarint() == 3;
        case 5 when tag & 7 == 0:
          type = reader.readVarint();
        case 6 when tag & 7 == 2:
          typeName = reader.readString();
        case 9 when tag & 7 == 0:
          oneofIndex = reader.readVarint();
        default:
          reader.skip(tag & 7);
      }
    }
    if (name == null || number == 0 || type == 0) {
      throw const FormatException('Invalid field descriptor.');
    }
    return ProtobufFieldDescriptor(
      name: name,
      number: number,
      type: type,
      repeated: repeated,
      typeName: typeName,
      oneofIndex: oneofIndex,
    );
  }

  /// 读取 oneof 声明的名称（OneofDescriptorProto 字段 1）。
  static String _parseOneofName(_WireReader reader) {
    while (!reader.isDone) {
      final tag = reader.readVarint();
      if (tag >> 3 == 1 && tag & 7 == 2) return reader.readString();
      reader.skip(tag & 7);
    }
    return '';
  }

  /// 判断消息是否为 map entry（MessageOptions 字段 7）。
  static bool _isMapEntry(_WireReader reader) {
    while (!reader.isDone) {
      final tag = reader.readVarint();
      if (tag >> 3 == 7 && tag & 7 == 0) return reader.readVarint() != 0;
      reader.skip(tag & 7);
    }
    return false;
  }

  /// 解析 EnumDescriptorProto：1=名称、2=枚举值列表。
  static ProtobufEnumDescriptor? _parseEnum(_WireReader reader, String prefix) {
    String? name;
    final values = <String, int>{};
    while (!reader.isDone) {
      final tag = reader.readVarint();
      if (tag >> 3 == 1 && tag & 7 == 2) {
        name = reader.readString();
      } else if (tag >> 3 == 2 && tag & 7 == 2) {
        final value = _WireReader(reader.readLengthDelimited());
        String? valueName;
        int? number;
        while (!value.isDone) {
          final valueTag = value.readVarint();
          if (valueTag >> 3 == 1 && valueTag & 7 == 2) {
            valueName = value.readString();
          } else if (valueTag >> 3 == 2 && valueTag & 7 == 0) {
            number = value.readVarint();
          } else {
            value.skip(valueTag & 7);
          }
        }
        if (valueName != null && number != null) values[valueName] = number;
      } else {
        reader.skip(tag & 7);
      }
    }
    if (name == null) return null;
    return ProtobufEnumDescriptor(name: '.$prefix.$name', values: values);
  }
}

/// 基于字节偏移的 protobuf wire 格式读取器。
class _WireReader {
  /// 创建读取器并绑定待解析的字节。
  _WireReader(this._bytes);

  /// 待解析的原始字节。
  final Uint8List _bytes;
  // 当前读取偏移。
  int _offset = 0;

  /// 是否已读完所有字节。
  bool get isDone => _offset >= _bytes.length;

  /// 读取一个变长整数（varint），每 7 位一字节、续字节最高位为 1。
  int readVarint() {
    var value = 0;
    var shift = 0;
    while (true) {
      // 越界或移位超过 64 位说明数据损坏。
      if (_offset >= _bytes.length || shift > 63) {
        throw const FormatException('Invalid Protobuf wire data.');
      }
      final byte = _bytes[_offset++];
      value |= (byte & 0x7f) << shift;
      // 最高位为 0 表示 varint 结束。
      if (byte & 0x80 == 0) return value;
      shift += 7;
    }
  }

  /// 读取一段长度前缀字节：先读长度 varint，再取对应切片。
  Uint8List readLengthDelimited() {
    final length = readVarint();
    if (length < 0 || _offset + length > _bytes.length) {
      throw const FormatException('Invalid Protobuf field length.');
    }
    // 使用视图切片，避免不必要的整块拷贝。
    final value = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return value;
  }

  /// 读取长度前缀的字符串（UTF-8 编码）。
  String readString() => String.fromCharCodes(readLengthDelimited());

  /// 按 wire 类型跳过对应字节：0=varint、1=64 位、2=长度前缀、5=32 位。
  void skip(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
      case 1:
        _offset += 8;
      case 2:
        readLengthDelimited();
      case 5:
        _offset += 4;
      default:
        throw const FormatException('Unsupported Protobuf wire type.');
    }
    // 跳过越过末尾说明数据格式非法。
    if (_offset > _bytes.length) {
      throw const FormatException('Invalid Protobuf wire data.');
    }
  }
}
