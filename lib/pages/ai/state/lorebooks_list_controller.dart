import 'package:flutter/foundation.dart';

import '../../../models/ai_lorebook.dart';
import '../../../services/ai_agent_cloud_service.dart';
import '../../../widgets/ai/ai_status_dot.dart';

/// 世界书列表只展示服务端 `/api/ai/lorebooks`。
class LorebooksListController extends ChangeNotifier {
  List<AiLorebook> lorebooks = [];
  Map<String, int> entryCounts = {};
  AiSyncStatus syncStatus = AiSyncStatus.idle;
  String? syncError;

  bool get hasData => lorebooks.isNotEmpty;
  bool get isInitialLoading => syncStatus == AiSyncStatus.syncing && !hasData;

  String? get syncLabel {
    switch (syncStatus) {
      case AiSyncStatus.syncing:
        return '正在加载世界书…';
      case AiSyncStatus.warning:
        return '刷新失败，仍显示上次加载的列表';
      case AiSyncStatus.error:
        return syncError ?? '加载世界书失败';
      case AiSyncStatus.success:
      case AiSyncStatus.idle:
        return null;
    }
  }

  Future<void> init() => refresh();

  Future<void> refresh() async {
    syncError = null;
    syncStatus = AiSyncStatus.syncing;
    notifyListeners();
    try {
      final snapshot = await AiAgentCloudService().syncLorebooksFromCloud();
      lorebooks = snapshot.lorebooks;
      entryCounts = snapshot.entryCounts;
      syncStatus = AiSyncStatus.success;
      syncError = null;
    } catch (e) {
      syncError = '加载世界书失败';
      syncStatus = hasData ? AiSyncStatus.warning : AiSyncStatus.error;
    }
    notifyListeners();
  }

  Future<void> deleteLorebook(String id) async {
    await AiAgentCloudService().deleteLorebook(id);
    await refresh();
  }

  int entryCountFor(String lorebookId) => entryCounts[lorebookId] ?? 0;
}
