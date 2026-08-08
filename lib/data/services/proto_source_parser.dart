import 'dart:io';

import 'package:flutter/services.dart';

import 'protobuf_descriptor_set.dart';

/// 解析本地 `.proto` 源文件及其 import 图，产出供 gRPC 使用的动态描述。
class ProtoSourceParser {
  /// 创建 proto 源解析器。
  const ProtoSourceParser();

  /// 从本地入口文件或应用资源递归读取 schema 图。
  Future<ProtobufDescriptorSet> parseFile(String entryPath) async {
    const assetPrefix = 'asset://';
    if (entryPath.startsWith(assetPrefix)) {
      final assetPath = entryPath.substring(assetPrefix.length);
      final source = await rootBundle.loadString(assetPath);
      // 内置示例 schema 不含 import；用户导入的本地文件仍可完整解析其
      // 相对 import 图，避免把应用资源寻址与用户文件寻址混为一层。
      if (RegExp(r'import\s+"').hasMatch(source)) {
        throw const FormatException(
          'Bundled Protobuf schemas cannot import other files.',
        );
      }
      return parse(entryPath: entryPath, sources: {entryPath: source});
    }
    final sources = <String, String>{};
    Future<void> collect(String path) async {
      final normalizedPath = _normalizePath(path);
      if (sources.containsKey(normalizedPath)) return;
      final source = await File(normalizedPath).readAsString();
      sources[normalizedPath] = source;
      for (final match in RegExp(
        r'import\s+"([^"]+)"\s*;',
      ).allMatches(source)) {
        await collect(_resolveImportPath(normalizedPath, match.group(1)!));
      }
    }

    final normalizedEntryPath = _normalizePath(entryPath);
    await collect(normalizedEntryPath);
    return parse(entryPath: normalizedEntryPath, sources: sources);
  }

  /// [sources] 以 import 路径为键，入口路径必须存在于该映射。
  ProtobufDescriptorSet parse({
    required String entryPath,
    required Map<String, String> sources,
  }) {
    final visited = <String>{};
    final messages = <String, ProtobufMessageDescriptor>{};
    final services = <String, ProtobufServiceDescriptor>{};
    final enums = <String, ProtobufEnumDescriptor>{};

    /// 递归解析单个 proto 源文件；已访问过的路径直接跳过。
    void visit(String path) {
      if (!visited.add(path)) return;
      final source = sources[path];
      if (source == null) throw FormatException('Missing proto import: $path');
      // 先剥离块注释与行注释，避免关键字误匹配。
      final clean = source
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAll(RegExp(r'//.*'), '');
      for (final match in RegExp(r'import\s+"([^"]+)"\s*;').allMatches(clean)) {
        visit(_resolveImportPath(path, match.group(1)!));
      }
      final package =
          RegExp(r'package\s+([\w.]+)\s*;').firstMatch(clean)?.group(1) ?? '';
      final prefix = package.isEmpty ? '' : '.$package';
      for (final declaration in _blocks(clean, 'message')) {
        final name = declaration.name;
        final qualified = '$prefix.$name';
        final fields = <ProtobufFieldDescriptor>[];
        final oneofs = <String>[];
        // oneof 字段先解析并记录索引，其余字段随后加入。
        for (final oneof in _blocks(declaration.body, 'oneof')) {
          final index = oneofs.length;
          oneofs.add(oneof.name);
          fields.addAll(_fields(oneof.body, prefix: prefix, oneofIndex: index));
        }
        fields.addAll(_fields(declaration.body, prefix: prefix));
        messages[qualified] = ProtobufMessageDescriptor(
          name: qualified,
          fields: fields,
          oneofs: oneofs,
        );
      }
      for (final declaration in _blocks(clean, 'enum')) {
        final values = <String, int>{};
        for (final match in RegExp(
          r'\b(\w+)\s*=\s*(-?\d+)\s*;',
        ).allMatches(declaration.body)) {
          values[match.group(1)!] = int.parse(match.group(2)!);
        }
        enums['$prefix.${declaration.name}'] = ProtobufEnumDescriptor(
          name: '$prefix.${declaration.name}',
          values: values,
        );
      }
      for (final declaration in _blocks(clean, 'service')) {
        final methods = <ProtobufMethodDescriptor>[];
        final rpc = RegExp(
          r'rpc\s+(\w+)\s*\(\s*(stream\s+)?([.\w]+)\s*\)\s+returns\s*\(\s*(stream\s+)?([.\w]+)\s*\)\s*;',
        );
        for (final match in rpc.allMatches(declaration.body)) {
          methods.add(
            ProtobufMethodDescriptor(
              name: match.group(1)!,
              requestType: _qualified(prefix, match.group(3)!),
              responseType: _qualified(prefix, match.group(5)!),
              clientStreaming: match.group(2) != null,
              serverStreaming: match.group(4) != null,
            ),
          );
        }
        services['$prefix.${declaration.name}'] = ProtobufServiceDescriptor(
          name: '$prefix.${declaration.name}',
          methods: methods,
        );
      }
    }

    visit(entryPath);
    if (messages.isEmpty && services.isEmpty) {
      throw const FormatException(
        'No messages or services found in proto source.',
      );
    }
    return ProtobufDescriptorSet(
      messageTypes: messages.keys.toList()..sort(),
      messages: Map.unmodifiable(messages),
      enumTypes: Map.unmodifiable(enums),
      services: Map.unmodifiable(services),
    );
  }

