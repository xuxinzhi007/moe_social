import 'dart:convert';

import '../models/ai_agent.dart';
import '../models/ai_lorebook.dart';
import '../models/ai_lorebook_entry.dart';
import '../models/ai_provider_profile.dart';
import 'ai_agent_cloud_service.dart';
import 'ai_db_service.dart';
import 'ai_provider_service.dart';

class AiCharacterCardImportResult {
  final AiAgent agent;
  final AiProviderProfile? providerProfile;
  final AiLorebook? lorebook;
  final List<String> notices;

  const AiCharacterCardImportResult({
    required this.agent,
    this.providerProfile,
    this.lorebook,
    this.notices = const [],
  });
}

class AiCharacterCardService {
  AiCharacterCardService._();

  static final AiCharacterCardService _instance = AiCharacterCardService._();
  factory AiCharacterCardService() => _instance;

  static const String cardType = 'moe_social_character_card';
  static const int cardVersion = 1;

  Future<String> exportCharacterCardJson(AiAgent agent) async {
    AiProviderProfile? providerProfile;
    final providerId = agent.providerProfileId?.trim() ?? '';
    if (providerId.isNotEmpty) {
      final resolved = await AiProviderService().resolveProfile(providerId);
      if (!resolved.isBuiltinBackend) {
        providerProfile = resolved;
      }
    }

    AiLorebook? lorebook;
    List<AiLorebookEntry> lorebookEntries = const [];
    final lorebookId = agent.lorebookId?.trim() ?? '';
    if (lorebookId.isNotEmpty) {
      lorebook = await AiDbService().getLorebook(lorebookId);
      if (lorebook != null) {
        lorebookEntries = await AiDbService().getLorebookEntries(lorebook.id);
      }
    }

    final payload = <String, dynamic>{
      'card_type': cardType,
      'version': cardVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'agent': _agentToCardMap(agent),
      if (providerProfile != null)
        'provider_profile': _providerToCardMap(providerProfile),
      if (lorebook != null)
        'lorebook': _lorebookToCardMap(
          lorebook,
          entries: lorebookEntries,
        ),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<AiCharacterCardImportResult> importCharacterCardJson(
    String rawJson,
  ) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (_) {
      throw Exception('角色卡 JSON 解析失败');
    }
    if (decoded is! Map) {
      throw Exception('角色卡格式无效');
    }

    final root = Map<String, dynamic>.from(decoded);
    final agentRaw = root['agent'];
    if (agentRaw is! Map) {
      throw Exception('角色卡缺少 agent 字段');
    }
    final agentMap = Map<String, dynamic>.from(agentRaw);
    final notices = <String>[];
    final now = DateTime.now();

    AiProviderProfile? importedProvider;
    final providerRaw = root['provider_profile'];
    if (providerRaw is Map) {
      importedProvider = await _importProviderProfile(
        Map<String, dynamic>.from(providerRaw),
        now: now,
      );
      notices.add('Provider 已导入，但不包含 API Key，请手动补充');
    }

    AiLorebook? importedLorebook;
    final lorebookRaw = root['lorebook'];
    if (lorebookRaw is Map) {
      importedLorebook = await _importLorebook(
        Map<String, dynamic>.from(lorebookRaw),
        now: now,
      );
    }

    String? providerProfileId;
    if (importedProvider != null) {
      providerProfileId =
          importedProvider.isBuiltinBackend ? null : importedProvider.id;
    } else {
      final requestedProviderId =
          (agentMap['provider_profile_id'] ?? '').toString().trim();
      if (requestedProviderId.isNotEmpty &&
          requestedProviderId != AiProviderProfile.builtinBackendId) {
        final existing =
            await AiProviderService().resolveProfile(requestedProviderId);
        if (!existing.isBuiltinBackend) {
          providerProfileId = existing.id;
        } else {
          notices.add('原角色卡未附带可用 Provider，导入后需要手动重新选择');
        }
      }
    }

    final importedAgent = AiAgent(
      id: 'agent_import_${DateTime.now().microsecondsSinceEpoch}',
      name: _safeString(agentMap['name'], fallback: '导入角色'),
      description: _safeString(agentMap['description']),
      systemPrompt: _safeString(agentMap['system_prompt']),
      modelName: _safeString(agentMap['model_name']),
      providerProfileId: providerProfileId,
      lorebookId: importedLorebook?.id,
      persona: _safeString(agentMap['persona']),
      scenario: _safeString(agentMap['scenario']),
      openingMessage: _safeString(agentMap['opening_message']),
      exampleDialogues: _safeString(agentMap['example_dialogues']),
      createdAt: now,
    );

    await AiAgentCloudService().saveAgent(importedAgent);

    return AiCharacterCardImportResult(
      agent: importedAgent,
      providerProfile: importedProvider,
      lorebook: importedLorebook,
      notices: notices,
    );
  }

  Map<String, dynamic> _agentToCardMap(AiAgent agent) {
    return {
      'name': agent.name,
      'description': agent.description,
      'system_prompt': agent.systemPrompt,
      'model_name': agent.modelName,
      'provider_profile_id': agent.providerProfileId,
      'persona': agent.persona,
      'scenario': agent.scenario,
      'opening_message': agent.openingMessage,
      'example_dialogues': agent.exampleDialogues,
    };
  }

  Map<String, dynamic> _providerToCardMap(AiProviderProfile profile) {
    return {
      'name': profile.name,
      'provider_type': profile.providerType.value,
      'base_url': profile.baseUrl,
      'default_model': profile.defaultModel,
      'manual_models': profile.manualModels,
      'use_server_memory': profile.useServerMemory,
      'supports_system_messages': profile.supportsSystemMessages,
      'supports_streaming': profile.supportsStreaming,
      'supports_vision': profile.supportsVision,
      'supports_tool_calls': profile.supportsToolCalls,
    };
  }

  Map<String, dynamic> _lorebookToCardMap(
    AiLorebook lorebook, {
    required List<AiLorebookEntry> entries,
  }) {
    return {
      'name': lorebook.name,
      'description': lorebook.description,
      'entries': entries.map(_lorebookEntryToCardMap).toList(),
    };
  }

  Map<String, dynamic> _lorebookEntryToCardMap(AiLorebookEntry entry) {
    return {
      'title': entry.title,
      'content': entry.content,
      'keywords': entry.keywords,
      'enabled': entry.enabled,
      'always_enabled': entry.alwaysEnabled,
      'priority': entry.priority,
    };
  }

  Future<AiProviderProfile> _importProviderProfile(
    Map<String, dynamic> raw, {
    required DateTime now,
  }) async {
    final existingProfiles = await AiProviderService().listProfiles();
    final baseName = _safeString(raw['name'], fallback: '导入 Provider');
    final profile = AiProviderProfile(
      id: 'provider_import_${DateTime.now().microsecondsSinceEpoch}',
      name: _buildUniqueName(
        baseName,
        existingProfiles.map((e) => e.name).toSet(),
      ),
      providerType: AiProviderType.fromValue(
        _safeString(
          raw['provider_type'],
          fallback: AiProviderType.openAiCompatible.value,
        ),
      ),
      baseUrl: _safeString(raw['base_url']),
      defaultModel: _safeString(raw['default_model']),
      manualModels: _stringList(raw['manual_models']),
      useServerMemory: raw['use_server_memory'] == true ||
          raw['use_server_memory'] == 1,
      supportsSystemMessages: raw['supports_system_messages'] != false &&
          raw['supports_system_messages'] != 0,
      supportsStreaming: raw['supports_streaming'] != false &&
          raw['supports_streaming'] != 0,
      supportsVision: raw['supports_vision'] == true ||
          raw['supports_vision'] == 1,
      supportsToolCalls: raw['supports_tool_calls'] == true ||
          raw['supports_tool_calls'] == 1,
      createdAt: now,
      updatedAt: now,
    );
    await AiProviderService().saveProfile(profile);
    return profile;
  }

  Future<AiLorebook?> _importLorebook(
    Map<String, dynamic> raw, {
    required DateTime now,
  }) async {
    final entriesRaw = raw['entries'];
    final existingLorebooks = await AiDbService().getLorebooks();
    final lorebook = AiLorebook(
      id: 'lorebook_import_${DateTime.now().microsecondsSinceEpoch}',
      name: _buildUniqueName(
        _safeString(raw['name'], fallback: '导入 Lorebook'),
        existingLorebooks.map((e) => e.name).toSet(),
      ),
      description: _safeString(raw['description']),
      createdAt: now,
      updatedAt: now,
    );

    final entries = <AiLorebookEntry>[];
    if (entriesRaw is List) {
      for (var i = 0; i < entriesRaw.length; i++) {
        final item = entriesRaw[i];
        if (item is! Map) continue;
        final entryMap = Map<String, dynamic>.from(item);
        entries.add(
          AiLorebookEntry(
            id: '${lorebook.id}_entry_$i',
            lorebookId: lorebook.id,
            title: _safeString(entryMap['title']),
            content: _safeString(entryMap['content']),
            keywords: _stringList(entryMap['keywords']),
            enabled: entryMap['enabled'] != false,
            alwaysEnabled: entryMap['always_enabled'] == true,
            priority: _safeInt(entryMap['priority'], fallback: 50),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    await AiAgentCloudService().saveLorebook(lorebook, entries);

    return lorebook;
  }

  String _buildUniqueName(String base, Set<String> existingNames) {
    if (!existingNames.contains(base)) return base;
    final importedBase = '$base（导入）';
    if (!existingNames.contains(importedBase)) return importedBase;
    var index = 2;
    while (true) {
      final candidate = '$base（导入$index）';
      if (!existingNames.contains(candidate)) return candidate;
      index++;
    }
  }

  String _safeString(dynamic value, {String fallback = ''}) {
    final text = value?.toString() ?? '';
    if (text.trim().isEmpty) return fallback;
    return text;
  }

  int _safeInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
