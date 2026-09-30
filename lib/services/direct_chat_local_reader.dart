import 'package:shared_preferences/shared_preferences.dart';

/// 修正私信列表的本机隐藏标记。会话行本身只来自服务端列表。
class DirectChatLocalReader {
  DirectChatLocalReader._();

  /// 左滑「不显示」曾经误写清空标记，再次进入聊天会把记录滤掉。
  ///
  /// 本地会话键还在，说明不是「清空聊天记录」（那条路径会删掉会话键）。
  /// 把时间挪到列表隐藏标记后，去掉清空标记，聊天记录仍可打开。
  static Future<void> releaseMisusedClearMarkers() async {
    final prefs = await SharedPreferences.getInstance();
    const clearedPrefix = 'direct_chat_cleared_';
    const hiddenPrefix = 'direct_chat_hidden_';
    const transcriptPrefix = 'direct_chat_';
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith(clearedPrefix)) continue;
      final rest = key.substring(clearedPrefix.length);
      if (!prefs.containsKey('$transcriptPrefix$rest')) continue;
      final clearedAt = DateTime.tryParse(prefs.getString(key) ?? '');
      if (clearedAt != null) {
        final hiddenKey = '$hiddenPrefix$rest';
        final hiddenAt = DateTime.tryParse(prefs.getString(hiddenKey) ?? '');
        if (hiddenAt == null || clearedAt.isAfter(hiddenAt)) {
          await prefs.setString(hiddenKey, clearedAt.toIso8601String());
        }
      }
      await prefs.remove(key);
    }
  }
}
