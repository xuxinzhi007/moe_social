import 'memory_service.dart';

/// OpenClaw 式日记层：`memory/YYYY-MM-DD.md` 在 KV 库中的等价实现。
abstract final class MemoryDailyNote {
  static const String keyPrefix = 'daily_note:';

  static String dailyKey([DateTime? at]) {
    final d = (at ?? DateTime.now()).toUtc();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$keyPrefix$y-$m-$day';
  }

  static bool isDailyKey(String key) =>
      key.toLowerCase().startsWith(keyPrefix);

  /// 追加一行到今日日记（合并写入，不覆盖历史行）。
  static Future<void> appendObservation(
    String userId,
    String line, {
    String? sessionId,
    String? sourceMsgId,
    String source = 'daily_observation',
  }) async {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    final key = dailyKey();
    var existing = '';
    try {
      final list = await MemoryService.getUserMemories(userId);
      for (final m in list) {
        if (m.key == key) {
          existing = m.value;
          break;
        }
      }
    } catch (_) {}

    final merged = _merge(existing, trimmed);
    await MemoryService.upsertUserMemory(
      userId: userId,
      key: key,
      value: merged,
      memoryType: 'observation',
      source: source,
      sourceMsgId: sourceMsgId,
      sessionId: sessionId,
      confidence: 0.5,
    );
  }

  /// 加载今日与昨日日记正文（OpenClaw 默认加载两日）。
  static Future<List<({String date, String body})>> loadRecent(
    String userId, {
    int days = 2,
  }) async {
    final now = DateTime.now().toUtc();
    final want = <String>{
      for (var i = 0; i < days; i++)
        dailyKey(now.subtract(Duration(days: i))),
    };
    final out = <({String date, String body})>[];
    try {
      final list = await MemoryService.getUserMemories(userId);
      for (final m in list) {
        if (!want.contains(m.key)) continue;
        final body = m.value.trim();
        if (body.isEmpty) continue;
        final date = m.key.substring(keyPrefix.length);
        out.add((date: date, body: body));
      }
    } catch (_) {}
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static String _merge(String existing, String line) {
    final base = existing.trim();
    if (base.isEmpty) return line;
    if (base.contains(line)) return base;
    return '$base\n$line';
  }
}
