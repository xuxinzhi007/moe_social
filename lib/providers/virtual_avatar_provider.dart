import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvatarQuickActions {
  static const notifications = 'notifications';
  static const createPost = 'create_post';
  static const greet = 'greet';
  static const checkin = 'checkin';

  static const defaults = <String>{
    notifications,
    createPost,
    greet,
  };
}

class VirtualAvatarProvider extends ChangeNotifier {
  static const _keyEnabled = 'virtual_avatar_enabled';
  static const _keyQuickActions = 'virtual_avatar_quick_actions';
  static const _keyCharacterId = 'virtual_avatar_character_id';
  static const _keySkinId = 'virtual_avatar_skin_id';
  static const _keyHiddenUntilDay = 'virtual_avatar_hidden_until_day';

  bool _initialized = false;
  bool _enabled = false; // default off
  bool _hiddenInSession = false;
  String? _hiddenUntilDay;

  Set<String> _quickActions = {...AvatarQuickActions.defaults};
  String _characterId = 'default_moe';
  String _skinId = 'classic';

  bool get initialized => _initialized;
  bool get enabled => _enabled;
  bool get hiddenInSession => _hiddenInSession;
  Set<String> get quickActions => _quickActions;
  String get characterId => _characterId;
  String get skinId => _skinId;

  bool get hiddenToday => _hiddenUntilDay == _todayKey();
  bool get isVisible => _enabled && !_hiddenInSession && !hiddenToday;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? false;
    _quickActions =
        (prefs.getStringList(_keyQuickActions)?.toSet() ?? <String>{});
    if (_quickActions.isEmpty) {
      _quickActions = {...AvatarQuickActions.defaults};
    }
    _characterId = prefs.getString(_keyCharacterId) ?? 'default_moe';
    _skinId = prefs.getString(_keySkinId) ?? 'classic';
    _hiddenUntilDay = prefs.getString(_keyHiddenUntilDay);
    _initialized = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (value) {
      _hiddenInSession = false;
      _hiddenUntilDay = null;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
    if (value) {
      await prefs.remove(_keyHiddenUntilDay);
    }
  }

  Future<void> setQuickActionEnabled(String action, bool enabled) async {
    if (enabled) {
      _quickActions.add(action);
    } else {
      if (_quickActions.length <= 1) return;
      _quickActions.remove(action);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyQuickActions, _quickActions.toList());
  }

  Future<void> setCharacterId(String id) async {
    _characterId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCharacterId, id);
  }

  Future<void> setSkinId(String id) async {
    _skinId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySkinId, id);
  }

  void hideForSession() {
    _hiddenInSession = true;
    notifyListeners();
  }

  Future<void> hideForToday() async {
    _hiddenUntilDay = _todayKey();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHiddenUntilDay, _hiddenUntilDay!);
  }

  Future<void> restoreVisibility() async {
    _hiddenInSession = false;
    _hiddenUntilDay = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHiddenUntilDay);
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
