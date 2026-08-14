/// 响应查看器的稳定页签标识。
///
/// UI 标签独立本地化，语言切换不会改变当前页签状态。
enum ResponseTab {
  /// 响应体。
  body,

  /// 响应头。
  headers,

  /// 请求快照。
  requestSnapshot,
}
