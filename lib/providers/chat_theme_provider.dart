import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/chat_skin.dart';

/// 聊天主题皮肤选择（SharedPreferences 持久化）。
class ChatThemeProvider with ChangeNotifier {
  static const String _skinIdKey = 'chat_skin_id';

  ChatSkin _currentSkin = ChatSkins.lavender;

  ChatSkin get currentSkin => _currentSkin;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final skinId = prefs.getString(_skinIdKey);
    if (skinId != null) {
      _currentSkin = ChatSkins.byId(skinId) ?? ChatSkins.lavender;
    }
    notifyListeners();
  }

  Future<void> setSkin(ChatSkin skin) async {
    if (_currentSkin.id == skin.id) return;
    final old = _currentSkin;
    _currentSkin = skin;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skinIdKey, skin.id);
    } catch (e) {
      // 写盘失败回滚到旧值，保持 UI 与持久化一致；不向外抛出。
      // 守卫：仅当当前值仍是本次要写的 skin 时才回滚，避免并发切换被旧回滚覆盖。
      if (identical(_currentSkin, skin)) {
        _currentSkin = old;
        notifyListeners();
      }
      debugPrint('聊天皮肤持久化失败: $e');
    }
  }
}
