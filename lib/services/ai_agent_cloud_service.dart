import '../models/ai_agent.dart';
import '../models/ai_lorebook.dart';
import '../models/ai_lorebook_entry.dart';
import 'ai_cloud_config_service.dart';
import 'ai_db_service.dart';

class AiAgentCloudService {
  AiAgentCloudService._();

  static final AiAgentCloudService _instance = AiAgentCloudService._();
  factory AiAgentCloudService() => _instance;

  Future<List<AiAgent>> getLocalAgents() {
    return AiDbService().getAgents();
  }

  Future<List<AiAgent>> getAgents() async {
    final localAgents = await AiDbService().getAgents();
    if (localAgents.isNotEmpty) {
      return localAgents;
    }
    final cloudAgents = await AiCloudConfigService().fetchAgents();
    if (cloudAgents != null && cloudAgents.isNotEmpty) {
      return cloudAgents.map(AiAgent.fromMap).toList();
    }
    return localAgents;
  }

  Future<List<AiAgent>> syncAgentsFromCloud() async {
    final cloudAgents = await AiCloudConfigService().fetchAgents();
    if (cloudAgents == null) {
      throw Exception('云端角色卡同步失败');
    }
    if (cloudAgents.isEmpty) {
      return AiDbService().getAgents();
    }
    return cloudAgents.map(AiAgent.fromMap).toList();
  }

  Future<void> saveAgent(AiAgent agent) async {
    await AiDbService().insertAgent(agent);
    await AiCloudConfigService().upsertAgent(agent.toMap());
  }

  Future<void> updateAgent(AiAgent agent) async {
    await AiDbService().updateAgent(agent);
    await AiCloudConfigService().upsertAgent(agent.toMap());
  }

  Future<void> syncAgentToCloud(AiAgent agent) async {
    await AiCloudConfigService().upsertAgent(agent.toMap());
  }

  Future<void> deleteAgent(String agentId) async {
    await AiDbService().deleteAgent(agentId);
    await AiCloudConfigService().deleteAgent(agentId);
  }

  Future<List<AiLorebook>> getLocalLorebooks() {
    return AiDbService().getLorebooks();
  }

  Future<List<AiLorebook>> getLorebooks() async {
    final snapshot = await getLorebooksSnapshot();
    return snapshot.lorebooks;
  }

  Future<({List<AiLorebook> lorebooks, Map<String, int> entryCounts})>
      getLocalLorebooksSnapshot() async {
    final local = await AiDbService().getLorebooks();
    if (local.isEmpty) {
      return (lorebooks: local, entryCounts: <String, int>{});
    }
    final counts = await Future.wait(
      local.map((lorebook) async {
        final entries = await AiDbService().getLorebookEntries(lorebook.id);
        return MapEntry(lorebook.id, entries.length);
      }),
    );
    return (
      lorebooks: local,
      entryCounts: Map<String, int>.fromEntries(counts),
    );
  }

  /// 单次拉取世界书列表与条目数量，避免列表页 N+1 重复请求云端。
  Future<({List<AiLorebook> lorebooks, Map<String, int> entryCounts})>
      getLorebooksSnapshot() async {
    final cloudLorebooks = await AiCloudConfigService().fetchLorebooks();
    if (cloudLorebooks != null && cloudLorebooks.isNotEmpty) {
      final lorebooks = cloudLorebooks
          .map((e) => AiLorebook.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      final counts = <String, int>{};
      for (final item in cloudLorebooks) {
        final id = item['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final rawEntries = item['entries'];
        if (rawEntries is List) {
          counts[id] = rawEntries.length;
        } else {
          counts[id] = 0;
        }
      }
      return (lorebooks: lorebooks, entryCounts: counts);
    }

    final local = await AiDbService().getLorebooks();
    if (local.isEmpty) {
      return (lorebooks: local, entryCounts: <String, int>{});
    }
    final counts = await Future.wait(
      local.map((lorebook) async {
        final entries = await AiDbService().getLorebookEntries(lorebook.id);
        return MapEntry(lorebook.id, entries.length);
      }),
    );
    return (
      lorebooks: local,
      entryCounts: Map<String, int>.fromEntries(counts),
    );
  }

  Future<({List<AiLorebook> lorebooks, Map<String, int> entryCounts})>
      syncLorebooksFromCloud() async {
    final cloudLorebooks = await AiCloudConfigService().fetchLorebooks();
    if (cloudLorebooks == null) {
      throw Exception('云端世界书同步失败');
    }
    if (cloudLorebooks.isEmpty) {
      return getLocalLorebooksSnapshot();
    }
    final lorebooks = cloudLorebooks
        .map((e) => AiLorebook.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final counts = <String, int>{};
    for (final item in cloudLorebooks) {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final rawEntries = item['entries'];
      counts[id] = rawEntries is List ? rawEntries.length : 0;
    }
    return (lorebooks: lorebooks, entryCounts: counts);
  }

  Future<List<AiLorebookEntry>> getLorebookEntries(String lorebookId) async {
    final cloudLorebooks = await AiCloudConfigService().fetchLorebooks();
    if (cloudLorebooks != null && cloudLorebooks.isNotEmpty) {
      final item = cloudLorebooks.cast<Map<String, dynamic>?>().firstWhere(
            (entry) => entry?['id']?.toString() == lorebookId,
            orElse: () => null,
          );
      if (item != null) {
        final rawEntries = (item['entries'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const <Map<String, dynamic>>[];
        return rawEntries.map(AiLorebookEntry.fromMap).toList();
      }
    }
    return AiDbService().getLorebookEntries(lorebookId);
  }

  Future<void> saveLorebook(
    AiLorebook lorebook,
    List<AiLorebookEntry> entries,
  ) async {
    await AiDbService().insertLorebook(lorebook);
    await AiDbService().replaceLorebookEntries(lorebook.id, entries);
    await AiCloudConfigService().upsertLorebook(
      lorebook.toMap(),
      entries.map((e) => e.toMap()).toList(),
    );
  }

  Future<void> updateLorebook(
    AiLorebook lorebook,
    List<AiLorebookEntry> entries,
  ) async {
    await AiDbService().updateLorebook(lorebook);
    await AiDbService().replaceLorebookEntries(lorebook.id, entries);
    await AiCloudConfigService().upsertLorebook(
      lorebook.toMap(),
      entries.map((e) => e.toMap()).toList(),
    );
  }

  Future<void> deleteLorebook(String lorebookId) async {
    await AiDbService().deleteLorebook(lorebookId);
    await AiCloudConfigService().deleteLorebook(lorebookId);
  }
}
