/// 请求编辑器分区的稳定标识。
///
/// 展示标签由本地化资源映射，切换语言不会影响 ViewModel 保存的活动分区。
enum RequestEditorSection {
  /// 查询参数。
  params('Params'),

  /// 请求头。
  headers('Headers'),

  /// 认证。
  auth('Auth'),

  /// 请求体。
  body('Body'),

  /// 协议配置。
  protocol('Protocol');

  /// 绑定稳定的节标识。
  const RequestEditorSection(this.id);

  /// 稳定的节标识，与本地化文本无关。
  final String id;
}
