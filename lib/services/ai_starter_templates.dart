import '../models/ai_agent.dart';
import '../models/ai_lorebook.dart';
import '../models/ai_lorebook_entry.dart';

class AiStarterAgentTemplate {
  final String id;
  final String name;
  final String tagline;
  final String description;
  final String systemPrompt;
  final String persona;
  final String scenario;
  final String openingMessage;
  final String exampleDialogues;
  final List<String> suggestedKeywords;

  const AiStarterAgentTemplate({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.systemPrompt,
    required this.persona,
    required this.scenario,
    required this.openingMessage,
    required this.exampleDialogues,
    this.suggestedKeywords = const [],
  });
}

class AiStarterLorebookTemplate {
  final String id;
  final String name;
  final String description;
  final List<AiStarterLorebookEntryTemplate> entries;

  const AiStarterLorebookTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.entries,
  });
}

class AiStarterLorebookEntryTemplate {
  final String title;
  final String content;
  final List<String> keywords;
  final bool enabled;
  final bool alwaysEnabled;
  final int priority;

  const AiStarterLorebookEntryTemplate({
    required this.title,
    required this.content,
    this.keywords = const [],
    this.enabled = true,
    this.alwaysEnabled = false,
    this.priority = 50,
  });
}

class AiStarterTemplates {
  static const List<AiStarterAgentTemplate> agentTemplates = [
    AiStarterAgentTemplate(
      id: 'companion_cafe',
      name: '短句闲聊',
      tagline: '像微信 · 一两句就够',
      description: '适合日常陪聊。先接住对方刚说的话，不写长段。',
      systemPrompt: '用短句说话，像微信聊天，一两句就够。可以聊，也可以回答知道的事。不知道就说不知道。',
      persona: '轻快，像朋友。不说教，不编造对方没说过的事。',
      scenario: '现在是一次普通聊天。',
      openingMessage: '在的。想聊什么？',
      exampleDialogues: '用户：今天有点累。\n你：先歇一下。想说就说，不想说也行。',
      suggestedKeywords: ['闲聊', '短句', '陪伴'],
    ),
    AiStarterAgentTemplate(
      id: 'strategy_partner',
      name: '认真答问',
      tagline: '先回答 · 再说清楚',
      description: '适合问事情。先给结论，再用一两句补上原因。',
      systemPrompt: '先回答问题，再补一句原因。用短句。不知道就说不知道，不要编。',
      persona: '清楚、直接，仍然像朋友，不像说明书。',
      scenario: '对方来问一件具体的事。',
      openingMessage: '你问，我先答。',
      exampleDialogues: '用户：这个怎么开始？\n你：先做最小的一步。做完再决定要不要继续。',
      suggestedKeywords: ['答问', '清楚', '短句'],
    ),
    AiStarterAgentTemplate(
      id: 'fantasy_archivist',
      name: '安静陪着',
      tagline: '少问 · 接住情绪',
      description: '适合不想被追问的时候。先陪着，对方想说再接。',
      systemPrompt: '少提问。先接住对方的感受，再用一句短话回应。不要分析对方，不要列建议。',
      persona: '安静、稳。在，但不挤。',
      scenario: '对方只是想有人在。',
      openingMessage: '我在。你不用说很多。',
      exampleDialogues: '用户：今天有点累。\n你：那就先这样坐一会儿。',
      suggestedKeywords: ['安静', '陪伴', '短句'],
    ),
  ];

