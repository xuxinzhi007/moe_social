import '../models/user_memory.dart';
import '../models/user_memory_display.dart' show UserMemoryDisplayProfile;

/// 与 `backend/pkg/memory.DefaultBootstrapBudget` 对齐的客户端注入预算。
class MemoryBootstrapBudget {
  final int maxProfileRunes;
  final int maxDailyRunes;
  final int maxSearchItems;
  final int maxSearchRunes;

  const MemoryBootstrapBudget({
    this.maxProfileRunes = 280,
    this.maxDailyRunes = 400,
    this.maxSearchItems = 8,
    this.maxSearchRunes = 520,
  });

  static const MemoryBootstrapBudget defaults = MemoryBootstrapBudget();

  factory MemoryBootstrapBudget.fromApiMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    int pick(String snake, String camel, int fallback) {
      final v = raw[snake] ?? raw[camel];
      if (v is num) return v.toInt();
      return fallback;
    }

    return MemoryBootstrapBudget(
      maxProfileRunes: pick(
        'bootstrap_max_profile_runes',
        'bootstrapMaxProfileRunes',
        defaults.maxProfileRunes,
      ),
      maxDailyRunes: pick(
        'bootstrap_max_daily_runes',
        'bootstrapMaxDailyRunes',
        defaults.maxDailyRunes,
      ),
      maxSearchItems: pick(
        'bootstrap_max_search_items',
        'bootstrapMaxSearchItems',
        defaults.maxSearchItems,
      ),
      maxSearchRunes: pick(
        'bootstrap_max_search_runes',
        'bootstrapMaxSearchRunes',
        defaults.maxSearchRunes,
      ),
    );
  }
}

int memoryRuneLength(String text) => text.runes.length;

String truncateMemoryRunes(String text, int maxRunes) {
  if (maxRunes <= 0) return '';
  final runes = text.runes.toList();
  if (runes.length <= maxRunes) return text;
  return '${String.fromCharCodes(runes.take(maxRunes))}…';
}

/// OpenClaw 式分层块（精选 → 日记 → 检索），与 [ComposeBootstrap] 同序。
abstract final class MemoryBootstrapComposer {
  static String? profilesBlock(
    List<UserMemoryDisplayProfile> profiles, {
    MemoryBootstrapBudget budget = MemoryBootstrapBudget.defaults,
  }) {
    if (budget.maxProfileRunes <= 0) return null;
    final lines = <String>[];
    var used = 0;
    const header = '=== 用户长期画像（精选层 / MEMORY）===';
    used += memoryRuneLength(header) + 1;

    final limit = profiles.length < 6 ? profiles.length : 6;
    for (var i = 0; i < limit; i++) {
      final p = profiles[i];
      final summary = p.summary.trim();
      if (summary.isEmpty) continue;
      final line = '- ${p.title}：$summary';
      final cost = memoryRuneLength(line) + 1;
      if (used + cost > budget.maxProfileRunes && lines.isNotEmpty) break;
      lines.add(line);
      used += cost;
    }
    if (lines.isEmpty) return null;
    return '$header\n${lines.join('\n')}';
  }

  static String? dailyBlock(
    List<({String date, String body})> daily, {
    MemoryBootstrapBudget budget = MemoryBootstrapBudget.defaults,
  }) {
    if (budget.maxDailyRunes <= 0 || daily.isEmpty) return null;
    final buffer = StringBuffer('=== 近期日记（工作记忆，今日/昨日）===\n');
    var used = memoryRuneLength(buffer.toString());
    var wrote = false;
    for (final d in daily) {
      final chunk = '[${d.date}]\n${d.body}\n';
      final cost = memoryRuneLength(chunk);
      if (used + cost > budget.maxDailyRunes && wrote) break;
      buffer.write(chunk);
      used += cost;
      wrote = true;
    }
    if (!wrote) return null;
    return buffer.toString().trimRight();
  }

  static String? searchBlock(
    List<UserMemory> memories, {
    MemoryBootstrapBudget budget = MemoryBootstrapBudget.defaults,
  }) {
    if (budget.maxSearchRunes <= 0 || memories.isEmpty) return null;
    final buffer = StringBuffer('=== 与本句相关的记忆检索 ===\n');
    var used = memoryRuneLength(buffer.toString());
    var count = 0;
    final maxItems = budget.maxSearchItems > 0 ? budget.maxSearchItems : 8;
    for (final memory in memories) {
      if (count >= maxItems) break;
      final content = memory.value.trim();
      if (content.isEmpty) continue;
      final line = '- $content';
      final cost = memoryRuneLength(line) + 1;
      if (used + cost > budget.maxSearchRunes && count > 0) break;
      buffer.writeln(line);
      used += cost;
      count++;
    }
    if (count == 0) return null;
    return buffer.toString().trimRight();
  }

  static String composeTail() {
    return '请把以上信息当作你已了解的用户背景，在合适时自然参考，不要机械复述。';
  }
}
