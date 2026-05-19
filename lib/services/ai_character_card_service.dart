import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ai_agent.dart';
import 'ai_character_card_storage.dart' as card_storage;
import '../models/ai_lorebook.dart';
import '../models/ai_lorebook_entry.dart';
import '../models/ai_provider_profile.dart';
import 'ai_agent_cloud_service.dart';
import 'ai_db_service.dart';
import 'ai_provider_service.dart';

class AiCharacterCardImportResult {
  final AiAgent agent;
  final AiLorebook? lorebook;
  final List<String> notices;

  const AiCharacterCardImportResult({
    required this.agent,
    this.lorebook,
    this.notices = const [],
  });
}

/// 角色卡导入/导出：仅共享人设与世界观，不共享 API Key / Provider 账号。
class AiCharacterCardService {
  AiCharacterCardService._();

  static final AiCharacterCardService _instance = AiCharacterCardService._();
  factory AiCharacterCardService() => _instance;

  static const String cardType = 'moe_social_character_card';
  static const int cardVersion = 2;
  static const String exportSubdir = 'character_cards';

  /// 应用内角色卡导出目录（便于备份与再次导入）。
  Future<String?> exportDirectoryPath() async {
    return card_storage.characterCardExportDirectory();
  }

  /// 复制他人公开角色卡到本账号草稿（清空 Provider / Lorebook 绑定）。
  AiAgent cloneAgentForLocalUse(AiAgent source) {
    final now = DateTime.now();
    return source.copyWith(
      id: 'agent_${now.microsecondsSinceEpoch}',
      providerProfileId: null,
      lorebookId: null,
      createdByUserId: null,
      isPublic: false,
      createdAt: now,
      updatedAt: null,
    );
  }

  Future<String> exportCharacterCardJson(AiAgent agent) async {
    final modelBinding = await _buildModelBinding(agent);

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
      'portable': true,
      'notes': '角色卡仅含人设与推荐模型；使用方需在本机选择 API 来源并填写 Key，不会使用导出者的账号或额度。',
      'agent': _agentToCardMap(agent),
      'model_binding': modelBinding,
      if (lorebook != null)
        'lorebook': _lorebookToCardMap(
          lorebook,
          entries: lorebookEntries,
        ),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String exportFileName(AiAgent agent) {
    final safeName = agent.name
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final base = safeName.isEmpty ? 'character' : safeName;
    return '${base}_card.json';
  }

  /// 写入应用内导出目录，返回实际保存路径（文件名含角色名）。
  Future<String> saveCharacterCardToExportDir(AiAgent agent) async {
    final raw = await exportCharacterCardJson(agent);
    return card_storage.writeCharacterCardExport(
      fileName: exportFileName(agent),
      content: raw,
    );
  }

  /// 导出为文件：先以角色名保存到应用目录，再唤起系统分享/另存。
  Future<String> shareCharacterCardFile(AiAgent agent) async {
    final fileName = exportFileName(agent);
    if (kIsWeb) {
      final raw = await exportCharacterCardJson(agent);
      await Share.share(raw, subject: '角色卡：${agent.name}');
      return fileName;
    }
    final savedPath = await saveCharacterCardToExportDir(agent);
    await Share.shareXFiles(
      [XFile(savedPath)],
      subject: '导出角色卡：${agent.name}',
    );
    return savedPath;
  }

  Future<void> copyCharacterCardToClipboard(AiAgent agent) async {
    final raw = await exportCharacterCardJson(agent);
    await Clipboard.setData(ClipboardData(text: raw));
  }

  /// 从系统文件选择器读取 JSON 角色卡（桌面端默认打开应用导出目录）。
  Future<AiCharacterCardImportResult> importCharacterCardFromFilePicker() async {
    final exportDir = await exportDirectoryPath();
    final initialDirectory =
        card_storage.desktopPickerInitialDirectory(exportDir);

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      dialogTitle: '选择角色卡 JSON 文件',
      withData: kIsWeb,
      initialDirectory: initialDirectory,
    );
    if (picked == null || picked.files.isEmpty) {
      throw _ImportCancelled();
    }

    final file = picked.files.single;
    final raw = await _readPickedFileContent(file);
    return importCharacterCardJson(raw);
  }

