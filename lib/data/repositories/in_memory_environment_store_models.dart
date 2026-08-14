import 'package:sendreq/domain/environments/environment_models.dart';

/// 变量的内部存储表示（不可变），含作用域与类型信息。
class StoredEnvironmentVariable {
  const StoredEnvironmentVariable(
    this.id,
    this.scope,
    this.key,
    this.value,
    this.type, {
    this.isProtected = false,
    this.isRequired = false,
  });

  /// 变量唯一 ID。
  final String id;

  /// 变量所属作用域名（环境名或 Global）。
  final String scope;

  /// 变量名（用于模板引用）。
  final String key;

  /// 变量值（密钥为明文存储，展示时再脱敏）。
  final String value;

  /// 变量类型（字符串/数字/密钥）。
  final EnvironmentVariableType type;

  /// token 这类环境必需变量不可删除、改名或改类型。
  final bool isProtected;

  /// baseUrl 这类必填变量不可删除、改名，也不可为空。
  final bool isRequired;

  /// 复制并仅替换给定字段的变量，其余字段保持原值。
  StoredEnvironmentVariable copyWith({
    String? scope,
    String? key,
    String? value,
    EnvironmentVariableType? type,
    bool? isProtected,
    bool? isRequired,
  }) => StoredEnvironmentVariable(
    id,
    scope ?? this.scope,
    key ?? this.key,
    value ?? this.value,
    type ?? this.type,
    isProtected: isProtected ?? this.isProtected,
    isRequired: isRequired ?? this.isRequired,
  );

  /// 序列化为存储 Map，供文件持久化。
  Map<String, Object> toJson() => {
    'id': id,
    'scope': scope,
    'key': key,
    'value': value,
    'type': type.name,
    'isProtected': isProtected,
    'isRequired': isRequired,
  };

  /// 从存储 Map 恢复变量；字段缺失或类型不符时抛出异常。
  factory StoredEnvironmentVariable.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid variable.');
    final json = Map<String, dynamic>.from(value);
    final id = json['id'];
    final scope = json['scope'];
    final key = json['key'];
    final storedValue = json['value'];
    final typeName = json['type'];
    final type = switch (typeName) {
      'string' => EnvironmentVariableType.string,
      'number' => EnvironmentVariableType.number,
      'boolean' => EnvironmentVariableType.boolean,
      'secret' => EnvironmentVariableType.secret,
      _ => null,
    };
    if (id is! String ||
        scope is! String ||
        key is! String ||
        storedValue is! String ||
        type == null) {
      throw const FormatException('Invalid variable fields.');
    }
    return StoredEnvironmentVariable(
      id,
      scope,
      key,
      storedValue,
      type,
      isProtected: json['isProtected'] == true,
      isRequired: json['isRequired'] == true,
    );
  }

  /// 转成可供 UI 展示的视图；密钥未揭示时用圆点占位并标记脱敏。
  EnvironmentVariableView toView({
    required bool revealSecret,
    bool isAuthenticationBinding = false,
  }) => EnvironmentVariableView(
    id: id,
    scope: scope,
    key: key,
    displayValue: type == EnvironmentVariableType.secret && !revealSecret
        ? '••••••••••••••••'
        : value,
    type: type,
    isMasked: type == EnvironmentVariableType.secret && !revealSecret,
    isProtected: isProtected,
    isRequired: isRequired,
    isAuthenticationBinding: isAuthenticationBinding,
  );
}
