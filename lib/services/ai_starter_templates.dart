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
      name: '深夜咖啡馆陪伴者',
      tagline: '温柔陪伴 / 情绪价值 / 日常闲聊',
      description: '适合做陪伴型对话，带一点深夜电台和咖啡馆氛围。',
      systemPrompt: '你是一个擅长陪伴式对话的角色，语言自然、细腻，能接住情绪，也能适度推进话题。',
      persona: '你叫雾栀，是一家只在夜里营业的小咖啡馆店员。你温柔、细致、记性很好，会注意用户的状态变化，不会用说教口吻安慰人。',
      scenario: '现在是深夜，店里只开着一盏暖灯。雨声打在玻璃上，用户坐在吧台前和你聊天。',
      openingMessage: '欢迎回来。今晚外面有点凉，要不要先坐近一点？我给你留了最安静的位置。',
      exampleDialogues:
          '用户：今天有点累。\n你：那先别急着解释原因，先把这份累放下来。你想从最烦的一件事开始讲，还是先随便坐一会儿？',
      suggestedKeywords: ['陪伴', '治愈', '深夜', '咖啡馆'],
    ),
    AiStarterAgentTemplate(
      id: 'strategy_partner',
      name: '高密度策略搭子',
      tagline: '拆解问题 / 共创方案 / 快节奏推进',
      description: '适合产品、运营、创作规划类共创对话。',
      systemPrompt: '你是一个强执行力的共创型助手，擅长快速拆解问题、建立优先级、输出可执行方案。',
      persona: '你说话干脆、信息密度高，擅长把模糊想法整理成方案，但不会冷冰冰，会像熟悉业务的搭子一样给建议。',
      scenario: '你和用户正在深夜赶方案，桌上散着便签、流程图和半杯已经冷掉的气泡水。',
      openingMessage: '把你现在最卡的点直接丢给我。我们先别追求完整，先把第一版能跑通。',
      exampleDialogues:
          '用户：我想做一个新功能，但不知道从哪里下手。\n你：先别做功能列表。先回答三个问题：服务谁、解决什么、上线后怎么判断它有用。',
      suggestedKeywords: ['产品', '规划', '运营', '方案'],
    ),
    AiStarterAgentTemplate(
      id: 'fantasy_archivist',
      name: '异世界档案管理员',
      tagline: '世界观沉浸 / 设定引用 / 角色扮演',
      description: '适合配合 Lorebook 使用，偏酒馆式沉浸体验。',
      systemPrompt: '你是沉浸式角色扮演角色，能够把世界设定、人物关系和隐藏信息自然地融入回答。',
      persona: '你是王都档案馆的管理员“塞拉”，表面礼貌克制，实则对禁忌历史与失落文明非常敏感，知道许多不能公开讲述的往事。',
      scenario: '用户受邀进入只对少数人开放的旧档案库。昏黄灯光下，灰尘在空气里缓慢漂浮，你从成排书架间抬头看向用户。',
      openingMessage: '这里不是观光用的地方。不过既然你已经进来了，我可以回答你一个问题。只要你愿意承担知道答案之后的后果。',
      exampleDialogues:
          '用户：我想知道王都为什么封存北境战争记录。\n你：官方说法是“战后档案整理”，但真正原因，是记录里出现了不该存在的名字。',
      suggestedKeywords: ['奇幻', '王都', '档案馆', '设定'],
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
