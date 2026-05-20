/// 从用户消息中规则提取可持久化的账号级事实（不依赖 LLM）。
abstract final class MemoryHeuristicExtract {
  static List<Map<String, String>> fromUserMessage(String userMessage) {
    final text = userMessage.trim();
    if (text.isEmpty) return const [];

    // 用户在给 AI 改角色名，不是用户自己的昵称。
    if (RegExp(r'^你(?:现在|以后|今晚)?(?:叫|是)').hasMatch(text)) {
      return const [];
    }

    final items = <Map<String, String>>[];

    void addNickname(String raw) {
      final name = _cleanName(raw);
      if (name == null) return;
      items.add({
        'key': 'user_nickname',
        'value': name,
        'memory_type': 'identity',
      });
    }

    final patterns = <RegExp>[
      RegExp(r'我(?:现在|已经|又)?改(?:了|成)?名(?:叫|为|成)?[「"“]?([^」"”\s，。!！?？\n]+)'),
      RegExp(r'我(?:现在)?叫[「"“]?([^」"”\s，。!！?？\n]+)'),
      RegExp(r'(?:请)?叫我[「"“]?([^」"”\s，。!！?？\n]+)'),
      RegExp(r'我的名字(?:是|叫)[「"“]?([^」"”\s，。!！?？\n]+)'),
      RegExp(r'以后请叫我[「"“]?([^」"”\s，。!！?？\n]+)'),
      RegExp(r'请记住[，,]?我(?:叫|是)[「"“]?([^」"”\s，。!！?？\n]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        addNickname(match.group(1)!);
        break;
      }
    }

    final remember = RegExp(
      r'记住[：:]?\s*(?:我)?(?:喜欢|爱|讨厌|不爱)([^，。!！?？\n]{1,40})',
    ).firstMatch(text);
    if (remember != null) {
      final value = remember.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        items.add({
          'key': 'user_preference',
          'value': value,
          'memory_type': 'preference',
        });
      }
    }

    return items;
  }

  static String? _cleanName(String raw) {
    var name = raw.trim();
    name = name.replaceAll(RegExp(r'^[「"“]|[」"”]$'), '');
    name = name.replaceAll(RegExp(r'[吧呢啊呀]$'), '');
    if (name.isEmpty || name.length > 24) return null;
    if (RegExp(r'^(你|我|他|她|它|管理员|角色)').hasMatch(name) && name.length <= 2) {
      return null;
    }
    return name;
  }
}
