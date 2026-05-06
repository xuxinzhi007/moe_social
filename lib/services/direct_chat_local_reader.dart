import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 读取 [DirectChatPage] 持久化的 `direct_chat_*` 会话，得到每个 peer 的最后一条消息与时间。
class DirectChatLocalReader {
  DirectChatLocalReader._();

  static Future<Map<String, ({DateTime at, String rawPreview})>> readThreadTails(
    String myUserId,
  ) async {
    if (myUserId.isEmpty) return {};
    final prefs = await SharedPreferences.getInstance();
    const prefix = 'direct_chat_';
    final out = <String, ({DateTime at, String rawPreview})>{};

    for (final k in prefs.getKeys()) {
      if (!k.startsWith(prefix)) continue;
      final rest = k.substring(prefix.length);
      final parts = rest.split('_');
      if (parts.length != 2) continue;
      final a = parts[0];
      final b = parts[1];
      final peerId = a == myUserId ? b : (b == myUserId ? a : '');
      if (peerId.isEmpty || peerId == myUserId) continue;

      final raw = prefs.getString(k);
      if (raw == null || raw.isEmpty) continue;
      try {
        final list = json.decode(raw) as List<dynamic>;
        if (list.isEmpty) continue;
        final last = list.last as Map<String, dynamic>;
        final content = (last['content'] as String?)?.trim() ?? '';
        if (content.isEmpty) continue;
        final at = DateTime.tryParse(last['time'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final prev = out[peerId];
        if (prev == null || at.isAfter(prev.at)) {
          out[peerId] = (at: at, rawPreview: content);
        }
      } catch (_) {}
    }
    return out;
  }
}