  static const List<AiStarterLorebookTemplate> lorebookTemplates = [
    AiStarterLorebookTemplate(
      id: 'urban_fantasy_city',
      name: '新月城夜间都市',
      description: '现代都市外壳下隐藏超自然秩序的夜行世界。',
      entries: [
        AiStarterLorebookEntryTemplate(
          title: '新月城',
          content: '新月城是一座表面繁华、夜晚秩序复杂的沿海都市。白天由商业与媒体统治，夜晚则由情报贩子、旧家族与异能组织重新划分边界。',
          keywords: ['新月城', '城市', '夜晚', '沿海都市'],
          alwaysEnabled: true,
          priority: 90,
        ),
        AiStarterLorebookEntryTemplate(
          title: '夜行公约',
          content: '所有拥有异常能力的人都默认遵守“夜行公约”：不在公众视野中暴露异常，不在白天处理越界冲突，不在学校和医院动手。',
          keywords: ['公约', '规则', '异常能力', '夜行'],
          priority: 80,
        ),
        AiStarterLorebookEntryTemplate(
          title: '灰港街区',
          content: '灰港街区是信息交换最频繁的地方。酒吧、旧书店和唱片行都是情报掩体，真正的交易通常发生在表层闲聊之后。',
          keywords: ['灰港', '街区', '酒吧', '情报'],
          priority: 70,
        ),
      ],
    ),
    AiStarterLorebookTemplate(
      id: 'kingdom_archive',
      name: '王都与旧档案库',
      description: '适用于宫廷、秘史、遗迹与档案馆风格角色。',
      entries: [
        AiStarterLorebookEntryTemplate(
          title: '王都艾斯维尔',
          content: '艾斯维尔是王国的中心，拥有严格的礼制与层级秩序。城内分为上城区、议政区与旧城遗址，越靠近王宫，秘密越多。',
          keywords: ['王都', '艾斯维尔', '王宫', '上城区'],
          alwaysEnabled: true,
          priority: 90,
        ),
        AiStarterLorebookEntryTemplate(
          title: '旧档案库',
          content: '旧档案库保存着战争、王室血统与失落宗教的记录。能进入这里的人极少，许多卷宗被标注为“不得公开朗读”。',
          keywords: ['档案库', '卷宗', '历史', '禁忌'],
          priority: 85,
        ),
        AiStarterLorebookEntryTemplate(
          title: '北境战争',
          content:
              '北境战争在官方叙述中已经结束多年，但民间始终流传“最后一役从未被真正记载”的说法。有人认为胜利并不完整，有人认为战争根本没有彻底结束。',
          keywords: ['北境战争', '战争', '北境', '最后一役'],
          priority: 75,
        ),
      ],
    ),
  ];

  static AiAgent buildAgentFromTemplate(
    AiStarterAgentTemplate template, {
    required String modelName,
    String? providerProfileId,
    String? lorebookId,
  }) {
    final now = DateTime.now();
    return AiAgent(
      id: 'template_${template.id}_${now.microsecondsSinceEpoch}',
      name: template.name,
      description: template.description,
      systemPrompt: template.systemPrompt,
      modelName: modelName,
      providerProfileId: providerProfileId,
      lorebookId: lorebookId,
      persona: template.persona,
      scenario: template.scenario,
      openingMessage: template.openingMessage,
      exampleDialogues: template.exampleDialogues,
      createdAt: now,
    );
  }

  static AiLorebook buildLorebookFromTemplate(
    AiStarterLorebookTemplate template,
  ) {
    final now = DateTime.now();
    return AiLorebook(
      id: 'lore_template_${template.id}_${now.microsecondsSinceEpoch}',
      name: template.name,
      description: template.description,
      createdAt: now,
      updatedAt: now,
    );
  }

  static List<AiLorebookEntry> buildLorebookEntriesFromTemplate(
    AiStarterLorebookTemplate template, {
    required String lorebookId,
  }) {
    final now = DateTime.now();
    return List<AiLorebookEntry>.generate(template.entries.length, (index) {
      final item = template.entries[index];
      return AiLorebookEntry(
        id: '${lorebookId}_tpl_$index',
        lorebookId: lorebookId,
        title: item.title,
        content: item.content,
        keywords: item.keywords,
        enabled: item.enabled,
        alwaysEnabled: item.alwaysEnabled,
        priority: item.priority,
        createdAt: now,
        updatedAt: now,
      );
    });
  }
}
