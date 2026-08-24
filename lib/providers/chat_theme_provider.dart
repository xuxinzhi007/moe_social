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
    _currentSkin = skin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skinIdKey, skin.id);
    notifyListeners();
  }
}