  /// 从消息或 oneof 声明体中提取字段列表。
  List<ProtobufFieldDescriptor> _fields(
    String source, {
    required String prefix,
    int? oneofIndex,
  }) {
    final fields = <ProtobufFieldDescriptor>[];
    final expression = RegExp(
      r'\b(repeated\s+)?([.\w]+)\s+(\w+)\s*=\s*(\d+)\s*;',
    );
    for (final match in expression.allMatches(source)) {
      fields.add(
        ProtobufFieldDescriptor(
          name: match.group(3)!,
          number: int.parse(match.group(4)!),
          type: _fieldType(match.group(2)!),
          repeated: match.group(1) != null,
          // Source-level names are relative to the file package unless they
          // start with a dot. The codec only accepts descriptor-level fully
          // qualified names, so resolve them while the package is available.
          typeName: _isScalar(match.group(2)!)
              ? null
              : _qualified(prefix, match.group(2)!),
          oneofIndex: oneofIndex,
        ),
      );
    }
    return fields;
  }

  /// 将 proto 类型名映射为 protobuf 字段类型编号。
  int _fieldType(String value) => switch (value) {
    'bool' => 8,
    'string' => 9,
    'bytes' => 12,
    'int32' || 'int64' || 'uint32' || 'uint64' => 5,
    'sint32' || 'sint64' => 17,
    _ => 11,
  };

  /// 判断类型名是否为内置标量类型。
  bool _isScalar(String value) => const {
    'bool',
    'string',
    'bytes',
    'int32',
    'int64',
    'uint32',
    'uint64',
    'sint32',
    'sint64',
  }.contains(value);

  /// 拼接完整限定名；以点开头的绝对名原样返回。
  String _qualified(String prefix, String name) =>
      name.startsWith('.') ? name : '$prefix.$name';

  /// 基于导入文件所在目录计算 import 的稳定逻辑路径。
  ///
  /// 内存解析可继续使用 `health.proto` 这类相对 key，文件解析则使用绝对
  /// key；两种模式都会用同一规则遍历 import 图。
  String _resolveImportPath(String sourcePath, String importedPath) {
    if (importedPath.startsWith('/')) return _normalizePath(importedPath);
    final separatorIndex = sourcePath.lastIndexOf('/');
    final base = separatorIndex == -1
        ? ''
        : sourcePath.substring(0, separatorIndex + 1);
    return _normalizePath('$base$importedPath');
  }

  /// 消除 `.` / `..`，让递归收集与解析使用相同 map key。
  String _normalizePath(String path) => Uri(path: path).normalizePath().path;
}

/// 一次声明块（message/enum/service）的名称与正文。
class _ProtoBlock {
  /// 创建声明块。
  const _ProtoBlock(this.name, this.body);

  /// 声明名称。
  final String name;

  /// 声明花括号内的正文。
  final String body;
}

/// 提取源码中所有指定关键字的声明块，按花括号深度匹配正文。
List<_ProtoBlock> _blocks(String source, String keyword) {
  final output = <_ProtoBlock>[];
  final start = RegExp('\\b$keyword\\s+(\\w+)\\s*\\{');
  for (final match in start.allMatches(source)) {
    var depth = 1;
    var index = match.end;
    // 用花括号计数定位声明体的结束位置。
    while (index < source.length && depth > 0) {
      final c = source[index++];
      if (c == '{') depth++;
      if (c == '}') depth--;
    }
    if (depth == 0) {
      output.add(
        _ProtoBlock(match.group(1)!, source.substring(match.end, index - 1)),
      );
    }
  }
  return output;
}
