import '../auth_service.dart';
import '../models/ai_agent.dart';
import '../models/ai_lorebook.dart';
import '../models/ai_lorebook_entry.dart';
import 'ai_cloud_config_service.dart';

/// 角色卡和世界书以 `/api/ai/agents`、`/api/ai/lorebooks` 为唯一名单。
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

  /// 聊天页只修改提示词，以最新卡保留服务端模型绑定及其他元数据。
  Future<void> updateSystemPrompt(String agentId, String prompt) async {
    final agents = await getAgents();
    final current = agents.where((agent) => agent.id == agentId).firstOrNull;
    if (current == null) throw Exception('角色卡已不存在，请刷新后重试');
    await updateAgent(current.copyWith(systemPrompt: prompt));
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

  Future<List<AiLorebook>> getLorebooks() async {
    final snapshot = await getLorebooksSnapshot();
    return snapshot.lorebooks;
  }

  /// 拉取世界书列表与条目数量。云端空列表就是空列表。
  Future<({List<AiLorebook> lorebooks, Map<String, int> entryCounts})>
      getLorebooksSnapshot() async {
    return syncLorebooksFromCloud();
  }

  Future<({List<AiLorebook> lorebooks, Map<String, int> entryCounts})>
      syncLorebooksFromCloud() async {
    final cloudLorebooks = await AiCloudConfigService().fetchLorebooks();
    if (cloudLorebooks == null) {
      throw Exception('加载世界书失败');
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
    if (cloudLorebooks == null) {
      throw Exception('加载世界书失败');
    }
    for (final raw in cloudLorebooks) {
      if (raw['id']?.toString() != lorebookId) continue;
      final rawEntries = (raw['entries'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];
      return rawEntries.map(AiLorebookEntry.fromMap).toList();
    }
    return const [];
  }

  Future<void> saveLorebook(
    AiLorebook lorebook,
    List<AiLorebookEntry> entries,
  ) async {
    await AiCloudConfigService().upsertLorebook(
      lorebook.toMap(),
      entries.map((e) => e.toMap()).toList(),
    );
  }

  Future<void> updateLorebook(
    AiLorebook lorebook,
    List<AiLorebookEntry> entries,
  ) async {
    await saveLorebook(lorebook, entries);
  }

  Future<void> deleteLorebook(String lorebookId) async {
    await AiCloudConfigService().deleteLorebook(lorebookId);
  }
}
