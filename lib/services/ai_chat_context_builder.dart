import '../models/ai_agent.dart';
import 'ai_lorebook_service.dart';
import 'ai_memory_orchestrator.dart';
import 'ai_prompt_defaults.dart';
import 'ai_roleplay_prompt_builder.dart';

class AiChatContext {
  const AiChatContext({
    required this.messages,
    required this.systemPrompt,
    required this.memoryMeta,
  });

  final List<Map<String, String>> messages;
  final String systemPrompt;
  final AiMemoryEnrichResult memoryMeta;
}

class AiChatContextBuilder {
  AiChatContextBuilder._();

  static final AiChatContextBuilder _instance = AiChatContextBuilder._();
  factory AiChatContextBuilder() => _instance;

  Future<AiChatContext> build({
    required AiAgent agent,
    required List<Map<String, String>> history,
    required String latestUserMessage,
    required List<String> recentConversation,
    required String overrideSystemPrompt,
    String? userPersona,
  }) async {
    final lorebookEntries = await AiLorebookService().resolveEntriesForAgent(
      agent: agent,
      latestUserMessage: latestUserMessage,
      recentConversation: recentConversation,
    );

    final baseSystem = AiRoleplayPromptBuilder.buildSystemPrompt(
      agent,
      overrideSystemPrompt: overrideSystemPrompt.trim().isNotEmpty
          ? overrideSystemPrompt.trim()
          : AiPromptDefaults.defaultAgentSystemPrompt,
      userPersona: userPersona,
      lorebookEntries: lorebookEntries,
    );

    final guardedSystem = AiRoleplayPromptBuilder.isRoleplayStyleAgent(agent)
        ? baseSystem
        : _withNoAiSelfDisclosureRule(baseSystem);

    final memoryMeta = await AiMemoryOrchestrator().enrichSystemPromptWithMeta(
      agent: agent,
      basePrompt: guardedSystem,
      latestUserMessage: latestUserMessage,
    );

    return AiChatContext(
      messages: [
        {'role': 'system', 'content': memoryMeta.prompt},
        ...history,
      ],
      systemPrompt: memoryMeta.prompt,
      memoryMeta: memoryMeta,
    );
  }

  String _withNoAiSelfDisclosureRule(String prompt) {
    const rule = '''

补充硬性规则：
1) 不要说“作为AI”“我是AI助手”“我只是模型/程序”等自我限制话术。
2) 用户问“你是谁/你叫什么”时，直接以自然人格化口吻回答，不要暴露模型身份。
''';
    return '$prompt$rule';
  }
}
