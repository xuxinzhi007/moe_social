// 原生平台走 flutter_secure_storage，这三个函数不该被调用到。
//
// 抛错而不是静默返回 null：静默会把「存储坏了」伪装成「没有待处理事务」，
// 而后者是正常状态（用户还没发起授权）。前者必须让授权当场失败。
UnsupportedError _webOnly() =>
    UnsupportedError('sessionStorage 仅在 Web 平台可用');

String? readOauthSessionItem(String key) => throw _webOnly();

void writeOauthSessionItem(String key, String value) => throw _webOnly();

void removeOauthSessionItem(String key) => throw _webOnly();
