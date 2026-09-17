/// 飞书授权页关闭时带回登录页的结果。
class FeishuLoginResult {
  const FeishuLoginResult._({
    this.ticket,
    this.state,
    this.errorMessage,
  });

  /// 服务端在回调时签发的一次性票据，由登录页连同本地 verifier 换 token。
  /// 授权码不再经回跳 URL 传递，所以这里拿不到 code —— 这正是旧协议的问题：
  /// 地址栏、浏览器历史与沿途代理日志都会留下 URL。
  final String? ticket;

  /// 与 ticket 一起带回的 state，登录页用它找回本地待处理事务。
  final String? state;

  final String? errorMessage;

  bool get hasTicket => ticket != null && ticket!.trim().isNotEmpty;

  factory FeishuLoginResult.authorized({
    required String ticket,
    required String state,
  }) =>
      FeishuLoginResult._(ticket: ticket.trim(), state: state.trim());

  factory FeishuLoginResult.cancelled() => const FeishuLoginResult._();

  factory FeishuLoginResult.fail(String message) =>
      FeishuLoginResult._(errorMessage: message);
}
