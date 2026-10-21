import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';
import 'llm_api_service.dart';

/// 模型服务是否在线。目录接口能返回即在线，请求失败即离线。
class CompanionModelPresence extends ChangeNotifier {
  CompanionModelPresence._();

  static final CompanionModelPresence instance = CompanionModelPresence._();

  /// null 表示还在确认。
  bool? online;

  Future<void>? _inflight;

  Future<void> refresh() {
    final current = _inflight;
    if (current != null) return current;
    final run = _load();
    _inflight = run;
    return run.whenComplete(() {
      if (identical(_inflight, run)) _inflight = null;
    });
  }

  Future<void> _load() async {
    bool next;
    try {
      await LlmApiService.fetchCatalog();
      next = true;
    } catch (_) {
      next = false;
    }
    if (next == online) return;
    online = next;
    notifyListeners();
  }
}

/// 首页和聊天顶栏共用的在线状态。
class CompanionModelStatusChip extends StatelessWidget {
  const CompanionModelStatusChip({super.key, this.onTap, this.compact = false});

  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CompanionModelPresence.instance,
      builder: (context, _) {
        final online = CompanionModelPresence.instance.online;
        final label = switch (online) {
          null => '检查中',
          true => '在线',
          false => '离线',
        };
        final color = switch (online) {
          null => MoeTokens.hintText,
          true => MoeTokens.success,
          false => MoeTokens.danger,
        };
        final chip = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 6 : 7,
              height: compact ? 6 : 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: compact ? 5 : 5),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 11 : 10,
                fontWeight: FontWeight.w800,
                color: compact ? MoeTokens.hintText : MoeTokens.inkMuted,
              ),
            ),
          ],
        );
        if (onTap == null) return chip;
        return GestureDetector(onTap: onTap, child: chip);
      },
    );
  }
}
