import '../models/ai_agent.dart';
import '../models/ai_lorebook.dart';
import '../models/ai_lorebook_entry.dart';
import 'ai_cloud_config_service.dart';
import 'ai_db_service.dart';

class AiAgentCloudService {
  AiAgentCloudService._();

  static final AiAgentCloudService _instance = AiAgentCloudService._();
  factory AiAgentCloudService() => _instance;

  Future<List<AiAgent>> getAgents() async {
    final cloudAgents = await AiCloudConfigService().fetchAgents();
    if (cloudAgents != null && cloudAgents.isNotEmpty) {
      return cloudAgents.map(AiAgent.fromMap).toList();
    }
    return AiDbService().getAgents();
  }

  Future<void> saveAgent(AiAgent agent) async {
    await AiDbService().insertAgent(agent);
    await AiCloudConfigService().upsertAgent(agent.toMap());
  }

  Future<void> updateAgent(AiAgent agent) async {
    await AiDbService().updateAgent(agent);
    await AiCloudConfigService().upsertAgent(agent.toMap());
  }

  Future<void> deleteAgent(String agentId) async {
    await AiDbService().deleteAgent(agentId);
    await AiCloudConfigService().deleteAgent(agentId);
  }

  Future<List<AiLorebook>> getLorebooks() async {
    final cloudLorebooks = await AiCloudConfigService().fetchLorebooks();
    if (cloudLorebooks != null && cloudLorebooks.isNotEmpty) {
      return cloudLorebooks
          .map((e) => AiLorebook.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    return AiDbService().getLorebooks();
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
