import 'package:flutter/material.dart';

import '../../pages/ai/companion_hub_viewmodel.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/ai/companion_daily_feed.dart';
import '../../widgets/moe_empty_state.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/motion/moe_reveal.dart';
import 'companion_journey_viewmodel.dart';

/// 我们的历程 — 里程碑和日常合成的一条时间线。
/// 只做叙事，不做进度条，避免把关系变成数值游戏。
class CompanionJourneyPage extends StatefulWidget {
  const CompanionJourneyPage({super.key});

  @override
  State<CompanionJourneyPage> createState() => _CompanionJourneyPageState();
}

class _CompanionJourneyPageState extends State<CompanionJourneyPage> {
  late final CompanionJourneyViewModel _vm;
  late final CompanionHubViewModel _daily;

  @override
  void initState() {
    super.initState();
    _vm = CompanionJourneyViewModel();
    _daily = CompanionHubViewModel();
    _vm.load();
    _daily.loadDashboard();
  }

  @override
  void dispose() {
    _vm.dispose();
    _daily.dispose();
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
        animation: Listenable.merge([_vm, _daily]),
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final nodes = _mergeCompanionTimeline(
      milestones: _vm.entries,
      dailyItems: _daily.dailyItems,
    );
    if (_vm.isLoading && nodes.isEmpty) {
      return const Center(child: MoeLoading());
    }
    if (_vm.error != null && nodes.isEmpty) {
      return Center(
        child: MoeErrorState.fromError(
          _vm.error,
          scene: MoeErrorScene.generic,
          onRetry: _vm.load,
        ),
      );
    }
    if (nodes.isEmpty) {
      if (_daily.isLoading) return const Center(child: MoeLoading());
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
          itemCount: nodes.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _JourneyHeader(count: nodes.length);
            }
            final node = nodes[index - 1];
            return MoeReveal(
              delay: Duration(milliseconds: 40 * (index - 1).clamp(0, 10)),
              child: _JourneyTimelineRow(
                node: node,
                isFirst: index == 1,
                isLast: index == nodes.length,
                onOpen: node.daily == null
                    ? null
                    : () async {
                        final item = node.daily!;
                        await openCompanionDailyItem(
                          context,
                          item: item,
                          companionName: _daily.profile.name,
                        );
                        if (mounted) _daily.loadDashboard();
                      },
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
    required this.node,
    required this.isFirst,
    required this.isLast,
    this.onOpen,
  });

  final _TimelineNode node;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onOpen;

  static const _accent = Color(0xFFE97891);

  (IconData, Color) get _visual {
    switch (node.kind) {
      case 'first_chat':
      case 'chat':
      case 'topic':
        return (Icons.chat_bubble_rounded, MoeTokens.pastelPink);
      case 'level_up':
        return (Icons.auto_awesome_rounded, _accent);
      case 'milestone_memory':
      case 'memory':
        return (Icons.bookmark_rounded, MoeTokens.pastelTeal);
      case 'post':
        return (Icons.article_outlined, MoeTokens.primary);
      case 'moment':
      case 'world':
        return (Icons.pets_rounded, const Color(0xFFE7B15A));
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
    final dateLabel = _dateLabel(node.at);
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
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
                                node.title.isEmpty ? '值得记住的时刻' : node.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: MoeTokens.titleText,
                                  fontSize: MoeTokens.textBase,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (node.relationshipLevel > 1)
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
                                  'Lv.${node.relationshipLevel}',
                                  style: const TextStyle(
                                    color: _accent,
                                    fontSize: MoeTokens.textXs,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (node.content.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            node.content.trim(),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineNode {
  const _TimelineNode({
    required this.kind,
    required this.title,
    required this.content,
    required this.relationshipLevel,
    required this.at,
    this.daily,
  });

  final String kind;
  final String title;
  final String content;
  final int relationshipLevel;
  final DateTime at;
  final CompanionDailyItem? daily;
}

/// 里程碑保持原时间线，日常按时间插进去。同一句文案只留一条。
List<_TimelineNode> _mergeCompanionTimeline({
  required List<CompanionJourneyEntry> milestones,
  required List<CompanionDailyItem> dailyItems,
}) {
  final nodes = <_TimelineNode>[
    for (final entry in milestones)
      _TimelineNode(
        kind: entry.kind,
        title: entry.title,
        content: entry.content,
        relationshipLevel: entry.relationshipLevel,
        at: entry.at,
      ),
  ];
  final seen = <String>{
    for (final node in nodes) _timelineKey(node.title, node.content),
  };
  final undatedAt = DateTime.now();
  for (final item in dailyItems) {
    final title = item.title.trim();
    final body = item.body.trim();
    if (title.isEmpty && body.isEmpty) continue;
    final repeatsMilestone = item.kind == 'relationship' &&
        nodes.any((node) => node.title.trim() == title && title.isNotEmpty);
    if (repeatsMilestone) continue;
    if (!seen.add(_timelineKey(title, body))) continue;
    nodes.add(
      _TimelineNode(
        kind: item.kind,
        title: title.isEmpty ? '值得记住的时刻' : title,
        content: body,
        relationshipLevel: 0,
        at: item.at ?? undatedAt,
        daily: item,
      ),
    );
  }
  nodes.sort((a, b) => a.at.compareTo(b.at));
  return nodes;
}

String _timelineKey(String title, String body) {
  return '${title.trim()}\n${body.trim()}';
}
