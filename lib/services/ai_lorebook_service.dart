import '../models/ai_agent.dart';
import '../models/ai_lorebook_entry.dart';
import 'ai_agent_cloud_service.dart';
import 'ai_db_service.dart';

class AiLorebookService {
  AiLorebookService._();

  static final AiLorebookService _instance = AiLorebookService._();
  factory AiLorebookService() => _instance;

  Future<List<AiLorebookEntry>> resolveEntriesForAgent({
    required AiAgent agent,
    required String latestUserMessage,
    List<String> recentConversation = const [],
    int maxEntries = 8,
    int maxChars = 2400,
  }) async {
    final lorebookId = agent.lorebookId?.trim() ?? '';
    if (lorebookId.isEmpty) return const [];

    final entries = await AiAgentCloudService().getLorebookEntries(lorebookId);
    if (entries.isEmpty) return const [];

    return selectEntries(
      entries,
      latestUserMessage: latestUserMessage,
      recentConversation: recentConversation,
      maxEntries: maxEntries,
      maxChars: maxChars,
    );
  }

  List<AiLorebookEntry> selectEntries(
    List<AiLorebookEntry> entries, {
    required String latestUserMessage,
    List<String> recentConversation = const [],
    int maxEntries = 8,
    int maxChars = 2400,
  }) {
    final contextText = [
      latestUserMessage,
      ...recentConversation.where((e) => e.trim().isNotEmpty),
    ].join('\n');
    final normalizedContext = contextText.toLowerCase();

    final matched = entries.where((entry) {
      if (!entry.enabled) return false;
      if (entry.alwaysEnabled) return true;
      if (entry.keywords.isEmpty || normalizedContext.isEmpty) return false;
      for (final keyword in entry.keywords) {
        if (normalizedContext.contains(keyword.trim().toLowerCase())) {
          return true;
        }
      }
      return false;
    }).toList()
      ..sort((a, b) {
        final alwaysCompare = (b.alwaysEnabled ? 1 : 0) - (a.alwaysEnabled ? 1 : 0);
        if (alwaysCompare != 0) return alwaysCompare;
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    final out = <AiLorebookEntry>[];
    var totalChars = 0;
    for (final entry in matched) {
      final rendered = _renderEntry(entry);
      if (rendered.isEmpty) continue;
      final nextChars = totalChars + rendered.length;
      if (out.isNotEmpty && (out.length >= maxEntries || nextChars > maxChars)) {
        break;
      }
      out.add(entry);
      totalChars = nextChars;
      if (out.length >= maxEntries) {
        break;
      }
    }
    return out;
  }

  String buildPromptSection(List<AiLorebookEntry> entries) {
    if (entries.isEmpty) return '';
    final buffer = StringBuffer(
      '[世界书设定]\n以下设定在当前对话中生效，请自然遵守和引用，不要机械逐条复述规则。',
    );
    for (final entry in entries) {
      final rendered = _renderEntry(entry);
      if (rendered.isEmpty) continue;
      buffer.write('\n\n$rendered');
    }
    return buffer.toString().trim();
  }

  String _renderEntry(AiLorebookEntry entry) {
    final content = entry.content.trim();
    if (content.isEmpty) return '';
    final title = entry.title.trim().isEmpty ? '设定' : entry.title.trim();
    return '[$title]\n$content';
  }
}
