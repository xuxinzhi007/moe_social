import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/motion/moe_reveal.dart';
import 'companion_journey_viewmodel.dart';

/// 我们的历程 — 关系里程碑时间线（关系事件 + 里程碑记忆）。
/// 只做叙事时间线，不做进度条，避免把关系变成数值游戏。
class CompanionJourneyPage extends StatefulWidget {
  const CompanionJourneyPage({super.key});

  @override
  State<CompanionJourneyPage> createState() => _CompanionJourneyPageState();
}

class _CompanionJourneyPageState extends State<CompanionJourneyPage> {
  late final CompanionJourneyViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = CompanionJourneyViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('我们的历程'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: MoeTokens.surface1,
        foregroundColor: MoeTokens.titleText,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/ai-memories'),
            child: const Text('记得的事'),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _vm,
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_vm.isLoading && _vm.entries.isEmpty) {
      return const Center(child: MoeLoading());
    }
    if (_vm.error != null && _vm.entries.isEmpty) {
      return Center(
        child: MoeErrorState.fromError(
          _vm.error,
          scene: MoeErrorScene.generic,
          onRetry: _vm.load,
        ),
      );
    }
    if (_vm.entries.isEmpty) {
      return Center(
        child: MoeEmptyState(
          icon: Icons.favorite_rounded,
          title: '你们的历程才刚刚开始',
          subtitle: '去和 TA 聊聊，创造第一个里程碑',
          primaryAction: MoeEmptyStateAction(
            label: '去聊天',
            icon: Icons.chat_bubble_rounded,
            onPressed: () => Navigator.pushNamed(context, '/ai-chat'),
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          itemCount: _vm.entries.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _JourneyHeader(count: _vm.entries.length);
            }
            final entry = _vm.entries[index - 1];
            return MoeReveal(
              delay: Duration(milliseconds: 40 * (index - 1).clamp(0, 10)),
              child: _JourneyTimelineRow(
                entry: entry,
                isFirst: index == 1,
                isLast: index == _vm.entries.length,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        '从第一次相遇到现在，已经积累了 $count 个值得记住的时刻',
        style: const TextStyle(
          color: MoeTokens.hintText,
          fontSize: MoeTokens.textSm,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _JourneyTimelineRow extends StatelessWidget {
  const _JourneyTimelineRow({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final CompanionJourneyEntry entry;
  final bool isFirst;
  final bool isLast;

  static const _accent = Color(0xFFE97891);

  (IconData, Color) get _visual {
    switch (entry.kind) {
      case 'first_chat':
        return (Icons.chat_bubble_rounded, MoeTokens.pastelPink);
      case 'level_up':
        return (Icons.auto_awesome_rounded, _accent);
      case 'milestone_memory':
        return (Icons.bookmark_rounded, MoeTokens.pastelTeal);
      default:
        return (Icons.favorite_rounded, MoeTokens.primary);
    }
  }

  String _dateLabel(DateTime at) {
    if (at.millisecondsSinceEpoch == 0) return '';
    return '${at.year}年${at.month}月${at.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = _visual;
    final dateLabel = _dateLabel(entry.at);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: tint.withValues(alpha: 0.35)),
                  ),
                  child: Icon(icon, size: 14, color: tint),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: MoeTokens.surfaceBorder,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: MoeTokens.surface1,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                  border: Border.all(color: MoeTokens.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title.isEmpty ? '值得记住的时刻' : entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MoeTokens.titleText,
                              fontSize: MoeTokens.textBase,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (entry.relationshipLevel > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(
                                MoeTokens.radiusFull,
                              ),
                            ),
                            child: Text(
                              'Lv.${entry.relationshipLevel}',
                              style: const TextStyle(
                                color: _accent,
                                fontSize: MoeTokens.textXs,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (entry.content.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.content.trim(),
                        style: const TextStyle(
                          color: MoeTokens.caption,
                          fontSize: MoeTokens.textSm,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (dateLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        isFirst ? '$dateLabel · 起点' : dateLabel,
                        style: const TextStyle(
                          color: MoeTokens.hintText,
                          fontSize: MoeTokens.textXs,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
