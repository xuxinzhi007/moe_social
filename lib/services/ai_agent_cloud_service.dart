import '../auth_service.dart';
import '../models/ai_agent.dart';
import '../models/ai_lorebook.dart';
import '../models/ai_lorebook_entry.dart';
import 'ai_cloud_config_service.dart';
import 'ai_db_service.dart';

/// 角色卡（AiAgent）以服务器 `GET/PUT/DELETE /api/ai/agents` 为唯一数据源。
/// 本地 SQLite 仅用于聊天会话/消息等，不再缓存角色卡列表。
class AiAgentCloudService {
  AiAgentCloudService._();

  static final AiAgentCloudService _instance = AiAgentCloudService._();
  factory AiAgentCloudService() => _instance;

  Future<List<AiAgent>> getAgents() async {
    final cloudAgents = await AiCloudConfigService().fetchAgents();
    if (cloudAgents == null) {
      throw Exception('加载角色卡失败');
    }
    return cloudAgents.map(AiAgent.fromMap).toList();
  }

  /// 从服务器拉取最新角色卡列表（不写本地）。
  Future<List<AiAgent>> syncAgentsFromCloud() => getAgents();

  Future<List<AiAgent>> fetchPublicAgents({int limit = 50}) async {
    final raw = await AiCloudConfigService().fetchPublicAgents(limit: limit);
    if (raw == null) return const [];
    return raw.map(AiAgent.fromMap).toList();
  }

  Future<void> saveAgent(AiAgent agent) async {
    final record = await _withServerMetadata(agent, isNew: true);
    await AiCloudConfigService().upsertAgent(record.toMap());
  }

  Future<void> updateAgent(AiAgent agent) async {
    final record = await _withServerMetadata(agent, isNew: false);
    await AiCloudConfigService().upsertAgent(record.toMap());
  }

  @Deprecated('Use saveAgent / updateAgent')
  Future<void> syncAgentToCloud(AiAgent agent) async {
    final record = await _withServerMetadata(agent, isNew: false);
    await AiCloudConfigService().upsertAgent(record.toMap());
  }

  Future<AiAgent> _withServerMetadata(AiAgent agent,
      {required bool isNew}) async {
    final now = DateTime.now();
    String? creator = agent.createdByUserId;
    if (isNew) {
      try {
        creator = await AuthService.getUserId();
      } catch (_) {}
    }
    return agent.copyWith(
      createdByUserId: creator,
      updatedAt: now,
    );
  }

  Future<void> deleteAgent(String agentId) async {
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
