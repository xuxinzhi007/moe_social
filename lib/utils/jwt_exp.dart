import 'dart:convert';

/// 仅从 JWT payload 读取 [exp]（秒级 Unix 时间戳），不校验签名（仅用于客户端判断何时刷新）。
int? decodeJwtExpUnixSeconds(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    var payload = parts[1];
    final pad = 4 - payload.length % 4;
    if (pad != 4) {
      payload = payload.padRight(payload.length + pad, '=');
    }
    payload = payload.replaceAll('-', '+').replaceAll('_', '/');
    final bytes = base64.decode(payload);
    final map = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
    final exp = map['exp'];
    if (exp is int) return exp;
    if (exp is num) return exp.toInt();
  } catch (_) {}
  return null;
}
