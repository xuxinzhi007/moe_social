import '../models/ai_agent.dart';

/// 按角色卡字段生成快捷回复，避免通用「学习效率」类文案。
List<String> buildAgentQuickReplies(AiAgent agent) {
  final replies = <String>[];
  final seen = <String>{};

  void add(String text) {
    final t = text.trim();
    if (t.isEmpty || t.length > 48) return;
    if (seen.add(t)) replies.add(t);
  }

  final opening = agent.openingMessage.trim();
  if (opening.isNotEmpty) {
    add('继续刚才的话题');
    if (opening.contains('?') || opening.contains('？')) {
      add('我想先听听你的建议');
    }
  }

  final scenario = agent.scenario.trim();
  if (scenario.isNotEmpty) {
    add('我们现在在哪里？');
    add('描述一下周围的氛围');
  }

  final persona = agent.persona.trim();
  if (persona.contains('温柔') || persona.contains('陪伴')) {
    add('（靠近一点，轻声说话）');
  } else if (persona.contains('傲娇') || persona.contains('毒舌')) {
    add('（别过头，假装不在意）');
  } else {
    add('（自然地继续聊下去）');
  }

  add('今天过得怎么样？');
  add('给我一点小惊喜');
  add('我有点想你了');

  if (replies.length < 4) {
    add('你好呀');
    add('换个话题聊聊');
  }

  return replies.take(6).toList();
}
