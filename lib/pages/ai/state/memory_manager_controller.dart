import 'package:flutter/foundation.dart';

import '../../../models/ai_agent.dart';
import '../../../models/user_memory.dart';
import '../../../models/user_memory_display.dart';
import '../../../models/user_memory_profile.dart';
import '../../../services/ai_memory_orchestrator.dart';

/// 记忆库页：仅展示后端处理后的用户可读数据。
class MemoryManagerController extends ChangeNotifier {
  MemoryManagerController(this.agent);

  final AiAgent agent;

  String headline = '';
  List<UserMemoryDisplayItem> displayItems = [];
  List<UserMemoryDisplayProfile> displayProfiles = [];
  List<UserMemory> accountMemories = [];
  List<UserMemoryProfile> accountProfiles = [];

  bool memoryPaused = false;
  bool isLoading = true;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      final state = await AiMemoryOrchestrator().loadManagerState(agent);
      memoryPaused = state.activeMode == AiMemoryMode.disabled;
      accountMemories = state.accountMemories;
      accountProfiles = state.accountProfiles;
      final display = state.display;
      if (display != null) {
        headline = display.headline;
        displayItems = display.items;
        displayProfiles = display.profiles;
      } else {
        headline = memoryPaused
            ? '记忆功能已暂停（调试模式）'
            : '继续聊天后，AI 会自动记住你的偏好与重要信息';
        displayItems = const [];
        displayProfiles = const [];
      }
      isLoading = false;
    } catch (_) {
      isLoading = false;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deleteAccountMemory(UserMemory memory) async {
    await AiMemoryOrchestrator().deleteAccountMemory(memory);
    await load();
  }

  Future<void> clearAccountMemories() async {
    if (accountMemories.isEmpty) return;
    await AiMemoryOrchestrator()
        .clearAllAccountMemories(List<UserMemory>.from(accountMemories));
    await load();
  }
}
