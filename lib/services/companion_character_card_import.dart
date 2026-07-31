import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'ai_character_card_storage.dart' as card_storage;

/// 从角色卡解析出的关系层草稿（不落库，由 Hub 资料编辑确认后保存）。
class CompanionCardImportDraft {
  const CompanionCardImportDraft({
    this.name = '',
    this.persona = '',
    this.personalityTraits = const [],
    this.systemPromptOverride = '',
    this.sourceLabel = '角色卡',
    this.notices = const [],
    this.avatarPngBytes,
  });

  final String name;
  final String persona;
  final List<String> personalityTraits;
  final String systemPromptOverride;
  final String sourceLabel;
  final List<String> notices;

  /// PNG 角色卡原图，可供上传为头像；JSON 卡为 null。
  final Uint8List? avatarPngBytes;
}

/// 用户取消文件选择。
class CompanionCardImportCancelled implements Exception {
  @override
  String toString() => '已取消选择文件';
}

/// SillyTavern / Moe 角色卡 → Companion 关系层字段（轻量导入）。
///
/// 支持：
/// - SillyTavern Character Card V2/V3 JSON（`spec: chara_card_v2|v3`）
/// - TavernAI / ST V1 扁平 JSON
/// - Moe Social 导出卡（`card_type: moe_social_character_card`）
/// - PNG 内嵌 `chara` tEXt（base64 JSON）
///
/// 不做：Lorebook 全量导入、多 bond、酒馆 Agent 落库。
class CompanionCharacterCardImport {
  CompanionCharacterCardImport._();

  static const int maxPersonaChars = 4000;
  static const int maxOverrideChars = 6000;
  static const int maxTraits = 8;

