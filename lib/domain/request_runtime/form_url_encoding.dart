import 'package:sendreq/domain/workspace/workspace_models.dart';

/// 将启用的键值字段编码为 application/x-www-form-urlencoded 请求正文。
///
/// 保留字段顺序、重复键与空值；空字段名不构成可发送的表单字段。
String encodeFormUrlFields(Iterable<KeyValueRow> fields) => [
  for (final field in fields)
    if (field.enabled && field.keyName.trim().isNotEmpty)
      '${encodeFormUrlComponent(field.keyName)}=${encodeFormUrlComponent(field.value)}',
].join('&');

/// x-www-form-urlencoded 使用加号表示空格，同时保留加号本身的百分号编码。
String encodeFormUrlComponent(String value) =>
    Uri.encodeQueryComponent(value).replaceAll('%20', '+');
