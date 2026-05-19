/// 聊天消息展示与重试相关工具。
class AiChatMessageUtils {
  AiChatMessageUtils._();

  static const _errorPrefixes = [
    '请求失败',
    '无法连接',
    'API 认证失败',
    'Provider 请求失败',
    '模型服务请求失败',
    '响应格式异常',
    '请先在「模型来源」',
    'Ollama 错误',
    '请求超时',
  ];

  /// 将整行中文括号动作转为 Markdown 斜体，便于与对话区分。
  static String formatRoleplayContent(String raw) {
    final lines = raw.split('\n');
    final out = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('（') &&
          trimmed.endsWith('）') &&
          trimmed.length >= 2) {
        out.add('*${trimmed.substring(1, trimmed.length - 1)}*');
      } else {
        out.add(line);
      }
    }
    return out.join('\n');
  }

  static bool looksLikeErrorContent(String content) {
    final t = content.trim();
    if (t.isEmpty) return false;
    for (final prefix in _errorPrefixes) {
      if (t.startsWith(prefix)) return true;
    }
    return false;
  }
}