  /// 文件选择器：`.json` / `.png`。
  static Future<CompanionCardImportDraft> fromFilePicker() async {
    final exportDir = await card_storage.characterCardExportDirectory();
    final initialDirectory =
        card_storage.desktopPickerInitialDirectory(exportDir);

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'png'],
      dialogTitle: '选择角色卡（JSON 或 PNG）',
      withData: true,
      initialDirectory: initialDirectory,
    );
    if (picked == null || picked.files.isEmpty) {
      throw CompanionCardImportCancelled();
    }

    final file = picked.files.single;
    final bytes = await _readPickedBytes(file);
    return fromBytes(bytes, fileName: file.name);
  }

  static Future<Uint8List> _readPickedBytes(PlatformFile file) async {
    final inline = file.bytes;
    if (inline != null && inline.isNotEmpty) {
      return Uint8List.fromList(inline);
    }
    final path = file.path?.trim();
    if (path != null && path.isNotEmpty) {
      final raw = await card_storage.readBytesAtPath(path);
      return Uint8List.fromList(raw);
    }
    throw Exception('无法读取所选文件');
  }

  /// 从粘贴的 JSON 文本解析。
  static CompanionCardImportDraft fromJsonString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw Exception('角色卡内容为空');
    }
    return _parseDecodedJson(trimmed, avatarPngBytes: null);
  }

  /// 按文件字节解析（自动识别 PNG / JSON）。
  static CompanionCardImportDraft fromBytes(
    Uint8List bytes, {
    String? fileName,
  }) {
    if (_isPng(bytes)) {
      final embedded = _extractPngCharaJson(bytes);
      if (embedded == null || embedded.trim().isEmpty) {
        throw Exception('PNG 中未找到角色卡数据（缺少 chara 文本块）');
      }
      return _parseDecodedJson(
        embedded,
        avatarPngBytes: bytes,
        sourceHint: 'SillyTavern PNG',
      );
    }

    late final String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      throw Exception('无法按文本读取该文件，请使用 JSON 或标准 PNG 角色卡');
    }
    final lower = (fileName ?? '').toLowerCase();
    if (lower.endsWith('.png')) {
      throw Exception('该 PNG 无法识别为角色卡');
    }
    return _parseDecodedJson(text, avatarPngBytes: null);
  }

  static CompanionCardImportDraft _parseDecodedJson(
    String raw, {
    required Uint8List? avatarPngBytes,
    String? sourceHint,
  }) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw Exception('角色卡内容无法识别，请检查是否为完整 JSON');
    }
    if (decoded is! Map) {
      throw Exception('这不是有效的角色卡文件');
    }
    final root = Map<String, dynamic>.from(decoded);
    return _parseRoot(
      root,
      avatarPngBytes: avatarPngBytes,
      sourceHint: sourceHint,
    );
  }

  static CompanionCardImportDraft _parseRoot(
    Map<String, dynamic> root, {
    required Uint8List? avatarPngBytes,
    String? sourceHint,
  }) {
    final notices = <String>[];

    // Moe Social 自有格式
    final cardType = _str(root['card_type']);
    if (cardType == 'moe_social_character_card') {
      final agentRaw = root['agent'];
      if (agentRaw is! Map) {
        throw Exception('Moe 角色卡缺少 agent 字段');
      }
      final agent = Map<String, dynamic>.from(agentRaw);
      if (root['lorebook'] != null) {
        notices.add('已跳过 Lorebook（轻量导入仅写入关系层人设）');
      }
      return _mapFields(
        name: _str(agent['name'], fallback: '导入角色'),
        description: _str(agent['description']),
        personality: _str(agent['persona']),
        scenario: _str(agent['scenario']),
        systemPrompt: _str(agent['system_prompt']),
        firstMes: _str(agent['opening_message']),
        mesExample: _str(agent['example_dialogues']),
        tags: const [],
        sourceLabel: sourceHint ?? 'Moe Social 角色卡',
        notices: notices,
        avatarPngBytes: avatarPngBytes,
      );
    }

    // SillyTavern V2 / V3
    final spec = _str(root['spec']).toLowerCase();
    final dataRaw = root['data'];
    final dataMap =
        dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : null;
    final looksLikeStSpec = spec.contains('chara_card_v2') ||
        spec.contains('chara_card_v3');
    final looksLikeStData = dataMap != null &&
        (_str(dataMap['name']).isNotEmpty ||
            _str(dataMap['description']).isNotEmpty ||
            _str(dataMap['personality']).isNotEmpty);
    if (looksLikeStSpec || looksLikeStData) {
      final data = dataMap ?? root;
      if (data['character_book'] != null) {
        notices.add('已跳过 Character Book / 世界书（轻量导入）');
      }
      final tags = _stringList(data['tags']);
      final label = sourceHint ??
          (spec.contains('v3') ? 'SillyTavern V3' : 'SillyTavern V2');
      return _mapFields(
        name: _str(data['name'], fallback: '导入角色'),
        description: _str(data['description']),
        personality: _str(data['personality']),
        scenario: _str(data['scenario']),
        systemPrompt: _str(data['system_prompt']),
        firstMes: _str(data['first_mes']),
        mesExample: _str(data['mes_example']),
        tags: tags,
        sourceLabel: label,
        notices: notices,
        avatarPngBytes: avatarPngBytes,
      );
    }

    // TavernAI / ST V1 扁平
    if (_str(root['name']).isNotEmpty ||
        _str(root['description']).isNotEmpty ||
        _str(root['personality']).isNotEmpty) {
      return _mapFields(
        name: _str(root['name'], fallback: '导入角色'),
        description: _str(root['description']),
        personality: _str(root['personality']),
        scenario: _str(root['scenario']),
        systemPrompt: _str(root['system_prompt']),
        firstMes: _str(root['first_mes']),
        mesExample: _str(root['mes_example']),
        tags: _stringList(root['tags']),
        sourceLabel: sourceHint ?? 'SillyTavern / TavernAI',
        notices: notices,
        avatarPngBytes: avatarPngBytes,
      );
    }

    throw Exception('无法识别的角色卡格式（支持 ST V2/V3、扁平 JSON、Moe 导出卡）');
  }

  static CompanionCardImportDraft _mapFields({
    required String name,
    required String description,
    required String personality,
    required String scenario,
    required String systemPrompt,
    required String firstMes,
    required String mesExample,
    required List<String> tags,
    required String sourceLabel,
    required List<String> notices,
    required Uint8List? avatarPngBytes,
  }) {
    final personaParts = <String>[];
    if (description.isNotEmpty) personaParts.add(description);
    if (personality.isNotEmpty) {
      personaParts.add('性格：$personality');
    }
    if (scenario.isNotEmpty) {
      personaParts.add('场景：$scenario');
    }
    var persona = personaParts.join('\n\n').trim();
    if (persona.length > maxPersonaChars) {
      persona = persona.substring(0, maxPersonaChars);
      notices.add('人设过长，已截断至 $maxPersonaChars 字');
    }

    final overrideParts = <String>[];
    if (systemPrompt.isNotEmpty) overrideParts.add(systemPrompt);
    if (mesExample.isNotEmpty) {
      overrideParts.add('[对话示例]\n$mesExample');
    }
    if (firstMes.isNotEmpty) {
      overrideParts.add('[开场白参考]\n$firstMes');
    }
    var override = overrideParts.join('\n\n').trim();
    if (override.length > maxOverrideChars) {
      override = override.substring(0, maxOverrideChars);
      notices.add('系统提示词过长，已截断至 $maxOverrideChars 字');
    }

    var traits = tags
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(maxTraits)
        .toList(growable: false);
    if (traits.isEmpty && personality.isNotEmpty && personality.length <= 80) {
      traits = personality
          .split(RegExp(r'[，,、/|;；\n]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e.length <= 24)
          .take(maxTraits)
          .toList(growable: false);
    }

    if (persona.isEmpty && override.isEmpty && name.trim().isEmpty) {
      throw Exception('角色卡没有可用的名字或人设内容');
    }

    if (avatarPngBytes != null) {
      notices.add('可选用 PNG 卡面作为头像');
    }
    notices.add('已填入编辑表单，确认后点「保存」才会生效');

    return CompanionCardImportDraft(
      name: name.trim().isEmpty ? '导入角色' : name.trim(),
      persona: persona,
      personalityTraits: traits,
      systemPromptOverride: override,
      sourceLabel: sourceLabel,
      notices: List<String>.unmodifiable(notices),
      avatarPngBytes: avatarPngBytes,
    );
  }

  static bool _isPng(Uint8List bytes) {
    if (bytes.length < 8) return false;
    return bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  /// 读取 PNG tEXt 中 keyword=`chara` 的 base64 JSON（ST 常见写法）。
  static String? _extractPngCharaJson(Uint8List bytes) {
    var offset = 8;
    while (offset + 12 <= bytes.length) {
      final length = _readUint32(bytes, offset);
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      final dataStart = offset + 8;
      final dataEnd = dataStart + length;
      if (dataEnd + 4 > bytes.length) break;

      if (type == 'tEXt' && length > 0) {
        final data = bytes.sublist(dataStart, dataEnd);
        final nul = data.indexOf(0);
        if (nul > 0) {
          final keyword =
              utf8.decode(data.sublist(0, nul), allowMalformed: true);
          if (keyword == 'chara') {
            final payload = data.sublist(nul + 1);
            final b64 = utf8.decode(payload, allowMalformed: true).trim();
            try {
              return utf8.decode(base64.decode(b64));
            } catch (_) {
              if (b64.startsWith('{')) return b64;
            }
          }
        }
      }

      if (type == 'IEND') break;
      offset = dataEnd + 4;
    }
    return null;
  }

  static int _readUint32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static String _str(dynamic value, {String fallback = ''}) {
    final text = value?.toString() ?? '';
    if (text.trim().isEmpty) return fallback;
    return text.trim();
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
}