  Future<String> _readPickedFileContent(PlatformFile file) async {
    final path = file.path?.trim();
    if (path != null && path.isNotEmpty) {
      return card_storage.readFileAtPath(path);
    }
    final bytes = file.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return utf8.decode(bytes);
    }
    throw Exception('无法读取所选文件');
  }

  Future<AiCharacterCardImportResult> importCharacterCardJson(
    String rawJson,
  ) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (_) {
      throw Exception('角色卡内容无法识别，请检查复制是否完整');
    }
    if (decoded is! Map) {
      throw Exception('这不是有效的角色卡文件');
    }

    final root = Map<String, dynamic>.from(decoded);
    final agentRaw = root['agent'];
    if (agentRaw is! Map) {
      throw Exception('角色卡内容不完整，缺少角色信息');
    }
    final agentMap = Map<String, dynamic>.from(agentRaw);
    final notices = <String>[
      '已导入人设；请在本机选择 API 来源并填写 Key',
    ];
    final now = DateTime.now();

    final binding = _resolveModelBinding(root, agentMap);
    if (binding.suggestedModel.isNotEmpty &&
        _safeString(agentMap['model_name']).isEmpty) {
      agentMap['model_name'] = binding.suggestedModel;
    }
    if (binding.notice != null) {
      notices.add(binding.notice!);
    }

    AiLorebook? importedLorebook;
    final lorebookRaw = root['lorebook'];
    if (lorebookRaw is Map) {
      importedLorebook = await _importLorebook(
        Map<String, dynamic>.from(lorebookRaw),
        now: now,
      );
    }

    final importedAgent = AiAgent(
      id: 'agent_import_${now.microsecondsSinceEpoch}',
      name: _safeString(agentMap['name'], fallback: '导入角色'),
      description: _safeString(agentMap['description']),
      systemPrompt: _safeString(agentMap['system_prompt']),
      modelName: _safeString(
        agentMap['model_name'],
        fallback: binding.suggestedModel,
      ),
      providerProfileId: null,
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
      lorebook: importedLorebook,
      notices: notices,
    );
  }

  Future<Map<String, dynamic>> _buildModelBinding(AiAgent agent) async {
    final binding = <String, dynamic>{
      'suggested_model': agent.modelName.trim(),
    };

    final providerId = agent.providerProfileId?.trim() ?? '';
    if (providerId.isEmpty) {
      binding['provider_type'] = AiProviderType.backendOllama.value;
      binding['provider_label'] = '内置 Ollama';
      return binding;
    }

    try {
      final profile = await AiProviderService().resolveProfile(providerId);
      if (!profile.isBuiltinBackend) {
        binding['provider_type'] = profile.providerType.value;
        binding['provider_label'] = profile.name;
      } else {
        binding['provider_type'] = AiProviderType.backendOllama.value;
        binding['provider_label'] = '内置 Ollama';
      }
    } catch (_) {
      binding['provider_type'] = AiProviderType.openAiCompatible.value;
    }

    return binding;
  }

  _ResolvedModelBinding _resolveModelBinding(
    Map<String, dynamic> root,
    Map<String, dynamic> agentMap,
  ) {
    final bindingRaw = root['model_binding'];
    if (bindingRaw is Map) {
      final map = Map<String, dynamic>.from(bindingRaw);
      return _ResolvedModelBinding(
        suggestedModel: _safeString(map['suggested_model']),
        notice: _hintFromBinding(map),
      );
    }

    // v1 兼容：旧卡可能带 provider_profile（含 base_url），仅提取模型建议，不导入 Provider。
    final legacyProvider = root['provider_profile'];
    if (legacyProvider is Map) {
      final map = Map<String, dynamic>.from(legacyProvider);
      final model = _safeString(agentMap['model_name']).isNotEmpty
          ? _safeString(agentMap['model_name'])
          : _safeString(map['default_model']);
      return _ResolvedModelBinding(
        suggestedModel: model,
        notice:
            '旧版卡片含第三方 API 地址，已跳过导入；请使用你自己的 API 来源（推荐模型：${model.isEmpty ? "见编辑器" : model}）',
      );
    }

    return _ResolvedModelBinding(
      suggestedModel: _safeString(agentMap['model_name']),
    );
  }

  String? _hintFromBinding(Map<String, dynamic> binding) {
    final model = _safeString(binding['suggested_model']);
    final label = _safeString(binding['provider_label']);
    if (model.isEmpty && label.isEmpty) return null;
    if (label.isEmpty) return '推荐模型：$model';
    if (model.isEmpty) return '原创建者常用来源：$label（需在本机自行配置）';
    return '推荐模型：$model；原创建者常用来源：$label（需在本机自行配置）';
  }

  Map<String, dynamic> _agentToCardMap(AiAgent agent) {
    return {
      'name': agent.name,
      'description': agent.description,
      'system_prompt': agent.systemPrompt,
      'model_name': agent.modelName,
      'persona': agent.persona,
      'scenario': agent.scenario,
      'opening_message': agent.openingMessage,
      'example_dialogues': agent.exampleDialogues,
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

class _ImportCancelled implements Exception {
  @override
  String toString() => '已取消选择文件';
}

class _ResolvedModelBinding {
  const _ResolvedModelBinding({
    required this.suggestedModel,
    this.notice,
  });

  final String suggestedModel;
  final String? notice;
}
