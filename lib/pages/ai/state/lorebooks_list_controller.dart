import 'package:flutter/foundation.dart';

import '../../../models/ai_lorebook.dart';
import '../../../services/ai_agent_cloud_service.dart';
import '../../../services/ai_db_service.dart';
import '../../../widgets/ai/ai_status_dot.dart';

/// 世界书列表：本地优先展示 + 后台云端同步（与 Provider 页同一节奏）。
class LorebooksListController extends ChangeNotifier {
  List<AiLorebook> lorebooks = [];
  Map<String, int> entryCounts = {};
  AiSyncStatus syncStatus = AiSyncStatus.idle;
  String? syncError;

  bool get hasLocalData => lorebooks.isNotEmpty;
  bool get isInitialLoading =>
      syncStatus == AiSyncStatus.syncing && !hasLocalData;

  String? get syncLabel {
    switch (syncStatus) {
      case AiSyncStatus.syncing:
        return '正在同步云端世界书…';
      case AiSyncStatus.warning:
        return '云端同步失败，已显示本地数据';
      case AiSyncStatus.success:
        return '已与云端同步';
      case AiSyncStatus.idle:
      case AiSyncStatus.error:
        return null;
    }
  }

  Future<void> init() async {
    await loadLocalFirst();
    await syncFromCloud();
  }

  Future<void> refresh() async {
    await loadLocalFirst();
    await syncFromCloud();
  }

  Future<void> loadLocalFirst() async {
    try {
      final local = await AiDbService().getLorebooks();
      if (local.isEmpty) {
        lorebooks = [];
        entryCounts = {};
        notifyListeners();
        return;
      }
      final counts = await Future.wait(
        local.map((lorebook) async {
          final entries = await AiDbService().getLorebookEntries(lorebook.id);
          return MapEntry(lorebook.id, entries.length);
        }),
      );
      lorebooks = local;
      entryCounts = Map<String, int>.fromEntries(counts);
      notifyListeners();
    } catch (_) {
      // 本地读取失败不阻塞，云端同步仍会尝试
    }
  }

  Future<void> syncFromCloud() async {
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
      syncError = e.toString();
      syncStatus = hasLocalData ? AiSyncStatus.warning : AiSyncStatus.error;
    }
    notifyListeners();
  }

  Future<void> deleteLorebook(String id) async {
    await AiAgentCloudService().deleteLorebook(id);
    await refresh();
  }

  int entryCountFor(String lorebookId) => entryCounts[lorebookId] ?? 0;
}
